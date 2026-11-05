--!nonstrict
--[[
	Kitz Audio Logger — a client-side audio logger for Roblox.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/Scripts/main/Alogger.lua"))()

	Walks a scan target for every Sound, pulls the numeric id out of each
	SoundId, resolves the real name through MarketplaceService, and lists them
	in a draggable window.

	Scan targets are Workspace, Lighting, SoundService and Game, one pass each,
	time sliced across frames so a big place never stalls. Auto Scan starts OFF
	and, once on, catches sounds the game creates after load through
	DescendantAdded instead of re-walking the tree every second.

	KitzBans.txt holds the ban list, one "id | name" per line. It is read before
	anything else runs, so a banned id never reaches the list, and Ban/Banned
	rewrite it on every change. Open and Save use KitzAudios.txt.

	_g.KitzAlogger.rescan() and _g.KitzAlogger.destroy() are the public handles.
	Loaded from Kbar, _g.Kbar.notify carries the toasts.
]]

local CONFIG = {
	windowWidth = 660,
	windowHeight = 372,
	titleHeight = 28,
	toolbarHeight = 26,
	rightWidth = 200,
	rowHeight = 22,
	listPadding = 6,
	resolveSpacing = 0.12,
	renderDebounce = 0.1,
	scanSlice = 0.003,
	maxRows = 300,
	cornerRadius = 7,
	strokeThickness = 2,
	filePath = "KitzAudios.txt",
	banPath = "KitzBans.txt",
	selectedPath = "KitzSelected.txt",
	font = Enum.Font.Code,
	sizes = { title = 13, body = 12, small = 10, tiny = 9 },
	colour = {
		background = Color3.fromRGB(10, 11, 12),
		backgroundTop = Color3.fromRGB(38, 40, 43),
		panel = Color3.fromRGB(36, 36, 37),
		panelTop = Color3.fromRGB(46, 46, 47),
		edge = Color3.fromRGB(64, 70, 79),
		text = Color3.fromRGB(236, 238, 241),
		dim = Color3.fromRGB(140, 148, 158),
		dimmer = Color3.fromRGB(116, 124, 133),
		accent = Color3.fromRGB(224, 73, 47),
		green = Color3.fromRGB(88, 214, 120),
		red = Color3.fromRGB(226, 62, 50),
		rowFill = Color3.fromRGB(255, 255, 255),
	},
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui")
local guiName = "KitzAudioLogger"

if _G.KitzAlogger and typeof(_G.KitzAlogger.destroy) == "function" then
	pcall(_G.KitzAlogger.destroy)
end
local previous = playerGui:FindFirstChild(guiName)
if previous then
	previous:Destroy()
end

----------------------------------------------------------------------
-- executor helpers
----------------------------------------------------------------------

local function executor()
	local ok, name = pcall(function()
		return identifyexecutor()
	end)
	if ok and typeof(name) == "string" then
		return name
	end
	return nil
end

local handle = executor() or "this executor"
local canWrite = typeof(writefile) == "function" and typeof(isfile) == "function"
local canRead = typeof(readfile) == "function"
local canClip = typeof(setclipboard) == "function"

local function readFile(path)
	if not canRead then
		return nil
	end
	if typeof(isfile) == "function" then
		local ok, exists = pcall(isfile, path)
		if not ok or not exists then
			return nil
		end
	end
	local ok, body = pcall(readfile, path)
	if ok and typeof(body) == "string" then
		return body
	end
	return nil
end

local function writeFile(path, body)
	if not canWrite then
		return false
	end
	local ok = pcall(writefile, path, body)
	return ok
end

local function copyText(text)
	if not canClip then
		return false
	end
	local ok = pcall(setclipboard, text)
	return ok
end

----------------------------------------------------------------------
-- notify
----------------------------------------------------------------------

local function notify(titleText, bodyText)
	local kbar = _G.Kbar
	if kbar and typeof(kbar.notify) == "function" then
		local ok = pcall(kbar.notify, titleText, bodyText)
		if ok then
			return
		end
	end
	print("[Kitz Audio Logger] " .. tostring(titleText) .. ": " .. tostring(bodyText))
end

----------------------------------------------------------------------
-- ui helpers
----------------------------------------------------------------------

local make, corner, stroke, label, tween, motionInfo

function make(class, properties, parent)
	local instance = Instance.new(class)
	for key, value in pairs(properties) do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function corner(instance, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end

function stroke(instance, colour, thickness, transparency)
	return make("UIStroke", {
		Color = colour,
		Thickness = thickness or CONFIG.strokeThickness,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, instance)
end

function label(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		Font = CONFIG.font,
		TextSize = CONFIG.sizes.body,
		TextColor3 = CONFIG.colour.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in pairs(properties or {}) do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

function tween(instance, info, goals)
	local animation = TweenService:Create(instance, info, goals)
	animation:Play()
	return animation
end

function motionInfo(duration, style)
	local reduced = false
	pcall(function()
		reduced = GuiService.ReducedMotionEnabled
	end)
	return TweenInfo.new(reduced and 0 or duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function trim(text, limit)
	if #text <= limit then
		return text
	end
	return string.sub(text, 1, limit - 1) .. "…"
end

local function parseId(value)
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	local digits = string.match(value, "rbxassetid://(%d+)")
		or string.match(value, "[%?&]id=(%d+)")
		or string.match(value, "^%s*(%d+)")
	if not digits then
		return nil
	end
	local id = tonumber(digits)
	if not id or id <= 0 then
		return nil
	end
	return id
end

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------

local state = {
	entries = {},
	order = {},
	seen = {},
	banned = {},
	bannedNames = {},
	pending = {},
	pendingSet = {},
	resolvedCount = 0,
	scannedCount = 0,
	queueTotal = 0,
	selected = nil,
	scope = "Game",
	autoScan = false,
	rendered = 0,
	needRebuild = false,
}

local connections = {}
local function track(connection)
	table.insert(connections, connection)
	return connection
end

-- the ban list is read before any scan exists, so a banned id can never be
-- displayed, not even for the moment between the first scan and the first read
local function loadBans()
	local text = readFile(CONFIG.banPath)
	if not text then
		return
	end
	for line in string.gmatch(text, "[^\r\n]+") do
		local id = parseId(line)
		if id then
			state.banned[id] = true
			local name = string.match(line, "|%s*(.+)$")
			if name and name ~= "" then
				state.bannedNames[id] = name
			end
		end
	end
end

local function persistBans()
	local ids = {}
	for id in pairs(state.banned) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local lines = {}
	for _, id in ipairs(ids) do
		local name = state.bannedNames[id]
		if name then
			table.insert(lines, tostring(id) .. " | " .. name)
		else
			table.insert(lines, tostring(id))
		end
	end
	return writeFile(CONFIG.banPath, table.concat(lines, "\n"))
end

loadBans()

----------------------------------------------------------------------
-- the window
----------------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = guiName,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 620,
})
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end)
gui.Parent = playerGui

local window = make("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	Size = UDim2.fromOffset(CONFIG.windowWidth, CONFIG.windowHeight),
	BackgroundColor3 = CONFIG.colour.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(window, CONFIG.cornerRadius + 3)
stroke(window, CONFIG.colour.edge, CONFIG.strokeThickness, 0.3)

local title = make("Frame", {
	Name = "Title",
	Size = UDim2.new(1, 0, 0, CONFIG.titleHeight),
	BackgroundColor3 = CONFIG.colour.backgroundTop,
	BorderSizePixel = 0,
}, window)

label(title, {
	Name = "Name",
	Text = "Kitz Audio Logger",
	TextSize = CONFIG.sizes.title,
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.fromOffset(152, CONFIG.titleHeight),
})

-- the progress strip sits in the title row, right of the name
local progressTrack = make("Frame", {
	Name = "Progress",
	Position = UDim2.new(0, 170, 0.5, -4),
	Size = UDim2.new(1, -170 - 76, 0, 8),
	BackgroundColor3 = Color3.fromRGB(28, 30, 33),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, title)
corner(progressTrack, 4)
stroke(progressTrack, CONFIG.colour.edge, 1, 0.55)

local progressFill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = CONFIG.colour.accent,
	BorderSizePixel = 0,
}, progressTrack)
corner(progressFill, 4)

local function windowButton(name, glyphText, offsetX)
	local button = make("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, offsetX, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = glyphText,
		Font = CONFIG.font,
		TextSize = CONFIG.sizes.small,
		TextColor3 = CONFIG.colour.dim,
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.colour.rowFill,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
	}, title)
	corner(button, 5)
	local buttonStroke = stroke(button, CONFIG.colour.rowFill, 1.5, 0.86)
	return button, buttonStroke
end

local minimiseButton, minimiseStroke = windowButton("Minimise", "_", -34)
local closeButton, closeStroke = windowButton("Close", "X", -9)

local body = make("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(0, CONFIG.titleHeight),
	Size = UDim2.new(1, 0, 1, -CONFIG.titleHeight),
	BackgroundTransparency = 1,
}, window)

