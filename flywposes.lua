--!nonstrict
--[[
	flywposes.lua — client-side flight with the System Broken fly poses.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/scripts/main/flywposes.lua"))()

	F           toggle flight
	WASD        move, camera relative
	Space       rise
	Left Ctrl   descend
	Left Shift  sprint

	The poses are the ones System Broken uses. That script does not just play an
	animation: it plays it and then freezes the track at a fixed TimePosition
	with speed 0, so the character holds one still pose instead of cycling the
	clip. These are the same asset ids and the same TimePositions, done the same
	way. Each pose is { id = <asset id>, time = <seconds> }.

	System Broken has no separate pose for rising or descending, so those two
	hold the hover pose. Change any time value if a clip doesn't freeze on the
	frame you want.
]]

if _G.FlywPosesCleanup then
	pcall(_G.FlywPosesCleanup)
	_G.FlywPosesCleanup = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

local CONFIG = {
	toggleKey = Enum.KeyCode.F,
	speed = 50,
	sprintMultiplier = 1.8,
	verticalSpeed = 46,
	acceleration = 10,
	pitch = 20,
	bank = 26,
	poseFade = 0.2,
	showBadge = true,

	-- id and time are straight out of System Broken's PlayAnim(id, time, speed) calls.
	poses = {
		hover   = { id = 10714347256, time = 4.00 },
		forward = { id = 10714177846, time = 4.65 },
		back    = { id = 10147823318, time = 4.11 },
		left    = { id = 10147823318, time = 3.55 },
		right   = { id = 10147823318, time = 4.81 },
		up      = { id = 10714347256, time = 4.00 },
		down    = { id = 10714347256, time = 4.00 },
	},
}

local wantFly = false
local flying = false
local humanoid, root, animator, animateScript
local bodyVelocity, bodyGyro
local stepConn, deathConn, spawnConn, inputConn
local poseTracks = {}
local poseAssets = {}
local poseFailures = {}
local activePose
local badge
local badgeLabel
local badgeSpeed

local function setBadge(on)
	if not CONFIG.showBadge then return end

	if not on then
		if badge then
			badge:Destroy()
			badge = nil
		end
		badgeLabel = nil
		badgeSpeed = nil
		return
	end

	if badge then return end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FlywPosesBadge"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromOffset(126, 34)
	pill.Position = UDim2.new(0, 20, 1, -54)
	pill.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(64, 67, 76)
	stroke.Thickness = 2
	stroke.Parent = pill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(232, 234, 238)
	label.Text = string.format("FLY  %d", CONFIG.speed)
	label.Parent = pill

	gui.Parent = playerGui

	badge = gui
	badgeLabel = label
	badgeSpeed = CONFIG.speed
end

local function toAssetId(value)
	if typeof(value) == "number" then
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if typeof(value) == "string" and value ~= "" then
		if tonumber(value) then
			return "rbxassetid://" .. value
		end
		return value
	end
	return nil
end

local function getPoseTrack(name)
	local cached = poseTracks[name]
	if cached then return cached end
	if poseFailures[name] then return nil end

	local pose = CONFIG.poses[name]
	local id = pose and toAssetId(pose.id)
	if not id or not animator then return nil end

	local asset = Instance.new("Animation")
	asset.Name = "FlywPose_" .. name
	asset.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(asset)
	end)

	if not ok or not track then
		asset:Destroy()
		poseFailures[name] = true
		return nil
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	poseTracks[name] = track
	poseAssets[name] = asset
	return track
end

-- System Broken plays the track, jumps it to a fixed TimePosition and sets the
-- speed to 0, which freezes the clip on that frame. TimePosition can't be set
-- until the track has loaded, so wait for Length and clamp to it.
local function freezeAt(track, time)
	task.spawn(function()
		local deadline = os.clock() + 4
		while track.Length <= 0 and os.clock() < deadline do
			task.wait()
		end
		local length = track.Length
		if length <= 0 then return end
		local target = math.clamp(time, 0, math.max(0, length - 0.02))
		pcall(function()
			track.TimePosition = target
		end)
		pcall(function()
			track:AdjustSpeed(0)
		end)
	end)
end

local function stopAllPoses(fade)
	for _, track in pairs(poseTracks) do
		pcall(function()
			track:Stop(fade or 0)
		end)
	end
	activePose = nil
end

local function setPose(name)
	if activePose == name then return end

	local pose = CONFIG.poses[name]
	if not pose then
		name = "hover"
		pose = CONFIG.poses.hover
	end

	local nextTrack = getPoseTrack(name)
	if not nextTrack then
		stopAllPoses(CONFIG.poseFade)
		return
	end

	local previous = activePose and poseTracks[activePose]
	if previous and previous ~= nextTrack then
		pcall(function()
			previous:Stop(CONFIG.poseFade)
		end)
	end

	-- speed 0 on Play, so the clip never moves forward while it fades in
	pcall(function()
		nextTrack:Play(CONFIG.poseFade, 1, 0)
	end)
	freezeAt(nextTrack, pose.time)
	activePose = name
end

