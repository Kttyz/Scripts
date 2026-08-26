-- Freecam (Standalone GUI)
-- F6 (or custom key): toggle | WASD: move | Q/E: up/down | Shift: faster | Right mouse: look

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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
	if gui then gui:Destroy() end
end

_G.FreecamCleanup = cleanup

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "FreecamGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(280, 340)
main.Position = UDim2.new(0, 20, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", main).Color = Color3.fromRGB(85, 85, 95)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundTransparency = 1
titleBar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "Freecam"
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.fromOffset(26, 26)
minimizeBtn.Position = UDim2.new(1, -62, 0, 4)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.new(1, 1, 1)
minimizeBtn.TextSize = 16
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 65)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.fromOffset(10, 42)
content.BackgroundTransparency = 1
content.Parent = main

local function makeLabel(text, y)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 20)
	lbl.Position = UDim2.fromOffset(0, y)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(190, 190, 200)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = content
	return lbl
end

local statusLbl = makeLabel("Status: OFF", 0)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, 0, 0, 34)
toggleBtn.Position = UDim2.fromOffset(0, 28)
toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 140)
toggleBtn.Text = "Toggle Freecam"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = content
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

makeLabel("Keybind (click then press a key):", 75)

local keybindBtn = Instance.new("TextButton")
keybindBtn.Size = UDim2.new(1, 0, 0, 32)
keybindBtn.Position = UDim2.fromOffset(0, 100)
keybindBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
keybindBtn.Text = "Current: F6"
keybindBtn.TextColor3 = Color3.new(1, 1, 1)
keybindBtn.TextSize = 13
keybindBtn.Font = Enum.Font.GothamBold
keybindBtn.Parent = content
Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 4)

makeLabel("Normal Speed:", 145)

local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(1, 0, 0, 28)
speedBox.Position = UDim2.fromOffset(0, 168)
speedBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
speedBox.Text = tostring(NORMAL_SPEED)
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.Font = Enum.Font.Gotham
speedBox.TextSize = 14
speedBox.Parent = content
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 4)

makeLabel("Fast Speed (Shift):", 208)

local fastBox = Instance.new("TextBox")
fastBox.Size = UDim2.new(1, 0, 0, 28)
fastBox.Position = UDim2.fromOffset(0, 231)
fastBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
fastBox.Text = tostring(FAST_SPEED)
fastBox.TextColor3 = Color3.new(1, 1, 1)
fastBox.Font = Enum.Font.Gotham
fastBox.TextSize = 14
fastBox.Parent = content
Instance.new("UICorner", fastBox).CornerRadius = UDim.new(0, 4)

-- ==================== GUI LOGIC ====================
local waitingForKey = false
local minimized = false
local expandedSize = Vector2.new(280, 340)

connect(toggleBtn.MouseButton1Click, function()
	setEnabled(not enabled)
	statusLbl.Text = enabled and "Status: ON" or "Status: OFF"
	toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(60, 100, 140)
end)

connect(keybindBtn.MouseButton1Click, function()
	waitingForKey = true
	keybindBtn.Text = "Press any key..."
	keybindBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 40)
end)

connect(speedBox.FocusLost, function()
	local n = tonumber(speedBox.Text)
	if n and n > 0 then
		NORMAL_SPEED = n
	end
	speedBox.Text = tostring(NORMAL_SPEED)
end)

connect(fastBox.FocusLost, function()
	local n = tonumber(fastBox.Text)
	if n and n > 0 then
		FAST_SPEED = n
	end
	fastBox.Text = tostring(FAST_SPEED)
end)

connect(closeBtn.MouseButton1Click, cleanup)

connect(minimizeBtn.MouseButton1Click, function()
	minimized = not minimized
	content.Visible = not minimized
	minimizeBtn.Text = minimized and "+" or "-"
	main.Size = UDim2.fromOffset(expandedSize.X, minimized and 34 or expandedSize.Y)
end)

-- Drag
local dragging, dragStart, startPos = false, nil, nil
connect(titleBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ==================== INPUT ====================
connect(UserInputService.InputBegan, function(input, gameProcessed)
	if waitingForKey and input.KeyCode ~= Enum.KeyCode.Unknown then
		TOGGLE_KEY = input.KeyCode
		keybindBtn.Text = "Current: " .. input.KeyCode.Name
		keybindBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
		waitingForKey = false
		return
	end

	if input.KeyCode == TOGGLE_KEY and not gameProcessed then
		setEnabled(not enabled)
		statusLbl.Text = enabled and "Status: ON" or "Status: OFF"
		toggleBtn.BackgroundColor3 = enabled and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(60, 100, 140)
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
