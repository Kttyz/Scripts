-- Player Watchlist / Staff Detector (Admins + Mods + Custom Watch)
-- Fancy notifications, global TextChatService monitoring, and custom player labels.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== CONFIG ====================

local ADMIN_USERNAMES = {
	"zog", -- zog
	"MerciElan", -- Knot
	"unicornisforalljk", -- Jerry
}

local MOD_USERNAMES = {
	"Alex_banned54", -- CharlieEatsNuggies
	"DollszMaker", -- Nai
	"55Love_5", -- lee
	"traceallmyscars", -- captor
	"Ioomisyy", -- bec
	"unhingedjaws", -- unhingedjaws
	"solivne", -- kaia
	"owdadaouch", -- heh/daniel
	"paranoid4172", -- paranoid4172
}

local CHECK_INTERVAL = 3
local NOTIFY_MODE = "stack" -- "stack" or "single"
local MONITORED_COMMANDS = {
	";kick", ";ban", ";smite", ";bring", ";fling",
	";freeze", ";jail", ";unfreeze", ";unjail", ";re", ";sword",
}

-- ===============================================

local watchedPlayers = {}
local playerData = {}
local connections = {}
local running = true
local minimized = false
local expandedSize = Vector2.new(340, 500)
local logEntries = {}
local selectingCustomWatch = false

if _G.PlayerWatchlistCleanup then
	pcall(_G.PlayerWatchlistCleanup)
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function playNotifySound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://97972687450528"
	sound.Volume = 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

-- ==================== NOTIFICATIONS ====================

local NotifyGui = Instance.new("ScreenGui")
NotifyGui.Name = "WatchlistNotifications"
NotifyGui.ResetOnSpawn = false
NotifyGui.Parent = PlayerGui

local function createNotificationFrame()
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(36, 36, 37)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(250, 100)
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
	text.Position = UDim2.fromOffset(8, 28)
	text.Size = UDim2.new(1, -16, 1, -34)
	text.Font = Enum.Font.Gotham
	text.TextSize = 14
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextWrapped = true
	text.Parent = frame
	return frame, title, text
end

local singleFrame, singleTitle, singleText = createNotificationFrame()
local singleToken, stackCount = 0, 0

local function tween(object, position, direction)
	TweenService:Create(object, TweenInfo.new(0.35, Enum.EasingStyle.Quart, direction), { Position = position }):Play()
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
	tween(frame, UDim2.new(1, -270, 1, -120 - ((slot - 1) * 110)), Enum.EasingDirection.Out)
	task.delay(length or 5, function()
		tween(frame, UDim2.new(1, -270, 1, 20), Enum.EasingDirection.In)
		task.wait(0.4)
		if frame then frame:Destroy() end
		stackCount = math.max(stackCount - 1, 0)
	end)
end

-- ==================== MAIN GUI ====================

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

local function makeTopButton(text, color, offset)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(26, 26)
	button.Position = UDim2.new(1, offset, 0, 4)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Parent = main
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
	return button
end

local minimizeButton = makeTopButton("-", Color3.fromRGB(70, 70, 80), -62)
local killButton = makeTopButton("X", Color3.fromRGB(130, 60, 65), -32)

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

local customWatchButton = Instance.new("TextButton")
customWatchButton.LayoutOrder = 1
customWatchButton.Size = UDim2.new(1, 0, 0, 28)
customWatchButton.BackgroundColor3 = Color3.fromRGB(85, 75, 125)
customWatchButton.Text = "❔ Add / Edit Watch"
customWatchButton.TextColor3 = Color3.new(1, 1, 1)
customWatchButton.TextSize = 13
customWatchButton.Font = Enum.Font.GothamBold
customWatchButton.AutoButtonColor = false
customWatchButton.Parent = content
Instance.new("UICorner", customWatchButton).CornerRadius = UDim.new(0, 4)

local tabFrame = Instance.new("Frame")
tabFrame.LayoutOrder = 2
tabFrame.Size = UDim2.new(1, 0, 1, -132)
tabFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
tabFrame.Parent = content
Instance.new("UICorner", tabFrame).CornerRadius = UDim.new(0, 4)

