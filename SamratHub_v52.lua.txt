pcall(function()
    if game.CoreGui:FindFirstChild("SamratHub") then game.CoreGui.SamratHub:Destroy() end
    if game.CoreGui:FindFirstChild("SamratFOV") then game.CoreGui.SamratFOV:Destroy() end
    if game.CoreGui:FindFirstChild("SamratAimHL") then game.CoreGui.SamratAimHL:Destroy() end
    if _G._SamratConns then for _,c in pairs(_G._SamratConns) do pcall(function() c:Disconnect() end) end end
    pcall(function() game:GetService("RunService"):UnbindFromRenderStep("SamratCam") end)
    pcall(function() if _G._SamratDrawC then _G._SamratDrawC:Remove() end end)
    pcall(function() if _G._SamratDrawD then _G._SamratDrawD:Remove() end end)
    _G._SamratActive = false
    task.wait(0.3)
end)

_G._SamratConns = {}
_G._SamratActive = true

local Players   = game:GetService("Players")
local RS        = game:GetService("RunService")
local UIS       = game:GetService("UserInputService")
local RepS      = game:GetService("ReplicatedStorage")
local CS        = game:GetService("CollectionService")
local SG        = game:GetService("StarterGui")
local HttpS     = game:GetService("HttpService")
local LP        = Players.LocalPlayer
local Cam       = workspace.CurrentCamera

-- ================================================
-- SAVE / LOAD SYSTEM
-- writefile/readfile — supported by most executors
-- Saves: all toggles, all sliders, all button positions
-- ================================================
local SAVE_FILE = "SamratHub_Save.json"

local DEFAULT_SETTINGS = {
    Skillaimbot     = false,
    CamLock         = false,
    FixLock         = false,
    AimPrediction   = true,
    AimFOV          = 150,
    MaxAimDistance  = 300,
    GunAimbot       = false,
    ESPEnabled      = false,
    SpeedEnabled    = false,
    SpeedValue      = 1,
    WalkOnWater     = false,
    AutoHakiEnabled = false,
    AutoRaceAbility = false,
    AutoV4          = false,
    AntiStun        = false,
    FastAttack      = false,
    FflagBlocky     = false,
    BtnScale        = 100,
    LockBtnPos      = false,
}

-- Default button/panel positions (UDim2 stored as {xs,xo,ys,yo})
local DEFAULT_LAYOUT = {
    MenuBtn = {0, 6, 0, 6},
    AimBtn  = {0, 6, 0, 43},
    CamBtn  = {0, 6, 0, 80},
    LockBtn = {0, 6, 0, 117},
    JumpBtn = {1, -58, 0.5, -24},
    MainFrame= {0.5, -122, 0.5, -165},
}

local function loadSave()
    local ok, data = pcall(function()
        if readfile then
            local raw = readfile(SAVE_FILE)
            return HttpS:JSONDecode(raw)
        end
    end)
    if ok and type(data) == "table" then return data end
    return {}
end

local function writeSave(data)
    pcall(function()
        if writefile then
            writefile(SAVE_FILE, HttpS:JSONEncode(data))
        end
    end)
end

-- Load saved data once at startup
local savedData = loadSave()

local function getSaved(key, default)
    if savedData[key] ~= nil then return savedData[key] end
    return default
end

-- Apply saved settings to _G
local function applySettings(src)
    for k, def in pairs(DEFAULT_SETTINGS) do
        local v = src[k]
        if v == nil then v = def end
        _G[k] = v
    end
    _G.AimBotSkillPosition = nil
end

applySettings(savedData)

-- Save all current _G settings
local function saveAllSettings()
    local out = {}
    for k in pairs(DEFAULT_SETTINGS) do
        out[k] = _G[k]
    end
    -- Also save button positions
    out._layout = savedData._layout or {}
    writeSave(out)
end

-- Save a single setting immediately
local function saveSetting(key, val)
    savedData[key] = val
    writeSave(savedData)
end

-- Save button position
local function saveLayout(name, pos)
    if not savedData._layout then savedData._layout = {} end
    savedData._layout[name] = {pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset}
    writeSave(savedData)
end

-- Load position for a named element, fallback to default
local function loadPos(name)
    local p = (savedData._layout or {})[name] or DEFAULT_LAYOUT[name]
    if p then return UDim2.new(p[1], p[2], p[3], p[4]) end
    return nil
end

-- Reset layout to defaults
local function resetLayout()
    savedData._layout = {}
    for k, p in pairs(DEFAULT_LAYOUT) do
        savedData._layout[k] = p
    end
    writeSave(savedData)
end

-- ================================================
-- THEME
-- ================================================
local T = {
    Pri=Color3.fromRGB(150,15,15), Acc=Color3.fromRGB(255,45,45),
    AccDim=Color3.fromRGB(180,30,30), Bg=Color3.fromRGB(14,14,14),
    Surf=Color3.fromRGB(24,24,24), Brd=Color3.fromRGB(50,50,50),
    W=Color3.fromRGB(255,255,255), Dim=Color3.fromRGB(140,140,140),
    On=Color3.fromRGB(255,50,50), Off=Color3.fromRGB(100,100,100),
}

local AimTarget, AimTargetHRP = nil, nil
local ESPData       = {}
local IsHighJumping = false
local ToggleUp      = {}
local curTab        = "Combat"
local sideBtns      = {}
local namedBtns     = {}   -- keyed by name for position saving
local frameC, lastFT, curFPS = 0, tick(), 60

local function sC(c) table.insert(_G._SamratConns, c) return c end
local function isP(p) return p and p.Team and p.Team.Name:lower():find("pirate") ~= nil end
local function isM(p) return p and p.Team and p.Team.Name:lower():find("marine") ~= nil end
local function noti(a,b,d) pcall(function() SG:SetCore("SendNotification",{Title=a,Text=b,Duration=d or 3}) end) end

local function getBtnSize()
    local s = _G.BtnScale or 100
    return math.floor(78*s/100), math.floor(33*s/100), math.clamp(math.floor(12*s/100), 8, 18)
end

-- ================================================
-- FOV CIRCLE
-- ================================================
local drawOK = false
local drawC, drawD

pcall(function()
    drawC = Drawing.new("Circle")
    drawC.Color = Color3.fromRGB(255,55,55)
    drawC.Thickness = 2; drawC.NumSides = 60
    drawC.Filled = false; drawC.Visible = false; drawC.Radius = 150

    drawD = Drawing.new("Circle")
    drawD.Color = Color3.fromRGB(255,50,50)
    drawD.Filled = true; drawD.Visible = false; drawD.Radius = 3

    drawOK = true
    _G._SamratDrawC = drawC
    _G._SamratDrawD = drawD
end)

local FovGui = Instance.new("ScreenGui")
FovGui.Name = "SamratFOV"; FovGui.ResetOnSpawn = false
FovGui.DisplayOrder = 99; FovGui.Parent = game.CoreGui

