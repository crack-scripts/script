--══════════════════════════════════════════════════════════════
--  ONION13 HUB — Fixed & Optimized
--══════════════════════════════════════════════════════════════

-------------------------------------------------
-- Services
-------------------------------------------------
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local StarterGui          = game:GetService("StarterGui")
local CollectionService   = game:GetService("CollectionService")

-------------------------------------------------
-- Local Player / References
--  ★ Palitan ang mga placeholder na ito ng
--    totoong reference mula sa iyong game.
-------------------------------------------------
local LocalPlayer = Players.LocalPlayer

-- Mga function na kailangan mong i‑define batay sa laro:
-- v29(player)  → true kung Pirate
-- v30(player)  → true kung Marine
-- v17()        → save / sync settings
-- v19(inst)    → optimize / remove meshes (Fflag)
-- v21          → current aimbot target reference

local function isPirate(player)
    -- PALITAN ITO ng totoong logic
    return player:FindFirstChild("Team") and tostring(player.Team) == "Pirates"
end

local function isMarine(player)
    -- PALITAN ITO ng totoong logic
    return player:FindFirstChild("Team") and tostring(player.Team) == "Marines"
end

local function syncSettings()
    -- PALITAN ITO kung meron kang save/sync function
end

local function optimizeInstance(inst)
    -- PALITAN ITO ng totoong Fflag / anti-lag logic
    if inst:IsA("MeshPart") then
        inst.TextureID = ""
    end
end

-------------------------------------------------
-- Default Global Settings
-------------------------------------------------
_G.Skillaimbot      = _G.Skillaimbot      or false
_G.AimBotSkillPosition = _G.AimBotSkillPosition or nil
_G.ESPEnabled       = _G.ESPEnabled       or false
_G.SpeedEnabled     = _G.SpeedEnabled     or false
_G.SpeedValue       = _G.SpeedValue       or 1
_G.MaxAimDistance   = _G.MaxAimDistance   or 500
_G.WalkOnWater      = _G.WalkOnWater      or false
_G.AutoRaceAbility  = _G.AutoRaceAbility  or false
_G.AutoV4           = _G.AutoV4           or false
_G.AntiStun         = _G.AntiStun         or false
_G.FastAttack       = _G.FastAttack       or false
_G.FflagBlocky      = _G.FflagBlocky      or false

local currentAimTarget = nil  -- dating "v21"

--══════════════════════════════════════════════════════════════
-- 1. NAMECALL HOOK  (Skill Aimbot)
--══════════════════════════════════════════════════════════════
local Metatable        = getrawmetatable(game)
local OriginalNamecall = Metatable.__namecall

setreadonly(Metatable, false)

Metatable.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}

    if _G.Skillaimbot and _G.AimBotSkillPosition then
        if method == "FireServer" or method == "InvokeServer" then
            local changed = false
            for i = 1, #args do
                local argType = typeof(args[i])
                if argType == "Vector3" then
                    args[i] = _G.AimBotSkillPosition
                    changed = true
                elseif argType == "CFrame" then
                    args[i] = CFrame.new(_G.AimBotSkillPosition)
                    changed = true
                end
            end
            if changed then
                return OriginalNamecall(self, unpack(args))
            end
        end
    end

    return OriginalNamecall(self, ...)
end)

setreadonly(Metatable, true)

--══════════════════════════════════════════════════════════════
-- 2. ESP SYSTEM
--══════════════════════════════════════════════════════════════
local espData = {}  -- [Player] = { Box, NameLabel, TeamLabel, ... }