----------------------------------------------------------------------
-- left column: toolbar, list, status
----------------------------------------------------------------------

local statusHeight = 16

local leftColumn = make("Frame", {
	Name = "List",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.new(1, -CONFIG.rightWidth - 22, 1, -8),
}, body)

local toolbar = make("Frame", {
	Name = "Toolbar",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, CONFIG.toolbarHeight),
}, leftColumn)

local function toolButton(parent, name, text, width)
	local button = make("TextButton", {
		Name = name,
		Text = text,
		Font = CONFIG.font,
		TextSize = CONFIG.sizes.small,
		TextColor3 = CONFIG.colour.text,
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.colour.rowFill,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 20),
	}, parent)
	corner(button, 5)
	local buttonStroke = stroke(button, CONFIG.colour.rowFill, 1.5, 0.82)
	track(button.MouseEnter:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.89 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.64 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundTransparency = 0.95 })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.82 })
	end))
	return button, buttonStroke
end

local openButton = toolButton(toolbar, "Open", "Open", 46)
openButton.Position = UDim2.fromOffset(0, 3)
local saveButton = toolButton(toolbar, "Save", "Save", 46)
saveButton.Position = UDim2.fromOffset(50, 3)
local playToolButton = toolButton(toolbar, "Play", "Play", 46)
playToolButton.Position = UDim2.fromOffset(100, 3)
local copyToolButton = toolButton(toolbar, "Copy", "Copy", 46)
copyToolButton.Position = UDim2.fromOffset(150, 3)

