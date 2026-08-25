-- Invisible Player Tool - local visual aid
-- Fixed: uses LocalTransparencyModifier only, so server transparency updates do not reset the effect.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TARGET_TRANSPARENCY = 0.5
local INVISIBLE_THRESHOLD = 0.85
local CHECK_INTERVAL = 2.5
local transparencyEnabled = true
local outlineEnabled = true
local running = true
local trackedInvisible = {}
local originalModifiers = {}
local highlights = {}
local connections = {}
local logEntries = {}

if _G.InvisiblePlayerToolCleanup then pcall(_G.InvisiblePlayerToolCleanup) end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function getParts(character)
	local parts = {}
	if not character then return parts end
	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") and object.Name ~= "HumanoidRootPart" then
			table.insert(parts, object)
		end
	end
	return parts
end

local function isInvisible(player)
	if player == LocalPlayer or not player.Character then return false end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	local parts = getParts(player.Character)
	if #parts == 0 then return false end
	local hidden = 0
	for _, part in ipairs(parts) do
		-- Check the real replicated transparency, not this tool's local modifier.
		if part.Transparency >= INVISIBLE_THRESHOLD then hidden += 1 end
	end
	return hidden / #parts >= 0.7
end

local function restoreVisuals(player)
	if originalModifiers[player] then
		for part, oldModifier in pairs(originalModifiers[player]) do
			if part and part.Parent then part.LocalTransparencyModifier = oldModifier end
		end
		originalModifiers[player] = nil
	end
	if highlights[player] then
		highlights[player]:Destroy()
		highlights[player] = nil
	end
end

local function applyTransparency(player)
	if not transparencyEnabled or not player.Character then return end
	originalModifiers[player] = originalModifiers[player] or {}
	for _, part in ipairs(getParts(player.Character)) do
		if originalModifiers[player][part] == nil then
			originalModifiers[player][part] = part.LocalTransparencyModifier
		end
		-- This is local-only. Do not write to part.Transparency.
		part.LocalTransparencyModifier = TARGET_TRANSPARENCY
	end
end

local function applyOutline(player)
	if not outlineEnabled or not player.Character then return end
	local highlight = highlights[player]
	if not highlight or highlight.Parent ~= player.Character then
		if highlight then highlight:Destroy() end
		highlight = Instance.new("Highlight")
		highlight.Name = "InvisibleToolHighlight"
		highlight.Adornee = player.Character
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.OutlineTransparency = 0
		highlight.FillTransparency = 1
		highlight.Parent = player.Character
		highlights[player] = highlight
	end
end

local function maintainVisuals(player)
	applyTransparency(player)
	applyOutline(player)
end

-- ==================== GUI ====================

local gui = Instance.new("ScreenGui")
gui.Name = "InvisiblePlayerToolGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(320, 420)
main.Position = UDim2.new(0, 20, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", main).Color = Color3.fromRGB(85, 85, 95)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -76, 0, 34)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "Invisible Player Tool"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 14
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local function makeButton(text, position, size, color, parent)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 13
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
	return button
end

local minimizeButton = makeButton("-", UDim2.new(1, -62, 0, 4), UDim2.fromOffset(26, 26), Color3.fromRGB(70, 70, 80), main)
local closeButton = makeButton("X", UDim2.new(1, -32, 0, 4), UDim2.fromOffset(26, 26), Color3.fromRGB(130, 60, 65), main)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -54)
content.Position = UDim2.fromOffset(10, 40)
content.BackgroundTransparency = 1
content.Parent = main

local transparencyButton = makeButton("", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32), Color3.fromRGB(55, 120, 80), content)
local outlineButton = makeButton("", UDim2.fromOffset(0, 38), UDim2.new(1, 0, 0, 32), Color3.fromRGB(55, 120, 80), content)
local checkButton = makeButton("Check Visibility", UDim2.fromOffset(0, 76), UDim2.new(1, 0, 0, 32), Color3.fromRGB(60, 80, 110), content)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, 0, 1, -148)
list.Position = UDim2.fromOffset(0, 116)
list.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.Parent = content
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 4)
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = list

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 24)
status.Position = UDim2.new(0, 0, 1, -24)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(180, 180, 185)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Parent = content