local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOV"; fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.new(0.5,0,0.5,0); fovFrame.BackgroundTransparency = 1
fovFrame.BorderSizePixel = 0; fovFrame.Visible = false; fovFrame.Parent = FovGui
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovFrame)
fovStroke.Color = Color3.fromRGB(255,55,55); fovStroke.Thickness = 2
pcall(function() fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end)

local dotFrame = Instance.new("Frame")
dotFrame.Name = "Dot"; dotFrame.AnchorPoint = Vector2.new(0.5, 0.5)
dotFrame.Position = UDim2.new(0.5,0,0.5,0); dotFrame.Size = UDim2.new(0,6,0,6)
dotFrame.BackgroundColor3 = T.Acc; dotFrame.BackgroundTransparency = 0.2
dotFrame.BorderSizePixel = 0; dotFrame.Visible = false; dotFrame.Parent = FovGui
Instance.new("UICorner", dotFrame).CornerRadius = UDim.new(1, 0)

-- ================================================
-- AIM HIGHLIGHT
-- ================================================
local AimHL = Instance.new("Highlight")
AimHL.Name = "SamratAimHL"
AimHL.FillColor = Color3.fromRGB(255,0,0); AimHL.FillTransparency = 0.8
AimHL.OutlineColor = Color3.fromRGB(255,50,50); AimHL.OutlineTransparency = 0
AimHL.Enabled = false; AimHL.Parent = game.CoreGui
pcall(function() AimHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)

-- ================================================
-- TARGET FINDER
-- ================================================
local function findTarget()
    local vs = Cam.ViewportSize
    local ctr = Vector2.new(vs.X/2, vs.Y/2)
    local fov = _G.AimFOV or 150
    local maxD = _G.MaxAimDistance or 300
    local mc = LP.Character
    if not mc or not mc:FindFirstChild("HumanoidRootPart") then return nil, 0 end
    local myP = mc.HumanoidRootPart.Position

    if _G.FixLock and AimTarget then
        local ch = AimTarget.Character
        if ch then
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            local hum = ch:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - myP).Magnitude
                if d <= maxD * 1.5 then return AimTarget, d end
            end
        end
    end

    local best, bestSD, bestWD = nil, fov, 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local wd = (hrp.Position - myP).Magnitude
                if wd <= maxD then
                    local sp, onS = Cam:WorldToScreenPoint(hrp.Position)
                    if onS then
                        local sd = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
                        if sd < bestSD then bestSD = sd; best = p; bestWD = wd end
                    end
                end
            end
        end
    end
    return best, bestWD
end

local function getPred(hrp)
    if not hrp then return nil end
    if not _G.AimPrediction then return hrp.Position end
    local ping = 0
    pcall(function() ping = LP:GetNetworkPing() end)
    return hrp.Position + (hrp.Velocity * math.clamp(ping + 0.05, 0.02, 0.25))
end

-- ================================================
-- METATABLE HOOKS
-- ================================================
local function deepR(t, pos, cf, d)
    if d > 8 then return end
    for k, v in pairs(t) do
        if typeof(v) == "Vector3" then t[k] = pos
        elseif typeof(v) == "CFrame" then t[k] = cf
        elseif type(v) == "table" then deepR(v, pos, cf, d+1) end
    end
end

pcall(function()
    local mt = getrawmetatable(game)
    local oNc, oIdx = mt.__namecall, mt.__index
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(...)
        local m = getnamecallmethod(); local a = {...}
        if (_G.Skillaimbot or _G.GunAimbot) and _G.AimBotSkillPosition then
            if m == "FireServer" or m == "InvokeServer" then
                local pos = _G.AimBotSkillPosition; local cf = CFrame.new(pos)
                for i = 2, #a do
                    if typeof(a[i]) == "Vector3" then a[i] = pos
                    elseif typeof(a[i]) == "CFrame" then a[i] = cf
                    elseif typeof(a[i]) == "Ray" then
                        local c = LP.Character
                        if c and c:FindFirstChild("HumanoidRootPart") then
                            a[i] = Ray.new(c.HumanoidRootPart.Position, (pos - c.HumanoidRootPart.Position).Unit * 1000)
                        end
                    elseif type(a[i]) == "table" then deepR(a[i], pos, cf, 0) end
                end
                return oNc(unpack(a))
            end
        end
        return oNc(...)
    end)
    mt.__index = newcclosure(function(self, key)
        if (_G.Skillaimbot or _G.GunAimbot) and _G.AimBotSkillPosition
        and typeof(self) == "Instance" and self:IsA("Mouse") then
            if key == "Hit" then return CFrame.new(_G.AimBotSkillPosition)
            elseif key == "Target" then return AimTargetHRP
            elseif key == "X" then return (Cam:WorldToScreenPoint(_G.AimBotSkillPosition)).X
            elseif key == "Y" then return (Cam:WorldToScreenPoint(_G.AimBotSkillPosition)).Y
            elseif key == "UnitRay" then
                local o = Cam.CFrame.Position
                return Ray.new(o, (_G.AimBotSkillPosition - o).Unit)
            end
        end
        return oIdx(self, key)
    end)
    setreadonly(mt, true)
end)

-- ================================================
-- ESP
-- ================================================
local function mkLbl(par, sz, pos, col, fnt, txt)
    local l = Instance.new("TextLabel"); l.Size = sz; l.Position = pos or UDim2.new()
    l.BackgroundTransparency = 1; l.TextColor3 = col; l.TextStrokeTransparency = 0.3
    l.TextScaled = true; l.Font = fnt; l.Text = txt; l.Parent = par; return l
end

local function createESP(player)
    if player == LP then return end
    if not player.Team or (not isP(player) and not isM(player)) then return end
    if ESPData[player] and ESPData[player].Box then ESPData[player].Box:Destroy() end
    local ch = player.Character
    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "SESP"; bb.AlwaysOnTop = true; bb.Size = UDim2.new(0,130,0,78)
    bb.StudsOffset = Vector3.new(0,3,0); bb.Adornee = ch.HumanoidRootPart; bb.Parent = game.CoreGui
    local nL = mkLbl(bb, UDim2.new(1,0,.17,0), nil, T.W, Enum.Font.SourceSansBold, player.Name)
    local tL = mkLbl(bb, UDim2.new(1,0,.12,0), UDim2.new(0,0,.17,0), T.Dim, Enum.Font.SourceSans, "-")
    local lL = mkLbl(bb, UDim2.new(1,0,.12,0), UDim2.new(0,0,.29,0), Color3.fromRGB(255,215,0), Enum.Font.SourceSansBold, "Lv...")
    local hBg = Instance.new("Frame")
    hBg.Size = UDim2.new(.78,0,.055,0); hBg.Position = UDim2.new(.11,0,.43,0)
    hBg.BackgroundColor3 = Color3.fromRGB(40,40,40); hBg.BorderSizePixel = 0; hBg.Parent = bb
    Instance.new("UICorner", hBg).CornerRadius = UDim.new(0, 3)
    local hF = Instance.new("Frame"); hF.Size = UDim2.new(1,0,1,0)
    hF.BackgroundColor3 = Color3.fromRGB(0,255,0); hF.BorderSizePixel = 0; hF.Parent = hBg
    Instance.new("UICorner", hF).CornerRadius = UDim.new(0, 3)
    local hL = mkLbl(bb, UDim2.new(1,0,.12,0), UDim2.new(0,0,.5,0), Color3.fromRGB(0,255,0), Enum.Font.SourceSansBold, "100%")
    local dL = mkLbl(bb, UDim2.new(1,0,.12,0), UDim2.new(0,0,.64,0), Color3.fromRGB(255,255,80), Enum.Font.SourceSansBold, "0m")
    local aL = mkLbl(bb, UDim2.new(1,0,.15,0), UDim2.new(0,0,.8,0), T.Acc, Enum.Font.GothamBold, "")
    ESPData[player] = {Box=bb,HPBar=hF,HPLabel=hL,LvlLabel=lL,NameLabel=nL,TeamLabel=tL,DistLabel=dL,AimLabel=aL}