local tabButtons = Instance.new("Frame")
tabButtons.Size = UDim2.new(1, 0, 0, 30)
tabButtons.BackgroundTransparency = 1
tabButtons.Parent = tabFrame

local function makeTab(text, position, color)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.5, 0, 1, 0)
	button.Position = position
	button.Text = text
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Parent = tabButtons
	Instance.new("UICorner", button)
	return button
end

local playersTabBtn = makeTab("Players", UDim2.new(), Color3.fromRGB(55, 120, 80))
local logTabBtn = makeTab("Log", UDim2.new(0.5, 0, 0, 0), Color3.fromRGB(55, 55, 65))

local function makeScroll()
	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.new(1, 0, 1, -30)
	frame.Position = UDim2.new(0, 0, 0, 30)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.Parent = tabFrame
	local list = Instance.new("UIListLayout", frame)
	list.Padding = UDim.new(0, 6)
	return frame, list
end

local playerList, playerLayout = makeScroll()
local logFrame, logLayout = makeScroll()
logFrame.Visible = false
logLayout.Padding = UDim.new(0, 4)

local resizeHandle = Instance.new("TextLabel")
resizeHandle.Size = UDim2.fromOffset(22, 22)
resizeHandle.Position = UDim2.new(1, -22, 1, -22)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Font = Enum.Font.GothamBold
resizeHandle.Text = "///"
resizeHandle.TextColor3 = Color3.fromRGB(140, 140, 150)
resizeHandle.TextSize = 11
resizeHandle.Parent = main

-- ==================== CUSTOM ROLE EDITOR ====================

local editorOverlay = Instance.new("Frame")
editorOverlay.Size = UDim2.fromScale(1, 1)
editorOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
editorOverlay.BackgroundTransparency = 0.4
editorOverlay.Visible = false
editorOverlay.ZIndex = 20
editorOverlay.Parent = gui

local editor = Instance.new("Frame")
editor.Size = UDim2.fromOffset(290, 232)
editor.Position = UDim2.new(0.5, -145, 0.5, -116)
editor.BackgroundColor3 = Color3.fromRGB(35, 35, 43)
editor.BorderSizePixel = 0
editor.ZIndex = 21
editor.Parent = editorOverlay
Instance.new("UICorner", editor).CornerRadius = UDim.new(0, 6)

local editorTitle = Instance.new("TextLabel")
editorTitle.Size = UDim2.new(1, -20, 0, 36)
editorTitle.Position = UDim2.fromOffset(10, 0)
editorTitle.BackgroundTransparency = 1
editorTitle.TextColor3 = Color3.new(1, 1, 1)
editorTitle.Font = Enum.Font.GothamBold
editorTitle.TextSize = 14
editorTitle.TextXAlignment = Enum.TextXAlignment.Left
editorTitle.ZIndex = 22
editorTitle.Parent = editor

local function makeInput(placeholder, y)
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, -20, 0, 34)
	input.Position = UDim2.fromOffset(10, y)
	input.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
	input.BorderSizePixel = 0
	input.PlaceholderText = placeholder
	input.PlaceholderColor3 = Color3.fromRGB(175, 175, 185)
	input.TextColor3 = Color3.new(1, 1, 1)
	input.TextSize = 14
	input.Font = Enum.Font.Gotham
	input.ClearTextOnFocus = false
	input.ZIndex = 22
	input.Parent = editor
	Instance.new("UICorner", input).CornerRadius = UDim.new(0, 4)
	return input
end

local emojiInput = makeInput("Emoji (example: ⚠️)", 45)
local roleInput = makeInput("Role/name (example: Suspicious)", 86)

local saveButton = Instance.new("TextButton")
saveButton.Size = UDim2.fromOffset(130, 34)
saveButton.Position = UDim2.fromOffset(10, 140)
saveButton.BackgroundColor3 = Color3.fromRGB(55, 120, 80)
saveButton.Text = "Save"
saveButton.TextColor3 = Color3.new(1, 1, 1)
saveButton.Font = Enum.Font.GothamBold
saveButton.TextSize = 13
saveButton.ZIndex = 22
saveButton.Parent = editor
Instance.new("UICorner", saveButton).CornerRadius = UDim.new(0, 4)