local banButton = toolButton(toolbar, "BanAudio", "BanAudio", 66)
banButton.AnchorPoint = Vector2.new(1, 0)
banButton.Position = UDim2.new(1, -4, 0, 3)
local bannedButton = toolButton(toolbar, "Banned", "Banned", 58)
bannedButton.AnchorPoint = Vector2.new(1, 0)
bannedButton.Position = UDim2.new(1, -76, 0, 3)

local listFrame = make("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(0, CONFIG.toolbarHeight + 2),
	Size = UDim2.new(1, 0, 1, -CONFIG.toolbarHeight - 2 - statusHeight),
	BackgroundColor3 = CONFIG.colour.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, leftColumn)
corner(listFrame, CONFIG.cornerRadius)
stroke(listFrame, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)

local scroller = make("ScrollingFrame", {
	Name = "Sounds",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(CONFIG.listPadding, CONFIG.listPadding),
	Size = UDim2.new(1, -CONFIG.listPadding * 2, 1, -CONFIG.listPadding * 2),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = CONFIG.colour.edge,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, listFrame)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2),
}, scroller)

local emptyLabel = label(listFrame, {
	Name = "Empty",
	Text = "No sounds yet.  Press Game to scan.",
	TextColor3 = CONFIG.colour.dimmer,
	TextSize = CONFIG.sizes.small,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
})

local statusLabel = label(leftColumn, {
	Name = "Status",
	Text = "FOUND 0 · NAMED 0 · QUEUE 0",
	TextColor3 = CONFIG.colour.dimmer,
	TextSize = CONFIG.sizes.tiny,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, 0),
	Size = UDim2.new(1, -12, 0, statusHeight),
})

----------------------------------------------------------------------
-- right column: Settings group over Scan group
----------------------------------------------------------------------

local rightColumn = make("Frame", {
	Name = "Side",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 0),
	Size = UDim2.new(0, CONFIG.rightWidth, 1, -8),
	BackgroundTransparency = 1,
}, body)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 3),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Top,
}, rightColumn)

local function groupHeading(order, text)
	local heading = label(rightColumn, {
		Name = "Heading",
		Text = text,
		TextColor3 = CONFIG.colour.dim,
		TextSize = CONFIG.sizes.tiny,
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 14),
	})
	return heading
end

