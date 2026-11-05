--!nonstrict
--[[
	Kitz Audio Logger — a client-side audio logger for Roblox.

	loadstring(game:HttpGet("https://raw.githubusercontent.com/Kttyz/Scripts/main/Alogger.lua"))()

	Walks the instance tree for every Sound, pulls the numeric id out of each
	SoundId, resolves the real name through MarketplaceService, and lists them in
	a draggable window. Open and Save read and write KitzAudios.txt through the
	executor's file functions; BanAudio keeps a blacklist in KitzBans.txt so a
	track never comes back. Auto Scan keeps catching sounds the game creates
	after load.

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
	scanInterval = 1.5,
	resolveSpacing = 0.12,
	maxRows = 300,
	cornerRadius = 7,
	strokeThickness = 2,
	filePath = "KitzAudios.txt",
	banPath = "KitzBans.txt",
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
	if not canRead or typeof(isfile) ~= "function" or not isfile(path) then
		return nil
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

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------

local state = {
	entries = {},
	order = {},
	seen = {},
	banned = {},
	pending = {},
	pendingSet = {},
	resolvedCount = 0,
	scannedCount = 0,
	queueTotal = 0,
	selected = nil,
	autoScan = true,
}

local connections = {}
local function track(connection)
	table.insert(connections, connection)
	return connection
end

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
-- left column: toolbar and list
----------------------------------------------------------------------

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

local openButton = toolButton(toolbar, "Open", "Open", 52)
openButton.Position = UDim2.fromOffset(0, 3)
local saveButton = toolButton(toolbar, "Save", "Save", 52)
saveButton.Position = UDim2.fromOffset(58, 3)
local banButton = toolButton(toolbar, "BanAudio", "BanAudio", 72)
banButton.AnchorPoint = Vector2.new(1, 0)
banButton.Position = UDim2.new(1, -4, 0, 3)

local listFrame = make("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(0, CONFIG.toolbarHeight + 2),
	Size = UDim2.new(1, 0, 1, -CONFIG.toolbarHeight - 2),
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
	Text = "No sounds yet.  Auto Scan is on.",
	TextColor3 = CONFIG.colour.dimmer,
	TextSize = CONFIG.sizes.small,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
})

----------------------------------------------------------------------
-- right column: readouts over the controls
----------------------------------------------------------------------

local rightColumn = make("Frame", {
	Name = "Side",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 0),
	Size = UDim2.new(0, CONFIG.rightWidth, 1, -8),
	BackgroundTransparency = 1,
}, body)

local readouts = make("Frame", {
	Name = "Readouts",
	Size = UDim2.fromOffset(CONFIG.rightWidth, 4 * 24 + 6),
	BackgroundColor3 = CONFIG.colour.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, rightColumn)
corner(readouts, CONFIG.cornerRadius)
stroke(readouts, CONFIG.colour.edge, CONFIG.strokeThickness, 0.35)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 2),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, readouts)

local readoutValues = {}

local function readout(order, key, titleText)
	local row = make("Frame", {
		Name = key,
		BackgroundColor3 = CONFIG.colour.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.new(1, -10, 0, 21),
		LayoutOrder = order,
	}, readouts)
	corner(row, 6)
	stroke(row, CONFIG.colour.edge, 1.5, 0.6)

	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = CONFIG.colour.accent,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
	}, row)

	label(row, {
		Name = "Label",
		Text = titleText,
		TextColor3 = CONFIG.colour.dim,
		TextSize = CONFIG.sizes.tiny,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0.6, -8, 1, 0),
	})

	local value = label(row, {
		Name = "Value",
		Text = "0",
		TextSize = CONFIG.sizes.small,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0.4, 0, 0, 0),
		Size = UDim2.new(0.6, -8, 1, 0),
	})

	readoutValues[key] = { row = row, fill = fill, value = value }
	return row
end

readout(1, "scanned", "SCANNED")
readout(2, "found", "FOUND")
readout(3, "named", "NAMED")
readout(4, "queue", "QUEUE")

local hatch = make("Frame", {
	Name = "Hatch",
	Position = UDim2.fromOffset(0, 4 * 24 + 12),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, rightColumn)
for index = 1, 11 do
	local line = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((index - 0.5) / 11, 0, 0.5, 0),
		Size = UDim2.fromOffset(1.5, 28),
		Rotation = 24,
		BackgroundColor3 = CONFIG.colour.edge,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}, hatch)
	corner(line, 1)
end

local controls = make("Frame", {
	Name = "Controls",
	Position = UDim2.fromOffset(0, 4 * 24 + 40),
	Size = UDim2.new(1, 0, 1, -(4 * 24 + 44)),
	BackgroundTransparency = 1,
}, rightColumn)

make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 4),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, controls)

local function controlButton(order, name, text)
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
		Size = UDim2.new(1, -10, 0, 27),
		LayoutOrder = order,
	}, controls)
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

local autoButton, autoStroke = controlButton(1, "Auto", "AUTO SCAN")
local playButton = controlButton(2, "Play", "PLAY")
local copyButton = controlButton(3, "Copy", "COPY ID")
local saveAllButton = controlButton(4, "SaveAll", "SAVE ALL")

----------------------------------------------------------------------
-- reading the tree
----------------------------------------------------------------------

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

local rowWidgets = {}
local renderQueued = false

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

	local widget = { row = row, stroke = rowStroke }

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