end

local function clearESP()
    for _,d in pairs(ESPData) do if d.Box then d.Box:Destroy() end end
    table.clear(ESPData)
end

local lastE = 0
sC(RS.RenderStepped:Connect(function()
    if not _G._SamratActive or not _G.ESPEnabled then return end
    local now = tick(); if (now - lastE) < .25 then return end; lastE = now
    local rm = {}
    for p, d in pairs(ESPData) do
        if not p or not p.Parent or not d.Box or not d.Box.Parent then
            table.insert(rm, p)
        else
            local ch = p.Character
            if ch and ch:FindFirstChild("HumanoidRootPart") and ch:FindFirstChild("Humanoid") then
                local hu, hr = ch.Humanoid, ch.HumanoidRootPart
                if hu.Health > 0 then
                    d.Box.Adornee = hr; d.Box.Enabled = true
                    d.HPLabel.Text = string.format("%.0f HP", hu.Health)
                    local r = math.clamp(hu.Health/hu.MaxHealth, 0, 1)
                    d.HPBar.Size = UDim2.new(r,0,1,0)
                    local c = r>.6 and Color3.fromRGB(0,255,0) or r>.3 and Color3.fromRGB(255,165,0) or Color3.fromRGB(255,0,0)
                    d.HPBar.BackgroundColor3 = c; d.HPLabel.TextColor3 = c
                    local lv = "?"
                    if p:FindFirstChild("Data") and p.Data:FindFirstChild("Level") then lv = tostring(p.Data.Level.Value)
                    elseif p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Level") then lv = tostring(p.leaderstats.Level.Value) end
                    d.LvlLabel.Text = "Lv. "..lv
                    if isP(p) then d.NameLabel.TextColor3 = Color3.fromRGB(255,50,50); d.TeamLabel.Text = "PIRATE"; d.TeamLabel.TextColor3 = Color3.fromRGB(255,50,50)
                    elseif isM(p) then d.NameLabel.TextColor3 = Color3.fromRGB(50,150,255); d.TeamLabel.Text = "MARINE"; d.TeamLabel.TextColor3 = Color3.fromRGB(50,150,255) end
                    local mc = LP.Character
                    if mc and mc:FindFirstChild("HumanoidRootPart") then
                        d.DistLabel.Text = string.format("%.0fm", (mc.HumanoidRootPart.Position - hr.Position).Magnitude)
                    end
                    d.AimLabel.Text = (AimTarget==p and (_G.Skillaimbot or _G.CamLock or _G.GunAimbot)) and "[LOCKED]" or ""
                else d.Box.Enabled = false end
            else d.Box.Enabled = false end
        end
    end
    for _,p in pairs(rm) do
        if ESPData[p] and ESPData[p].Box then ESPData[p].Box:Destroy() end; ESPData[p] = nil
    end
end))

-- ================================================
-- MAIN GUI
-- ================================================
local Gui = Instance.new("ScreenGui")
Gui.Name = "SamratHub"; Gui.Parent = game.CoreGui
Gui.ResetOnSpawn = false; Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ================================================
-- FPS / PING
-- ================================================
local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(0,140,0,16)
FpsLabel.Position = UDim2.new(1,-146,0,6)
FpsLabel.BackgroundTransparency = 1; FpsLabel.TextColor3 = T.W
FpsLabel.TextStrokeTransparency = 0.5; FpsLabel.TextSize = 11
FpsLabel.Font = Enum.Font.SourceSans
FpsLabel.TextXAlignment = Enum.TextXAlignment.Right
FpsLabel.Text = "FPS: 60 | Ping: 0ms"; FpsLabel.Parent = Gui

-- ================================================
-- SIDE BUTTON BUILDER (with position save)
-- ================================================
local function mkSideBtn(txt, saveName, defaultPos, gKey, onToggle)
    local on = _G[gKey] or false
    local bw, bh, bts = getBtnSize()

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, bw, 0, bh)
    btn.Position = loadPos(saveName) or defaultPos
    btn.BackgroundColor3 = T.Bg; btn.BorderSizePixel = 0
    btn.Text = txt..(on and " ON" or " OFF")
    btn.TextColor3 = on and T.On or T.Off
    btn.TextSize = bts; btn.Font = Enum.Font.GothamBold
    btn.Parent = Gui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = on and T.Acc or T.Brd; stroke.Thickness = 1.2

    local ds, sp, wasDrag = nil, nil, false

    sC(btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            ds = i.Position; sp = btn.Position; wasDrag = false
        end
    end))
    sC(btn.InputChanged:Connect(function(i)
        if ds and not _G.LockBtnPos and
        (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            if (i.Position - ds).Magnitude > 10 then
                wasDrag = true
                local d = i.Position - ds
                btn.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
            end
        end
    end))
    sC(btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            if not wasDrag then
                on = not on; _G[gKey] = on
                btn.Text = txt..(on and " ON" or " OFF")
                btn.TextColor3 = on and T.On or T.Off
                stroke.Color = on and T.Acc or T.Brd
                saveSetting(gKey, on)    -- save immediately
                if onToggle then onToggle(on) end
            else
                saveLayout(saveName, btn.Position)  -- save new position
            end
            ds = nil; wasDrag = false
        end
    end))

    table.insert(sideBtns, btn)
    namedBtns[saveName] = btn

    local function sync(v)
        on = v; _G[gKey] = v
        btn.Text = txt..(on and " ON" or " OFF")
        btn.TextColor3 = on and T.On or T.Off
        stroke.Color = on and T.Acc or T.Brd
    end

    return btn, stroke, sync
end