local function groupButton(order, name, text)
	local button = make("TextButton", {
		Name = name,
		Text = text,
		Font = CONFIG.font,
		TextSize = CONFIG.sizes.body,
		TextColor3 = CONFIG.colour.text,
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.colour.panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 22),
		LayoutOrder = order,
	}, rightColumn)
	corner(button, 6)
	local buttonStroke = stroke(button, CONFIG.colour.edge, 1.5, 0.45)
	track(button.MouseEnter:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundColor3 = CONFIG.colour.panelTop })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.15 })
	end))
	track(button.MouseLeave:Connect(function()
		tween(button, motionInfo(0.1), { BackgroundColor3 = CONFIG.colour.panel })
		tween(buttonStroke, motionInfo(0.1), { Transparency = 0.45 })
	end))
	return button, buttonStroke
end

groupHeading(1, "Settings:")
local saveSelectedButton = groupButton(2, "SaveSelected", "Save Selected")
local saveAllButton = groupButton(3, "SaveAll", "Save All")
local clearSelectedButton = groupButton(4, "ClrSelected", "Clr Selected")
local clearUnselectedButton = groupButton(5, "ClrUnselected", "Clr Unselected")

groupHeading(7, "Scan:")
local scopeButtons = {}
local scopeOrder = { "Workspace", "Lighting", "SoundService", "Game" }
for index, name in ipairs(scopeOrder) do
	scopeButtons[name] = groupButton(7 + index, "Scan" .. name, name)
end
local autoButton, autoStroke = groupButton(13, "Auto", "Auto Scan")

----------------------------------------------------------------------
-- list rows
----------------------------------------------------------------------

local rowWidgets = {}
local renderQueued = false

-- the pass that is currently being walked, if any: { list, cursor, scope }
local scanQueue = nil

