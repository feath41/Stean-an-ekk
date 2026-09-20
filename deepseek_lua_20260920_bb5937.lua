-- Steal An Egg Hub v2.1 - Delta Safe Build
-- Game ID: 1789906834

print("[Hub] Step 1: Loading services...")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
print("[Hub] Step 2: LocalPlayer =", LP and LP.Name or "NIL")
if not LP then return warn("[Hub] No LocalPlayer") end

local PlayerGui = LP:WaitForChild("PlayerGui", 10)
if not PlayerGui then return warn("[Hub] No PlayerGui") end
print("[Hub] Step 3: PlayerGui OK")

-- Config
local Config = {
    autoSteal=false, returnToBase=true, stealDelay=0.35,
    maxRange=5000, approachDist=6, baseGuardRadius=60,
    rarity={Common=false,Uncommon=false,Rare=false,Epic=false,
            Legendary=false,Mythic=false,Cosmic=false,
            Secret=true,Eternal=true,Divine=true},
    espEgg=false, espTrap=false, espHostile=false,
    espPlayer=false, espParasite=false, espRange=3000,
    autoHatch=false, autoClaim=false, autoTreadmill=false,
    autoSell=false, autoUpgrade=false, autoFeedMonster=false,
    antiFall=true, antiTrap=false, avoidRadius=30,
    blockKick=true, blockKill=true, spoofWalkSpeed=true,
}
getgenv().Config = Config

local State = {
    stolen=0, fails=0, lastEgg="-", flySpeed=200, lockXY=false,
}

-- Utils
local function getChar() return LP.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function isAlive()
    local h = getHum()
    return h and h.Health > 0
end
local function dst(a,b) return (a-b).Magnitude end

local RARITY_ORDER = {"Common","Uncommon","Rare","Epic","Legendary",
                      "Mythic","Cosmic","Secret","Eternal","Divine"}
local RARITY_COLOR = {
    Common=Color3.fromRGB(150,160,175),
    Uncommon=Color3.fromRGB(120,220,150),
    Rare=Color3.fromRGB(90,170,255),
    Epic=Color3.fromRGB(180,130,255),
    Legendary=Color3.fromRGB(255,190,80),
    Mythic=Color3.fromRGB(255,110,200),
    Cosmic=Color3.fromRGB(90,230,240),
    Secret=Color3.fromRGB(255,235,130),
    Eternal=Color3.fromRGB(200,120,255),
    Divine=Color3.fromRGB(255,255,255),
}
local function rarityIndex(r)
    for i,v in ipairs(RARITY_ORDER) do if v==r then return i end end
    return 0
end

print("[Hub] Step 4: Installing hooks...")

-- HOOK (optional, wrapped)
local HookStatus = { namecall=false, metamethod=false }
local realWalkSpeed = 16

local function installHooks()
    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("no metatable") end
        setreadonly(mt, false)
        local origNC = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if Config.blockKick and method == "Kick" and not checkcaller() then
                return nil
            end
            if Config.blockKill and method == "TakeDamage"
               and typeof(self)=="Instance" and self:IsA("Humanoid")
               and LP.Character and self:IsDescendantOf(LP.Character)
               and not checkcaller() then
                return nil
            end
            return origNC(self, ...)
        end)
        local origI = mt.__index
        mt.__index = newcclosure(function(self, key)
            if Config.spoofWalkSpeed and key == "WalkSpeed"
               and typeof(self)=="Instance" and self:IsA("Humanoid")
               and LP.Character and self:IsDescendantOf(LP.Character)
               and not checkcaller() then
                return realWalkSpeed
            end
            return origI(self, key)
        end)
        setreadonly(mt, true)
    end)
    if ok then
        HookStatus.namecall = true
        HookStatus.metamethod = true
        print("[Hub] Hooks installed OK")
    else
        warn("[Hub] Hook failed:", err)
    end
end

task.spawn(function()
    pcall(installHooks)
end)

print("[Hub] Step 5: Hooks done, hookstatus:", HookStatus.namecall, HookStatus.metamethod)

