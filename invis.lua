-- Invisible Player Tool - LOCAL ONLY (Fixed & Improved)
-- Dual-mode: works standalone or when loaded by the Unified Hub
-- Transparency flashing bug fixed

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local function playNotifySound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://97972687450528"
	sound.Volume = 1.0
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local IS_HUB = _G.UnifiedHubLoading == true

local TRANSPARENCY_ENABLED = true
local OUTLINE_ENABLED = true
local TARGET_TRANSPARENCY = 0.5
local INVISIBLE_TRANSPARENCY = 0.999
local CHECK_INTERVAL = 2.5
local INVISIBLE_THRESHOLD = 0.85

local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)
local OUTLINE_TRANSPARENCY = 0
local FILL_TRANSPARENCY = 1

local NOTIFY_MODE = "stack"

local trackedInvisible = {}
local originalParts = {}
local highlights = {}
local connections = {}
local running = true
local minimized = false
local expandedSize = Vector2.new(300, 460)
local logEntries = {}

if _G.InvisiblePlayerToolCleanup then
	pcall(_G.InvisiblePlayerToolCleanup)
end

local function connect(signal, callback)
	local conn = signal:Connect(callback)
	table.insert(connections, conn)
	return conn
end

-- ==================== NOTIFICATIONS ====================
local NotifyGui = Instance.new("ScreenGui")
NotifyGui.Name = "InvisibleToolNotifications"
NotifyGui.ResetOnSpawn = false
NotifyGui.Parent = PlayerGui

local singleFrame, singleTitle, singleText
local singleToken = 0
local stackCount = 0

local function createNotificationFrame()
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0, 250, 0, 100)
	frame.Position = UDim2.new(1, -270, 1, 20)
	frame.Parent = NotifyGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

	local title = Instance.new("TextLabel")
	title.BackgroundColor3 = Color3.fromRGB(46, 46, 47)
	title.BorderSizePixel = 0
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.Text = "Invisible Tool"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 8, 0, 28)
	text.Size = UDim2.new(1, -16, 1, -34)
	text.Font = Enum.Font.Gotham
	text.TextSize = 14
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextWrapped = true
	text.Parent = frame

	return frame, title, text
end

singleFrame, singleTitle, singleText = createNotificationFrame()

local function tween(obj, pos, dir)
	TweenService:Create(obj, TweenInfo.new(0.35, Enum.EasingStyle.Quart, dir), {Position = pos}):Play()
end

local function notifySingle(title, text, length)
	singleToken += 1
	local token = singleToken
	singleTitle.Text = title or "Invisible Tool"
	singleText.Text = text or ""
	tween(singleFrame, UDim2.new(1, -270, 1, -120), Enum.EasingDirection.Out)

	task.delay(length or 5, function()
		if token == singleToken then
			tween(singleFrame, UDim2.new(1, -270, 1, 20), Enum.EasingDirection.In)
		end
	end)
end

local function notifyStack(title, text, length)
	stackCount += 1
	local slot = stackCount
	local frame, titleLabel, textLabel = createNotificationFrame()
	titleLabel.Text = title or "Invisible Tool"
	textLabel.Text = text or ""

	local yOffset = -120 - ((slot - 1) * 110)
	tween(frame, UDim2.new(1, -270, 1, yOffset), Enum.EasingDirection.Out)

	task.delay(length or 5, function()
		tween(frame, UDim2.new(1, -270, 1, 20), Enum.EasingDirection.In)
		task.wait(0.4)
		if frame then frame:Destroy() end
		stackCount = math.max(stackCount - 1, 0)
	end)
end

-- ==================== GUI VARIABLES ====================
local gui, main, titleBar, content, statusLabel
local transparencyButton, outlineButton, scanLabel
local checkVisibilityButton, actionKillButton, testNotifyBtn
local invisTabBtn, logTabBtn, invisList, logFrame
local minimizeButton, killButton, resizeHandle
local minusButton, plusButton

-- Forward declare
local cleanup
local updateGui
local refreshEffects
local manualCheckVisibility