local function rowFor(entry, order)
	local row = make("TextButton", {
		Name = tostring(entry.id),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.colour.rowFill,
		BackgroundTransparency = 0.97,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -2, 0, CONFIG.rowHeight),
		LayoutOrder = order,
	}, scroller)
	corner(row, 4)
	local rowStroke = stroke(row, CONFIG.colour.rowFill, 1.5, 0.9)

	label(row, {
		Name = "Name",
		Text = entry.name,
		TextSize = CONFIG.sizes.small,
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(1, -84, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(row, {
		Name = "Id",
		Text = tostring(entry.id),
		TextColor3 = CONFIG.colour.dimmer,
		TextSize = CONFIG.sizes.tiny,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -76, 0, 0),
		Size = UDim2.fromOffset(70, CONFIG.rowHeight),
	})

	local widget = { row = row, stroke = rowStroke, entry = entry, nameLabel = row:FindFirstChild("Name") }

	local function paint(selected)
		if not row.Parent then
			return
		end
		tween(row, motionInfo(0.12), { BackgroundTransparency = selected and 0.88 or 0.97 })
		tween(rowStroke, motionInfo(0.12), {
			Color = selected and CONFIG.colour.accent or CONFIG.colour.rowFill,
			Transparency = selected and 0.2 or 0.9,
		})
	end

	widget.paint = paint
	rowWidgets[entry.id] = widget

	-- rows are rebuilt on every render, so these stay untracked: destroying the
	-- row takes its own connections with it
	row.MouseEnter:Connect(function()
		if state.selected ~= entry.id then
			tween(row, motionInfo(0.1), { BackgroundTransparency = 0.92 })
		end
	end)
	row.MouseLeave:Connect(function()
		if state.selected ~= entry.id then
			tween(row, motionInfo(0.1), { BackgroundTransparency = 0.97 })
		end
	end)
	row.Activated:Connect(function()
		state.selected = entry.id
		for id, other in pairs(rowWidgets) do
			if other.paint then
				other.paint(id == entry.id)
			end
		end
	end)
	return row
end

----------------------------------------------------------------------
-- rendering: append new rows, rebuild only when something was removed
----------------------------------------------------------------------

local moreLabel = nil
local refreshMoreLabel

local function clearRows()
	for _, child in ipairs(scroller:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	rowWidgets = {}
	state.rendered = 0
	moreLabel = nil
end

refreshMoreLabel = function()
	local total = #state.order
	local shown = math.min(total, CONFIG.maxRows)
	if total > shown then
		if not moreLabel or not moreLabel.Parent then
			moreLabel = label(scroller, {
				Name = "More",
				Text = "",
				TextColor3 = CONFIG.colour.dimmer,
				TextSize = CONFIG.sizes.tiny,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -2, 0, 18),
				LayoutOrder = shown + 1,
			})
		end
		moreLabel.Text = ("+%d more"):format(total - shown)
		moreLabel.LayoutOrder = shown + 1
	elseif moreLabel and moreLabel.Parent then
		moreLabel:Destroy()
		moreLabel = nil
	end
end

local function appendRows()
	local total = #state.order
	local cap = math.min(total, CONFIG.maxRows)
	while state.rendered < cap do
		state.rendered += 1
		local entry = state.entries[state.order[state.rendered]]
		if entry then
			rowFor(entry, state.rendered)
			if state.selected == entry.id and rowWidgets[entry.id] then
				rowWidgets[entry.id].paint(true)
			end
		end
	end
	if refreshMoreLabel then
		refreshMoreLabel()
	end
	emptyLabel.Visible = state.rendered == 0
end

local function renderList()
	renderQueued = false
	if not scroller.Parent then
		return
	end
	if state.needRebuild then
		state.needRebuild = false
		clearRows()
	end
	appendRows()
end

local function queueRender(rebuild)
	if rebuild then
		state.needRebuild = true
	end
	if renderQueued then
		return
	end
	renderQueued = true
	task.delay(CONFIG.renderDebounce, renderList)
end

local function updateStats()
	local percent = 1
	if scanQueue then
		percent = scanQueue.cursor / math.max(#scanQueue.list, 1)
	end
	tween(progressFill, motionInfo(0.2), { Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1) })

	statusLabel.Text = ("FOUND %d · NAMED %d · QUEUE %d · %s")
		:format(#state.order, state.resolvedCount, #state.pending, state.scope)
end

----------------------------------------------------------------------
-- collecting ids
----------------------------------------------------------------------

local function addEntry(id)
	if state.seen[id] or state.banned[id] then
		return false
	end
	state.seen[id] = true
	state.entries[id] = {
		id = id,
		name = "Audio " .. tostring(id),
		resolved = false,
	}
	table.insert(state.order, id)

	if not state.pendingSet[id] then
		state.pendingSet[id] = true
		table.insert(state.pending, id)
		state.queueTotal += 1
	end
	queueRender()
	return true
end

local function dropEntry(id)
	local entry = state.entries[id]
	if not entry then
		return false
	end
	state.entries[id] = nil
	state.seen[id] = nil
	state.pendingSet[id] = nil
	for index = #state.order, 1, -1 do
		if state.order[index] == id then
			table.remove(state.order, index)
		end
	end
	for index = #state.pending, 1, -1 do
		if state.pending[index] == id then
			table.remove(state.pending, index)
		end
	end
	if state.selected == id then
		state.selected = nil
	end
	queueRender(true)
	return true
end

local scopeRoots = {
	Workspace = function()
		return workspace
	end,
	Lighting = function()
		return game:GetService("Lighting")
	end,
	SoundService = function()
		return SoundService
	end,
	Game = function()
		return game
	end,
}

-- one pass over one target, sliced against os.clock so a 200k instance place
-- never eats a frame: the slice returns false and the pump resumes it next frame

local function beginScan(name)
	local rootFor = scopeRoots[name]
	if not rootFor then
		return false
	end
	local ok, root = pcall(rootFor)
	if not ok or not root then
		return false
	end
	state.scope = name
	scanQueue = { list = root:GetDescendants(), cursor = 0, scope = name }
	state.scannedCount = #scanQueue.list
	updateStats()
	return true
end

local function stepScan(budget)
	if not scanQueue then
		return true
	end
	local list = scanQueue.list
	local deadline = os.clock() + (budget or CONFIG.scanSlice)
	local index = scanQueue.cursor + 1
	while index <= #list do
		local instance = list[index]
		if typeof(instance) == "Instance" and instance:IsA("Sound") then
			local id = parseId(instance.SoundId)
			if id then
				addEntry(id)
			end
		end
		index += 1
		if os.clock() >= deadline then
			scanQueue.cursor = index - 1
			return false
		end
	end
	scanQueue = nil
	return true
end

----------------------------------------------------------------------
-- name resolution, one at a time
----------------------------------------------------------------------

task.spawn(function()
	while true do
		local id = table.remove(state.pending, 1)
		if id then
			state.pendingSet[id] = nil
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)
			end)
			local entry = state.entries[id]
			if entry and not entry.resolved then
				entry.resolved = true
				state.resolvedCount += 1
				if ok and typeof(info) == "table" and typeof(info.Name) == "string" then
					entry.name = info.Name
					local widget = rowWidgets[id]
					if widget and widget.nameLabel and widget.nameLabel.Parent then
						widget.nameLabel.Text = info.Name
					end
				end
			end
			updateStats()
			task.wait(CONFIG.resolveSpacing)
		else
			task.wait(0.2)
		end
	end
end)

----------------------------------------------------------------------
-- the scan pump and live capture
----------------------------------------------------------------------

task.spawn(function()
	while true do
		if scanQueue then
			stepScan()
			updateStats()
		end
		task.wait()
	end
end)

local captureConnection = nil

local function setCapturing(on)
	if on and not captureConnection then
		local ok, connection = pcall(function()
			return game.DescendantAdded:Connect(function(instance)
				if typeof(instance) == "Instance" and instance:IsA("Sound") then
					local id = parseId(instance.SoundId)
					if id then
						addEntry(id)
					end
				end
			end)
		end)
		if ok then
			captureConnection = connection
		else
			notify("Audio Logger", "This game blocks new-sound capture")
		end
	elseif not on and captureConnection then
		pcall(function()
			captureConnection:Disconnect()
		end)
		captureConnection = nil
	end
end

local function setAutoScan(on)
	state.autoScan = on
	setCapturing(on)
	tween(autoStroke, motionInfo(0.15), {
		Color = on and CONFIG.colour.green or CONFIG.colour.edge,
		Transparency = on and 0.25 or 0.45,
	})
	if on then
		beginScan(state.scope)
	end
end

----------------------------------------------------------------------
-- actions
----------------------------------------------------------------------

local playing

local function stopPlaying()
	if playing and playing.Parent then
		pcall(function()
			playing:Stop()
			playing:Destroy()
		end)
	end
	playing = nil
end

local function selectedEntry()
	if not state.selected then
		return nil
	end
	return state.entries[state.selected]
end

local function playSelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	stopPlaying()
	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. tostring(entry.id)
		sound.Volume = 1
		sound.Parent = SoundService
		sound:Play()
		playing = sound
	end)
	if ok then
		notify("Audio Logger", "Playing " .. trim(entry.name, 28))
	else
		notify("Audio Logger", "That sound will not load")
	end
