-- Freecam Module (for Unified Hub)
-- F6 (or custom key): toggle | WASD: move | Q/E: up/down | Shift: faster | Right mouse: look

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local TOGGLE_KEY = Enum.KeyCode.F6
local NORMAL_SPEED = 32
local FAST_SPEED = 90
local LOOK_SENSITIVITY = 0.0025

if _G.FreecamCleanup then
	pcall(_G.FreecamCleanup)
end

local connections = {}
local enabled = false
local looking = false
local keysDown = {}
local yaw, pitch = 0, 0
local cameraPosition

local savedCameraType
local savedCameraSubject
local savedRootPart
local savedRootAnchored
local savedHumanoid
local savedWalkSpeed
local savedJumpPower
local savedJumpHeight
local savedUseJumpPower
local savedAutoRotate

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function getCamera()
	return Workspace.CurrentCamera
end

local function freezeCharacter()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	savedHumanoid, savedRootPart = humanoid, rootPart

	if humanoid then
		savedWalkSpeed = humanoid.WalkSpeed
		savedJumpPower = humanoid.JumpPower
		savedJumpHeight = humanoid.JumpHeight
		savedUseJumpPower = humanoid.UseJumpPower
		savedAutoRotate = humanoid.AutoRotate
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end
	if rootPart then
		savedRootAnchored = rootPart.Anchored
		rootPart.Anchored = true
	end
end

local function unfreezeCharacter()
	if savedRootPart and savedRootPart.Parent then
		savedRootPart.Anchored = savedRootAnchored == true
	end
	if savedHumanoid and savedHumanoid.Parent then
		savedHumanoid.WalkSpeed = savedWalkSpeed or 16
		savedHumanoid.JumpPower = savedJumpPower or 50
		savedHumanoid.JumpHeight = savedJumpHeight or 7.2
		savedHumanoid.UseJumpPower = savedUseJumpPower == true
		savedHumanoid.AutoRotate = savedAutoRotate ~= false
	end
	savedRootPart, savedHumanoid = nil, nil
end

local function setEnabled(shouldEnable)
	if enabled == shouldEnable then return end
	local camera = getCamera()
	if not camera then return end

	enabled = shouldEnable
	looking = false
	keysDown = {}

	if enabled then
		savedCameraType = camera.CameraType
		savedCameraSubject = camera.CameraSubject
		cameraPosition = camera.CFrame.Position
		local x, y = camera.CFrame:ToOrientation()
		pitch, yaw = x, y
		camera.CameraType = Enum.CameraType.Scriptable
		freezeCharacter()
	else
		camera.CameraType = savedCameraType or Enum.CameraType.Custom
		camera.CameraSubject = savedCameraSubject
		unfreezeCharacter()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

local function cleanup()
	setEnabled(false)
	for _, connection in ipairs(connections) do
		pcall(function() connection:Disconnect() end)
	end
	connections = {}
end

_G.FreecamCleanup = cleanup

connect(UserInputService.InputBegan, function(input, gameProcessed)
	if input.KeyCode == TOGGLE_KEY and not gameProcessed then
		setEnabled(not enabled)
		return
	end
	if not enabled or gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		looking = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseIconEnabled = false
	elseif input.KeyCode ~= Enum.KeyCode.Unknown then
		keysDown[input.KeyCode] = true
	end
end)

connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		looking = false
		if enabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	elseif input.KeyCode ~= Enum.KeyCode.Unknown then
		keysDown[input.KeyCode] = nil
	end
end)

connect(UserInputService.InputChanged, function(input)
	if enabled and looking and input.UserInputType == Enum.UserInputType.MouseMovement then
		yaw -= input.Delta.X * LOOK_SENSITIVITY
		pitch = math.clamp(pitch - input.Delta.Y * LOOK_SENSITIVITY, math.rad(-89), math.rad(89))
	end
end)

connect(RunService.RenderStepped, function(deltaTime)
	if not enabled then return end
	local camera = getCamera()
	if not camera then return end

	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local movement = Vector3.zero
	if keysDown[Enum.KeyCode.W] then movement += rotation.LookVector end
	if keysDown[Enum.KeyCode.S] then movement -= rotation.LookVector end
	if keysDown[Enum.KeyCode.D] then movement += rotation.RightVector end
	if keysDown[Enum.KeyCode.A] then movement -= rotation.RightVector end
	if keysDown[Enum.KeyCode.E] then movement += Vector3.yAxis end
	if keysDown[Enum.KeyCode.Q] then movement -= Vector3.yAxis end

	if movement.Magnitude > 0 then
		local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		cameraPosition += movement.Unit * (fast and FAST_SPEED or NORMAL_SPEED) * deltaTime
	end
	camera.CFrame = CFrame.new(cameraPosition) * rotation
end)