-- ==================== CREATE GUI (standalone only) ====================
if not IS_HUB then
	gui = Instance.new("ScreenGui")
	gui.Name = "InvisiblePlayerToolGui"
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui

	main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.fromOffset(expandedSize.X, expandedSize.Y)
	main.Position = UDim2.new(0, 20, 0.5, -230)
	main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	main.BorderSizePixel = 0
	main.Parent = gui
	Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", main).Color = Color3.fromRGB(85, 85, 95)

	titleBar = Instance.new("TextLabel")
	titleBar.Size = UDim2.new(1, -76, 0, 34)
	titleBar.Position = UDim2.fromOffset(10, 0)
	titleBar.BackgroundTransparency = 1
	titleBar.Font = Enum.Font.GothamBold
	titleBar.Text = "Invisible Player Tool"
	titleBar.TextColor3 = Color3.fromRGB(245, 245, 245)
	titleBar.TextSize = 14
	titleBar.TextXAlignment = Enum.TextXAlignment.Left
	titleBar.Parent = main

	local function makeTopButton(text, xOffset, color)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromOffset(26, 26)
		button.Position = UDim2.new(1, xOffset, 0, 4)
		button.BackgroundColor3 = color
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Text = text
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 16
		button.AutoButtonColor = false
		button.Parent = main
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
		return button
	end

	minimizeButton = makeTopButton("-", -62, Color3.fromRGB(70, 70, 80))
	killButton = makeTopButton("X", -32, Color3.fromRGB(130, 60, 65))

	content = Instance.new("Frame")
	content.Size = UDim2.new(1, -20, 1, -54)
	content.Position = UDim2.fromOffset(10, 40)
	content.BackgroundTransparency = 1
	content.Parent = main

	local layout = Instance.new("UIListLayout", content)
	layout.Padding = UDim.new(0, 7)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local function styleButton(button, color)
		button.BackgroundColor3 = color or Color3.fromRGB(55, 55, 65)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 13
		button.AutoButtonColor = false
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
	end

	local function createButton(order)
		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 34)
		styleButton(button)
		button.Parent = content
		return button
	end

	transparencyButton = createButton(1)
	outlineButton = createButton(2)

	local scanControl = Instance.new("Frame")
	scanControl.LayoutOrder = 3
	scanControl.Size = UDim2.new(1, 0, 0, 34)
	scanControl.BackgroundTransparency = 1
	scanControl.Parent = content

	minusButton = Instance.new("TextButton")
	minusButton.Size = UDim2.fromOffset(34, 34)
	minusButton.Text = "-"
	minusButton.TextSize = 18
	styleButton(minusButton)
	minusButton.Parent = scanControl

	scanLabel = Instance.new("TextLabel")
	scanLabel.Size = UDim2.new(1, -76, 1, 0)
	scanLabel.Position = UDim2.fromOffset(38, 0)
	scanLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 53)
	scanLabel.BorderSizePixel = 0
	scanLabel.Font = Enum.Font.GothamBold
	scanLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	scanLabel.TextSize = 12
	scanLabel.Parent = scanControl
	Instance.new("UICorner", scanLabel).CornerRadius = UDim.new(0, 4)

	plusButton = Instance.new("TextButton")
	plusButton.Size = UDim2.fromOffset(34, 34)
	plusButton.Position = UDim2.new(1, -34, 0, 0)
	plusButton.Text = "+"
	plusButton.TextSize = 18
	styleButton(plusButton)
	plusButton.Parent = scanControl

	local actionRow = Instance.new("Frame")
	actionRow.LayoutOrder = 4
	actionRow.Size = UDim2.new(1, 0, 0, 34)
	actionRow.BackgroundTransparency = 1
	actionRow.Parent = content

	checkVisibilityButton = Instance.new("TextButton")
	checkVisibilityButton.Size = UDim2.new(0.5, -4, 1, 0)
	checkVisibilityButton.Text = "Check Visibility"
	styleButton(checkVisibilityButton, Color3.fromRGB(60, 80, 110))
	checkVisibilityButton.Parent = actionRow

	actionKillButton = Instance.new("TextButton")
	actionKillButton.Size = UDim2.new(0.5, -4, 1, 0)
	actionKillButton.Position = UDim2.new(0.5, 4, 0, 0)
	actionKillButton.Text = "Kill Script"
	styleButton(actionKillButton, Color3.fromRGB(130, 60, 65))
	actionKillButton.Parent = actionRow

	testNotifyBtn = Instance.new("TextButton")
	testNotifyBtn.LayoutOrder = 5
	testNotifyBtn.Size = UDim2.new(1, 0, 0, 34)
	testNotifyBtn.Text = "Test Notify"
	styleButton(testNotifyBtn, Color3.fromRGB(70, 100, 140))
	testNotifyBtn.Parent = content

	local tabFrame = Instance.new("Frame")
	tabFrame.LayoutOrder = 6
	tabFrame.Size = UDim2.new(1, 0, 1, -200)
	tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	tabFrame.Parent = content
	Instance.new("UICorner", tabFrame).CornerRadius = UDim.new(0, 4)

	local tabButtons = Instance.new("Frame")
	tabButtons.Size = UDim2.new(1, 0, 0, 30)
	tabButtons.BackgroundTransparency = 1
	tabButtons.Parent = tabFrame

	invisTabBtn = Instance.new("TextButton")
	invisTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
	invisTabBtn.Text = "Invisible Players"
	invisTabBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80)
	invisTabBtn.Parent = tabButtons
	Instance.new("UICorner", invisTabBtn)

	logTabBtn = Instance.new("TextButton")
	logTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
	logTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
	logTabBtn.Text = "Log"
	logTabBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	logTabBtn.Parent = tabButtons
	Instance.new("UICorner", logTabBtn)

	invisList = Instance.new("ScrollingFrame")
	invisList.Size = UDim2.new(1, 0, 1, -30)
	invisList.Position = UDim2.new(0, 0, 0, 30)
	invisList.BackgroundTransparency = 1
	invisList.ScrollBarThickness = 4
	invisList.Parent = tabFrame
	Instance.new("UIListLayout", invisList).Padding = UDim.new(0, 2)

	logFrame = Instance.new("ScrollingFrame")
	logFrame.Size = UDim2.new(1, 0, 1, -30)
	logFrame.Position = UDim2.new(0, 0, 0, 30)
	logFrame.BackgroundTransparency = 1
	logFrame.ScrollBarThickness = 4
	logFrame.Visible = false
	logFrame.Parent = tabFrame
	Instance.new("UIListLayout", logFrame).Padding = UDim.new(0, 2)

	statusLabel = Instance.new("TextLabel")
	statusLabel.LayoutOrder = 7
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Text = "Ready"
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
	statusLabel.TextSize = 11
	statusLabel.TextWrapped = true
	statusLabel.Parent = content

	resizeHandle = Instance.new("TextLabel")
	resizeHandle.Size = UDim2.fromOffset(22, 22)
	resizeHandle.Position = UDim2.new(1, -22, 1, -22)
	resizeHandle.BackgroundTransparency = 1
	resizeHandle.Font = Enum.Font.GothamBold
	resizeHandle.Text = "///"
	resizeHandle.TextColor3 = Color3.fromRGB(140, 140, 150)
	resizeHandle.TextSize = 11
	resizeHandle.TextXAlignment = Enum.TextXAlignment.Center
	resizeHandle.TextYAlignment = Enum.TextYAlignment.Center
	resizeHandle.Parent = main