local function createESP(player)
    if player == LocalPlayer then return end
    if not player.Team and not isPirate(player) and not isMarine(player) then
        return
    end

    -- Linisin ang lumang ESP kung meron
    if espData[player] and espData[player].Box then
        espData[player].Box:Destroy()
    end

    -- BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name           = "ESP_" .. player.Name
    billboard.AlwaysOnTop    = true
    billboard.Size           = UDim2.new(0, 150, 0, 70)
    billboard.StudsOffset    = Vector3.new(0, 3, 0)

    -- Name Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                 = UDim2.new(1, 0, 0.25, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextScaled           = true
    nameLabel.Font                 = Enum.Font.SourceSansBold
    nameLabel.Text                 = player.Name
    nameLabel.Parent               = billboard

    -- Team Label
    local teamLabel = Instance.new("TextLabel")
    teamLabel.Size                 = UDim2.new(1, 0, 0.18, 0)
    teamLabel.Position             = UDim2.new(0, 0, 0.25, 0)
    teamLabel.BackgroundTransparency = 1
    teamLabel.TextStrokeTransparency = 0.5
    teamLabel.TextScaled           = true
    teamLabel.Font                 = Enum.Font.SourceSans
    teamLabel.Text                 = "No Team"
    teamLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
    teamLabel.Parent               = billboard

    -- Level Label
    local lvlLabel = Instance.new("TextLabel")
    lvlLabel.Size                 = UDim2.new(1, 0, 0.18, 0)
    lvlLabel.Position             = UDim2.new(0, 0, 0.43, 0)
    lvlLabel.BackgroundTransparency = 1
    lvlLabel.TextColor3           = Color3.fromRGB(255, 215, 0)
    lvlLabel.TextStrokeTransparency = 0.5
    lvlLabel.TextScaled           = true
    lvlLabel.Font                 = Enum.Font.SourceSansBold
    lvlLabel.Text                 = "Lv..."
    lvlLabel.Parent               = billboard

    -- HP Bar Background
    local hpBg = Instance.new("Frame")
    hpBg.Size            = UDim2.new(0.8, 0, 0.1, 0)
    hpBg.Position        = UDim2.new(0.1, 0, 0.62, 0)
    hpBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    hpBg.BorderSizePixel = 0
    hpBg.Parent          = billboard

    -- HP Bar Fill
    local hpBar = Instance.new("Frame")
    hpBar.Size            = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpBar.BorderSizePixel = 0
    hpBar.Parent          = hpBg

    -- HP Text
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Size                 = UDim2.new(1, 0, 0.2, 0)
    hpLabel.Position             = UDim2.new(0, 0, 0.6, 0)  -- relative sa billboard
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3           = Color3.fromRGB(0, 255, 0)
    hpLabel.TextStrokeTransparency = 0.5
    hpLabel.TextScaled           = true
    hpLabel.Font                 = Enum.Font.SourceSansBold
    hpLabel.Text                 = "100%"
    hpLabel.Parent               = billboard

    -- Distance Label
    local distLabel = Instance.new("TextLabel")
    distLabel.Size                 = UDim2.new(1, 0, 0.18, 0)
    distLabel.Position             = UDim2.new(0, 0, 0.8, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3           = Color3.fromRGB(255, 255, 0)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextScaled           = true
    distLabel.Font                 = Enum.Font.SourceSansBold
    distLabel.Text                 = "0 studs"
    distLabel.Parent               = billboard

    -- I-parent ang billboard sa CoreGui muna; adornee ang maglalagay sa character
    billboard.Parent = game:GetService("CoreGui")

    espData[player] = {
        Box       = billboard,
        NameLabel = nameLabel,
        TeamLabel = teamLabel,
        LvlLabel  = lvlLabel,
        HPBar     = hpBar,
        HPLabel   = hpLabel,
        DistLabel = distLabel,
    }
end

-------------------------------------------------
-- ESP Update Loop  (throttled to ~3.3 FPS)
-------------------------------------------------
local lastESPUpdate = 0

RunService.RenderStepped:Connect(function()
    local now = tick()
    if (now - lastESPUpdate) < 0.3 then return end
    lastESPUpdate = now

    if not _G.ESPEnabled then return end

    for player, data in pairs(espData) do
        -- Cleanup kung wala na ang player
        if not player or not player.Parent or not data.Box or not data.Box.Parent then
            if data.Box then data.Box:Destroy() end
            espData[player] = nil
            continue
        end

        local char = player.Character
        if not char then
            data.Box.Enabled = false
            continue
        end

        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChild("Humanoid")

        if not hrp or not hum or hum.Health <= 0 then
            data.Box.Enabled = false
            continue
        end

        -- Adornee + Enable
        data.Box.Adornee = hrp
        data.Box.Enabled = true

        -- HP
        local hp    = hum.Health
        local maxHp = hum.MaxHealth
        local ratio = hp / maxHp

        local hpText = string.format("%.0f HP", hp)
        if data.HPLabel.Text ~= hpText then
            data.HPLabel.Text = hpText
        end

        local barSize = UDim2.new(ratio, 0, 1, 0)
        if data.HPBar.Size ~= barSize then
            data.HPBar.Size = barSize
        end

        local pct = ratio * 100
        local hpColor
        if pct > 60 then
            hpColor = Color3.fromRGB(0, 255, 0)
        elseif pct > 30 then
            hpColor = Color3.fromRGB(255, 165, 0)
        else
            hpColor = Color3.fromRGB(255, 0, 0)
        end

        if data.HPBar.BackgroundColor3 ~= hpColor then
            data.HPBar.BackgroundColor3 = hpColor
            data.HPLabel.TextColor3     = hpColor
        end

        -- Level
        local lvlStr = "?"
        if player:FindFirstChild("Data") and player.Data:FindFirstChild("Level") then
            lvlStr = tostring(player.Data.Level.Value)
        elseif player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level") then
            lvlStr = tostring(player.leaderstats.Level.Value)
        end
        local lvlText = "Lv. " .. lvlStr
        if data.LvlLabel.Text ~= lvlText then
            data.LvlLabel.Text = lvlText
        end

        -- Team
        if isPirate(player) then
            if data.TeamLabel.Text ~= "PIRATE" then
                data.NameLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                data.TeamLabel.Text       = "PIRATE"
                data.TeamLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif isMarine(player) then
            if data.TeamLabel.Text ~= "MARINE" then
                data.NameLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
                data.TeamLabel.Text       = "MARINE"
                data.TeamLabel.TextColor3 = Color3.fromRGB(0, 150, 255)
            end
        end

        -- Distance
        local myChar = LocalPlayer.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") then
            local dist = (myChar.HumanoidRootPart.Position - hrp.Position).Magnitude
            data.DistLabel.Text = string.format("%.0fm", dist)
        end
    end
end)

-------------------------------------------------
-- Player Added / Removing  (ESP)
-------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if _G.ESPEnabled then
            task.wait(1)
            createESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if espData[player] then
        if espData[player].Box then
            espData[player].Box:Destroy()
        end
        espData[player] = nil
    end
end)

--══════════════════════════════════════════════════════════════
-- 3. GUI  — ONION13 HUB
--══════════════════════════════════════════════════════════════

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color     or Color3.fromRGB(60, 60, 60)
    s.Thickness = thickness or 1.5
    s.Parent    = parent
    return s
end

-------------------------------------------------
-- ScreenGui
-------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "Onion13Hub"
screenGui.ResetOnSpawn = false
screenGui.Parent       = game:GetService("CoreGui")

-------------------------------------------------
-- Menu Button
-------------------------------------------------
local menuBtn = Instance.new("TextButton")
menuBtn.Size            = UDim2.new(0, 80, 0, 40)
menuBtn.Position        = UDim2.new(0, 8, 0, 8)
menuBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
menuBtn.BorderSizePixel = 0
menuBtn.Text            = "MENU"
menuBtn.TextColor3      = Color3.fromRGB(0, 255, 100)
menuBtn.TextSize        = 16
menuBtn.Font            = Enum.Font.GothamBold
menuBtn.Parent          = screenGui
addCorner(menuBtn, 8)

-------------------------------------------------
-- Aim Toggle Button
-------------------------------------------------
local aimBtn = Instance.new("TextButton")
aimBtn.Size            = UDim2.new(0, 80, 0, 40)
aimBtn.Position        = UDim2.new(0, 8, 0, 55)
aimBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
aimBtn.BorderSizePixel = 0
aimBtn.Text            = "AIM OFF"
aimBtn.TextColor3      = Color3.fromRGB(255, 50, 50)
aimBtn.TextSize        = 14
aimBtn.Font            = Enum.Font.GothamBold
aimBtn.Parent          = screenGui
addCorner(aimBtn, 8)

-------------------------------------------------
-- Main Frame
-------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Size            = UDim2.new(0, 300, 0, 420)
mainFrame.Position        = UDim2.new(0.5, -150, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Visible         = false
mainFrame.Parent          = screenGui
addCorner(mainFrame, 12)

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size            = UDim2.new(1, 0, 0, 45)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
titleBar.BorderSizePixel = 0
titleBar.Parent          = mainFrame
addCorner(titleBar, 12)

local emojiLabel = Instance.new("TextLabel")
emojiLabel.Size                 = UDim2.new(0, 30, 1, 0)
emojiLabel.Position             = UDim2.new(0, 5, 0, 0)
emojiLabel.BackgroundTransparency = 1
emojiLabel.Text                 = utf8.char(129477)
emojiLabel.TextSize             = 22
emojiLabel.Parent               = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                 = UDim2.new(1, -80, 1, 0)
titleLabel.Position             = UDim2.new(0, 40, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                 = "ONION13"
titleLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize             = 18
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.Parent               = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size            = UDim2.new(0, 35, 0, 35)
closeBtn.Position        = UDim2.new(1, -40, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text            = "X"
closeBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize        = 18
closeBtn.Font            = Enum.Font.GothamBold
closeBtn.Parent          = titleBar
addCorner(closeBtn, 8)

-- ScrollingFrame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                  = UDim2.new(1, -16, 1, -55)
scrollFrame.Position              = UDim2.new(0, 8, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = 6
scrollFrame.ScrollBarImageColor3  = Color3.fromRGB(0, 255, 100)
scrollFrame.CanvasSize            = UDim2.new(0, 0, 0, 700)
scrollFrame.Parent                = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding   = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent    = scrollFrame

-- Auto-resize canvas
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 15)
end)

-- Footer
local footer = Instance.new("TextLabel")
footer.Size                 = UDim2.new(0, 180, 0, 28)
footer.Position             = UDim2.new(0.5, -90, 1, -35)
footer.BackgroundTransparency = 1
footer.Text                 = "Made by Onion13"
footer.TextColor3           = Color3.fromRGB(0, 255, 100)
footer.TextSize             = 14
footer.Font                 = Enum.Font.GothamBold
footer.TextStrokeTransparency = 0.3
footer.Parent               = mainFrame

-------------------------------------------------
-- Menu / Close Button Logic
-------------------------------------------------
menuBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftControl then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-------------------------------------------------
-- Toggle Button Factory
-------------------------------------------------
local SETTING_KEYS = {
    ["Skill Aimbot"]      = "Skillaimbot",
    ["ESP"]               = "ESPEnabled",
    ["Speed Boost"]       = "SpeedEnabled",
    ["Walk on Water"]     = "WalkOnWater",
    ["Auto Race Ability"] = "AutoRaceAbility",
    ["Auto V4"]           = "AutoV4",
    ["Anti-Stun"]         = "AntiStun",
    ["Fast Attack"]       = "FastAttack",
    ["Fflag"]             = "FflagBlocky",
}

local function createToggle(name, icon, callback)
    local btn = Instance.new("TextButton")
    btn.Size            = UDim2.new(1, -8, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.Text            = icon .. " " .. name
    btn.TextColor3      = Color3.fromRGB(255, 255, 255)
    btn.TextSize        = 13
    btn.Font            = Enum.Font.GothamBold
    btn.TextXAlignment  = Enum.TextXAlignment.Left
    btn.Parent          = scrollFrame
    addCorner(btn, 8)
    addStroke(btn)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent      = btn

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size                 = UDim2.new(0, 50, 1, 0)
    statusLabel.Position             = UDim2.new(1, -55, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize             = 12
    statusLabel.Font                 = Enum.Font.GothamBold
    statusLabel.Parent               = btn

    local settingKey = SETTING_KEYS[name]
    local state = settingKey and (_G[settingKey] or false) or false

    local function refresh()
        if settingKey == "Skillaimbot" then
            statusLabel.Text       = state and "AIM ON" or "AIM OFF"
            statusLabel.TextColor3 = state and Color3.fromRGB(0, 255, 100)
                                            or Color3.fromRGB(255, 50, 50)
        else
            statusLabel.Text       = state and "ON" or "OFF"
            statusLabel.TextColor3 = state and Color3.fromRGB(0, 255, 100)
                                            or Color3.fromRGB(255, 80, 80)
        end
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        state = not state
        if settingKey then
            _G[settingKey] = state
        end
        refresh()
        callback(state)
        syncSettings()
    end)
end

-------------------------------------------------
-- Slider Factory
-------------------------------------------------
local function createSlider(name, minVal, maxVal, default, callback)
    local frame = Instance.new("Frame")
    frame.Size            = UDim2.new(1, -8, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent          = scrollFrame
    addCorner(frame, 8)
    addStroke(frame)

    local CONFIG_KEYS = {
        ["Aim Distance"] = "MaxAimDistance",
        ["Speed"]        = "SpeedValue",
    }
    local configKey = CONFIG_KEYS[name]
    local currentVal = (configKey and _G[configKey]) or default

    local label = Instance.new("TextLabel")
    label.Size                 = UDim2.new(1, -16, 0, 22)
    label.Position             = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.Text                 = name .. ": " .. currentVal
    label.TextColor3           = Color3.fromRGB(255, 255, 255)
    label.TextSize             = 12
    label.Font                 = Enum.Font.GothamBold
    label.TextXAlignment       = Enum.TextXAlignment.Left
    label.Parent               = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size            = UDim2.new(1, -16, 0, 22)
    sliderBg.Position        = UDim2.new(0, 8, 0, 30)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent          = frame
    addCorner(sliderBg, 8)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size            = UDim2.new((currentVal - minVal) / (maxVal - minVal), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent          = sliderBg
    addCorner(sliderFill, 8)

    local dragging = false

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local ratio = math.clamp(
            (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X,
            0, 1
        )
        local value = math.floor(minVal + (maxVal - minVal) * ratio)

        sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
        label.Text      = name .. ": " .. value

        if configKey then
            _G[configKey] = value
        end
        callback(value)
        syncSettings()
    end)
end

--══════════════════════════════════════════════════════════════
-- 4. REGISTER ALL TOGGLES & SLIDERS
--══════════════════════════════════════════════════════════════

createToggle("Skill Aimbot", utf8.char(127919), function(enabled)
    _G.Skillaimbot = enabled
    if not enabled then
        currentAimTarget       = nil
        _G.AimBotSkillPosition = nil
    end
end)

createSlider("Aim Distance", 100, 1000, 500, function(val)
    _G.MaxAimDistance = val
end)

createToggle("ESP", utf8.char(128065, 65039), function(enabled)
    _G.ESPEnabled = enabled
    if enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                createESP(p)
            end
        end
    else
        for player, data in pairs(espData) do
            if data.Box then data.Box:Destroy() end
        end
        table.clear(espData)
    end
end)

createSlider("Speed", 1, 12, 1, function(val)
    _G.SpeedValue = val
end)

createToggle("Speed Boost",       utf8.char(9889),        function(e) _G.SpeedEnabled    = e end)
createToggle("Walk on Water",     utf8.char(127754),       function(e) _G.WalkOnWater     = e end)
createToggle("Auto Race Ability", utf8.char(128170),       function(e) _G.AutoRaceAbility = e end)
createToggle("Auto V4",           utf8.char(11088),        function(e) _G.AutoV4          = e end)
createToggle("Anti-Stun",         utf8.char(128737, 65039), function(e) _G.AntiStun        = e end)
createToggle("Fast Attack",       utf8.char(9876),         function(e) _G.FastAttack       = e end)

createToggle("Fflag", utf8.char(10024), function(enabled)
    _G.FflagBlocky = enabled
    if enabled then
        task.spawn(function()
            StarterGui:SetCore("SendNotification", {
                Title    = "Optimizing...",
                Text     = "Please wait (Anti-Lag)",
                Duration = 3,
            })
            local descendants = workspace:GetDescendants()
            for i, inst in ipairs(descendants) do
                if not _G.FflagBlocky then break end
                pcall(optimizeInstance, inst)
                if i % 200 == 0 then task.wait() end
            end
            StarterGui:SetCore("SendNotification", {
                Title    = "Success!",
                Text     = "Blocky Mode Active",
                Duration = 3,
            })
        end)
    end
end)

--══════════════════════════════════════════════════════════════
-- 5. AIM BUTTON  (draggable + toggle)
--══════════════════════════════════════════════════════════════

aimBtn.MouseButton1Click:Connect(function()
    _G.Skillaimbot = not _G.Skillaimbot
    aimBtn.Text       = _G.Skillaimbot and "AIM ON"  or "AIM OFF"
    aimBtn.TextColor3 = _G.Skillaimbot and Color3.fromRGB(0, 255, 100)
                                        or Color3.fromRGB(255, 50, 50)
    syncSettings()
    if not _G.Skillaimbot then
        currentAimTarget       = nil
        _G.AimBotSkillPosition = nil
    end
end)

-------------------------------------------------
-- Draggable Main Frame
-------------------------------------------------
do
    local dragInput, dragStart, startPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos  = mainFrame.Position
            dragInput = input
        end
    end)

    titleBar.InputEnded:Connect(function(input)
        if input == dragInput then dragInput = nil end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input ~= dragInput then return end
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end

--══════════════════════════════════════════════════════════════
-- 6. HEARTBEAT LOOP  (Speed, Walk on Water, Jump Boost)
--══════════════════════════════════════════════════════════════
local jumpHeld = false

RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end

        -- Speed Boost
        if _G.SpeedEnabled then
            local hum = char:FindFirstChild("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + hum.MoveDirection * (_G.SpeedValue or 1) * 0.5
            end
        end

        -- Walk on Water
        if _G.WalkOnWater ~= nil then
            if char:GetAttribute("WaterWalking") ~= _G.WalkOnWater then
                char:SetAttribute("WaterWalking", _G.WalkOnWater)
            end
        end

        -- Jump Boost  (jumpHeld set by jump button)
        if jumpHeld then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity = Vector3.new(hrp.Velocity.X, 230, hrp.Velocity.Z)
            end
        end
    end)
end)

--══════════════════════════════════════════════════════════════
-- 7. BACKGROUND LOOPS
--══════════════════════════════════════════════════════════════

-- Auto Race Ability
task.spawn(function()
    while task.wait(1) do
        if _G.AutoRaceAbility then
            pcall(function()
                ReplicatedStorage:WaitForChild("Remotes")
                    :WaitForChild("CommE"):FireServer("ActivateAbility")
            end)
        end
    end
end)

-- Auto V4
task.spawn(function()
    while task.wait(2) do
        if _G.AutoV4 then
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local raceEnergy     = char:FindFirstChild("RaceEnergy")
                local raceTransformed = char:FindFirstChild("RaceTransformed")
                if raceEnergy and raceTransformed
                and tonumber(raceEnergy.Value) == 1
                and raceTransformed.Value == false then
                    local vim = game:GetService("VirtualInputManager")
                    vim:SendKeyEvent(true,  "Y", false, game)
                    task.wait(0.1)
                    vim:SendKeyEvent(false, "Y", false, game)
                end
            end)
        end
    end
end)

-- Anti-Stun
task.spawn(function()
    while task.wait(0.25) do
        if _G.AntiStun then
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local stun = char:FindFirstChild("Stun")
                    if stun then stun.Value = 0 end
                end
            end)
        end
    end
end)

--══════════════════════════════════════════════════════════════
-- 8. FAST ATTACK SYSTEM
--══════════════════════════════════════════════════════════════
-- ⚠️ Ang section na ito ay gumagamit ng exploit-specific APIs
--    (debug.getupvalue, getrenv). Baguhin mo ayon sa executor mo.

local fastAttackReady = false
local netCoroutine, registerAttackRE

pcall(function()
    netCoroutine     = debug.getupvalue(getrenv()._G.SendHitsToServer, 1)
    registerAttackRE = ReplicatedStorage.Modules.Net["RE/RegisterAttack"]
    fastAttackReady  = true
end)

local function getNearbyTargets()
    local results = {}
    local myChar  = LocalPlayer.Character
    if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = myChar.HumanoidRootPart.Position

    -- Basic Mobs
    for _, mob in ipairs(CollectionService:GetTagged("BasicMob")) do
        if mob:IsA("Model") then
            local hum = mob:FindFirstChildOfClass("Humanoid")
            local hrp = mob:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                if (hrp.Position - myPos).Magnitude < 100 then
                    table.insert(results, hrp)
                end
            end
        end
    end

    -- Other Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                if (hrp.Position - myPos).Magnitude < 100 then
                    table.insert(results, hrp)
                end
            end
        end
    end

    return #results > 0 and results or nil
end

local function executeFastAttack()
    if not fastAttackReady then return end
    local targets = getNearbyTargets()
    if not targets then return end

    local primary = targets[1]
    local hitList = {}
    for i = 2, #targets do
        local hrp = targets[i]
        if hrp.Parent then
            table.insert(hitList, {hrp.Parent, hrp})
        end
    end

    registerAttackRE:FireServer(0/0)  -- NaN
    coroutine.resume(netCoroutine, primary, hitList)
end

task.spawn(function()
    while task.wait(0.1) do
        if _G.FastAttack then
            local char = LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool and (tool.ToolTip == "Melee" or tool.ToolTip == "Sword") then
                    pcall(executeFastAttack)
                end
            end
        end
    end
end)

--══════════════════════════════════════════════════════════════
-- 9. INITIAL ESP LOAD
--══════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1)
    if _G.ESPEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                pcall(createESP, p)
            end
        end
    end
end)

print("[Onion13Hub] Loaded successfully! ✅")
