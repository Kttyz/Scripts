-- Animation Changer (Local)
-- Idle1 = loop | Idle2 = fidget 5–15s | does not override emote wheel

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if _G.AnimChangerCleanup then
	pcall(_G.AnimChangerCleanup)
end

local DEFAULT_IDLE1 = 71638717540676
local DEFAULT_IDLE2 = 76158324638472

local connections = {}
local minimized = false
local expandedSize = Vector2.new(340, 560)
local originals = {}
local running = true

local idle1Asset = nil
local idle2Asset = nil
local idle2Track = nil
local idle2Busy = false
local idle2LoopRunning = false

local function connect(signal, cb)
	local c = signal:Connect(cb)
	table.insert(connections, c)
	return c
end

local ANIM_SLOTS = {
	{ key = "idle1", label = "Idle 1", folder = "idle" },
	{ key = "idle2", label = "Idle 2", folder = "idle" },
	{ key = "walk",  label = "Walk",  folder = "walk" },
	{ key = "run",   label = "Run",   folder = "run" },
	{ key = "jump",  label = "Jump",  folder = "jump" },
	{ key = "fall",  label = "Fall",  folder = "fall" },
	{ key = "climb", label = "Climb", folder = "climb" },
	{ key = "swim",  label = "Swim",  folder = "swim" },
}

local inputBoxes = {}

local function parseId(text)
	if not text or text == "" then return nil end
	text = tostring(text):gsub("%s+", "")
	if text:lower():find("/bundles/") then
		return nil, "bundle"
	end
	local num = text:match("(%d%d%d%d%d+)")
	if not num then return nil end
	return tonumber(num)
end

local function assetString(id)
	return "rbxassetid://" .. tostring(id)
end

local function idFromAsset(asset)
	if not asset then return nil end
	return tonumber((asset:match("(%d+)")))
end

-- Emote wheel / tool actions use these priorities
local function isEmoteOrActionPlaying(hum)
	if not hum then return false end
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
		if t.IsPlaying then
			local p = t.Priority
			if p == Enum.AnimationPriority.Action
				or p == Enum.AnimationPriority.Action2
				or p == Enum.AnimationPriority.Action3
				or p == Enum.AnimationPriority.Action4 then
				return true
			end
		end
	end
	return false
end

local function horizontalSpeed(char)
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
	if not root then return 0 end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- ==================== GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "AnimChangerGui"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(expandedSize.X, expandedSize.Y)
main.Position = UDim2.new(0, 20, 0.5, -280)
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
titleBar.Text = "Animation Changer"
titleBar.TextColor3 = Color3.fromRGB(245, 245, 245)
titleBar.TextSize = 14
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Active = true
titleBar.Parent = main

local function makeTopButton(text, color, offset)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(26, 26)
	btn.Position = UDim2.new(1, offset, 0, 4)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 16
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = false
	btn.Parent = main
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	return btn
end

local minimizeBtn = makeTopButton("-", Color3.fromRGB(70, 70, 80), -62)
local closeBtn = makeTopButton("X", Color3.fromRGB(130, 60, 65), -32)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -54)
content.Position = UDim2.fromOffset(10, 40)
content.BackgroundTransparency = 1
content.Parent = main

local layout = Instance.new("UIListLayout", content)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local statusLabel = Instance.new("TextLabel")
statusLabel.LayoutOrder = 0
statusLabel.Size = UDim2.new(1, 0, 0, 44)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "Idle2 never starts/continues during emotes.\nPress Apply after load."
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 180)
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = content

local function makeRow(order, labelText, placeholder, defaultText)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	row.BorderSizePixel = 0
	row.Parent = content
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(56, 36)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamSemibold
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(230, 230, 240)
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -72, 0, 26)
	box.Position = UDim2.fromOffset(64, 5)
	box.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	box.BorderSizePixel = 0
	box.PlaceholderText = placeholder or "ID or URL"
	box.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
	box.Text = defaultText or ""
	box.TextColor3 = Color3.new(1, 1, 1)
	box.TextSize = 11
	box.Font = Enum.Font.Gotham
	box.ClearTextOnFocus = false
	box.Parent = row
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	return box
end

for i, slot in ipairs(ANIM_SLOTS) do
	local defaultText, ph = "", "ID or URL"
	if slot.key == "idle1" then
		defaultText = tostring(DEFAULT_IDLE1)
		ph = "main idle (loop)"
	elseif slot.key == "idle2" then
		defaultText = tostring(DEFAULT_IDLE2)
		ph = "fidget 5–15s"
	end
	inputBoxes[slot.key] = makeRow(i, slot.label, ph, defaultText)
end