local cancelButton = Instance.new("TextButton")
cancelButton.Size = UDim2.fromOffset(130, 34)
cancelButton.Position = UDim2.fromOffset(150, 140)
cancelButton.BackgroundColor3 = Color3.fromRGB(90, 60, 65)
cancelButton.Text = "Cancel"
cancelButton.TextColor3 = Color3.new(1, 1, 1)
cancelButton.Font = Enum.Font.GothamBold
cancelButton.TextSize = 13
cancelButton.ZIndex = 22
cancelButton.Parent = editor
Instance.new("UICorner", cancelButton).CornerRadius = UDim.new(0, 4)

local removeButton = Instance.new("TextButton")
removeButton.Size = UDim2.new(1, -20, 0, 30)
removeButton.Position = UDim2.fromOffset(10, 188)
removeButton.BackgroundColor3 = Color3.fromRGB(145, 55, 60)
removeButton.Text = "Remove from Watchlist"
removeButton.TextColor3 = Color3.new(1, 1, 1)
removeButton.Font = Enum.Font.GothamBold
removeButton.TextSize = 13
removeButton.ZIndex = 22
removeButton.Parent = editor
Instance.new("UICorner", removeButton).CornerRadius = UDim.new(0, 4)

local editingPlayer
local showEditor

-- ==================== FUNCTIONS ====================

local function addLog(message)
	table.insert(logEntries, 1, os.date("%H:%M:%S") .. " | " .. message)
	if #logEntries > 50 then table.remove(logEntries) end
	for _, child in ipairs(logFrame:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	for _, messageText in ipairs(logEntries) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -10, 0, 26)
		label.BackgroundTransparency = 1
		label.Text = messageText
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 13
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.Parent = logFrame
	end
	logFrame.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y)
end

local function notify(title, text, length)
	playNotifySound()
	if NOTIFY_MODE == "stack" then notifyStack(title, text, length) else notifySingle(title, text, length) end
	addLog(title .. ": " .. text)
	statusLabel.Text = text
end

local function updatePlayerList()
	for _, child in ipairs(playerList:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
	end
	local hasPlayers = false
	for player, data in pairs(playerData) do
		if player.Parent and data then
			hasPlayers = true
			local isAdmin = data.category == "Admin"
			local isMod = data.category == "Mod"
			local color = isAdmin and Color3.fromRGB(60, 30, 30) or (isMod and Color3.fromRGB(40, 45, 60) or Color3.fromRGB(60, 50, 85))
			local textColor = isAdmin and Color3.fromRGB(255, 100, 100) or (isMod and Color3.fromRGB(100, 180, 255) or Color3.fromRGB(210, 180, 255))
			local emoji = isAdmin and "👑" or (isMod and "🛡️" or (data.emoji or "❔"))
			local rightRole = isAdmin and "ADMIN" or (isMod and "MOD" or (data.customRole or "Unknown"))

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, -8, 0, 36)
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			frame.Parent = playerList
			Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -105, 1, 0)
			label.Position = UDim2.fromOffset(8, 0)
			label.BackgroundTransparency = 1
			label.Text = emoji .. " " .. data.displayName .. " <font color='rgb(200,200,200)'>(@" .. data.username .. ")</font>"
			label.TextColor3 = textColor
			label.TextSize = 14
			label.Font = Enum.Font.GothamSemibold
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.RichText = true
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.Parent = frame

			local roleLabel = Instance.new("TextLabel")
			roleLabel.Size = UDim2.new(0, 92, 1, 0)
			roleLabel.Position = UDim2.new(1, -100, 0, 0)
			roleLabel.BackgroundTransparency = 1
			roleLabel.Text = rightRole
			roleLabel.TextColor3 = textColor
			roleLabel.TextSize = 11
			roleLabel.Font = Enum.Font.GothamBold
			roleLabel.TextXAlignment = Enum.TextXAlignment.Right
			roleLabel.TextTruncate = Enum.TextTruncate.AtEnd
			roleLabel.Parent = frame

			-- Only custom/Unknown entries are clickable. Admin and Mod entries stay locked.
			if data.category == "Custom" then
				local editRowButton = Instance.new("TextButton")
				editRowButton.Size = UDim2.fromScale(1, 1)
				editRowButton.BackgroundTransparency = 1
				editRowButton.Text = ""
				editRowButton.ZIndex = 2
				editRowButton.Parent = frame
				editRowButton.MouseButton1Click:Connect(function()
					if not editorOverlay.Visible then showEditor(player) end
				end)
			end
		end
	end
	if not hasPlayers then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 50)
		empty.BackgroundTransparency = 1
		empty.Text = "No staff 😭"
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
		empty.Font = Enum.Font.GothamSemibold
		empty.TextSize = 14
		empty.Parent = playerList
	end
	playerList.CanvasSize = UDim2.new(0, 0, 0, playerLayout.AbsoluteContentSize.Y)
