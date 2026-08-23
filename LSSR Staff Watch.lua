-- Player Watchlist / Staff Detector (Admins + Mods) + Fancy Notifications
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== CONFIG ====================
local ADMIN_USERNAMES = {
    "zog", "MerciElan", "unicornisforalljk",
}
local ADMIN_DISPLAYNAMES = {
    "zog", "Knot", "Jerry",
}
local MOD_USERNAMES = {
    "Alex_banned54", "DollszMaker", "55Love_5", "traceallmyscars", "loomisyy",
}
local MOD_DISPLAYNAMES = {
    "CharlieEatsNuggies", "Nai", "lee", "captor", "bec",
}

local CHECK_INTERVAL = 3
local NOTIFY_MODE = "stack"
-- ===============================================

local watchedPlayers = {}
local playerData = {}
local connections = {}
local running = true
local minimized = false
local expandedSize = Vector2.new(340, 500)
local logEntries = {}

if _G.PlayerWatchlistCleanup then pcall(_G.PlayerWatchlistCleanup) end

local function connect(signal, callback)
	local conn = signal:Connect(callback)
	table.insert(connections, conn)
	return conn
end

-- ==================== NOTIFICATIONS ====================
local NotifyGui = Instance.new("ScreenGui")
NotifyGui.Name = "WatchlistNotifications"
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
	title.Text = "Watchlist"
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
	singleTitle.Text = title or "Watchlist"
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
	titleLabel.Text = title or "Watchlist"
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

local function notify(title, text, length)
	if NOTIFY_MODE == "stack" then
		notifyStack(title, text, length)
	else
		notifySingle(title, text, length)
	end
	
	addLog(title .. ": " .. text)
	statusLabel.Text = text
end

-- ==================== GUI & LOGIC ====================
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerWatchlistGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(expandedSize.X, expandedSize.Y)
main.Position = UDim2.new(0, 20, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", main).Color = Color3.fromRGB(85, 85, 95)

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, -76, 0, 34)
titleBar.Position = UDim2.fromOffset(10, 0)
titleBar.BackgroundTransparency = 1
titleBar.Font = Enum.Font.GothamBold
titleBar.Text = "Player Watchlist"
titleBar.TextColor3 = Color3.fromRGB(245, 245, 245)
titleBar.TextSize = 14
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Parent = main

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.fromOffset(26, 26)
minimizeButton.Position = UDim2.new(1, -62, 0, 4)
minimizeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.new(1,1,1)
minimizeButton.TextSize = 16
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.AutoButtonColor = false
minimizeButton.Parent = main
Instance.new("UICorner", minimizeButton).CornerRadius = UDim.new(0, 4)

local killButton = Instance.new("TextButton")
killButton.Size = UDim2.fromOffset(26, 26)
killButton.Position = UDim2.new(1, -32, 0, 4)
killButton.BackgroundColor3 = Color3.fromRGB(130, 60, 65)
killButton.Text = "X"
killButton.TextColor3 = Color3.new(1,1,1)
killButton.TextSize = 16
killButton.Font = Enum.Font.GothamBold
killButton.AutoButtonColor = false
killButton.Parent = main
Instance.new("UICorner", killButton).CornerRadius = UDim.new(0, 4)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -54)
content.Position = UDim2.fromOffset(10, 40)
content.BackgroundTransparency = 1
content.Parent = main

local layout = Instance.new("UIListLayout", content)
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 24)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Scanning for staff..."
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
statusLabel.TextSize = 12
statusLabel.Parent = content

local tabFrame = Instance.new("Frame")
tabFrame.LayoutOrder = 2
tabFrame.Size = UDim2.new(1, 0, 1, -100)
tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
tabFrame.Parent = content
Instance.new("UICorner", tabFrame).CornerRadius = UDim.new(0, 4)

local tabButtons = Instance.new("Frame")
tabButtons.Size = UDim2.new(1, 0, 0, 30)
tabButtons.BackgroundTransparency = 1
tabButtons.Parent = tabFrame

local playersTabBtn = Instance.new("TextButton")
playersTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
playersTabBtn.Text = "Players"
playersTabBtn.BackgroundColor3 = Color3.fromRGB(55,120,80)
playersTabBtn.Parent = tabButtons
Instance.new("UICorner", playersTabBtn)

local logTabBtn = Instance.new("TextButton")
logTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
logTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
logTabBtn.Text = "Log"
logTabBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
logTabBtn.Parent = tabButtons
Instance.new("UICorner", logTabBtn)

local playerList = Instance.new("ScrollingFrame")
playerList.Size = UDim2.new(1, 0, 1, -30)
playerList.Position = UDim2.new(0,0,0,30)
playerList.BackgroundTransparency = 1
playerList.ScrollBarThickness = 4
playerList.Parent = tabFrame
Instance.new("UIListLayout", playerList).Padding = UDim.new(0, 6)

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, 0, 1, -30)
logFrame.Position = UDim2.new(0,0,0,30)
logFrame.BackgroundTransparency = 1
logFrame.ScrollBarThickness = 4
logFrame.Visible = false
logFrame.Parent = tabFrame
Instance.new("UIListLayout", logFrame).Padding = UDim.new(0, 4)

local resizeHandle = Instance.new("TextLabel")
resizeHandle.Size = UDim2.fromOffset(22, 22)
resizeHandle.Position = UDim2.new(1, -22, 1, -22)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Font = Enum.Font.GothamBold
resizeHandle.Text = "///"
resizeHandle.TextColor3 = Color3.fromRGB(140, 140, 150)
resizeHandle.TextSize = 11
resizeHandle.Parent = main