local function renderList()
	renderQueued = false
	if not scroller.Parent then
		return
	end
	for _, child in ipairs(scroller:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	rowWidgets = {}

	local shown = 0
	for _, id in ipairs(state.order) do
		if shown >= CONFIG.maxRows then
			break
		end
		local entry = state.entries[id]
		if entry then
			shown += 1
			rowFor(entry, shown)
			if state.selected == id then
				rowWidgets[id].paint(true)
			end
		end
	end

	emptyLabel.Visible = shown == 0
	if #state.order > shown then
		label(scroller, {
			Name = "More",
			Text = ("+%d more"):format(#state.order - shown),
			TextColor3 = CONFIG.colour.dimmer,
			TextSize = CONFIG.sizes.tiny,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -2, 0, 18),
			LayoutOrder = shown + 1,
		})
	end
end

local function queueRender()
	if renderQueued then
		return
	end
	renderQueued = true
	task.delay(0.15, renderList)
end

local function updateStats()
	local percent = 0
	if state.queueTotal > 0 then
		percent = 1 - (#state.pending / math.max(state.queueTotal, 1))
	end
	tween(progressFill, motionInfo(0.2), { Size = UDim2.fromScale(math.clamp(percent, 0, 1), 1) })

	readoutValues.scanned.value.Text = tostring(state.scannedCount)
	readoutValues.found.value.Text = tostring(#state.order)
	readoutValues.named.value.Text = tostring(state.resolvedCount)
	readoutValues.queue.value.Text = tostring(#state.pending)

	local resolvedFraction = if #state.order > 0 then state.resolvedCount / #state.order else 0
	tween(readoutValues.named.fill, motionInfo(0.2), {
		Size = UDim2.fromScale(math.clamp(resolvedFraction, 0, 1), 1),
	})
	local queueFraction = if state.queueTotal > 0 then #state.pending / math.max(state.queueTotal, 1) else 0
	tween(readoutValues.queue.fill, motionInfo(0.2), {
		Size = UDim2.fromScale(math.clamp(queueFraction, 0, 1), 1),
	})
end

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

-- one pass over the tree, time sliced so a big game never stalls a frame
local scanCursor = 0
local scanList = nil
local function scanOnce(budget)
	-- the pass keeps its own snapshot of the tree, so a slow walk does not
	-- re-read every descendant on each slice
	if not scanList then
		scanList = game:GetDescendants()
		scanCursor = 0
		state.scannedCount = #scanList
	end
	local list = scanList
	local deadline = os.clock() + budget
	local index = scanCursor + 1
	while index <= #list do
		local instance = list[index]
		if instance:IsA("Sound") then
			local id = parseId(instance.SoundId)
			if id then
				addEntry(id)
			end
		end
		index += 1
		if os.clock() >= deadline then
			scanCursor = index - 1
			return false
		end
	end
	scanCursor = 0
	scanList = nil
	return true
end

-- names, one at a time, so MarketplaceService is never hammered
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
				end
				queueRender()
			end
			updateStats()
			task.wait(CONFIG.resolveSpacing)
		else
			task.wait(0.2)
		end
	end
end)

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

local function saveAll()
	if #state.order == 0 then
		notify("Audio Logger", "Nothing to save yet")
		return
	end
	local lines = {}
	for _, id in ipairs(state.order) do
		local entry = state.entries[id]
		if entry then
			table.insert(lines, tostring(entry.id) .. " | " .. entry.name)
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

local function persistBans()
	local ids = {}
	for id in pairs(state.banned) do
		table.insert(ids, tostring(id))
	end
	writeFile(CONFIG.banPath, table.concat(ids, "\n"))
end

local function loadBans()
	local text = readFile(CONFIG.banPath)
	if not text then
		return
	end
	for line in string.gmatch(text, "[^\r\n]+") do
		local id = parseId(line)
		if id then
			state.banned[id] = true
		end
	end
end

local function banSelected()
	local entry = selectedEntry()
	if not entry then
		notify("Audio Logger", "Pick a sound first")
		return
	end
	state.banned[entry.id] = true
	state.entries[entry.id] = nil
	state.seen[entry.id] = nil
	for index, id in ipairs(state.order) do
		if id == entry.id then
			table.remove(state.order, index)
			break
		end
	end
	state.selected = nil
	persistBans()
	updateStats()
	queueRender()
	notify("Audio Logger", "Banned " .. tostring(entry.id))
end

local function setAutoScan(on)
	state.autoScan = on
	tween(autoStroke, motionInfo(0.15), {
		Color = on and CONFIG.colour.green or CONFIG.colour.edge,
		Transparency = on and 0.25 or 0.45,
	})
end

track(autoButton.Activated:Connect(function()
	setAutoScan(not state.autoScan)
	notify("Audio Logger", "Auto Scan " .. (state.autoScan and "on" or "off"))
end))
track(playButton.Activated:Connect(playSelected))
track(copyButton.Activated:Connect(copySelected))
track(saveAllButton.Activated:Connect(saveAll))
track(openButton.Activated:Connect(openSaved))
track(saveButton.Activated:Connect(saveAll))
track(banButton.Activated:Connect(banSelected))

----------------------------------------------------------------------
-- the scan loop
----------------------------------------------------------------------

task.spawn(function()
	while true do
		if state.autoScan and scroller.Parent then
			local done
			repeat
				local finished = scanOnce(0.002)
				done = finished
				updateStats()
				if not finished then
					task.wait()
				end
			until done or not state.autoScan
		end
		task.wait(CONFIG.scanInterval)
	end
end)

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
	rescan = function()
		repeat
			task.wait()
		until scanOnce(0.004)
		updateStats()
	end,
	entries = function()
		return state.order, state.entries
	end,
	destroy = destroy,
}

loadBans()
setAutoScan(true)
updateStats()
notify("Audio Logger", "Ready, scanning for sounds")
