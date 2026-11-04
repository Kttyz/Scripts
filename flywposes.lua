--!nonstrict
--[[
	flywposes.lua — client-side flight with pose animations.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/scripts/main/flywposes.lua"))()

	F           toggle flight
	WASD        move, camera relative
	Space       rise
	Left Ctrl   descend
	Left Shift  sprint

	Poses live in CONFIG.poses as animation asset ids. Leave one nil and the
	script borrows the matching animation already on your avatar, so it flies
	out of the box; paste your own ids to take over. The character is held in
	the pose with an AnimationPriority.Action track, so the pose wins over the
	default fall and walk animations while you fly.
]]

if _G.FlywPosesCleanup then
	pcall(_G.FlywPosesCleanup)
	_G.FlywPosesCleanup = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local CONFIG = {
	toggleKey = Enum.KeyCode.F,
	speed = 62,
	sprintMultiplier = 1.8,
	verticalSpeed = 46,
	acceleration = 10,
	pitch = 20,
	bank = 26,
	poseFade = 0.25,
	showBadge = true,

	-- nil = borrow from your avatar. Number or "rbxassetid://..." = use that.
	poses = {
		hover = nil,
		forward = nil,
		back = nil,
		left = nil,
		right = nil,
		up = nil,
		down = nil,
	},
}

local POSE_FALLBACK = {
	hover = "fall",
	forward = "swim",
	back = "fall",
	left = "swim",
	right = "swim",
	up = "jump",
	down = "fall",
}

local wantFly = false
local flying = false
local humanoid, root, animator
local bodyVelocity, bodyGyro
local stepConn, deathConn, spawnConn, inputConn
local resolvedPoses = {}
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

local function readAvatarAnimations(character)
	local ids = {}
	local animate = character:FindFirstChild("Animate")
	if not animate then return ids end
	for _, item in ipairs(animate:GetDescendants()) do
		if item:IsA("Animation") then
			local key = string.lower(item.Name)
			if not ids[key] and item.AnimationId ~= "" then
				ids[key] = item.AnimationId
			end
		end
	end
	return ids
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

local function resolvePoses(character)
	local avatarIds = readAvatarAnimations(character)
	resolvedPoses = {}
	for name, fallbackName in pairs(POSE_FALLBACK) do
		local id = toAssetId(CONFIG.poses[name]) or avatarIds[fallbackName]
		if id and id ~= "" then
			resolvedPoses[name] = id
		end
	end
end

local function getPoseTrack(name)
	local cached = poseTracks[name]
	if cached then return cached end
	if poseFailures[name] then return nil end

	local id = resolvedPoses[name]
	if not id or not animator then return nil end

	local asset = Instance.new("Animation")
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

local function setPose(name, force)
	if not force and activePose == name then return end
	if not resolvedPoses[name] then
		name = "hover"
	end
	if not force and activePose == name then return end

	local nextTrack = getPoseTrack(name)
	if not nextTrack then
		if activePose and poseTracks[activePose] then
			poseTracks[activePose]:Stop(CONFIG.poseFade)
		end
		activePose = nil
		return
	end

	if activePose and poseTracks[activePose] and activePose ~= name then
		poseTracks[activePose]:Stop(CONFIG.poseFade)
	end

	nextTrack:Play(CONFIG.poseFade, 1, 1)
	activePose = name
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

	for _, track in pairs(poseTracks) do
		pcall(function()
			track:Stop(CONFIG.poseFade)
		end)
	end
	for _, asset in pairs(poseAssets) do
		pcall(function()
			asset:Destroy()
		end)
	end
	poseTracks = {}
	poseAssets = {}
	activePose = nil

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

	resolvePoses(character)

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

	flying = true
	setPose("hover", true)
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
	humanoid, root, animator = nil, nil, nil
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
