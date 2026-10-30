-- Client-Sided Player Invisibility GUI
-- Executor ready | Type name + Toggle

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Remove old GUI if it exists
pcall(function()
    if CoreGui:FindFirstChild("ClientInvisGui") then
        CoreGui.ClientInvisGui:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClientInvisGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 260, 0, 145)
Main.Position = UDim2.new(0.5, -130, 0.4, 0)
Main.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 55, 65)
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Fix bottom corners of title bar
local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Client Invis"
Title.TextColor3 = Color3.fromRGB(235, 235, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Minimize Button (-)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "Minimize"
MinimizeBtn.Size = UDim2.new(0, 26, 0, 22)
MinimizeBtn.Position = UDim2.new(1, -58, 0.5, -11)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinimizeBtn

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "Close"
CloseBtn.Size = UDim2.new(0, 26, 0, 22)
CloseBtn.Position = UDim2.new(1, -28, 0.5, -11)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 50, 50)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

-- Content
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -20, 1, -45)
Content.Position = UDim2.new(0, 10, 0, 38)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Name Label
local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1, 0, 0, 18)
NameLabel.BackgroundTransparency = 1
NameLabel.Text = "Player Name:"
NameLabel.TextColor3 = Color3.fromRGB(180, 180, 195)
NameLabel.Font = Enum.Font.Gotham
NameLabel.TextSize = 12
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.Parent = Content

-- Name TextBox
local NameBox = Instance.new("TextBox")
NameBox.Name = "NameBox"
NameBox.Size = UDim2.new(1, 0, 0, 30)
NameBox.Position = UDim2.new(0, 0, 0, 20)
NameBox.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
NameBox.Text = ""
NameBox.PlaceholderText = "Type player name here..."
NameBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 140)
NameBox.TextColor3 = Color3.fromRGB(240, 240, 250)
NameBox.Font = Enum.Font.Gotham
NameBox.TextSize = 13
NameBox.ClearTextOnFocus = false
NameBox.Parent = Content

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = NameBox

local BoxStroke = Instance.new("UIStroke")
BoxStroke.Color = Color3.fromRGB(60, 60, 75)
BoxStroke.Thickness = 1
BoxStroke.Parent = NameBox

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(1, 0, 0, 34)
ToggleBtn.Position = UDim2.new(0, 0, 0, 60)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 115, 220)
ToggleBtn.Text = "Toggle Invis"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamSemibold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = Content

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

-- State
local isMinimized = false
local originalSize = Main.Size
local invisiblePlayers = {} -- [Player] = true/false

-- Functions
local function setPlayerInvisible(targetPlayer, state)
    if not targetPlayer or not targetPlayer.Character then return end

    local char = targetPlayer.Character
    local transparency = state and 1 or 0

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj.Name == "HumanoidRootPart" then
                obj.Transparency = 1
            else
                obj.Transparency = transparency
            end
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = transparency
        end
    end

    -- Accessories
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle then
                handle.Transparency = transparency
                for _, d in ipairs(handle:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("Texture") then
                        d.Transparency = transparency
                    end
                end
            end
        end
    end
end

local function findPlayer(name)
    name = name:lower():gsub("%s+", "")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():gsub("%s+", ""):find(name, 1, true) or 
           plr.DisplayName:lower():gsub("%s+", ""):find(name, 1, true) then
            return plr
        end
    end
    return nil
end

-- Toggle Button
ToggleBtn.MouseButton1Click:Connect(function()
    local name = NameBox.Text
    if name == "" then
        ToggleBtn.Text = "Enter a name!"
        task.wait(1.2)
        ToggleBtn.Text = "Toggle Invis"
        return
    end

    local target = findPlayer(name)
    if not target then
        ToggleBtn.Text = "Player not found"
        task.wait(1.2)
        ToggleBtn.Text = "Toggle Invis"
        return
    end

    local newState = not (invisiblePlayers[target] or false)
    invisiblePlayers[target] = newState
    setPlayerInvisible(target, newState)

    if newState then
        ToggleBtn.Text = target.Name .. " → Invisible"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 55, 55)
    else
        ToggleBtn.Text = target.Name .. " → Visible"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 115, 220)
    end

    task.wait(1.4)
    ToggleBtn.Text = "Toggle Invis"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 115, 220)
end)

-- Keep invis after respawn
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if invisiblePlayers[plr] then
            setPlayerInvisible(plr, true)
        end
    end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if invisiblePlayers[plr] then
            setPlayerInvisible(plr, true)
        end
    end)
end

-- Minimize
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        Content.Visible = false
        Main.Size = UDim2.new(0, 260, 0, 32)
    else
        Content.Visible = true
        Main.Size = originalSize
    end
end)

-- Close
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

print("Client Invis GUI loaded")