-- Remotes
local RemoteCache = {}
local function findRemote(kw)
    if RemoteCache[kw] ~= nil then return RemoteCache[kw] or nil end
    kw = kw:lower()
    local packages = RS:FindFirstChild("Packages")
    if packages then
        local net = packages:FindFirstChild("Networking")
        if net then
            for _, obj in ipairs(net:GetDescendants()) do
                if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
                   and obj.Name:lower():find(kw, 1, true) then
                    RemoteCache[kw] = obj
                    return obj
                end
            end
        end
    end
    for _, obj in ipairs(RS:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
           and obj.Name:lower():find(kw, 1, true) then
            RemoteCache[kw] = obj
            return obj
        end
    end
    RemoteCache[kw] = false
    return nil
end

local function fireSafe(remote, ...)
    if not remote then return false end
    return pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        else
            remote:FireServer(...)
        end
    end)
end

print("[Hub] Step 6: Scanner setup...")

-- Pet DB
local PET_DB = {
    spider={Rarity="Mythic",Zone="Jungle"},
    tiger={Rarity="Mythic",Zone="Jungle"},
    kingsnake={Rarity="Secret",Zone="Jungle"},
    yeti={Rarity="Secret",Zone="Snow"},
    icedragon={Rarity="Eternal",Zone="Snow"},
    phoenix={Rarity="Eternal",Zone="Volcano"},
    lavadragon={Rarity="Eternal",Zone="Volcano"},
    kraken={Rarity="Secret",Zone="Abyss"},
    elmaja={Rarity="Eternal",Zone="Abyss"},
    trex={Rarity="Secret",Zone="Prehistoric"},
    mosasaurus={Rarity="Eternal",Zone="Prehistoric"},
    cosmicdragon={Rarity="Secret",Zone="Cosmic"},
    unicorn={Rarity="Divine",Zone="Cosmic"},
    kitsune={Rarity="Divine",Zone="Cherry"},
    onitiger={Rarity="Eternal",Zone="Cherry"},
    gorillaking={Rarity="Eternal",Zone="Titan"},
    mutantshark={Rarity="Secret",Zone="Titan"},
}
local function lookupPet(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower():gsub("[^%a]","")
    n = n:gsub("^spiritbloom",""):gsub("^rainbow",""):gsub("^golden","")
    return PET_DB[n]
end

local ZONES = {
    {name="Forest",minX=553,maxX=646},
    {name="Lake",minX=653,maxX=793},
    {name="Desert",minX=796,maxX=1005},
    {name="Jungle",minX=1008,maxX=1240},
    {name="Snow",minX=1244,maxX=1564},
    {name="Volcano",minX=1568,maxX=1949},
    {name="Abyss",minX=1953,maxX=2378},
    {name="Prehistoric",minX=2382,maxX=2884},
    {name="Cosmic",minX=2888,maxX=3523},
    {name="Cherry",minX=3527,maxX=4263},
    {name="Titan",minX=4268,maxX=5123},
}
local function zoneOf(pos)
    if not pos then return nil end
    for _, z in ipairs(ZONES) do
        if pos.X >= z.minX and pos.X <= z.maxX then return z.name end
    end
    return nil
end

local function isParasiteEgg(o)
    return o:FindFirstChild("MonsterParasiteVisual") ~= nil
end

local function scanEggs()
    local out = {}
    local h = getHRP()
    if not h then return out end
    local hPos = h.Position

    local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then return out end

    for _, slot in ipairs(folder:GetChildren()) do
        local part = slot:FindFirstChild("Plane")
            or slot:FindFirstChild("Hitbox")
            or (slot:IsA("BasePart") and slot)
        if part then
            local pos = part.Position
            local rar, pet = nil, nil
            local db = lookupPet(slot.Name)
            if db then rar, pet = db.Rarity, slot.Name end
            for _, v in pairs(slot:GetAttributes()) do
                if type(v) == "string" then
                    local db2 = lookupPet(v)
                    if db2 then rar, pet = db2.Rarity, v end
                end
            end
            if rar or isParasiteEgg(slot) then
                table.insert(out, {
                    obj=slot, part=part, pos=pos,
                    rar=rar, pet=pet,
                    zone=zoneOf(pos),
                    isParasite=isParasiteEgg(slot),
                    dist=dst(hPos, pos),
                })
            end
        end
    end
    return out
end

print("[Hub] Step 7: GUI build...")

-- GUI
local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local root = Instance.new("Frame")
root.Size = UDim2.new(0, 400, 0, 480)
root.Position = UDim2.new(0, 40, 0, 100)
root.BackgroundColor3 = Color3.fromRGB(22,24,31)
root.BorderSizePixel = 0
root.Active = true
root.Draggable = true
root.Parent = screenGui
corner(root, 12)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1,-40,0,30)
header.Position = UDim2.new(0,10,0,4)
header.BackgroundTransparency = 1
header.Text = "Steal An Egg Hub v2.1"
header.TextColor3 = Color3.fromRGB(245,245,250)
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = root

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1,-20,0,16)
status.Position = UDim2.new(0,10,0,32)
status.BackgroundTransparency = 1
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(170,175,190)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = root