-- MENU button
local MenuBtn = Instance.new("TextButton")
do
    local bw, bh, bts = getBtnSize()
    MenuBtn.Size = UDim2.new(0, bw, 0, bh)
    MenuBtn.Position = loadPos("MenuBtn") or UDim2.new(0, 6, 0, 6)
    MenuBtn.BackgroundColor3 = T.Bg; MenuBtn.BorderSizePixel = 0
    MenuBtn.Text = "MENU"; MenuBtn.TextColor3 = T.Acc
    MenuBtn.TextSize = bts; MenuBtn.Font = Enum.Font.GothamBold
    MenuBtn.Parent = Gui
    Instance.new("UICorner", MenuBtn).CornerRadius = UDim.new(0, 8)
    Instance.new("UIStroke", MenuBtn).Color = T.Acc
    table.insert(sideBtns, MenuBtn)
    namedBtns["MenuBtn"] = MenuBtn

    -- draggable MENU button with save
    local mds, msp, mDrag = nil, nil, false
    sC(MenuBtn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            mds = i.Position; msp = MenuBtn.Position; mDrag = false
        end
    end))
    sC(MenuBtn.InputChanged:Connect(function(i)
        if mds and not _G.LockBtnPos and
        (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            if (i.Position - mds).Magnitude > 10 then
                mDrag = true
                local d = i.Position - mds
                MenuBtn.Position = UDim2.new(msp.X.Scale, msp.X.Offset+d.X, msp.Y.Scale, msp.Y.Offset+d.Y)
            end
        end
    end))
    sC(MenuBtn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            if mDrag then saveLayout("MenuBtn", MenuBtn.Position) end
            mds = nil; mDrag = false
        end
    end))
end

local AimBtn,  aimStr,  syncAim  = mkSideBtn("AIM",  "AimBtn",  UDim2.new(0,6,0,43),  "Skillaimbot", function(on)
    if not on then AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil end
    if ToggleUp["Skill Aimbot"] then ToggleUp["Skill Aimbot"](on) end
end)

local CamBtn,  camStr,  syncCam  = mkSideBtn("CAM",  "CamBtn",  UDim2.new(0,6,0,80),  "CamLock", function(on)
    if ToggleUp["Camera Lock"] then ToggleUp["Camera Lock"](on) end
end)

local LockBtn, lockStr, syncLock = mkSideBtn("LOCK", "LockBtn", UDim2.new(0,6,0,117), "FixLock", function(on)
    if ToggleUp["Fix Lock"] then ToggleUp["Fix Lock"](on) end
    if not on then AimTarget=nil; AimTargetHRP=nil end
end)

local AimInfo = Instance.new("TextLabel")
do
    local _, bh = getBtnSize()
    AimInfo.Size = UDim2.new(0,150,0,14)
    AimInfo.Position = UDim2.new(0,6,0,6+(bh+4)*4+2)
    AimInfo.BackgroundTransparency = 1; AimInfo.TextColor3 = T.Acc; AimInfo.TextSize = 9
    AimInfo.Font = Enum.Font.GothamBold; AimInfo.TextXAlignment = Enum.TextXAlignment.Left
    AimInfo.TextStrokeTransparency = 0.3; AimInfo.Text = ""; AimInfo.Parent = Gui
end

-- ================================================
-- MAIN FRAME (draggable, position saved)
-- ================================================
local Main = Instance.new("Frame")
Main.Name = "Main"; Main.Size = UDim2.new(0,245,0,330)
Main.Position = loadPos("MainFrame") or UDim2.new(0.5,-122,0.5,-165)
Main.BackgroundColor3 = T.Bg; Main.BorderSizePixel = 0
Main.Visible = false; Main.ClipsDescendants = true; Main.Parent = Gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = T.Pri

local TBar = Instance.new("Frame")
TBar.Size = UDim2.new(1,0,0,30); TBar.BackgroundColor3 = T.Pri
TBar.BorderSizePixel = 0; TBar.Active = true; TBar.Parent = Main
Instance.new("UICorner", TBar).CornerRadius = UDim.new(0, 12)
local TFix = Instance.new("Frame"); TFix.Size = UDim2.new(1,0,0,12)
TFix.Position = UDim2.new(0,0,1,-12); TFix.BackgroundColor3 = T.Pri
TFix.BorderSizePixel = 0; TFix.Parent = TBar

local function mL(par, sz, pos, txt, col, tsz, fnt, xa)
    local l = Instance.new("TextLabel"); l.Size = sz; l.Position = pos or UDim2.new()
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = col or T.W
    l.TextSize = tsz or 11; l.Font = fnt or Enum.Font.GothamBold
    l.TextXAlignment = xa or Enum.TextXAlignment.Center; l.Parent = par; return l
end

mL(TBar, UDim2.new(0,24,1,0), UDim2.new(0,5,0,0), utf8.char(128081), T.W, 16)
mL(TBar, UDim2.new(1,-64,1,0), UDim2.new(0,28,0,0), "SAMRAT HUB", T.W, 13, Enum.Font.GothamBold, Enum.TextXAlignment.Left)

local XBtn = Instance.new("TextButton")
XBtn.Size = UDim2.new(0,24,0,24); XBtn.Position = UDim2.new(1,-28,0,3)
XBtn.BackgroundColor3 = Color3.fromRGB(130,18,18); XBtn.BorderSizePixel = 0
XBtn.Text = "X"; XBtn.TextColor3 = T.W; XBtn.TextSize = 12
XBtn.Font = Enum.Font.GothamBold; XBtn.Parent = TBar
Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 6)

-- Main frame drag — save on release
local dS, fS
sC(TBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dS = i.Position; fS = Main.Position
    end
end))
sC(TBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        if dS then saveLayout("MainFrame", Main.Position) end
        dS = nil
    end
end))
sC(UIS.InputChanged:Connect(function(i)
    if dS and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dS
        Main.Position = UDim2.new(fS.X.Scale, fS.X.Offset+d.X, fS.Y.Scale, fS.Y.Offset+d.Y)
    end
end))

-- ================================================
-- SIDE TABS
-- ================================================
local TabStrip = Instance.new("Frame")
TabStrip.Size = UDim2.new(0,42,1,-52); TabStrip.Position = UDim2.new(0,2,0,32)
TabStrip.BackgroundTransparency = 1; TabStrip.Parent = Main
local TLL = Instance.new("UIListLayout"); TLL.Padding = UDim.new(0,3)
TLL.SortOrder = Enum.SortOrder.LayoutOrder
TLL.HorizontalAlignment = Enum.HorizontalAlignment.Center; TLL.Parent = TabStrip

local tabBtns, scrollFrames = {}, {}
local TABS = {
    {n="Combat",   ic=utf8.char(9876),  o=1},
    {n="Player",   ic=utf8.char(128100),o=2},
    {n="Auto",     ic=utf8.char(9889),  o=3},
    {n="Settings", ic=utf8.char(9881),  o=4},
}

local function showTab(name)
    curTab = name
    for n, sf in pairs(scrollFrames) do sf.Visible = (n == name) end
    for n, b in pairs(tabBtns) do b.BackgroundColor3 = (n == name) and T.Acc or T.Surf end
end