end

local function copySelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	if copyText(tostring(entry.id)) then
		notify("Audio Logger", "Copied " .. tostring(entry.id))
	else
		notify("Audio Logger", handle .. " cannot copy to the clipboard")
	end
end

local function entryLine(entry)
	return tostring(entry.id) .. " | " .. entry.name
end

local function saveAll()
	if #state.order == 0 then
		notify("Audio Logger", "Nothing to save yet")
		return
	end
	local lines = {}
	for _, id in ipairs(state.order) do
		local entry = state.entries[id]
		if entry then
			table.insert(lines, entryLine(entry))
		end
	end
	local text = table.concat(lines, "\n")
	local wrote = writeFile(CONFIG.filePath, text)
	local copied = copyText(text)
	if wrote then
		notify("Audio Logger", ("Saved %d to %s"):format(#lines, CONFIG.filePath))
	elseif copied then
		notify("Audio Logger", ("%d ids copied to the clipboard"):format(#lines))
	else
		notify("Audio Logger", handle .. " cannot write files")
	end
end

local function saveSelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	local text = entryLine(entry)
	if writeFile(CONFIG.selectedPath, text) then
		notify("Audio Logger", "Saved " .. tostring(entry.id) .. " to " .. CONFIG.selectedPath)
	elseif copyText(text) then
		notify("Audio Logger", "Copied " .. tostring(entry.id))
	else
		notify("Audio Logger", handle .. " cannot write files")
	end
end

local function openSaved()
	local text = readFile(CONFIG.filePath)
	if not text then
		notify("Audio Logger", "No " .. CONFIG.filePath .. " on this " .. handle)
		return
	end
	local added = 0
	for line in string.gmatch(text, "[^\r\n]+") do
		local id = parseId(line)
		if id and addEntry(id) then
			added += 1
		end
	end
	updateStats()
	queueRender()
	notify("Audio Logger", ("Opened %s, %d new"):format(CONFIG.filePath, added))
end

local function banSelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	state.banned[entry.id] = true
	state.bannedNames[entry.id] = entry.name
	dropEntry(entry.id)
	persistBans()
	updateStats()
	notify("Audio Logger", "Banned " .. tostring(entry.id))
end

local function clearSelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	dropEntry(entry.id)
	updateStats()
end

local function clearUnselected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick the one you want to keep first")
		return
	end
	for index = #state.order, 1, -1 do
		local id = state.order[index]
		if id ~= entry.id then
			dropEntry(id)
		end
	end
	updateStats()
end

----------------------------------------------------------------------
-- the banned panel
----------------------------------------------------------------------

local bannedPanel = make("Frame", {
	Name = "Banned",
	Position = UDim2.fromOffset(0, CONFIG.toolbarHeight + 2),
	Size = UDim2.new(1, 0, 1, -CONFIG.toolbarHeight - 2 - statusHeight),
	BackgroundColor3 = CONFIG.colour.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 5,
}, leftColumn)
corner(bannedPanel, CONFIG.cornerRadius)
stroke(bannedPanel, CONFIG.colour.edge, CONFIG.strokeThickness, 0.3)

local bannedHeader = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundColor3 = CONFIG.colour.backgroundTop,
	BorderSizePixel = 0,
	ZIndex = 6,
}, bannedPanel)

local bannedTitle = label(bannedHeader, {
	Name = "Title",
	Text = "Banned audios",
	TextSize = CONFIG.sizes.small,
	Position = UDim2.fromOffset(8, 0),
	Size = UDim2.new(1, -80, 1, 0),
	ZIndex = 7,
})

local bannedClose = make("TextButton", {
	Name = "Close",
	Text = "close",
	Font = CONFIG.font,
	TextSize = CONFIG.sizes.tiny,
	TextColor3 = CONFIG.colour.dim,
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(48, 18),
	ZIndex = 7,
}, bannedHeader)

local bannedScroller = make("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(CONFIG.listPadding, 26),
	Size = UDim2.new(1, -CONFIG.listPadding * 2, 1, -32),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = CONFIG.colour.edge,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 6,
}, bannedPanel)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2),
}, bannedScroller)