local function setStatus(msg, ok, err)
    status.Text = tostring(msg)
    if ok then status.TextColor3 = Color3.fromRGB(90,240,140)
    elseif err then status.TextColor3 = Color3.fromRGB(250,90,90)
    else status.TextColor3 = Color3.fromRGB(130,200,255) end
end

-- Tabs
local tabsRow = Instance.new("Frame")
tabsRow.Size = UDim2.new(1,-20,0,26)
tabsRow.Position = UDim2.new(0,10,0,52)
tabsRow.BackgroundTransparency = 1
tabsRow.Parent = root
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0,3)
tl.Parent = tabsRow

local TAB_NAMES = {"Egg","Pemain","Item","WP","ESP","Farm"}
local tabs = {}
for i, name in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 62, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(36,40,52)
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = Color3.fromRGB(220,220,220)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = tabsRow
    corner(b, 5)
    tabs[i] = b
end

local pagesFrame = Instance.new("Frame")
pagesFrame.Size = UDim2.new(1,-20,1,-150)
pagesFrame.Position = UDim2.new(0,10,0,84)
pagesFrame.BackgroundTransparency = 1
pagesFrame.Parent = root

local pages = {}
for i = 1, #TAB_NAMES do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,1,0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = pagesFrame
    pages[i] = f
end

local function switchTab(i)
    for j,p in ipairs(pages) do p.Visible = (j==i) end
    for j,t in ipairs(tabs) do
        t.BackgroundColor3 = (j==i) and Color3.fromRGB(55,120,220)
                                       or Color3.fromRGB(36,40,52)
    end
end
for i,b in ipairs(tabs) do
    b.MouseButton1Click:Connect(function() switchTab(i) end)
end
switchTab(1)

local function makeToggle(parent, y, label, getter, setter, h)
    h = h or 28
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,h)
    b.Position = UDim2.new(0,0,0,y)
    b.BackgroundColor3 = getter() and Color3.fromRGB(40,140,80)
                                     or Color3.fromRGB(45,49,64)
    b.BorderSizePixel = 0
    b.Text = label .. ": " .. (getter() and "ON" or "OFF")
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 11
    b.Parent = parent
    corner(b, 6)
    b.MouseButton1Click:Connect(function()
        setter(not getter())
        local on = getter()
        b.Text = label .. ": " .. (on and "ON" or "OFF")
        b.BackgroundColor3 = on and Color3.fromRGB(40,140,80)
                                   or Color3.fromRGB(45,49,64)
        setStatus(label .. (on and " ON" or " OFF"), on, false)
    end)
    return b
end

local function makeButton(parent, y, label, bg, cb, h)
    h = h or 34
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,h)
    b.Position = UDim2.new(0,0,0,y)
    b.BackgroundColor3 = bg or Color3.fromRGB(45,125,230)
    b.BorderSizePixel = 0
    b.Text = label
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = parent
    corner(b, 6)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then setStatus("Error: " .. tostring(err), false, true) end
    end)
    return b
end

-- Teleport helpers
local function getLocalRoot()
    local c = getChar() or LP.CharacterAdded:Wait()
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

local function safeTeleport(cf)
    if not cf then return end
    local r = getLocalRoot()
    if not r then return end
    pcall(function() r.CFrame = cf end)
end