for _, tab in ipairs(TABS) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(1,0,0,48); tb.BackgroundColor3 = (tab.n==curTab) and T.Acc or T.Surf
    tb.BorderSizePixel = 0; tb.Text = ""; tb.AutoButtonColor = false
    tb.LayoutOrder = tab.o; tb.Parent = TabStrip
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 8)
    local ic = Instance.new("TextLabel"); ic.Size = UDim2.new(1,0,0.5,0)
    ic.BackgroundTransparency = 1; ic.Text = tab.ic; ic.TextSize = 18; ic.TextColor3 = T.W; ic.Parent = tb
    local nm = Instance.new("TextLabel"); nm.Size = UDim2.new(1,0,0.4,0); nm.Position = UDim2.new(0,0,0.5,0)
    nm.BackgroundTransparency = 1; nm.Text = tab.n; nm.TextSize = 8
    nm.TextColor3 = T.W; nm.Font = Enum.Font.GothamBold; nm.Parent = tb
    tabBtns[tab.n] = tb
    sC(tb.MouseButton1Click:Connect(function() showTab(tab.n) end))

    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1,-50,1,-52); sf.Position = UDim2.new(0,46,0,32)
    sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3; sf.ScrollBarImageColor3 = T.Acc
    sf.CanvasSize = UDim2.new(0,0,0,0); sf.Visible = (tab.n==curTab); sf.Parent = Main
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = sf
    sC(ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+8)
    end))
    scrollFrames[tab.n] = sf
end

mL(Main, UDim2.new(1,0,0,16), UDim2.new(0,0,1,-18), "Samrat Hub v5.2", T.Acc, 8, Enum.Font.GothamBold)

-- ================================================
-- TOGGLE + SLIDER BUILDERS (with auto-save)
-- ================================================
local SMAP = {
    ["Skill Aimbot"]="Skillaimbot",   ["Camera Lock"]="CamLock",
    ["Fix Lock"]="FixLock",           ["Aim Prediction"]="AimPrediction",
    ["Gun Aimbot"]="GunAimbot",
    ["ESP"]="ESPEnabled",             ["Speed Boost"]="SpeedEnabled",
    ["Walk on Water"]="WalkOnWater",  ["Auto Haki"]="AutoHakiEnabled",
    ["Auto Race"]="AutoRaceAbility",  ["Auto V4"]="AutoV4",
    ["Anti-Stun"]="AntiStun",        ["Fast Attack"]="FastAttack",
    ["Fflag"]="FflagBlocky",          ["Lock Positions"]="LockBtnPos",
}