local bannedEmpty = label(bannedScroller, {
	Name = "Empty",
	Text = "Nothing banned yet.",
	TextColor3 = CONFIG.colour.dimmer,
	TextSize = CONFIG.sizes.small,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -2, 0, 18),
	LayoutOrder = 1,
	ZIndex = 7,
})

local function refreshBanned()
	for _, child in ipairs(bannedScroller:GetChildren()) do
		if child ~= bannedEmpty and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local ids = {}
	for id in pairs(state.banned) do
		table.insert(ids, id)
	end
	table.sort(ids)
	bannedTitle.Text = ("Banned audios (%d)"):format(#ids)
	bannedEmpty.Visible = #ids == 0

	for index, id in ipairs(ids) do
		local row = make("Frame", {
			Name = tostring(id),
			BackgroundColor3 = CONFIG.colour.panel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 0, CONFIG.rowHeight),
			LayoutOrder = index + 1,
			ZIndex = 6,
		}, bannedScroller)
		corner(row, 4)
		stroke(row, CONFIG.colour.edge, 1, 0.6)

		label(row, {
			Name = "Name",
			Text = trim(state.bannedNames[id] or ("Audio " .. tostring(id)), 34),
			TextSize = CONFIG.sizes.small,
			TextColor3 = CONFIG.colour.dim,
			Position = UDim2.fromOffset(7, 0),
			Size = UDim2.new(1, -140, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		})
		label(row, {
			Name = "Id",
			Text = tostring(id),
			TextColor3 = CONFIG.colour.dimmer,
			TextSize = CONFIG.sizes.tiny,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -112, 0, 0),
			Size = UDim2.fromOffset(52, CONFIG.rowHeight),
			ZIndex = 7,
		})

		local unban = make("TextButton", {
			Name = "Unban",
			Text = "UNBAN",
			Font = CONFIG.font,
			TextSize = CONFIG.sizes.tiny,
			TextColor3 = CONFIG.colour.text,
			AutoButtonColor = false,
			BackgroundColor3 = CONFIG.colour.rowFill,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(50, 16),
			ZIndex = 7,
		}, row)
		corner(unban, 4)
		stroke(unban, CONFIG.colour.rowFill, 1, 0.84)

		local unbanId = id
		track(unban.Activated:Connect(function()
			state.banned[unbanId] = nil
			state.bannedNames[unbanId] = nil
			persistBans()
			refreshBanned()
			updateStats()
			notify("Audio Logger", "Unbanned " .. tostring(unbanId))
			-- a fresh pass of the current target, so it comes back if it is still there
			beginScan(state.scope)
		end))
	end