local function safeFly(cf, done)
    if not cf then return end
    local r, hum = getLocalRoot()
    if not r or not hum then return end
    local speed = math.max(State.flySpeed, 10)
    local d = (cf.Position - r.Position).Magnitude
    hum.PlatformStand = true
    local t = TweenService:Create(r,
        TweenInfo.new(math.clamp(d/speed, 0.1, 60),
            Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame=cf})
    t:Play()
    t.Completed:Connect(function()
        pcall(function() hum.PlatformStand = false end)
        if done then done() end
    end)
end

-- PAGE 1: EGG
local pageEgg = pages[1]
local eggList = Instance.new("ScrollingFrame")
eggList.Size = UDim2.new(1,0,0,240)
eggList.BackgroundColor3 = Color3.fromRGB(18,20,26)
eggList.BorderSizePixel = 0
eggList.ScrollBarThickness = 4
eggList.CanvasSize = UDim2.new(0,0,0,0)
eggList.AutomaticCanvasSize = Enum.AutomaticSize.Y
eggList.Parent = pageEgg
corner(eggList, 6)
local el = Instance.new("UIListLayout")
el.Padding = UDim.new(0,3)
el.Parent = eggList

local function refreshList()
    for _, c in ipairs(eggList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local eggs = scanEggs()
    table.sort(eggs, function(a,b)
        local ra = rarityIndex(a.rar or "")
        local rb = rarityIndex(b.rar or "")
        if ra ~= rb then return ra > rb end
        return a.dist < b.dist
    end)
    local n = 0
    for _, e in ipairs(eggs) do
        if e.dist <= Config.maxRange then
            n = n + 1
            if n > 40 then break end
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,0,0,30)
            btn.BackgroundColor3 = Color3.fromRGB(34,38,48)
            btn.BorderSizePixel = 0
            btn.Text = string.format("%s | %s | %.0fm",
                (e.pet or e.obj.Name):sub(1,20),
                e.rar or "?",
                e.dist)
            btn.TextColor3 = RARITY_COLOR[e.rar] or Color3.fromRGB(220,220,220)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 10
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.Parent = eggList
            corner(btn, 4)
            btn.MouseButton1Click:Connect(function()
                setStatus("Fly ke: " .. (e.pet or e.obj.Name), false, false)
                safeFly(CFrame.new(e.pos + Vector3.new(0,5,0)), function()
                    setStatus("Arrived", true, false)
                end)
            end)
        end
    end
    setStatus(string.format("Eggs found: %d", n), false, false)
end

makeToggle(pageEgg, 248, "Auto Steal Egg",
    function() return Config.autoSteal end,
    function(v) Config.autoSteal = v end, 28)
makeToggle(pageEgg, 282, "Return To Base",
    function() return Config.returnToBase end,
    function(v) Config.returnToBase = v end, 28)

-- Rarity
local rTitle = Instance.new("TextLabel")
rTitle.Size = UDim2.new(1,0,0,16)
rTitle.Position = UDim2.new(0,0,0,320)
rTitle.BackgroundTransparency = 1
rTitle.Text = "Filter Rarity:"
rTitle.TextColor3 = Color3.fromRGB(180,200,240)
rTitle.Font = Enum.Font.Gotham
rTitle.TextSize = 11
rTitle.TextXAlignment = Enum.TextXAlignment.Left
rTitle.Parent = pageEgg

local rGrid = Instance.new("Frame")
rGrid.Size = UDim2.new(1,0,0,90)
rGrid.Position = UDim2.new(0,0,0,340)
rGrid.BackgroundTransparency = 1
rGrid.Parent = pageEgg
local rg = Instance.new("UIGridLayout")
rg.CellSize = UDim2.new(0, 88, 0, 22)
rg.CellPadding = UDim2.new(0,3,0,3)
rg.Parent = rGrid

for _, r in ipairs(RARITY_ORDER) do
    local st = Config.rarity[r]
    local rb = Instance.new("TextButton")
    rb.Size = UDim2.new(0,88,0,22)
    rb.BackgroundColor3 = st and RARITY_COLOR[r] or Color3.fromRGB(40,44,56)
    rb.Text = r
    rb.TextColor3 = st and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    rb.Font = Enum.Font.GothamBold
    rb.TextSize = 10
    rb.BorderSizePixel = 0
    rb.Parent = rGrid
    corner(rb, 4)
    rb.MouseButton1Click:Connect(function()
        Config.rarity[r] = not Config.rarity[r]
        local on = Config.rarity[r]
        rb.BackgroundColor3 = on and RARITY_COLOR[r] or Color3.fromRGB(40,44,56)
        rb.TextColor3 = on and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    end)