local function createToggle(name, icon, cat, ord, cb)
    local key = SMAP[name]
    local on = key and (_G[key] or false) or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-4,0,28); btn.BackgroundColor3 = T.Surf
    btn.BorderSizePixel = 0; btn.Text = ""; btn.AutoButtonColor = false
    btn.LayoutOrder = ord; btn.Parent = scrollFrames[cat]
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local st = Instance.new("UIStroke", btn); st.Thickness = 1; st.Color = on and T.AccDim or T.Brd
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 8)
    mL(btn, UDim2.new(1,-44,1,0), nil, icon.."  "..name, T.W, 9, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
    local sl = Instance.new("TextLabel"); sl.Size = UDim2.new(0,36,1,0)
    sl.Position = UDim2.new(1,-40,0,0); sl.BackgroundTransparency = 1
    sl.TextSize = 9; sl.Font = Enum.Font.GothamBold; sl.Parent = btn
    local function ref()
        sl.Text = on and "ON" or "OFF"; sl.TextColor3 = on and T.On or T.Off
        st.Color = on and T.AccDim or T.Brd
    end
    ref()
    ToggleUp[name] = function(v) on=v; if key then _G[key]=v end; ref() end
    sC(btn.MouseButton1Click:Connect(function()
        on = not on; if key then _G[key]=on end; ref()
        saveSetting(key, on)   -- auto-save on toggle
        if cb then cb(on) end
    end))
end

local function createSlider(name, mn, mx, cat, ord, cb)
    local SM = {["Aim FOV"]="AimFOV", ["Aim Dist"]="MaxAimDistance",
                ["Speed"]="SpeedValue", ["Btn Scale"]="BtnScale"}
    local key = SM[name]
    local cur = (key and _G[key]) or mn
    local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,-4,0,40)
    fr.BackgroundColor3 = T.Surf; fr.BorderSizePixel = 0
    fr.LayoutOrder = ord; fr.Parent = scrollFrames[cat]
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", fr).Color = T.Brd
    local lb = mL(fr, UDim2.new(1,-8,0,16), UDim2.new(0,4,0,1), name..": "..cur, T.W, 9, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
    local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,-8,0,14)
    bg.Position = UDim2.new(0,4,0,20); bg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    bg.BorderSizePixel = 0; bg.ClipsDescendants = true; bg.Parent = fr
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new(math.clamp((cur-mn)/(mx-mn),0,1),0,1,0)
    fl.BackgroundColor3 = T.Acc; fl.BorderSizePixel = 0; fl.Parent = bg
    Instance.new("UICorner", fl).CornerRadius = UDim.new(0, 5)
    local dr = false
    sC(bg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dr = true end
    end))
    sC(bg.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dr = false
            if key then saveSetting(key, _G[key]) end  -- auto-save on release
        end
    end))
    sC(UIS.InputChanged:Connect(function(i)
        if dr and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local r = math.clamp((i.Position.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
            local v = math.floor(mn + (mx-mn)*r)
            fl.Size = UDim2.new(r,0,1,0); lb.Text = name..": "..v
            if key then _G[key]=v end; if cb then cb(v) end
        end
    end))
end

-- ================================================
-- COMBAT TAB
-- ================================================
createToggle("Skill Aimbot", utf8.char(127919), "Combat", 1, function(on)
    _G.Skillaimbot = on; syncAim(on)
    if not on then AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil; AimInfo.Text="" end
end)
createToggle("Camera Lock",  utf8.char(127909), "Combat", 2, function(on) _G.CamLock=on; syncCam(on) end)
createToggle("Fix Lock",     utf8.char(128274), "Combat", 3, function(on)
    _G.FixLock=on; syncLock(on)
    if not on then AimTarget=nil; AimTargetHRP=nil end
end)
createToggle("Aim Prediction", utf8.char(128269), "Combat", 4, function(on) _G.AimPrediction=on end)
createSlider("Aim FOV",  50,   400,  "Combat", 5, function(v) _G.AimFOV=v end)
createSlider("Aim Dist", 30,   2000, "Combat", 6, function(v) _G.MaxAimDistance=v end)
createToggle("Fast Attack", utf8.char(9876,65039), "Combat", 7, function(on) _G.FastAttack=on end)
createToggle("Gun Aimbot", utf8.char(128299), "Combat", 8, function(on)
    _G.GunAimbot = on
    if not on and not _G.Skillaimbot then
        AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil; AimInfo.Text=""
    end
end)

-- ================================================
-- PLAYER TAB
-- ================================================
createToggle("ESP", utf8.char(128065,65039), "Player", 1, function(on)
    _G.ESPEnabled = on
    if on then for _,p in pairs(Players:GetPlayers()) do if p~=LP then pcall(createESP,p) end end
    else clearESP() end
end)
createToggle("Speed Boost",  utf8.char(128168), "Player", 2, function(on) _G.SpeedEnabled=on end)
createSlider("Speed", 1, 12, "Player", 3, function(v) _G.SpeedValue=v end)
createToggle("Walk on Water", utf8.char(127754),    "Player", 4, function(on) _G.WalkOnWater=on end)
createToggle("Anti-Stun",     utf8.char(128737,65039),"Player", 5, function(on) _G.AntiStun=on end)
createToggle("Auto Haki",     utf8.char(129354),    "Player", 6, function(on) _G.AutoHakiEnabled=on end)
createToggle("Fflag", utf8.char(10024), "Player", 7, function(on)
    _G.FflagBlocky = on
    if on then task.spawn(function()
        noti("Optimizing...", "Anti-Lag", 3)
        for i, inst in pairs(workspace:GetDescendants()) do
            if not _G.FflagBlocky then break end
            pcall(function()
                if inst:IsA("Decal") or inst:IsA("Texture") then inst.Transparency = 1
                elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") then inst.Enabled = false
                elseif inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then inst.Enabled = false
                elseif inst:IsA("MeshPart") then inst.TextureID = "" end
            end)
            if i % 250 == 0 then task.wait() end
        end
        if _G.FflagBlocky then noti("Done!", "Blocky ON", 3) end
    end) end
end)

-- ================================================
-- AUTO TAB
-- ================================================
createToggle("Auto Race", utf8.char(128170), "Auto", 1, function(on) _G.AutoRaceAbility=on end)
createToggle("Auto V4",   utf8.char(11088),  "Auto", 2, function(on) _G.AutoV4=on end)

-- ================================================
-- SETTINGS TAB
-- ================================================
createSlider("Btn Scale", 70, 140, "Settings", 1, function(v)
    _G.BtnScale = v
    local bw, bh, bts = getBtnSize()
    for _, btn in pairs(sideBtns) do
        btn.Size = UDim2.new(0, bw, 0, bh)
        if btn:IsA("TextButton") then btn.TextSize = bts end
    end
end)
createToggle("Lock Positions", utf8.char(128274), "Settings", 2, function(on) _G.LockBtnPos=on end)

-- ================================================
-- RESET LAYOUT BUTTON + CONFIRM DIALOG
-- ================================================
do
    -- Confirm dialog (hidden by default)
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1,0,1,0); Overlay.Position = UDim2.new(0,0,0,0)
    Overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    Overlay.BackgroundTransparency = 0.45; Overlay.BorderSizePixel = 0
    Overlay.ZIndex = 50; Overlay.Visible = false; Overlay.Parent = Gui

    local Dialog = Instance.new("Frame")
    Dialog.Size = UDim2.new(0,220,0,110)
    Dialog.Position = UDim2.new(0.5,-110,0.5,-55)
    Dialog.BackgroundColor3 = T.Bg; Dialog.BorderSizePixel = 0
    Dialog.ZIndex = 51; Dialog.Parent = Gui
    Dialog.Visible = false
    Instance.new("UICorner", Dialog).CornerRadius = UDim.new(0,12)
    local dlgStroke = Instance.new("UIStroke", Dialog)
    dlgStroke.Color = T.Acc; dlgStroke.Thickness = 1.5

    -- Title
    local dlgTitle = Instance.new("TextLabel")
    dlgTitle.Size = UDim2.new(1,0,0,32)
    dlgTitle.Position = UDim2.new(0,0,0,0)
    dlgTitle.BackgroundColor3 = T.Pri; dlgTitle.BorderSizePixel = 0
    dlgTitle.Text = utf8.char(9888).."  Reset Layout"
    dlgTitle.TextColor3 = T.W; dlgTitle.TextSize = 11
    dlgTitle.Font = Enum.Font.GothamBold; dlgTitle.ZIndex = 52
    dlgTitle.Parent = Dialog
    Instance.new("UICorner", dlgTitle).CornerRadius = UDim.new(0,12)
    -- fix bottom corners of title bar
    local dlgFix = Instance.new("Frame"); dlgFix.Size = UDim2.new(1,0,0,12)
    dlgFix.Position = UDim2.new(0,0,1,-12); dlgFix.BackgroundColor3 = T.Pri
    dlgFix.BorderSizePixel = 0; dlgFix.ZIndex = 52; dlgFix.Parent = dlgTitle

    -- Message
    local dlgMsg = Instance.new("TextLabel")
    dlgMsg.Size = UDim2.new(1,-16,0,30)
    dlgMsg.Position = UDim2.new(0,8,0,36)
    dlgMsg.BackgroundTransparency = 1
    dlgMsg.Text = "Are you sure you want to\nreset all button positions?"
    dlgMsg.TextColor3 = T.Dim; dlgMsg.TextSize = 10
    dlgMsg.Font = Enum.Font.Gotham; dlgMsg.TextWrapped = true
    dlgMsg.ZIndex = 52; dlgMsg.Parent = Dialog

    -- YES button
    local dlgYes = Instance.new("TextButton")
    dlgYes.Size = UDim2.new(0,90,0,26)
    dlgYes.Position = UDim2.new(0,10,1,-34)
    dlgYes.BackgroundColor3 = Color3.fromRGB(180,20,20)
    dlgYes.BorderSizePixel = 0; dlgYes.Text = "Yes, Reset"
    dlgYes.TextColor3 = T.W; dlgYes.TextSize = 10
    dlgYes.Font = Enum.Font.GothamBold; dlgYes.ZIndex = 52
    dlgYes.Parent = Dialog
    Instance.new("UICorner", dlgYes).CornerRadius = UDim.new(0,7)

    -- NO button
    local dlgNo = Instance.new("TextButton")
    dlgNo.Size = UDim2.new(0,90,0,26)
    dlgNo.Position = UDim2.new(1,-100,1,-34)
    dlgNo.BackgroundColor3 = T.Surf; dlgNo.BorderSizePixel = 0
    dlgNo.Text = "Cancel"; dlgNo.TextColor3 = T.W
    dlgNo.TextSize = 10; dlgNo.Font = Enum.Font.GothamBold
    dlgNo.ZIndex = 52; dlgNo.Parent = Dialog
    Instance.new("UICorner", dlgNo).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", dlgNo).Color = T.Brd

    local function openDialog()  Overlay.Visible=true; Dialog.Visible=true  end
    local function closeDialog() Overlay.Visible=false; Dialog.Visible=false end

    sC(dlgNo.MouseButton1Click:Connect(closeDialog))
    sC(Overlay.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then closeDialog() end
    end))

    sC(dlgYes.MouseButton1Click:Connect(function()
        closeDialog()
        resetLayout()

        -- Move all named buttons back to default positions
        for name, btn in pairs(namedBtns) do
            local def = DEFAULT_LAYOUT[name]
            if def then
                btn.Position = UDim2.new(def[1], def[2], def[3], def[4])
            end
        end
        -- Move main frame back
        Main.Position = UDim2.new(DEFAULT_LAYOUT.MainFrame[1], DEFAULT_LAYOUT.MainFrame[2],
                                   DEFAULT_LAYOUT.MainFrame[3], DEFAULT_LAYOUT.MainFrame[4])
        -- Move jump button back
        if namedBtns["JumpBtn"] then
            namedBtns["JumpBtn"].Position = UDim2.new(DEFAULT_LAYOUT.JumpBtn[1], DEFAULT_LAYOUT.JumpBtn[2],
                                                       DEFAULT_LAYOUT.JumpBtn[3], DEFAULT_LAYOUT.JumpBtn[4])
        end
        noti("Samrat Hub", "Layout reset to default!", 3)
    end))

    -- Reset Layout toggle row in Settings tab
    local rlFr = Instance.new("Frame")
    rlFr.Size = UDim2.new(1,-4,0,34); rlFr.BackgroundColor3 = T.Surf
    rlFr.BorderSizePixel = 0; rlFr.LayoutOrder = 3; rlFr.Parent = scrollFrames["Settings"]
    Instance.new("UICorner", rlFr).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", rlFr).Color = T.Brd
    Instance.new("UIPadding", rlFr).PaddingLeft = UDim.new(0,8)

    mL(rlFr, UDim2.new(1,-90,1,0), nil,
        utf8.char(128260).."  Reset Layout",
        T.W, 9, Enum.Font.GothamBold, Enum.TextXAlignment.Left)

    local rlBtn = Instance.new("TextButton")
    rlBtn.Size = UDim2.new(0,76,0,22); rlBtn.Position = UDim2.new(1,-82,0.5,-11)
    rlBtn.BackgroundColor3 = Color3.fromRGB(140,15,15); rlBtn.BorderSizePixel = 0
    rlBtn.Text = "RESET"; rlBtn.TextColor3 = T.W
    rlBtn.TextSize = 9; rlBtn.Font = Enum.Font.GothamBold
    rlBtn.Parent = rlFr
    Instance.new("UICorner", rlBtn).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", rlBtn).Color = T.Acc

    sC(rlBtn.MouseButton1Click:Connect(openDialog))