end

local function isWatched(player)
	local username = string.lower(player.Name)
	for _, name in ipairs(ADMIN_USERNAMES) do
		if username == string.lower(name) then return "Admin" end
	end
	for _, name in ipairs(MOD_USERNAMES) do
		if username == string.lower(name) then return "Mod" end
	end
	return nil
end

showEditor = function(player)
	editingPlayer = player
	local data = playerData[player]
	editorTitle.Text = "Edit watch: " .. player.DisplayName
	emojiInput.Text = data.emoji or "❔"
	roleInput.Text = data.customRole or "Unknown"
	editorOverlay.Visible = true
	emojiInput:CaptureFocus()
end

-- ==================== CHAT MONITOR ====================

local function onChatMessage(message)
	if not message or not message.TextSource then return end

	local userId = message.TextSource.UserId
	if not userId then return end

	local player = Players:GetPlayerByUserId(userId)
	if not player then return end

	local chatMessage = message.Text or ""
	local lowerMessage = string.lower(chatMessage)
	local command

	for _, monitoredCommand in ipairs(MONITORED_COMMANDS) do
		if string.find(lowerMessage, monitoredCommand, 1, true) then
			command = string.sub(monitoredCommand, 2)
			break
		end
	end

	if not command then return end

	local staffRole = isWatched(player)
	local title

	if staffRole then
		title = "[" .. staffRole .. "] [" .. player.DisplayName .. "]"
	else
		title = "[Potential Staff] [" .. player.Name .. "]"
	end

	addLog(
		title
			.. " used ;"
			.. command
			.. " — "
			.. player.DisplayName
			.. " (@"
			.. player.Name
			.. "): "
			.. chatMessage
	)

	playNotifySound()
	notifyStack(title, "Used ;" .. command .. "\n" .. chatMessage, 5)
	statusLabel.Text = title .. " used ;" .. command
end

connect(TextChatService.MessageReceived, onChatMessage)

-- ==================== PLAYER CHECK ====================

local function checkPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local category = isWatched(player)

			if category and not watchedPlayers[player] then
				watchedPlayers[player] = true

				playerData[player] = {
					username = player.Name,
					displayName = player.DisplayName,
					category = category,
				}

				notify(
					"[" .. category .. "]",
					player.DisplayName .. " (@" .. player.Name .. ") **JOINED**",
					6
				)
			end
		end
	end

	for player, data in pairs(playerData) do
		if not player.Parent then
			notify(
				"[" .. data.category .. "]",
				data.displayName .. " (@" .. data.username .. ") **LEFT**",
				5
			)

			watchedPlayers[player] = nil
			playerData[player] = nil
		end
	end

	updatePlayerList()
end

-- ==================== CUSTOM WATCH SELECTION ====================