-- ==================== FUNCTIONS ====================
local function addLog(message)
	table.insert(logEntries, 1, os.date("%H:%M:%S") .. " | " .. message)
	if #logEntries > 50 then table.remove(logEntries) end

	for _, v in ipairs(logFrame:GetChildren()) do
		if v:IsA("TextLabel") then v:Destroy() end
	end

	for _, msg in ipairs(logEntries) do
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 0, 26)
		lbl.BackgroundTransparency = 1
		lbl.Text = msg
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.TextSize = 13
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextWrapped = true
		lbl.Parent = logFrame
	end
	logFrame.CanvasSize = UDim2.new(0,0,0, logFrame.UIListLayout.AbsoluteContentSize.Y)
end

local function updatePlayerList()
	for _, v in ipairs(playerList:GetChildren()) do
		if v:IsA("TextLabel") or v:IsA("Frame") then v:Destroy() end
	end

	local hasPlayers = false

	for player, data in pairs(playerData) do
		if player.Parent and data then
			hasPlayers = true
			local color = data.category == "Admin" and Color3.fromRGB(60, 30, 30) or Color3.fromRGB(40, 45, 60)
			local emoji = data.category == "Admin" and "👑" or "🛡️"
			local textColor = data.category == "Admin" and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 180, 255)

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, -8, 0, 36)
			frame.BackgroundColor3 = color
			frame.Parent = playerList
			Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)
			
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -10, 1, 0)
			lbl.Position = UDim2.fromOffset(8, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = emoji .. " " .. data.displayName .. " <font color='rgb(200,200,200)'>(@" .. data.username .. ")</font>"
			lbl.TextColor3 = textColor
			lbl.TextSize = 14
			lbl.Font = Enum.Font.GothamSemibold
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.RichText = true
			lbl.Parent = frame
		end
	end

	if not hasPlayers then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1,0,0,50)
		empty.BackgroundTransparency = 1
		empty.Text = "No watched players in game"
		empty.TextColor3 = Color3.fromRGB(140,140,150)
		empty.Font = Enum.Font.GothamSemibold
		empty.TextSize = 14
		empty.Parent = playerList
	end
	
	playerList.CanvasSize = UDim2.new(0,0,0, playerList.UIListLayout.AbsoluteContentSize.Y)
end

local function isWatched(player)
	for _, name in ipairs(ADMIN_USERNAMES) do if player.Name == name then return "Admin" end end
	for _, name in ipairs(ADMIN_DISPLAYNAMES) do if player.DisplayName == name then return "Admin" end end
	for _, name in ipairs(MOD_USERNAMES) do if player.Name == name then return "Mod" end end
	for _, name in ipairs(MOD_DISPLAYNAMES) do if player.DisplayName == name then return "Mod" end end
	return nil
end

local function checkPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		local category = isWatched(player)
		
		if category and not watchedPlayers[player] then
			watchedPlayers[player] = true
			playerData[player] = {
				username = player.Name,
				displayName = player.DisplayName,
				category = category
			}
			notify("[" .. category .. "]", player.DisplayName .. " (@" .. player.Name .. ") **JOINED**", 6)
		end
	end
	
	-- Remove players who left
	for player, data in pairs(playerData) do
		if not player.Parent then
			notify("[" .. data.category .. "]", data.displayName .. " (@" .. data.username .. ") **LEFT**", 5)
			watchedPlayers[player] = nil
			playerData[player] = nil
		end
	end
	
	updatePlayerList()
end

local function cleanup()
	running = false
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	if gui then gui:Destroy() end
	if NotifyGui then NotifyGui:Destroy() end
end

_G.PlayerWatchlistCleanup = cleanup

-- Tab, Buttons, Drag, Resize (same as before)
connect(playersTabBtn.MouseButton1Click, function()
	playerList.Visible = true
	logFrame.Visible = false
	playersTabBtn.BackgroundColor3 = Color3.fromRGB(55,120,80)
	logTabBtn.BackgroundColor3 = Color3.fromRGB(55,55,65)
end)

connect(logTabBtn.MouseButton1Click, function()
	playerList.Visible = false
	logFrame.Visible = true
	logTabBtn.BackgroundColor3 = Color3.fromRGB(55,120,80)
	playersTabBtn.BackgroundColor3 = Color3.fromRGB(55,55,65)
end)

connect(minimizeButton.MouseButton1Click, function()
	minimized = not minimized
	content.Visible = not minimized
	resizeHandle.Visible = not minimized
	minimizeButton.Text = minimized and "+" or "-"
	main.Size = UDim2.fromOffset(expandedSize.X, minimized and 34 or expandedSize.Y)
end)

connect(killButton.MouseButton1Click, cleanup)

-- Drag
local dragging = false
local dragStart, startPosition
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
local resizing = false
local resizeStart, startSize
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
		local w = math.clamp(startSize.X + delta.X, 320, 550)
		local h = math.clamp(startSize.Y + delta.Y, 420, 650)
		expandedSize = Vector2.new(w, h)
		main.Size = UDim2.fromOffset(w, h)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end)

-- Events
connect(Players.PlayerAdded, function() task.wait(1.5); checkPlayers() end)
connect(Players.PlayerRemoving, checkPlayers)

-- Start
addLog("Player Watchlist loaded")
notify("Watchlist", "Monitoring Admins + Mods", 5)

while running and gui.Parent do
	checkPlayers()
	task.wait(CHECK_INTERVAL)
end