local function addLog(message)
	table.insert(logEntries, 1, os.date("%H:%M:%S") .. " | " .. message)
	if #logEntries > 50 then table.remove(logEntries) end
end

local function updateList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	if next(trackedInvisible) == nil then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 26)
		empty.BackgroundTransparency = 1
		empty.Text = "No invisible players detected"
		empty.TextColor3 = Color3.fromRGB(140, 140, 150)
		empty.Font = Enum.Font.GothamSemibold
		empty.TextSize = 14
		empty.Parent = list
	else
		for player in pairs(trackedInvisible) do
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, -8, 0, 26)
			row.BackgroundTransparency = 1
			row.Text = "• " .. player.DisplayName .. " (@" .. player.Name .. ")"
			row.TextColor3 = Color3.new(1, 1, 1)
			row.Font = Enum.Font.GothamSemibold
			row.TextSize = 13
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Parent = list
		end
	end
	list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end

local function setButtons()
	transparencyButton.Text = "Transparency: " .. (transparencyEnabled and "ON" or "OFF")
	transparencyButton.BackgroundColor3 = transparencyEnabled and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(90, 55, 60)
	outlineButton.Text = "Outline: " .. (outlineEnabled and "ON" or "OFF")
	outlineButton.BackgroundColor3 = outlineEnabled and Color3.fromRGB(55, 120, 80) or Color3.fromRGB(90, 55, 60)
end

local function checkVisibility()
	local becameVisible = 0
	for player in pairs(trackedInvisible) do
		restoreVisuals(player)
		if isInvisible(player) then
			maintainVisuals(player)
		else
			trackedInvisible[player] = nil
			becameVisible += 1
			addLog(player.DisplayName .. " became visible")
		end
	end
	status.Text = becameVisible > 0 and (becameVisible .. " player(s) became visible") or "No players became visible"
	updateList()
end

connect(transparencyButton.MouseButton1Click, function()
	transparencyEnabled = not transparencyEnabled
	for player in pairs(trackedInvisible) do
		if transparencyEnabled then
			applyTransparency(player)
		else
			if originalModifiers[player] then
				for part, oldModifier in pairs(originalModifiers[player]) do
					if part and part.Parent then part.LocalTransparencyModifier = oldModifier end
				end
				originalModifiers[player] = nil
			end
		end
	end
	setButtons()
end)

connect(outlineButton.MouseButton1Click, function()
	outlineEnabled = not outlineEnabled
	for player in pairs(trackedInvisible) do
		if outlineEnabled then applyOutline(player) elseif highlights[player] then highlights[player]:Destroy(); highlights[player] = nil end
	end
	setButtons()
end)
connect(checkButton.MouseButton1Click, checkVisibility)

local minimized = false
connect(minimizeButton.MouseButton1Click, function()
	minimized = not minimized
	content.Visible = not minimized
	minimizeButton.Text = minimized and "+" or "-"
	main.Size = UDim2.fromOffset(320, minimized and 34 or 420)
end)

local function cleanup()
	running = false
	for player in pairs(trackedInvisible) do restoreVisuals(player) end
	for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
	gui:Destroy()
end
_G.InvisiblePlayerToolCleanup = cleanup
connect(closeButton.MouseButton1Click, cleanup)

local dragging, dragStart, startPosition = false, nil, nil
connect(title.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging, dragStart, startPosition = true, input.Position, main.Position end
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

connect(Players.PlayerRemoving, function(player)
	restoreVisuals(player)
	trackedInvisible[player] = nil
	updateList()
end)

setButtons()
addLog("Tool loaded")
while running and gui.Parent do
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			if trackedInvisible[player] then
				-- Reapply only the local modifier so new accessories/parts stay visible.
				maintainVisuals(player)
			elseif isInvisible(player) then
				trackedInvisible[player] = true
				maintainVisuals(player)
				status.Text = player.DisplayName .. " is now invisible"
				addLog(player.DisplayName .. " detected as invisible")
			end
		end
	end
	updateList()
	task.wait(CHECK_INTERVAL)
end