connect(customWatchButton.MouseButton1Click, function()
	if editorOverlay.Visible then return end
	selectingCustomWatch = not selectingCustomWatch
	customWatchButton.Text = selectingCustomWatch and "Click a player to watch/edit..." or "❔ Add / Edit Watch"
	customWatchButton.BackgroundColor3 = selectingCustomWatch and Color3.fromRGB(125, 100, 185) or Color3.fromRGB(85, 75, 125)
	statusLabel.Text = selectingCustomWatch and "Click a player's character in the game." or "Custom selection cancelled."
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
	if not selectingCustomWatch or gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local target = LocalPlayer:GetMouse().Target
	local character = target and target:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player or player == LocalPlayer then
		statusLabel.Text = "Click another player's character."
		return
	end
	selectingCustomWatch = false
	customWatchButton.Text = "❔ Add / Edit Watch"
	customWatchButton.BackgroundColor3 = Color3.fromRGB(85, 75, 125)
	local data = playerData[player]
	if data and data.category == "Custom" then
		showEditor(player)
		return
	end
	if data then
		statusLabel.Text = player.DisplayName .. " is already watched as " .. data.category .. "."
		return
	end
	watchedPlayers[player] = true
	playerData[player] = {
		username = player.Name,
		displayName = player.DisplayName,
		category = "Custom",
		emoji = "❔",
		customRole = "Unknown",
	}
	notify(
		"[Watchlist]",
		"Added " .. player.DisplayName .. " (@" .. player.Name .. ") as ❔ Unknown",
		4
	)
	updatePlayerList()
end)

connect(saveButton.MouseButton1Click, function()
	if editingPlayer and playerData[editingPlayer] then
		local data = playerData[editingPlayer]
		data.emoji = emojiInput.Text ~= "" and emojiInput.Text or "❔"
		data.customRole = roleInput.Text ~= "" and roleInput.Text or "Unknown"
		notify(
			"[Watchlist]",
			"Updated " .. data.displayName .. " to " .. data.emoji .. " " .. data.customRole,
			4
		)
		updatePlayerList()
	end
	editorOverlay.Visible = false
	editingPlayer = nil
end)

connect(cancelButton.MouseButton1Click, function()
	editorOverlay.Visible = false
	editingPlayer = nil
end)

connect(removeButton.MouseButton1Click, function()
	if editingPlayer and playerData[editingPlayer] and playerData[editingPlayer].category == "Custom" then
		local data = playerData[editingPlayer]
		notify(
			"[Watchlist]",
			"Removed " .. data.displayName .. " (@" .. data.username .. ") from watchlist",
			4
		)
		watchedPlayers[editingPlayer] = nil
		playerData[editingPlayer] = nil
		updatePlayerList()
	end
	editorOverlay.Visible = false
	editingPlayer = nil
end)

-- ==================== CLEANUP ====================

local function cleanup()
	running = false
	for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
	if gui then gui:Destroy() end
	if NotifyGui then NotifyGui:Destroy() end
end

_G.PlayerWatchlistCleanup = cleanup

-- ==================== TABS / WINDOW ====================

connect(playersTabBtn.MouseButton1Click, function()
	playerList.Visible, logFrame.Visible = true, false
	playersTabBtn.BackgroundColor3, logTabBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80), Color3.fromRGB(55, 55, 65)
end)

connect(logTabBtn.MouseButton1Click, function()
	playerList.Visible, logFrame.Visible = false, true
	logTabBtn.BackgroundColor3, playersTabBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80), Color3.fromRGB(55, 55, 65)
end)

connect(minimizeButton.MouseButton1Click, function()
	minimized = not minimized
	content.Visible, resizeHandle.Visible = not minimized, not minimized
	minimizeButton.Text = minimized and "+" or "-"
	main.Size = UDim2.fromOffset(expandedSize.X, minimized and 34 or expandedSize.Y)
end)

connect(killButton.MouseButton1Click, cleanup)

local dragging, dragStart, startPosition = false, nil, nil
connect(titleBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPosition = true, input.Position, main.Position
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

local resizing, resizeStart, startSize = false, nil, nil
connect(resizeHandle.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		resizing, resizeStart, startSize = true, input.Position, main.AbsoluteSize
	end
end)
connect(UserInputService.InputChanged, function(input)
	if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - resizeStart
		local width = math.clamp(startSize.X + delta.X, 320, 550)
		local height = math.clamp(startSize.Y + delta.Y, 420, 650)
		expandedSize = Vector2.new(width, height)
		main.Size = UDim2.fromOffset(width, height)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end)

connect(Players.PlayerAdded, function()
	task.wait(1.5)
	checkPlayers()
end)
connect(Players.PlayerRemoving, function()
	checkPlayers()
end)

addLog("StaffWatch Loaded")
notify("Watchlist", "Watching for Staff", 5)
checkPlayers()

while running and gui.Parent do
	checkPlayers()
	task.wait(CHECK_INTERVAL)
end