end

showTab("Combat")

-- ================================================
-- JUMP BUTTON (draggable, position saved)
-- ================================================
local JB = Instance.new("TextButton")
JB.Size = UDim2.new(0,48,0,48)
JB.Position = loadPos("JumpBtn") or UDim2.new(1,-58,0.5,-24)
JB.BackgroundColor3 = T.Pri; JB.BorderSizePixel = 0; JB.Text = utf8.char(8593)
JB.TextColor3 = T.W; JB.TextSize = 22; JB.Font = Enum.Font.GothamBold; JB.Parent = Gui
Instance.new("UICorner", JB).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", JB).Color = T.Acc
namedBtns["JumpBtn"] = JB

local jDS, jSP, jDR = nil, nil, false
sC(JB.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        jDS=i.Position; jSP=JB.Position; jDR=false; IsHighJumping=true
    end
end))
sC(JB.InputChanged:Connect(function(i)
    if jDS and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        if not _G.LockBtnPos and (i.Position-jDS).Magnitude > 15 then
            jDR=true; IsHighJumping=false
            local d = i.Position - jDS
            JB.Position = UDim2.new(jSP.X.Scale, jSP.X.Offset+d.X, jSP.Y.Scale, jSP.Y.Offset+d.Y)
        end
    end
end))
sC(JB.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        IsHighJumping=false
        if jDR then saveLayout("JumpBtn", JB.Position) end
        jDS=nil; jDR=false
    end
end))

-- ================================================
-- BUTTON HANDLERS
-- ================================================
sC(MenuBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end))
sC(XBtn.MouseButton1Click:Connect(function() Main.Visible = false end))
sC(UIS.InputBegan:Connect(function(i, p)
    if not p and i.KeyCode == Enum.KeyCode.LeftControl then Main.Visible = not Main.Visible end
end))

-- ================================================
-- PLAYER EVENTS
-- ================================================
sC(Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        if _G.ESPEnabled then task.wait(1); pcall(createESP, p) end
    end)
end))
sC(Players.PlayerRemoving:Connect(function(p)
    if ESPData[p] then if ESPData[p].Box then ESPData[p].Box:Destroy() end; ESPData[p]=nil end
    if AimTarget==p then AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil end
end))

-- ================================================
-- CAMERA LOCK
-- ================================================
RS:BindToRenderStep("SamratCam", Enum.RenderPriority.Camera.Value + 1, function()
    if not _G._SamratActive or not _G.CamLock then return end
    if AimTargetHRP and AimTargetHRP.Parent then
        pcall(function()
            local hu = AimTargetHRP.Parent:FindFirstChild("Humanoid")
            if hu and hu.Health > 0 then
                Cam.CFrame = CFrame.lookAt(Cam.CFrame.Position, AimTargetHRP.Position)
            end
        end)
    end
end)

-- ================================================
-- AIM + FOV CIRCLE + FPS (RenderStepped)
-- ================================================
sC(RS.RenderStepped:Connect(function()
    if not _G._SamratActive then return end

    -- FPS
    frameC = frameC + 1
    local now = tick()
    if now - lastFT >= 0.5 then
        curFPS = math.floor(frameC/(now-lastFT)); frameC=0; lastFT=now
        local ping = 0; pcall(function() ping = math.floor(LP:GetNetworkPing()*1000) end)
        FpsLabel.Text = string.format("FPS: %d | Ping: %dms", curFPS, ping)
    end

    -- FOV circle
    local vs = Cam.ViewportSize
    local cx, cy = vs.X/2, vs.Y/2
    local fov = _G.AimFOV or 150
    local showFov = _G.Skillaimbot or _G.CamLock or _G.GunAimbot
    local hasT = AimTarget ~= nil

    if drawOK then
        drawC.Position = Vector2.new(cx, cy); drawC.Radius = fov
        drawC.Visible = showFov
        drawC.Color = hasT and Color3.fromRGB(255,20,20) or Color3.fromRGB(255,70,70)
        drawC.Thickness = hasT and 2.5 or 1.5
        drawD.Position = Vector2.new(cx, cy); drawD.Visible = showFov
        drawD.Color = hasT and T.Acc or T.Dim
        fovFrame.Visible = false; dotFrame.Visible = false
    else
        fovFrame.Position = UDim2.new(0,cx,0,cy)
        fovFrame.Size = UDim2.new(0,fov*2,0,fov*2); fovFrame.Visible = showFov
        fovStroke.Color = hasT and Color3.fromRGB(255,20,20) or Color3.fromRGB(255,70,70)
        fovStroke.Thickness = hasT and 2.5 or 1.5
        dotFrame.Position = UDim2.new(0,cx,0,cy); dotFrame.Visible = showFov
        dotFrame.BackgroundColor3 = hasT and T.Acc or T.Dim
    end

    if not showFov then
        if AimTarget then
            AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil
            AimInfo.Text=""; AimHL.Adornee=nil; AimHL.Enabled=false
        end
        return
    end

    local target, dist = findTarget()
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = target.Character.HumanoidRootPart
        AimTarget=target; AimTargetHRP=hrp
        if _G.Skillaimbot or _G.GunAimbot then _G.AimBotSkillPosition = getPred(hrp) end
        AimInfo.Text = string.format(utf8.char(187).." %s (%.0fm)", target.Name, dist)
        AimHL.Adornee=target.Character; AimHL.Enabled=true
    else
        AimTarget=nil; AimTargetHRP=nil; _G.AimBotSkillPosition=nil
        AimInfo.Text="No target"; AimHL.Adornee=nil; AimHL.Enabled=false
    end
end))