end

-- PAGE 2: PLAYER
local pagePlayer = pages[2]
local selPlayer = nil
local pBtn = makeButton(pagePlayer, 0, "Pilih Pemain", Color3.fromRGB(42,46,60), function()
    local lst = pagePlayer:FindFirstChild("PList")
    lst.Visible = not lst.Visible
    if not lst.Visible then return end
    for _, c in ipairs(lst:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local ib = Instance.new("TextButton")
            ib.Size = UDim2.new(1,0,0,28)
            ib.BackgroundColor3 = Color3.fromRGB(34,38,48)
            ib.BorderSizePixel = 0
            ib.Text = p.DisplayName
            ib.TextColor3 = Color3.fromRGB(220,220,220)
            ib.Font = Enum.Font.Gotham
            ib.TextSize = 12
            ib.Parent = lst
            corner(ib, 4)
            ib.MouseButton1Click:Connect(function()
                selPlayer = p.Name
                pBtn.Text = p.DisplayName
                lst.Visible = false
                setStatus("Pemain: " .. p.DisplayName, false, false)
            end)
        end
    end
end, 34)

local pList = Instance.new("ScrollingFrame")
pList.Name = "PList"
pList.Size = UDim2.new(1,0,0,180)
pList.Position = UDim2.new(0,0,0,42)
pList.BackgroundColor3 = Color3.fromRGB(18,20,26)
pList.BorderSizePixel = 0
pList.Visible = false
pList.ScrollBarThickness = 4
pList.CanvasSize = UDim2.new(0,0,0,0)
pList.AutomaticCanvasSize = Enum.AutomaticSize.Y
pList.Parent = pagePlayer
corner(pList, 6)
local pl = Instance.new("UIListLayout")
pl.Padding = UDim.new(0,2)
pl.Parent = pList

makeButton(pagePlayer, 232, "Teleport ke Pemain", Color3.fromRGB(45,125,230), function()
    if not selPlayer then error("Pilih pemain dulu!") end
    local p = Players:FindFirstChild(selPlayer)
    if not p or not p.Character then error("Target hilang!") end
    local h = p.Character:FindFirstChild("HumanoidRootPart")
    if not h then error("Target belum spawn!") end
    safeTeleport(h.CFrame * CFrame.new(0,0,-3))
    setStatus("TP OK", true, false)
end)
makeButton(pagePlayer, 274, "Terbang ke Pemain", Color3.fromRGB(36,175,105), function()
    if not selPlayer then error("Pilih pemain dulu!") end
    local p = Players:FindFirstChild(selPlayer)
    if not p or not p.Character then error("Target hilang!") end
    local h = p.Character:FindFirstChild("HumanoidRootPart")
    if not h then error("Target belum spawn!") end
    safeFly(h.CFrame * CFrame.new(0,0,-3), function()
        setStatus("Arrived", true, false)
    end)
end)

-- PAGE 3: ITEM
local pageItem = pages[3]
local selItem = nil

local function getItemName(inst)
    local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
    local list = {inst}
    if m and m ~= Workspace then table.insert(list, m) end
    for _, o in ipairs(list) do
        for _, a in ipairs({"EggName","ItemName","DisplayName","Type","Rarity"}) do
            local v = o:GetAttribute(a)
            if v and tostring(v) ~= "" then return tostring(v) end
        end
    end
    if m and m.Name ~= "Model" then return m.Name end
    return inst.Name
end

local iBtn = makeButton(pageItem, 0, "Pilih Item", Color3.fromRGB(42,46,60), function()
    local lst = pageItem:FindFirstChild("IList")
    lst.Visible = not lst.Visible
    if not lst.Visible then return end
    for _, c in ipairs(lst:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local seen = {}
    local n = 0
    for _, obj in ipairs(Workspace:GetChildren()) do
        if n >= 40 then break end
        local part
        if obj:IsA("Tool") and obj:FindFirstChild("Handle") then part = obj.Handle
        elseif obj:IsA("Model") then part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        elseif obj:IsA("BasePart") then part = obj end
        if part and not seen[part] then
            seen[part] = true
            local nm = obj.Name:lower()
            if nm:find("egg") or nm:find("item") or nm:find("coin") or obj:IsA("Tool") then
                n = n + 1
                local ib = Instance.new("TextButton")
                ib.Size = UDim2.new(1,0,0,28)
                ib.BackgroundColor3 = Color3.fromRGB(34,38,48)
                ib.BorderSizePixel = 0
                ib.Text = getItemName(obj)
                ib.TextColor3 = Color3.fromRGB(220,220,220)
                ib.Font = Enum.Font.Gotham
                ib.TextSize = 11
                ib.Parent = lst
                corner(ib, 4)
                ib.MouseButton1Click:Connect(function()
                    selItem = part
                    iBtn.Text = getItemName(obj)
                    lst.Visible = false
                    setStatus("Item: " .. getItemName(obj), false, false)
                end)
            end
        end
    end
end, 34)

local iList = Instance.new("ScrollingFrame")
iList.Name = "IList"
iList.Size = UDim2.new(1,0,0,180)
iList.Position = UDim2.new(0,0,0,42)
iList.BackgroundColor3 = Color3.fromRGB(18,20,26)
iList.BorderSizePixel = 0
iList.Visible = false
iList.ScrollBarThickness = 4
iList.CanvasSize = UDim2.new(0,0,0,0)
iList.AutomaticCanvasSize = Enum.AutomaticSize.Y
iList.Parent = pageItem
corner(iList, 6)
local il = Instance.new("UIListLayout")
il.Padding = UDim.new(0,2)
il.Parent = iList

makeButton(pageItem, 232, "Teleport ke Item", Color3.fromRGB(45,125,230), function()
    if not selItem or not selItem.Parent then error("Pilih item dulu!") end
    safeTeleport(selItem.CFrame * CFrame.new(0,2.5,0))
    setStatus("TP OK", true, false)
end)
makeButton(pageItem, 274, "Terbang ke Item", Color3.fromRGB(36,175,105), function()
    if not selItem or not selItem.Parent then error("Pilih item dulu!") end
    safeFly(selItem.CFrame * CFrame.new(0,2.5,0), function()
        setStatus("Arrived", true, false)
    end)
end)

-- PAGE 4: WAYPOINT
local pageWP = pages[4]
local wpCF = nil

local wpL = Instance.new("TextLabel")
wpL.Size = UDim2.new(1,0,0,34)
wpL.BackgroundColor3 = Color3.fromRGB(34,38,48)
wpL.Text = "Belum ada posisi"
wpL.TextColor3 = Color3.fromRGB(180,185,195)
wpL.Font = Enum.Font.Gotham
wpL.TextSize = 12
wpL.Parent = pageWP
corner(wpL, 6)

makeButton(pageWP, 44, "Tandai Posisi Sekarang", Color3.fromRGB(220,140,40), function()
    local r = getLocalRoot()
    if not r then error("Karakter belum siap") end
    wpCF = r.CFrame
    local p = wpCF.Position
    wpL.Text = string.format("(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    wpL.TextColor3 = Color3.fromRGB(255,215,120)
    setStatus("Posisi ditandai", true, false)
end)
makeButton(pageWP, 90, "Teleport ke WP", Color3.fromRGB(45,125,230), function()
    if not wpCF then error("Tandai dulu!") end
    safeTeleport(wpCF)
    setStatus("TP WP OK", true, false)
end)
makeButton(pageWP, 132, "Terbang ke WP", Color3.fromRGB(36,175,105), function()
    if not wpCF then error("Tandai dulu!") end
    safeFly(wpCF, function() setStatus("Arrived", true, false) end)
end)

-- PAGE 5: ESP
local pageESP = pages[5]
local espY = 0
local espList = {
    {"ESP Egg", function() return Config.espEgg end, function(v) Config.espEgg = v end},
    {"ESP Trap", function() return Config.espTrap end, function(v) Config.espTrap = v end},
    {"ESP Hostile", function() return Config.espHostile end, function(v) Config.espHostile = v end},
    {"ESP Player", function() return Config.espPlayer end, function(v) Config.espPlayer = v end},
}
for _, t in ipairs(espList) do
    makeToggle(pageESP, espY, t[1], t[2], t[3], 28)
    espY = espY + 32
end

local rangeL = Instance.new("TextLabel")
rangeL.Size = UDim2.new(1,0,0,18)
rangeL.Position = UDim2.new(0,0,0,espY+6)
rangeL.BackgroundTransparency = 1
rangeL.Text = "ESP Range: " .. Config.espRange
rangeL.TextColor3 = Color3.fromRGB(200,210,230)
rangeL.Font = Enum.Font.Gotham
rangeL.TextSize = 11
rangeL.TextXAlignment = Enum.TextXAlignment.Left
rangeL.Parent = pageESP

local rInput = Instance.new("TextBox")
rInput.Size = UDim2.new(0,100,0,26)
rInput.Position = UDim2.new(0,0,0,espY+28)
rInput.BackgroundColor3 = Color3.fromRGB(20,22,28)
rInput.BorderSizePixel = 0
rInput.Text = tostring(Config.espRange)
rInput.TextColor3 = Color3.fromRGB(255,215,100)
rInput.Font = Enum.Font.GothamBold
rInput.TextSize = 12
rInput.Parent = pageESP
corner(rInput, 4)
rInput.FocusLost:Connect(function()
    local n = tonumber(rInput.Text)
    if n and n > 0 then
        Config.espRange = n
        rangeL.Text = "ESP Range: " .. n
    else
        rInput.Text = tostring(Config.espRange)
    end
end)

-- PAGE 6: FARM
local pageFarm = pages[6]
local farmY = 0
local farmList = {
    {"Auto Hatch", function() return Config.autoHatch end, function(v) Config.autoHatch = v end},
    {"Auto Claim", function() return Config.autoClaim end, function(v) Config.autoClaim = v end},
    {"Auto Sell", function() return Config.autoSell end, function(v) Config.autoSell = v end},
    {"Kill Guard", function() return Config.blockKill end, function(v) Config.blockKill = v end},
    {"Anti Kick", function() return Config.blockKick end, function(v) Config.blockKick = v end},
}
for _, t in ipairs(farmList) do
    makeToggle(pageFarm, farmY, t[1], t[2], t[3], 28)
    farmY = farmY + 32
end

local spdL = Instance.new("TextLabel")
spdL.Size = UDim2.new(1,0,0,16)
spdL.Position = UDim2.new(0,0,0,farmY+6)
spdL.BackgroundTransparency = 1
spdL.Text = "Fly Speed:"
spdL.TextColor3 = Color3.fromRGB(200,210,230)
spdL.Font = Enum.Font.Gotham
spdL.TextSize = 11
spdL.TextXAlignment = Enum.TextXAlignment.Left
spdL.Parent = pageFarm

local spdI = Instance.new("TextBox")
spdI.Size = UDim2.new(0,100,0,26)
spdI.Position = UDim2.new(0,0,0,farmY+26)
spdI.BackgroundColor3 = Color3.fromRGB(20,22,28)
spdI.BorderSizePixel = 0
spdI.Text = tostring(State.flySpeed)
spdI.TextColor3 = Color3.fromRGB(255,215,100)
spdI.Font = Enum.Font.GothamBold
spdI.TextSize = 12
spdI.Parent = pageFarm
corner(spdI, 4)
spdI.FocusLost:Connect(function()
    local n = tonumber(spdI.Text)
    if n and n > 0 then
        State.flySpeed = math.clamp(math.floor(n), 10, 1500)
        spdI.Text = tostring(State.flySpeed)
    else
        spdI.Text = tostring(State.flySpeed)
    end
end)

print("[Hub] Step 8: Finalizing...")

-- Anti-fall
RunService.Heartbeat:Connect(function()
    if not isAlive() then return end
    local h = getHRP()
    if not h then return end
    if Config.antiFall and h.Velocity.Y < -100 then
        h.Velocity = Vector3.new(h.Velocity.X, 0, h.Velocity.Z)
    end
end)

-- Refresh eggs
task.spawn(function()
    while task.wait(2.5) do
        pcall(refreshList)
    end
end)

print("[Hub] ✅ LOADED SUCCESSFULLY")
setStatus("Hub loaded! Hooks: " .. (HookStatus.namecall and "ON" or "OFF"), true, false)