end

-- ==================== FUNCTIONS ====================
local function setStatus(message)
	if statusLabel then
		statusLabel.Text = message
	end
end

local function addLog(message)
	table.insert(logEntries, 1, os.date("%H:%M:%S") .. " | " .. message)
	if #logEntries > 50 then table.remove(logEntries) end

	if logFrame then
		for _, v in ipairs(logFrame:GetChildren()) do
			if v:IsA("TextLabel") then v:Destroy() end
		end
		for _, msg in ipairs(logEntries) do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -10, 0, 26)
			lbl.BackgroundTransparency = 1
			lbl.Text = msg
			lbl.TextColor3 = Color3.new(1, 1, 1)
			lbl.TextSize = 14
			lbl.Font = Enum.Font.GothamSemibold
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextWrapped = true
			lbl.Parent = logFrame
		end
		logFrame.CanvasSize = UDim2.new(0, 0, 0, logFrame.UIListLayout.AbsoluteContentSize.Y)
	end
end

local function notify(title, text, length)
	playNotifySound()
	if NOTIFY_MODE == "stack" then
		notifyStack(title, text, length)
	else
		notifySingle(title, text, length)
	end
	print(("[Invisible Tool] %s: %s"):format(title or "Notify", text or ""))
	setStatus(text or "")
	addLog((title or "Notify") .. ": " .. (text or ""))