local function preloadPoses()
	local list = {}
	for _, track in pairs(poseTracks) do
		list[#list + 1] = track
	end
	for _, asset in pairs(poseAssets) do
		list[#list + 1] = asset
	end
	if #list == 0 then return end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

local function stopFly(keepWanted)
	flying = false
	if not keepWanted then
		wantFly = false
	end

	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	stopAllPoses(CONFIG.poseFade)

	for _, asset in pairs(poseAssets) do
		pcall(function()
			asset:Destroy()
		end)
	end
	poseTracks = {}
	poseAssets = {}

	if animateScript and animateScript.Parent then
		pcall(function()
			animateScript.Disabled = false
		end)
	end

	if humanoid and humanoid.Parent then
		pcall(function()
			humanoid.PlatformStand = false
		end)
	end

	setBadge(false)
end

local function onStep(dt)
	if not flying then return end
	if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return end

	local camera = workspace.CurrentCamera
	if not camera or not bodyVelocity or not bodyGyro then return end

	local keyDown = UserInputService.IsKeyDown
	local forwardInput = (keyDown(UserInputService, Enum.KeyCode.W) and 1 or 0)
		- (keyDown(UserInputService, Enum.KeyCode.S) and 1 or 0)
	local strafeInput = (keyDown(UserInputService, Enum.KeyCode.D) and 1 or 0)
		- (keyDown(UserInputService, Enum.KeyCode.A) and 1 or 0)
	local riseInput = (keyDown(UserInputService, Enum.KeyCode.Space) and 1 or 0)
		- (keyDown(UserInputService, Enum.KeyCode.LeftControl) and 1 or 0)
	local sprinting = keyDown(UserInputService, Enum.KeyCode.LeftShift)

	local camCF = camera.CFrame
	local lookFlat = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	local rightFlat = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
	if lookFlat.Magnitude < 0.01 then
		lookFlat = Vector3.new(0, 0, -1)
	else
		lookFlat = lookFlat.Unit
	end
	if rightFlat.Magnitude < 0.01 then
		rightFlat = Vector3.new(1, 0, 0)
	else
		rightFlat = rightFlat.Unit
	end

	local speed = CONFIG.speed * (sprinting and CONFIG.sprintMultiplier or 1)

	local horizontal = lookFlat * forwardInput + rightFlat * strafeInput
	if horizontal.Magnitude > 1 then
		horizontal = horizontal.Unit
	end

	local target = horizontal * speed + Vector3.new(0, riseInput * CONFIG.verticalSpeed, 0)

	local alpha = 1 - math.exp(-CONFIG.acceleration * dt)
	bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(target, alpha)

	local pitch = -math.rad(CONFIG.pitch) * forwardInput
	local roll = -math.rad(CONFIG.bank) * strafeInput
	bodyGyro.CFrame = camCF * CFrame.Angles(pitch, 0, roll)

	local poseName = "hover"
	if horizontal.Magnitude > 0.1 then
		if math.abs(forwardInput) >= math.abs(strafeInput) then
			poseName = forwardInput > 0 and "forward" or "back"
		else
			poseName = strafeInput > 0 and "right" or "left"
		end
	elseif riseInput > 0 then
		poseName = "up"
	elseif riseInput < 0 then
		poseName = "down"
	end
	setPose(poseName)

	local shown = math.floor(speed)
	if badgeLabel and shown ~= badgeSpeed then
		badgeSpeed = shown
		badgeLabel.Text = string.format("FLY  %d", shown)
	end
end

local function bindCharacter()
	local character = player.Character
	if not character then return false end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return false end

	humanoid = hum
	root = hrp
	animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	animateScript = character:FindFirstChild("Animate")

	if deathConn then
		deathConn:Disconnect()
	end
	deathConn = hum.Died:Connect(function()
		stopFly(true)
	end)

	return true
end

local function startFly()
	if flying then return true end
	if not bindCharacter() then return false end

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bodyVelocity.P = 1250
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = root

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bodyGyro.P = 9e4
	bodyGyro.D = 500
	bodyGyro.CFrame = root.CFrame
	bodyGyro.Parent = root

	pcall(function()
		humanoid.PlatformStand = true
	end)

	-- holds the default idle/walk off the character so the pose owns the frame
	if animateScript then
		pcall(function()
			animateScript.Disabled = true
		end)
	end

	flying = true
	activePose = nil
	setPose("hover")
	preloadPoses()
	setBadge(true)

	stepConn = RunService.RenderStepped:Connect(onStep)
	return true
end

local function toggle()
	if wantFly then
		stopFly(false)
		return
	end
	wantFly = true
	if not startFly() then
		wantFly = false
	end
end

_G.FlywPosesToggle = toggle

inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == CONFIG.toggleKey then
		toggle()
	end
end)

spawnConn = player.CharacterAdded:Connect(function(character)
	stopFly(true)
	humanoid, root, animator, animateScript = nil, nil, nil, nil
	poseTracks, poseAssets, poseFailures = {}, {}, {}
	activePose = nil

	local hum = character:WaitForChild("Humanoid", 10)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if wantFly and hum and hrp then
		task.wait(0.2)
		if wantFly and not flying then
			startFly()
		end
	end
end)

_G.FlywPosesCleanup = function()
	stopFly(false)
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	if spawnConn then
		spawnConn:Disconnect()
		spawnConn = nil
	end
	if deathConn then
		deathConn:Disconnect()
		deathConn = nil
	end
	_G.FlywPosesToggle = nil
end