end

local function showBanned(show)
	if show then
		refreshBanned()
	end
	bannedPanel.Visible = show
end

----------------------------------------------------------------------
-- wiring
----------------------------------------------------------------------

track(autoButton.Activated:Connect(function()
	setAutoScan(not state.autoScan)
	notify("Audio Logger", "Auto Scan " .. (state.autoScan and "on" or "off"))
end))
track(saveSelectedButton.Activated:Connect(saveSelected))
track(saveAllButton.Activated:Connect(saveAll))
track(clearSelectedButton.Activated:Connect(clearSelected))
track(clearUnselectedButton.Activated:Connect(clearUnselected))

for _, name in ipairs(scopeOrder) do
	local button = scopeButtons[name]
	track(button.Activated:Connect(function()
		if beginScan(name) then
			notify("Audio Logger", "Scanning " .. name)
		else
			notify("Audio Logger", "Cannot scan " .. name .. " from here")
		end
	end))
end

track(playToolButton.Activated:Connect(playSelected))
track(copyToolButton.Activated:Connect(copySelected))
track(openButton.Activated:Connect(openSaved))
track(saveButton.Activated:Connect(saveAll))
track(banButton.Activated:Connect(banSelected))
track(bannedButton.Activated:Connect(function()
	showBanned(not bannedPanel.Visible)
end))
track(bannedClose.Activated:Connect(function()
	showBanned(false)
end))

----------------------------------------------------------------------
-- drag, minimise, close
----------------------------------------------------------------------

do
	local dragging = false
	local dragStart = nil
	local startPosition = nil

	track(title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = input.Position
			startPosition = window.Position
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local delta = input.Position - dragStart
		window.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end))
end

local minimised = false
track(minimiseButton.Activated:Connect(function()
	minimised = not minimised
	body.Visible = not minimised
	tween(window, motionInfo(0.18), {
		Size = UDim2.fromOffset(CONFIG.windowWidth, minimised and CONFIG.titleHeight or CONFIG.windowHeight),
	})
	minimiseButton.Text = minimised and "+" or "_"
end))

track(minimiseButton.MouseEnter:Connect(function()
	tween(minimiseStroke, motionInfo(0.1), { Transparency = 0.6 })
end))
track(minimiseButton.MouseLeave:Connect(function()
	tween(minimiseStroke, motionInfo(0.1), { Transparency = 0.86 })
end))
track(closeButton.MouseEnter:Connect(function()
	tween(closeButton, motionInfo(0.1), {
		BackgroundColor3 = CONFIG.colour.red,
		BackgroundTransparency = 0.72,
	})
	tween(closeStroke, motionInfo(0.1), { Color = CONFIG.colour.red, Transparency = 0.4 })
end))
track(closeButton.MouseLeave:Connect(function()
	tween(closeButton, motionInfo(0.1), {
		BackgroundColor3 = CONFIG.colour.rowFill,
		BackgroundTransparency = 0.95,
	})
	tween(closeStroke, motionInfo(0.1), {
		Color = CONFIG.colour.rowFill,
		Transparency = 0.86,
	})
end))

----------------------------------------------------------------------
-- public handle
----------------------------------------------------------------------

local function destroy()
	stopPlaying()
	setCapturing(false)
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	connections = {}
	if gui.Parent then
		gui:Destroy()
	end
	if _G.KitzAlogger and _G.KitzAlogger.gui == gui then
		_G.KitzAlogger = nil
	end
end

track(closeButton.Activated:Connect(destroy))

_G.KitzAlogger = {
	gui = gui,
	scan = function(name)
		return beginScan(name or state.scope)
	end,
	rescan = function()
		beginScan(state.scope)
	end,
	entries = function()
		return state.order, state.entries
	end,
	banned = function()
		return state.banned, state.bannedNames
	end,
	setAutoScan = setAutoScan,
	destroy = destroy,
}

setAutoScan(false)
updateStats()
notify("Audio Logger", "Ready. Auto Scan is off, pick a scan target.")