end

local function updateInvisibleList()
	if not invisList then return end

	for _, v in ipairs(invisList:GetChildren()) do
		if v:IsA("TextLabel") then v:Destroy() end
	end

	if next(trackedInvisible) == nil then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 20)
		empty.BackgroundTransparency = 1
		empty.Text = "No invisible players detected"
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
		empty.Font = Enum.Font.GothamSemibold
		empty.TextSize = 14
		empty.Parent = invisList
		return
	end

	for player in pairs(trackedInvisible) do
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 0, 26)
		lbl.BackgroundTransparency = 1
		lbl.Text = "• " .. player.DisplayName
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextSize = 14
		lbl.Font = Enum.Font.GothamSemibold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = invisList
	end
	invisList.CanvasSize = UDim2.new(0, 0, 0, invisList.UIListLayout.AbsoluteContentSize.Y)
end

local function getCharacterParts(character)
	if not character then return {} end
	local parts = {}
	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
			table.insert(parts, obj)
		end
	end
	return parts
end

local function isPlayerInvisible(player)
	if player == LocalPlayer then return false end
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end

	local parts = getCharacterParts(char)
	if #parts == 0 then return false end

	local hidden = 0
	for _, part in ipairs(parts) do
		local trans = math.max(part.Transparency, part.LocalTransparencyModifier or 0)
		if trans >= INVISIBLE_THRESHOLD then hidden += 1 end
	end
	return (hidden / #parts) >= 0.7
end

local function restoreTransparency(player)
	if originalParts[player] then
		for part, data in pairs(originalParts[player]) do
			if part and part.Parent then
				part.Transparency = data.Transparency
				part.LocalTransparencyModifier = data.LocalTransparencyModifier or 0
			end
		end
		originalParts[player] = nil
	end
	if highlights[player] then
		highlights[player]:Destroy()
		highlights[player] = nil
	end
end

local function applyTransparency(player)
	local char = player.Character
	if not char then return end
	originalParts[player] = originalParts[player] or {}
	for _, part in ipairs(getCharacterParts(char)) do
		if not originalParts[player][part] then
			originalParts[player][part] = {
				Transparency = part.Transparency,
				LocalTransparencyModifier = part.LocalTransparencyModifier
			}
		end
		part.Transparency = TARGET_TRANSPARENCY
		part.LocalTransparencyModifier = 0
	end
end

local function applyOutline(player)
	local char = player.Character
	if not char then return end
	if highlights[player] then highlights[player]:Destroy() end

	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.OutlineColor = OUTLINE_COLOR
	hl.OutlineTransparency = OUTLINE_TRANSPARENCY
	hl.FillTransparency = FILL_TRANSPARENCY
	hl.Parent = char
	highlights[player] = hl
end

refreshEffects = function(player)
	restoreTransparency(player)
	if TRANSPARENCY_ENABLED then
		applyTransparency(player)
	else
		for _, part in ipairs(getCharacterParts(player.Character)) do
			part.Transparency = INVISIBLE_TRANSPARENCY
			part.LocalTransparencyModifier = 0
		end
	end
	if OUTLINE_ENABLED then
		applyOutline(player)
	end
end

local function restorePlayer(player)
	restoreTransparency(player)
	trackedInvisible[player] = nil
end

-- Fixed: do not re-check already tracked players
local function updateInvisiblePlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if trackedInvisible[player] then continue end

		if isPlayerInvisible(player) then
			trackedInvisible[player] = true
			notify("Detected", player.DisplayName .. " is now invisible")
			refreshEffects(player)
		end
	end
	updateInvisibleList()
end

manualCheckVisibility = function()
	local count = 0
	for player in pairs(trackedInvisible) do
		restoreTransparency(player)
		if not isPlayerInvisible(player) then
			trackedInvisible[player] = nil
			count += 1
			notify("Visible", player.DisplayName .. " became visible")
		else
			refreshEffects(player)
		end
	end
	updateInvisibleList()
	if count == 0 then
		notify("Check", "No players became visible.")
	end
end

updateGui = function()
	if not transparencyButton then return end
	transparencyButton.Text = "Transparency: " .. (TRANSPARENCY_ENABLED and "ON" or "OFF")
	transparencyButton.BackgroundColor3 = TRANSPARENCY_ENABLED and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(90, 55, 60)

	outlineButton.Text = "Outline: " .. (OUTLINE_ENABLED and "ON" or "OFF")
	outlineButton.BackgroundColor3 = OUTLINE_ENABLED and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(90, 55, 60)

	scanLabel.Text = ("Scan interval: %.2fs"):format(CHECK_INTERVAL)
end

cleanup = function()
	running = false
	for player in pairs(trackedInvisible) do
		restorePlayer(player)
	end
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	if gui then gui:Destroy() end
	if NotifyGui then NotifyGui:Destroy() end
end

_G.InvisiblePlayerToolCleanup = cleanup

-- ==================== STANDALONE BUTTONS ====================
if not IS_HUB then
	connect(transparencyButton.MouseButton1Click, function()
		TRANSPARENCY_ENABLED = not TRANSPARENCY_ENABLED
		updateGui()
		for player in pairs(trackedInvisible) do
			refreshEffects(player)
		end
	end)

	connect(outlineButton.MouseButton1Click, function()
		OUTLINE_ENABLED = not OUTLINE_ENABLED
		updateGui()
		for player in pairs(trackedInvisible) do
			refreshEffects(player)
		end
	end)

	connect(minusButton.MouseButton1Click, function()
		CHECK_INTERVAL = math.max(0.25, CHECK_INTERVAL - 0.25)
		updateGui()
	end)

	connect(plusButton.MouseButton1Click, function()
		CHECK_INTERVAL = math.min(10, CHECK_INTERVAL + 0.25)
		updateGui()
	end)

	connect(checkVisibilityButton.MouseButton1Click, manualCheckVisibility)
	connect(killButton.MouseButton1Click, cleanup)
	connect(actionKillButton.MouseButton1Click, cleanup)

	connect(testNotifyBtn.MouseButton1Click, function()
		notify("Test", "Test notification successful!")
	end)

	connect(invisTabBtn.MouseButton1Click, function()
		invisList.Visible = true
		logFrame.Visible = false
		invisTabBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80)
		logTabBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	end)

	connect(logTabBtn.MouseButton1Click, function()
		invisList.Visible = false
		logFrame.Visible = true
		logTabBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80)
		invisTabBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	end)

	-- Drag
	local dragging, dragStart, startPosition = false, nil, nil
	connect(titleBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPosition = main.Position
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	-- Resize
	local resizing, resizeStart, startSize = false, nil, nil
	connect(resizeHandle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			resizeStart = input.Position
			startSize = main.AbsoluteSize
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - resizeStart
			local w = math.clamp(startSize.X + delta.X, 280, 520)
			local h = math.clamp(startSize.Y + delta.Y, 400, 600)
			expandedSize = Vector2.new(w, h)
			main.Size = UDim2.fromOffset(w, h)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
	end)

	-- Minimize
	connect(minimizeButton.MouseButton1Click, function()
		minimized = not minimized
		content.Visible = not minimized
		resizeHandle.Visible = not minimized
		minimizeButton.Text = minimized and "+" or "-"
		main.Size = UDim2.fromOffset(expandedSize.X, minimized and 34 or expandedSize.Y)
	end)
end

-- Player watching
local function watchPlayer(player)
	if player == LocalPlayer then return end
	connect(player.CharacterAdded, function()
		task.wait(0.4)
		if trackedInvisible[player] then
			refreshEffects(player)
		else
			restorePlayer(player)
		end
	end)
end

connect(Players.PlayerAdded, watchPlayer)
connect(Players.PlayerRemoving, function(player)
	restorePlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

-- Start
if not IS_HUB then
	updateGui()
end
addLog("Tool loaded successfully")
setStatus("Invisible Player Tool loaded")

while running do
	if IS_HUB or (gui and gui.Parent) then
		updateInvisiblePlayers()
		task.wait(CHECK_INTERVAL)
	else
		break
	end
end