local buttonRow = Instance.new("Frame")
buttonRow.LayoutOrder = 100
buttonRow.Size = UDim2.new(1, 0, 0, 34)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = content

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(0.5, -4, 1, 0)
applyBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 80)
applyBtn.Text = "Apply"
applyBtn.TextColor3 = Color3.new(1, 1, 1)
applyBtn.TextSize = 13
applyBtn.Font = Enum.Font.GothamBold
applyBtn.AutoButtonColor = false
applyBtn.Parent = buttonRow
Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 4)

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(0.5, -4, 1, 0)
resetBtn.Position = UDim2.new(0.5, 4, 0, 0)
resetBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 65)
resetBtn.Text = "Reset Defaults"
resetBtn.TextColor3 = Color3.new(1, 1, 1)
resetBtn.TextSize = 13
resetBtn.Font = Enum.Font.GothamBold
resetBtn.AutoButtonColor = false
resetBtn.Parent = buttonRow
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 4)

-- ==================== CORE ====================
local function getAnimate(char)
	return char and char:FindFirstChild("Animate")
end

local function getIdleAnimations(animate)
	local folder = animate and animate:FindFirstChild("idle")
	if not folder then return {} end
	local list = {}
	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Animation") then
			table.insert(list, obj)
		end
	end
	if #list == 0 then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("Animation") then
				table.insert(list, obj)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function captureOriginals(char)
	originals = {}
	local animate = getAnimate(char)
	if not animate then return false end

	local idles = getIdleAnimations(animate)
	originals.idle1, originals.idle2 = {}, {}
	if idles[1] then table.insert(originals.idle1, { id = idles[1].AnimationId }) end
	if idles[2] then table.insert(originals.idle2, { id = idles[2].AnimationId }) end

	for _, slot in ipairs(ANIM_SLOTS) do
		if slot.key ~= "idle1" and slot.key ~= "idle2" then
			local folder = animate:FindFirstChild(slot.folder)
			originals[slot.key] = {}
			if folder then
				for _, obj in ipairs(folder:GetDescendants()) do
					if obj:IsA("Animation") then
						table.insert(originals[slot.key], { id = obj.AnimationId })
					end
				end
			end
		end
	end
	return true
end

local function enforceIdle1OnAnimate(char)
	if not idle1Asset then return end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	-- never touch Animate while emoting
	if isEmoteOrActionPlaying(hum) then return end
	local idles = getIdleAnimations(getAnimate(char))
	for _, animObj in ipairs(idles) do
		animObj.AnimationId = idle1Asset
	end
end

local function setFolderAll(char, folderName, id)
	local animate = getAnimate(char)
	if not animate then return false end
	local folder = animate:FindFirstChild(folderName)
	if not folder then return false end
	local asset = assetString(id)
	local n = 0
	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("Animation") then
			obj.AnimationId = asset
			n += 1
		end
	end
	return n > 0
end

local function restoreOriginals(char)
	local restored = 0
	local animate = getAnimate(char)
	if not animate then return 0 end
	local idles = getIdleAnimations(animate)
	if originals.idle1 and originals.idle1[1] and idles[1] then
		idles[1].AnimationId = originals.idle1[1].id
		restored += 1
	end
	if originals.idle2 and originals.idle2[1] and idles[2] then
		idles[2].AnimationId = originals.idle2[1].id
		restored += 1
	end
	for _, slot in ipairs(ANIM_SLOTS) do
		if slot.key ~= "idle1" and slot.key ~= "idle2" then
			local folder = animate:FindFirstChild(slot.folder)
			local list = originals[slot.key]
			if folder and list then
				local anims = {}
				for _, obj in ipairs(folder:GetDescendants()) do
					if obj:IsA("Animation") then
						table.insert(anims, obj)
					end
				end
				for i, entry in ipairs(list) do
					if anims[i] then
						anims[i].AnimationId = entry.id
						restored += 1
					end
				end
			end
		end
	end
	return restored
end

local function stopIdle2Track(fade)
	if idle2Track then
		local t = idle2Track
		idle2Track = nil
		pcall(function()
			if t.IsPlaying then
				t:Stop(fade or 0.12)
			end
			t:Destroy()
		end)
	end
	idle2Busy = false
end

local function playIdle2Once()
	if idle2Busy or not idle2Asset then return end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if horizontalSpeed(char) > 2 then return end
	-- critical: do not start over emotes
	if isEmoteOrActionPlaying(hum) then return end

	idle2Busy = true

	-- Only fade OUR idle1 track weight — do not Stop every Idle track (breaks some emotes)
	if idle1Asset then
		for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
			if t.IsPlaying and t.Priority == Enum.AnimationPriority.Idle then
				local aid = t.Animation and t.Animation.AnimationId or ""
				if aid == idle1Asset then
					pcall(function()
						t:AdjustWeight(0.05, 0.2)
					end)
				end
			end
		end
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = idle2Asset

	local ok, track = pcall(function()
		return hum:LoadAnimation(anim)
	end)
	if not ok or not track then
		anim:Destroy()
		idle2Busy = false
		return
	end

	idle2Track = track
	track.Looped = false
	-- Idle priority: below Action emotes, so emote wheel always wins
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.2)

	local finished = false
	local function finish()
		if finished then return end
		finished = true
		idle2Track = nil
		idle2Busy = false
		pcall(function() anim:Destroy() end)

		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		-- only restore idle1 if not emoting
		if c and not isEmoteOrActionPlaying(h) then
			enforceIdle1OnAnimate(c)
		end
	end

	track.Stopped:Once(finish)
	task.delay(12, function()
		if idle2Track == track then
			pcall(function() track:Stop(0.1) end)
			finish()
		end
	end)