-- ================================================
-- HEARTBEAT
-- ================================================
sC(RS.Heartbeat:Connect(function()
    if not _G._SamratActive then return end
    pcall(function()
        local ch = LP.Character; if not ch then return end
        if _G.SpeedEnabled then
            local hu = ch:FindFirstChild("Humanoid"); local hr = ch:FindFirstChild("HumanoidRootPart")
            if hu and hr and hu.MoveDirection.Magnitude > 0 then
                hr.CFrame = hr.CFrame + (hu.MoveDirection * (_G.SpeedValue or 1) * 0.5)
            end
        end
        if _G.WalkOnWater ~= nil and ch:GetAttribute("WaterWalking") ~= _G.WalkOnWater then
            ch:SetAttribute("WaterWalking", _G.WalkOnWater)
        end
        if IsHighJumping and not jDR then
            local hr = ch:FindFirstChild("HumanoidRootPart")
            if hr then hr.Velocity = Vector3.new(hr.Velocity.X, 230, hr.Velocity.Z) end
        end
    end)
end))

-- ================================================
-- TIMED LOOPS
-- ================================================
task.spawn(function()
    while _G._SamratActive do task.wait(1)
        if _G.AutoHakiEnabled then pcall(function()
            local ch = LP.Character
            if ch and not ch:FindFirstChild("HasBuso") then
                RepS:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("Buso")
            end
        end) end
        if _G.AutoRaceAbility then pcall(function()
            RepS:WaitForChild("Remotes"):WaitForChild("CommE"):FireServer("ActivateAbility")
        end) end
    end
end)

task.spawn(function()
    while _G._SamratActive do task.wait(2)
        if _G.AutoV4 then pcall(function()
            local ch = LP.Character; if not ch then return end
            local re = ch:FindFirstChild("RaceEnergy"); local rt = ch:FindFirstChild("RaceTransformed")
            if re and rt and tonumber(re.Value)==1 and not rt.Value then
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true,"Y",false,game); task.wait(0.1)
                vim:SendKeyEvent(false,"Y",false,game)
            end
        end) end
    end
end)

task.spawn(function()
    while _G._SamratActive do task.wait(0.25)
        if _G.AntiStun then pcall(function()
            local ch = LP.Character
            if ch then local s=ch:FindFirstChild("Stun"); if s then s.Value=0 end end
        end) end
    end
end)

-- ================================================
-- FAST ATTACK
-- ================================================
local FA_OK = false; local NetCo, RegAtk
pcall(function()
    NetCo = debug.getupvalue(getrenv()._G.SendHitsToServer, 1)
    RegAtk = RepS.Modules.Net["RE/RegisterAttack"]; FA_OK = true
end)

local function doFA()
    if not FA_OK then return end
    local mc = LP.Character
    if not mc or not mc:FindFirstChild("HumanoidRootPart") then return end
    local myP = mc.HumanoidRootPart.Position; local tgts = {}
    pcall(function() for _,m in pairs(CS:GetTagged("BasicMob")) do if m:IsA("Model") then table.insert(tgts,m) end end end)
    for _,p in pairs(Players:GetPlayers()) do if p~=LP and p.Character then table.insert(tgts,p.Character) end end
    local roots = {}
    for _,mdl in pairs(tgts) do
        local hu=mdl:FindFirstChildOfClass("Humanoid"); local hr=mdl:FindFirstChild("HumanoidRootPart")
        if hu and hu.Health>0 and hr and (hr.Position-myP).Magnitude<100 then table.insert(roots,hr) end
    end
    if #roots==0 then return end; local hl={}
    for i=2,#roots do local par=roots[i].Parent; if par then table.insert(hl,{par,roots[i]}) end end
    RegAtk:FireServer(0/0); coroutine.resume(NetCo, roots[1], hl)
end

task.spawn(function()
    while _G._SamratActive do task.wait(0.1)
        if _G.FastAttack then
            local ch = LP.Character
            if ch then local tool = ch:FindFirstChildWhichIsA("Tool")
                if tool and (tool.ToolTip=="Melee" or tool.ToolTip=="Sword") then pcall(doFA) end
            end
        end
    end
end)

-- ================================================
-- GUN AIMBOT — FIXED (uses RemoteFunctionShoot)
-- ================================================
local function isGunTool(tool)
    if not tool then return false end
    if (tool.ToolTip or "") == "Gun" then return true end
    if tool:FindFirstChild("RemoteFunctionShoot") then return true end
    return false
end

local function getGunRemote()
    local ch = LP.Character; if not ch then return nil end
    local tool = ch:FindFirstChildWhichIsA("Tool"); if not tool then return nil end
    if not isGunTool(tool) then return nil end
    return tool:FindFirstChild("RemoteFunctionShoot")
end

local gunM1Held = false
sC(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        gunM1Held = true
    end
end))
sC(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        gunM1Held = false
    end
end))

task.spawn(function()
    while _G._SamratActive do
        task.wait(0.1)
        if _G.GunAimbot and gunM1Held then
            pcall(function()
                if not AimTarget or not AimTargetHRP then return end
                if not AimTargetHRP.Parent then return end
                local hum = AimTargetHRP.Parent:FindFirstChild("Humanoid")
                if not hum or hum.Health <= 0 then return end
                local pos = getPred(AimTargetHRP)
                _G.AimBotSkillPosition = pos
                local rf = getGunRemote()
                if rf then rf:InvokeServer(pos) end
                -- __index hook handles Mouse.Hit redirect for client visuals
            end)
        end
    end
end)

-- ================================================
-- INIT
-- ================================================
task.spawn(function()
    task.wait(1)
    if _G.ESPEnabled then
        for _,p in pairs(Players:GetPlayers()) do if p~=LP then pcall(createESP,p) end end
    end
end)

noti("Samrat Hub", "v5.2 Loaded! Settings saved "..utf8.char(128190), 4)