end

local function startIdle2Loop()
	if idle2LoopRunning then return end
	idle2LoopRunning = true
	task.spawn(function()
		while running and idle2LoopRunning and idle2Asset do
			task.wait(math.random(5, 15))
			if not running or not idle2LoopRunning or not idle2Asset then
				break
			end
			while idle2Busy and running do
				task.wait(0.2)
			end
			-- skip this tick entirely if emoting
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and isEmoteOrActionPlaying(hum) then
				continue
			end
			if running and idle2LoopRunning and idle2Asset then
				playIdle2Once()
			end
		end
		idle2LoopRunning = false
	end)
end

local function stopIdle2Loop()
	idle2LoopRunning = false
	idle2Asset = nil
	stopIdle2Track(0.1)
end

-- Cancel fidget only for real movement or emotes (never touch the emote track itself)
connect(RunService.Heartbeat, function()
	if not idle2Track or not idle2Track.IsPlaying then return end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if horizontalSpeed(char) > 2.5 or isEmoteOrActionPlaying(hum) then
		stopIdle2Track(0.1)
		-- do not enforce idle1 during emote
		if not isEmoteOrActionPlaying(hum) then
			enforceIdle1OnAnimate(char)
		end
	end
end)

local function applyAll()
	local char = LocalPlayer.Character
	if not char or not getAnimate(char) then
		statusLabel.Text = "No character / Animate script"
		return
	end

	if next(originals) == nil then
		captureOriginals(char)
	end

	local applied = 0
	local sawBundle = false

	local id1, err1 = parseId(inputBoxes.idle1.Text)
	if err1 == "bundle" then
		sawBundle = true
	elseif id1 then
		idle1Asset = assetString(id1)
		if not isEmoteOrActionPlaying(char:FindFirstChildOfClass("Humanoid")) then
			enforceIdle1OnAnimate(char)
		end
		applied += 1
	end

	local id2, err2 = parseId(inputBoxes.idle2.Text)
	if err2 == "bundle" then
		sawBundle = true
	elseif id2 then
		idle2Asset = assetString(id2)
		applied += 1
		if not idle2LoopRunning then
			startIdle2Loop()
		end
	elseif inputBoxes.idle2.Text == "" then
		stopIdle2Loop()
	end

	for _, slot in ipairs(ANIM_SLOTS) do
		if slot.key ~= "idle1" and slot.key ~= "idle2" then
			local id, err = parseId(inputBoxes[slot.key].Text)
			if err == "bundle" then
				sawBundle = true
			elseif id then
				if setFolderAll(char, slot.folder, id) then
					applied += 1
				end
			end
		end
	end

	if sawBundle then
		statusLabel.Text = "Don't use /bundles/ links."
	elseif applied > 0 then
		statusLabel.Text = ("Applied %d. Idle2 yields to emote wheel."):format(applied)
	else
		statusLabel.Text = "Nothing applied"
	end
end

local function resetDefaults()
	local char = LocalPlayer.Character
	if not char then
		statusLabel.Text = "No character"
		return
	end

	stopIdle2Loop()
	idle1Asset = nil

	inputBoxes.idle1.Text = tostring(DEFAULT_IDLE1)
	inputBoxes.idle2.Text = tostring(DEFAULT_IDLE2)
	for _, slot in ipairs(ANIM_SLOTS) do
		if slot.key ~= "idle1" and slot.key ~= "idle2" then
			inputBoxes[slot.key].Text = ""
		end
	end

	if next(originals) ~= nil then
		local n = restoreOriginals(char)
		statusLabel.Text = n > 0 and ("Restored %d original anim(s)"):format(n) or "Respawn to fully reset"
		return
	end
	statusLabel.Text = "No originals stored — respawn"
end

local function onCharacter(char)
	stopIdle2Loop()
	idle1Asset = nil
	task.wait(0.8)
	if captureOriginals(char) then
		statusLabel.Text = "Originals stored. Press Apply."
	else
		statusLabel.Text = "Animate not found"
	end
end

if LocalPlayer.Character then
	task.spawn(onCharacter, LocalPlayer.Character)
end
connect(LocalPlayer.CharacterAdded, onCharacter)

connect(applyBtn.MouseButton1Click, applyAll)
connect(resetBtn.MouseButton1Click, resetDefaults)

local function cleanup()
	running = false
	stopIdle2Loop()
	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	if gui then gui:Destroy() end
end
_G.AnimChangerCleanup = cleanup
connect(closeBtn.MouseButton1Click, cleanup)

connect(minimizeBtn.MouseButton1Click, function()
	minimized = not minimized
	content.Visible = not minimized
	minimizeBtn.Text = minimized and "+" or "-"
	main.Size = UDim2.fromOffset(expandedSize.X, minimized and 34 or expandedSize.Y)
end)

local dragging, dragStart, startPos
connect(titleBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
