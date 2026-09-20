--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║    STEAL AN EGG HUB v2 — MERGED (Steal + Teleport + ESP + Hook)   ║
    ║    Game ID: 1789906834                                            ║
    ║    Executor: Delta / Xeno / Solara / dll (support metatable)      ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  FITUR:                                                           ║
    ║   [🥚 Egg]   Auto Steal, Filter Rarity, List Egg, Return Base     ║
    ║   [👤 Pemain] Teleport / Fly ke Pemain                            ║
    ║   [📦 Item]   Teleport / Fly ke Item + Item Scanner               ║
    ║   [📍 WP]     Mark + Teleport Waypoint                            ║
    ║   [👁️ ESP]   Egg / Trap / Hostile / Player / Parasite            ║
    ║   [⚙️ Farm]  Auto Hatch / Claim / Treadmill / Sell / Upgrade      ║
    ║   [🛡️ Hook]  Anti-Kick / Anti-Kill / WalkSpeed Spoof             ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  ⚠️  Gunakan akun alternatif. Risiko ban selalu ada.             ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

--=====================================================================
-- [1] SERVICES & SAFE REFS
--=====================================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RS                = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")

local LP = Players.LocalPlayer
if not LP then return warn("[Hub] LocalPlayer tidak ditemukan") end
local PlayerGui = LP:WaitForChild("PlayerGui", 10)
if not PlayerGui then return warn("[Hub] PlayerGui tidak ditemukan") end

--=====================================================================
-- [2] EXECUTOR ENV (SOFT FALLBACK)
--=====================================================================
local ENV = getgenv and getgenv() or _G or {}

local hookfunction      = hookfunction      or (hookfunc)
local getrawmetatable   = getrawmetatable   or (debug and debug.getmetatable)
local setreadonly       = setreadonly       or make_writeable
local getnamecallmethod = getnamecallmethod or function() return nil end
local checkcaller       = checkcaller       or function() return true end
local newcclosure       = newcclosure       or function(f) return f end

local HAS_HOOK = hookfunction and getrawmetatable and setreadonly

--=====================================================================
-- [3] CONFIG & STATE
--=====================================================================
local Config = {
    -- Steal
    autoSteal       = false,
    returnToBase    = true,
    stealDelay      = 0.35,
    maxRange        = 5000,
    approachDist    = 6,
    baseGuardRadius = 60,
    blindFire       = false,

    rarity = {
        Common=false, Uncommon=false, Rare=false, Epic=false,
        Legendary=false, Mythic=false, Cosmic=false,
        Secret=true, Eternal=true, Divine=true,
    },

    -- ESP
    espEgg=false, espTrap=false, espHostile=false,
    espPlayer=false, espParasite=false,
    espRange=3000, espMinRarity=0,

    -- Farm
    autoHatch=false, autoClaim=false, autoTreadmill=false,
    autoSell=false, autoUpgrade=false, autoFeedMonster=false,

    -- Movement
    antiFall=true, antiTrap=false,
    avoidRadius=30,

    -- Hook
    blockKick=true, blockKill=true,
    spoofWalkSpeed=true, blockWalkSpeedWr=false,
}
ENV.Config = Config

local State = {
    stolen=0, fails=0, lastEgg="-", lastGrab="-",
    flySpeed=200, lockXY=false,
}

--=====================================================================
-- [4] HOOKS (INSTALL SETELAH SEMUA HELPER SIAP)
--=====================================================================
local HookStatus = { namecall=false, metamethod=false }
local realWalkSpeed = 16

local function installHooks()
    if not HAS_HOOK then
        warn("[Hook] Executor tidak support hookfunction/metatable — proteksi OFF")
        return
    end

    -- ---------- NAMECALL ----------
    local okNC, errNC = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("no metatable") end
        setreadonly(mt, false)
        local orig = mt.__namecall

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if Config.blockKick and method == "Kick" and not checkcaller() then
                return nil
            end

            if Config.blockKill then
                if method == "TakeDamage"
                   and typeof(self) == "Instance"
                   and self:IsA("Humanoid")
                   and LP.Character
                   and self:IsDescendantOf(LP.Character)
                   and not checkcaller() then
                    return nil
                end
                if method == "BreakJoints"
                   and typeof(self) == "Instance"
                   and self == LP.Character
                   and not checkcaller() then
                    return nil
                end
                if method == "Destroy"
                   and typeof(self) == "Instance"
                   and self:IsA("Humanoid")
                   and LP.Character
                   and self:IsDescendantOf(LP.Character)
                   and not checkcaller() then
                    return nil
                end
            end

            return orig(self, ...)
        end)

        setreadonly(mt, true)
    end)
    if okNC then HookStatus.namecall = true
    else warn("[Hook] Namecall gagal: " .. tostring(errNC)) end

    -- ---------- METAMETHOD ----------
    local okMM, errMM = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then error("no metatable") end
        setreadonly(mt, false)
        local origI = mt.__index
        local origN = mt.__newindex

        mt.__index = newcclosure(function(self, key)
            if Config.spoofWalkSpeed and key == "WalkSpeed"
               and typeof(self) == "Instance"
               and self:IsA("Humanoid")
               and LP.Character
               and self:IsDescendantOf(LP.Character)
               and not checkcaller() then
                return realWalkSpeed
            end
            return origI(self, key)
        end)

        mt.__newindex = newcclosure(function(self, key, value)
            if key == "WalkSpeed"
               and typeof(self) == "Instance"
               and self:IsA("Humanoid")
               and LP.Character
               and self:IsDescendantOf(LP.Character) then
                if Config.blockWalkSpeedWr and not checkcaller() then
                    return
                end
                if checkcaller() then realWalkSpeed = value end
            end
            return origN(self, key, value)
        end)

        setreadonly(mt, true)
    end)
    if okMM then HookStatus.metamethod = true
    else warn("[Hook] Metamethod gagal: " .. tostring(errMM)) end
end

--=====================================================================
-- [5] UTILITY
--=====================================================================
local function getChar()   return LP.Character end
local function getHRP()    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function isAlive()   local h = getHum(); return h and h.Health > 0 end
local function dist(a,b)   return (a-b).Magnitude end

local RARITY_ORDER = {
    "Common","Uncommon","Rare","Epic","Legendary",
    "Mythic","Cosmic","Secret","Eternal","Divine"
}
local RARITY_COLOR = {
    Common    = Color3.fromRGB(150,160,175),
    Uncommon  = Color3.fromRGB(120,220,150),
    Rare      = Color3.fromRGB(90,170,255),
    Epic      = Color3.fromRGB(180,130,255),
    Legendary = Color3.fromRGB(255,190,80),
    Mythic    = Color3.fromRGB(255,110,200),
    Cosmic    = Color3.fromRGB(90,230,240),
    Secret    = Color3.fromRGB(255,235,130),
    Eternal   = Color3.fromRGB(200,120,255),
    Divine    = Color3.fromRGB(255,255,255),
}
local function rarityIndex(r)
    for i, v in ipairs(RARITY_ORDER) do
        if v == r then return i end
    end
    return 0
end

--=====================================================================
-- [6] ZONE MAP
--=====================================================================
local ZONES = {
    {name="Forest",        minX=553.42,  maxX=646.49},
    {name="Lake",          minX=653.01,  maxX=793.51},
    {name="Desert",        minX=796.48,  maxX=1005.04},
    {name="Jungle",        minX=1008.56, maxX=1240.12},
    {name="Snow",          minX=1244.13, maxX=1564.18},
    {name="Volcano",       minX=1568.33, maxX=1949.58},
    {name="Abyss Ocean",   minX=1953.30, maxX=2378.73},
    {name="Prehistoric",   minX=2382.87, maxX=2884.09},
    {name="Cosmic",        minX=2888.03, maxX=3523.51},
    {name="Cherry Blossom",minX=3527.67, maxX=4263.53},
    {name="Titan Temple",  minX=4268.09, maxX=5123.06},
}
local function zoneOf(pos)
    if not pos then return nil end
    for _, z in ipairs(ZONES) do
        if pos.X >= z.minX and pos.X <= z.maxX then return z.name end
    end
    return nil
end

--=====================================================================
-- [7] PET DATABASE (ringkas)
--=====================================================================
local PET_DB = {
    spider={Rarity="Mythic",Income=22000,Zone="Jungle"},
    tiger={Rarity="Mythic",Income=28000,Zone="Jungle"},
    kingsnake={Rarity="Secret",Income=3500000,Zone="Jungle"},
    yeti={Rarity="Secret",Income=5000000,Zone="Snow"},
    icedragon={Rarity="Eternal",Income=65000000,Zone="Snow"},
    phoenix={Rarity="Eternal",Income=85000000,Zone="Volcano"},
    lavadragon={Rarity="Eternal",Income=100000000,Zone="Volcano"},
    kraken={Rarity="Secret",Income=15000000,Zone="Abyss"},
    elmaja={Rarity="Eternal",Income=130000000,Zone="Abyss"},
    trex={Rarity="Secret",Income=25000000,Zone="Prehistoric"},
    mosasaurus={Rarity="Eternal",Income=180000000,Zone="Prehistoric"},
    cosmicdragon={Rarity="Secret",Income=60000000,Zone="Cosmic"},
    unicorn={Rarity="Divine",Income=1000000000,Zone="Cosmic"},
    kitsune={Rarity="Divine",Income=1800000000,Zone="Cherry"},
    onitiger={Rarity="Eternal",Income=600000000,Zone="Cherry"},
    gorillaking={Rarity="Eternal",Income=880000000,Zone="Titan"},
    nightflame={Rarity="Divine",Zone="Titan"},
    mutantshark={Rarity="Secret",Income=215000000,Zone="Titan"},
}
local function lookupPet(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower():gsub("[^%a]","")
    n = n:gsub("^spiritbloom",""):gsub("^rainbow",""):gsub("^golden","")
    n = n:gsub("^bloom",""):gsub("^silver","")
    return PET_DB[n]
end

--=====================================================================
-- [8] REMOTE FINDER
--=====================================================================
local RemoteCache = {}
local function findRemote(keyword)
    if RemoteCache[keyword] ~= nil then
        return RemoteCache[keyword] or nil
    end
    local kw = keyword:lower()

    -- 1. Packages/Networking
    local packages = RS:FindFirstChild("Packages")
    if packages then
        local net = packages:FindFirstChild("Networking")
        if net then
            for _, obj in ipairs(net:GetDescendants()) do
                if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
                   and obj.Name:lower():find(kw, 1, true) then
                    RemoteCache[keyword] = obj
                    return obj
                end
            end
        end
    end

    -- 2. Anywhere in RS
    for _, obj in ipairs(RS:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
           and obj.Name:lower():find(kw, 1, true) then
            RemoteCache[keyword] = obj
            return obj
        end
    end

    -- 3. Workspace (rare)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
           and obj.Name:lower():find(kw, 1, true) then
            RemoteCache[keyword] = obj
            return obj
        end
    end

    RemoteCache[keyword] = false
    return nil
end

local function fireSafe(remote, ...)
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        else
            remote:FireServer(...)
        end
    end)
    return ok
end

--=====================================================================
-- [9] BASE DETECTION
--=====================================================================
local baseCache, baseCacheTime = nil, 0
local function getMyBase()
    if tick() - baseCacheTime < 5 and baseCache then return baseCache end
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local isMine = false
            for _, key in ipairs({"Owner","OwnerName","Player","PlayerName"}) do
                local o = plot:FindFirstChild(key)
                if o and o:IsA("ValueBase") and tostring(o.Value) == LP.Name then
                    isMine = true; break
                end
            end
            if isMine then
                local p = plot:IsA("Model") and plot:GetPivot().Position
                    or (plot:FindFirstChildWhichIsA("BasePart") or {}).Position
                if p then baseCache, baseCacheTime = p, tick(); return p end
            end
        end
    end
    local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
    baseCache = sp and sp.Position or nil
    baseCacheTime = tick()
    return baseCache
end

--=====================================================================
-- [10] EGG SCANNER
--=====================================================================
local function isParasiteEgg(obj)
    return obj:FindFirstChild("MonsterParasiteVisual") ~= nil
        or obj:GetAttribute("MonsterParasite") ~= nil
        or obj:GetAttribute("Parasite") ~= nil
end
local function isRareEgg(obj)
    return obj:FindFirstChild("RareAreaEggHighlight") ~= nil
end

local function scanEggs()
    local out = {}
    local h = getHRP()
    local hPos = h and h.Position or Vector3.new(0,0,0)
    local base = getMyBase()

    -- Folder utama
    local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then return out end

    for _, slot in ipairs(folder:GetChildren()) do
        if slot:IsA("Model") or slot:IsA("BasePart") then
            local part = slot:FindFirstChild("Plane")
                or slot:FindFirstChild("Hitbox")
                or (slot:IsA("BasePart") and slot)
                or slot:FindFirstChildWhichIsA("BasePart")
            if part then
                local pos = part.Position
                local rar, petName, income = nil, nil, nil
                local isPar  = isParasiteEgg(slot)
                local isRare = isRareEgg(slot)

                -- DB lookup by name
                local db = lookupPet(slot.Name)
                if db then
                    rar, income, petName = db.Rarity, db.Income, slot.Name
                end

                -- DB lookup by attributes
                for _, v in pairs(slot:GetAttributes()) do
                    if type(v) == "string" then
                        local db2 = lookupPet(v)
                        if db2 then
                            rar, income, petName = db2.Rarity, db2.Income, v
                        end
                    end
                end

                -- Ownership checks
                local inMyBase = false
                if base and dist(pos, base) < Config.baseGuardRadius then
                    inMyBase = true
                end
                if slot.Parent == getChar() then inMyBase = true end

                local owned = false
                local p = slot.Parent
                while p and p ~= Workspace do
                    if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then
                        local pl = Players:GetPlayerFromCharacter(p)
                        if pl and pl ~= LP then owned = true; break end
                    end
                    p = p.Parent
                end

                if rar or isPar or isRare then
                    table.insert(out, {
                        obj=slot, part=part, pos=pos,
                        rar=rar, income=income, pet=petName,
                        zone=zoneOf(pos),
                        isParasite=isPar, isRare=isRare,
                        dist=dist(hPos, pos),
                        inMyBase=inMyBase, owned=owned,
                    })
                end
            end
        end
    end
    return out
end

--=====================================================================
-- [11] OTHER SCANNERS
--=====================================================================
local function scanTraps()
    local out = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if (v:IsA("BasePart") or v:IsA("Model"))
           and (n:find("trap") or n:find("spike") or n:find("mine")
             or n:find("snare") or n:find("bomb")) then
            local p = v:IsA("BasePart") and v.Position
                or (v.PrimaryPart and v.PrimaryPart.Position)
            if p then table.insert(out, {obj=v, pos=p}) end
        end
    end
    return out
end

local function scanHostile()
    local out = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            if not Players:GetPlayerFromCharacter(v) then
                local p = v:FindFirstChild("HumanoidRootPart")
                if p then table.insert(out, {obj=v, pos=p.Position}) end
            end
        end
    end
    return out
end

local function scanPlayers()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            if h then table.insert(out, {plr=p, part=h, pos=h.Position}) end
        end
    end
    return out
end

--=====================================================================
-- [12] ESP SYSTEM
--=====================================================================
local ESPStore = {}  -- [uid] = {Highlight, Billboard, Label, Part, LastSeen, Kind}

local function espDestroy(entry)
    pcall(function() entry.Highlight:Destroy() end)
    pcall(function() entry.Billboard:Destroy() end)
end

local function clearESP(kind)
    for uid, data in pairs(ESPStore) do
        if not kind or data.Kind == kind then
            espDestroy(data)
            ESPStore[uid] = nil
        end
    end
end

local function espDraw(kind, uid, adornee, part, label, color)
    if ESPStore[uid] then
        ESPStore[uid].LastSeen = tick()
        ESPStore[uid].Label.Text = label
        return
    end

    local hl = Instance.new("Highlight")
    hl.Name = "ESP_"..kind
    hl.Adornee = adornee or part
    hl.FillColor = color
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.new(1,1,1)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = PlayerGui

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_BB_"..kind
    bb.Adornee = part
    bb.Size = UDim2.new(0, 160, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = PlayerGui

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.2
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.Parent = bb

    ESPStore[uid] = {
        Kind = kind, Highlight = hl, Billboard = bb, Label = lbl,
        Adornee = part, LastSeen = tick(),
    }
end

local espRunning = false
local function startESPLoop()
    if espRunning then return end
    espRunning = true

    RunService.RenderStepped:Connect(function()
        -- purge
        local now = tick()
        for uid, data in pairs(ESPStore) do
            local expired = (now - data.LastSeen) > 1.5
            local gone    = not data.Adornee or not data.Adornee.Parent
            if expired or gone then
                espDestroy(data)
                ESPStore[uid] = nil
            end
        end

        local h = getHRP()
        if not h then return end
        local hPos = h.Position

        -- Eggs
        if Config.espEgg then
            for _, e in ipairs(scanEggs()) do
                if e.dist <= Config.espRange and not e.inMyBase and not e.owned then
                    local rar = e.rar or "?"
                    local ridx = rarityIndex(rar)
                    if e.isParasite or ridx >= Config.espMinRarity or rar == "?" then
                        local c = RARITY_COLOR[rar] or Color3.fromRGB(200,200,200)
                        local tag = e.isParasite and "[PAR] " or (e.isRare and "[RARE] " or "")
                        local txt = string.format("%s%s\n[%s] %s",
                            tag, e.pet or e.obj.Name, rar, e.zone or "?")
                        espDraw("Egg", "E_"..e.obj:GetDebugId(), e.obj, e.part, txt, c)
                    end
                end
            end
        end

        -- Traps
        if Config.espTrap then
            for _, t in ipairs(scanTraps()) do
                if dist(hPos, t.pos) <= Config.espRange then
                    local part = t.obj:IsA("BasePart") and t.obj
                        or t.obj.PrimaryPart
                        or t.obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        espDraw("Trap", "T_"..t.obj:GetDebugId(), t.obj, part,
                            "TRAP", Color3.fromRGB(255,80,80))
                    end
                end
            end
        end

        -- Hostile
        if Config.espHostile then
            for _, v in ipairs(scanHostile()) do
                if dist(hPos, v.pos) <= Config.espRange then
                    local part = v.obj:FindFirstChild("HumanoidRootPart") or v.obj.PrimaryPart
                    if part then
                        espDraw("Hostile", "H_"..v.obj:GetDebugId(), v.obj, part,
                            "MOB", Color3.fromRGB(255,120,20))
                    end
                end
            end
        end

        -- Players
        if Config.espPlayer then
            for _, p in ipairs(scanPlayers()) do
                if dist(hPos, p.pos) <= Config.espRange then
                    espDraw("Player", "P_"..p.plr.UserId, p.plr.Character, p.part,
                        p.plr.DisplayName, Color3.fromRGB(120,220,255))
                end
            end
        end
    end)
end

--=====================================================================
-- [13] MOVEMENT (Teleport / Fly)
--=====================================================================
local function getLocalRoot()
    local c = getChar()
    if not c then
        c = LP.CharacterAdded:Wait()
    end
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

local function safeTeleport(cf)
    if not cf then return false, "target nil" end
    local myRoot = getLocalRoot()
    if not myRoot then return false, "root nil" end
    local ok, err = pcall(function() myRoot.CFrame = cf end)
    return ok, err
end

local function safeFly(cf, onDone)
    if not cf then return false, "target nil" end
    local myRoot, hum = getLocalRoot()
    if not myRoot or not hum then return false, "root/hum nil" end

    local speed = math.max(State.flySpeed, 10)
    local startPos = myRoot.Position
    local endPos   = cf.Position

    hum.PlatformStand = true

    local function finish()
        pcall(function() hum.PlatformStand = false end)
        if onDone then onDone() end
    end

    if State.lockXY then
        local dz = math.abs(endPos.Z - startPos.Z)
        if dz > 4 then
            local mid = Vector3.new(startPos.X, startPos.Y, endPos.Z)
            local dir = (endPos.Z > startPos.Z) and Vector3.new(0,0,1) or Vector3.new(0,0,-1)
            local midCF = CFrame.new(mid, mid + dir)
            local t1 = TweenService:Create(myRoot,
                TweenInfo.new(math.clamp(dz/speed, 0.1, 40),
                    Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {CFrame = midCF})
            t1:Play()
            t1.Completed:Connect(function()
                local distF = (endPos - myRoot.Position).Magnitude
                local t2 = TweenService:Create(myRoot,
                    TweenInfo.new(math.clamp(distF/speed, 0.1, 40),
                        Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {CFrame = cf})
                t2:Play()
                t2.Completed:Connect(finish)
            end)
            return true
        end
    end

    local d = (endPos - startPos).Magnitude
    local t = TweenService:Create(myRoot,
        TweenInfo.new(math.clamp(d/speed, 0.1, 60),
            Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = cf})
    t:Play()
    t.Completed:Connect(finish)
    return true
end

--=====================================================================
-- [14] STEAL
--=====================================================================
local function grabEgg(egg)
    if not egg or not egg.obj or not egg.obj.Parent then
        State.fails = State.fails + 1
        return false
    end
    if not isAlive() then return false end

    local myRoot = getHRP()
    if myRoot then
        myRoot.CFrame = CFrame.new(egg.pos + Vector3.new(0,0,-Config.approachDist), egg.pos)
    end
    task.wait(0.05)

    local remote = findRemote("AskFieldEggCarry") or findRemote("AskFieldEgg")
    if remote then
        fireSafe(remote, egg.obj)
    end
    task.wait(Config.stealDelay)

    State.stolen = State.stolen + 1
    State.lastEgg = egg.pet or egg.obj.Name
    State.lastGrab = os.date("%H:%M:%S")
    return true
end

local stealActive = false
local function startStealLoop()
    if stealActive then return end
    stealActive = true
    task.spawn(function()
        while Config.autoSteal do
            task.wait(0.1)
            if isAlive() then
                local eggs = scanEggs()
                local best, bestScore = nil, -1
                for _, e in ipairs(eggs) do
                    if not e.inMyBase and not e.owned and e.dist <= Config.maxRange then
                        local pass = false
                        if e.isParasite then pass = true
                        elseif e.rar and Config.rarity[e.rar] then pass = true
                        elseif Config.blindFire and e.rar then pass = true end
                        if pass then
                            local score = rarityIndex(e.rar or "") * 10000 - e.dist
                            if score > bestScore then bestScore, best = score, e end
                        end
                    end
                end
                if best then
                    grabEgg(best)
                    if Config.returnToBase then
                        local base = getMyBase()
                        local h = getHRP()
                        if base and h and dist(h.Position, base) > Config.baseGuardRadius * 0.5 then
                            safeTeleport(CFrame.new(base + Vector3.new(0,5,0)))
                        end
                    end
                end
            end
        end
        stealActive = false
    end)
end

--=====================================================================
-- [15] FARM LOOP
--=====================================================================
task.spawn(function()
    while true do
        task.wait(1)
        if Config.autoHatch then
            local r = findRemote("Hatch") or findRemote("OpenEgg")
            if r then fireSafe(r) end
        end
        if Config.autoClaim then
            local r = findRemote("ChestClaim") or findRemote("Claim")
            if r then fireSafe(r) end
        end
        if Config.autoTreadmill then
            local r = findRemote("Treadmill")
            if r then fireSafe(r) end
        end
        if Config.autoSell then
            local r = findRemote("SellPet") or findRemote("Sell")
            if r then fireSafe(r) end
        end
        if Config.autoUpgrade then
            local r = findRemote("Upgrade")
            if r then fireSafe(r) end
        end
        if Config.autoFeedMonster then
            local r = findRemote("AskFeed")
            if r then fireSafe(r) end
        end
    end
end)

--=====================================================================
-- [16] ANTI-FALL / ANTI-TRAP LOOP
--=====================================================================
RunService.Heartbeat:Connect(function()
    if not isAlive() then return end
    local h = getHRP()
    if not h then return end

    if Config.antiFall and h.Velocity.Y < -100 then
        h.Velocity = Vector3.new(h.Velocity.X, 0, h.Velocity.Z)
    end

    if Config.antiTrap then
        for _, t in ipairs(scanTraps()) do
            if dist(h.Position, t.pos) < Config.avoidRadius then
                local dir = (h.Position - t.pos)
                if dir.Magnitude > 0 then
                    h.Velocity = h.Velocity + dir.Unit * 50
                end
            end
        end
    end
end)

--=====================================================================
-- [17] GUI
--=====================================================================
local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggHub"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

-- Root frame
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(0, 400, 0, 480)
root.Position = UDim2.new(0, 40, 0, 100)
root.BackgroundColor3 = Color3.fromRGB(22,24,31)
root.BorderSizePixel = 0
root.Active = true
root.Draggable = true
root.Parent = screenGui
corner(root, 12)

-- Header
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -70, 0, 30)
header.Position = UDim2.new(0, 10, 0, 4)
header.BackgroundTransparency = 1
header.Text = "🥚 Steal An Egg Hub v2"
header.TextColor3 = Color3.fromRGB(245,245,250)
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = root

-- Minimize
local btnMin = Instance.new("TextButton")
btnMin.Size = UDim2.new(0, 26, 0, 26)
btnMin.Position = UDim2.new(1, -32, 0, 6)
btnMin.BackgroundColor3 = Color3.fromRGB(180,60,60)
btnMin.Text = "—"
btnMin.TextColor3 = Color3.new(1,1,1)
btnMin.Font = Enum.Font.GothamBold
btnMin.TextSize = 14
btnMin.BorderSizePixel = 0
btnMin.Parent = root
corner(btnMin, 6)

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 16)
status.Position = UDim2.new(0, 10, 0, 32)
status.BackgroundTransparency = 1
status.Text = "Siap digunakan"
status.TextColor3 = Color3.fromRGB(170,175,190)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = root

local function setStatus(txt, success, error)
    status.Text = tostring(txt)
    if success then status.TextColor3 = Color3.fromRGB(90,240,140)
    elseif error then status.TextColor3 = Color3.fromRGB(250,90,90)
    else status.TextColor3 = Color3.fromRGB(130,200,255) end
end

-- Tab buttons
local tabsRow = Instance.new("Frame")
tabsRow.Size = UDim2.new(1, -20, 0, 26)
tabsRow.Position = UDim2.new(0, 10, 0, 52)
tabsRow.BackgroundTransparency = 1
tabsRow.Parent = root

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 3)
tabsLayout.Parent = tabsRow

local TAB_NAMES = {"🥚 Egg","👤 Pemain","📦 Item","📍 WP","👁️ ESP","⚙️ Farm"}
local tabs = {}
for i, name in ipairs(TAB_NAMES) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 60, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(36,40,52)
    b.BorderSizePixel = 0
    b.Text = name
    b.TextColor3 = Color3.fromRGB(220,220,220)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 10
    b.Parent = tabsRow
    corner(b, 5)
    tabs[i] = b
end

-- Pages container
local pagesFrame = Instance.new("Frame")
pagesFrame.Size = UDim2.new(1, -20, 1, -170)
pagesFrame.Position = UDim2.new(0, 10, 0, 84)
pagesFrame.BackgroundTransparency = 1
pagesFrame.Parent = root

local function newPage()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = pagesFrame
    return f
end
local pages = {}
for i = 1, #TAB_NAMES do pages[i] = newPage() end

local function switchTab(i)
    for j, p in ipairs(pages) do p.Visible = (j == i) end
    for j, t in ipairs(tabs) do
        t.BackgroundColor3 = (j == i) and Color3.fromRGB(55,120,220)
                                       or Color3.fromRGB(36,40,52)
    end
end
for i, b in ipairs(tabs) do
    b.MouseButton1Click:Connect(function() switchTab(i) end)
end
switchTab(1)

-- Reusable toggle button builder
local function makeToggle(parent, y, label, getter, setter, height)
    height = height or 30
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, height)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = getter() and Color3.fromRGB(40,140,80)
                                     or Color3.fromRGB(45,49,64)
    b.BorderSizePixel = 0
    b.Text = label .. ": " .. (getter() and "ON" or "OFF")
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
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

-- Reusable action button builder
local function makeButton(parent, y, label, bg, callback, height)
    height = height or 34
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, height)
    b.Position = UDim2.new(0, 0, 0, y)
    b.BackgroundColor3 = bg or Color3.fromRGB(45,125,230)
    b.BorderSizePixel = 0
    b.Text = label
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = parent
    corner(b, 6)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then setStatus("Error: " .. tostring(err), false, true) end
    end)
    return b
end

-- Scroll list builder
local function makeScroll(parent, y, height)
    height = height or 180
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 0, height)
    sf.Position = UDim2.new(0, 0, 0, y)
    sf.BackgroundColor3 = Color3.fromRGB(18,20,26)
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Parent = parent
    corner(sf, 6)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = sf
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = sf
    return sf
end

--=====================================================================
-- [18] PAGE 1 — EGG
--=====================================================================
local pageEgg = pages[1]

local eggList = makeScroll(pageEgg, 0, 220)
local eggInfoLabel = Instance.new("TextLabel")
eggInfoLabel.Size = UDim2.new(1, 0, 0, 18)
eggInfoLabel.Position = UDim2.new(0, 0, 0, 224)
eggInfoLabel.BackgroundTransparency = 1
eggInfoLabel.Text = "Scanning..."
eggInfoLabel.TextColor3 = Color3.fromRGB(180,200,240)
eggInfoLabel.Font = Enum.Font.Gotham
eggInfoLabel.TextSize = 11
eggInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
eggInfoLabel.Parent = pageEgg

-- Refresh list
local function refreshEggList()
    for _, c in ipairs(eggList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local eggs = scanEggs()
    table.sort(eggs, function(a, b)
        local ra, rb = rarityIndex(a.rar or ""), rarityIndex(b.rar or "")
        if ra ~= rb then return ra > rb end
        return a.dist < b.dist
    end)

    local shown = 0
    for _, e in ipairs(eggs) do
        if not e.inMyBase and not e.owned and e.dist <= Config.maxRange then
            shown = shown + 1
            if shown > 40 then break end
            local eb = Instance.new("TextButton")
            eb.Size = UDim2.new(1, 0, 0, 34)
            eb.BackgroundColor3 = Color3.fromRGB(34,38,48)
            eb.BorderSizePixel = 0
            eb.Text = string.format("%s%s | %s | %s | %.0fm",
                e.isParasite and "[PAR] " or (e.isRare and "[RARE] " or ""),
                (e.pet or e.obj.Name):sub(1, 22),
                e.rar or "?", e.zone or "?", e.dist)
            eb.TextColor3 = RARITY_COLOR[e.rar] or Color3.fromRGB(220,220,220)
            eb.Font = Enum.Font.Gotham
            eb.TextSize = 10
            eb.TextXAlignment = Enum.TextXAlignment.Left
            eb.Parent = eggList
            corner(eb, 4)
            eb.MouseButton1Click:Connect(function()
                setStatus("Fly ke: " .. (e.pet or e.obj.Name), false, false)
                safeFly(CFrame.new(e.pos + Vector3.new(0,5,0)), function()
                    setStatus("Grab...", true, false)
                    grabEgg(e)
                end)
            end)
        end
    end
    eggInfoLabel.Text = string.format("Egg ditemukan: %d (tap untuk fly+grab)", shown)
end

makeToggle(pageEgg, 246, "🥚 Auto Steal Egg", function() return Config.autoSteal end, function(v)
    Config.autoSteal = v
    if v then startStealLoop() end
end)

makeToggle(pageEgg, 280, "🏠 Return To Base", function() return Config.returnToBase end, function(v)
    Config.returnToBase = v
end)

-- Rarity grid
local rarityHolder = Instance.new("Frame")
rarityHolder.Size = UDim2.new(1, 0, 0, 120)
rarityHolder.Position = UDim2.new(0, 0, 0, 318)
rarityHolder.BackgroundTransparency = 1
rarityHolder.Parent = pageEgg

local rarityTitle = Instance.new("TextLabel")
rarityTitle.Size = UDim2.new(1, 0, 0, 16)
rarityTitle.BackgroundTransparency = 1
rarityTitle.Text = "Filter Rarity:"
rarityTitle.TextColor3 = Color3.fromRGB(180,200,240)
rarityTitle.Font = Enum.Font.Gotham
rarityTitle.TextSize = 11
rarityTitle.TextXAlignment = Enum.TextXAlignment.Left
rarityTitle.Parent = rarityHolder

local rGrid = Instance.new("Frame")
rGrid.Size = UDim2.new(1, 0, 0, 100)
rGrid.Position = UDim2.new(0, 0, 0, 18)
rGrid.BackgroundTransparency = 1
rGrid.Parent = rarityHolder
local rLayout = Instance.new("UIGridLayout")
rLayout.CellSize = UDim2.new(0, 88, 0, 22)
rLayout.CellPadding = UDim2.new(0, 3, 0, 3)
rLayout.Parent = rGrid

for _, r in ipairs(RARITY_ORDER) do
    local state = Config.rarity[r]
    local rb = Instance.new("TextButton")
    rb.Size = UDim2.new(0, 88, 0, 22)
    rb.BackgroundColor3 = state and RARITY_COLOR[r] or Color3.fromRGB(40,44,56)
    rb.Text = r
    rb.TextColor3 = state and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
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

--=====================================================================
-- [19] PAGE 2 — PEMAIN
--=====================================================================
local pagePlayer = pages[2]
local selectedPlayer = nil

local playerDropBtn = makeButton(pagePlayer, 0, "Pilih Pemain ▼",
    Color3.fromRGB(42,46,60), function()
        playerList.Visible = not playerList.Visible
        if playerList.Visible then
            -- refresh
            for _, c in ipairs(playerList:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    local ib = Instance.new("TextButton")
                    ib.Size = UDim2.new(1, 0, 0, 28)
                    ib.BackgroundColor3 = Color3.fromRGB(34,38,48)
                    ib.BorderSizePixel = 0
                    ib.Text = p.DisplayName .. " (@" .. p.Name .. ")"
                    ib.TextColor3 = Color3.fromRGB(220,220,220)
                    ib.Font = Enum.Font.Gotham
                    ib.TextSize = 12
                    ib.Parent = playerList
                    corner(ib, 4)
                    ib.MouseButton1Click:Connect(function()
                        selectedPlayer = p.Name
                        playerDropBtn.Text = p.DisplayName
                        playerList.Visible = false
                        setStatus("Pemain: " .. p.DisplayName, false, false)
                    end)
                end
            end
        end
    end, 34)
playerDropBtn.TextSize = 12

local playerList = makeScroll(pagePlayer, 42, 180)
playerList.Visible = false

local function getPlayerTarget()
    if not selectedPlayer then error("Pilih pemain dulu!") end
    local p = Players:FindFirstChild(selectedPlayer)
    if not p then error("Pemain sudah keluar!") end
    local ch = p.Character
    local h = ch and ch:FindFirstChild("HumanoidRootPart")
    if not h then error("Target belum spawn!") end
    return h.CFrame * CFrame.new(0, 0, -3)
end

makeButton(pagePlayer, 232, "Teleport ke Pemain", Color3.fromRGB(45,125,230), function()
    local ok, res = pcall(getPlayerTarget)
    if ok then safeTeleport(res); setStatus("TP OK", true, false)
    else setStatus("Skip: " .. tostring(res), false, true) end
end)
makeButton(pagePlayer, 274, "Terbang ke Pemain", Color3.fromRGB(36,175,105), function()
    local ok, res = pcall(getPlayerTarget)
    if ok then safeFly(res, function() setStatus("Sampai!", true, false) end); setStatus("Flying...", false, false)
    else setStatus("Skip: " .. tostring(res), false, true) end
end)

--=====================================================================
-- [20] PAGE 3 — ITEM
--=====================================================================
local pageItem = pages[3]
local selectedItem = nil

local function getItemName(inst)
    local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
    local checkList = { inst }
    if model and model ~= Workspace then table.insert(checkList, model) end
    for _, o in ipairs(checkList) do
        for _, attr in ipairs({"EggName","ItemName","DisplayName","Type","Rarity","Tier"}) do
            local v = o:GetAttribute(attr)
            if v and tostring(v) ~= "" then return tostring(v) end
        end
        local pr = o:FindFirstChildOfClass("ProximityPrompt")
        if pr and pr.ObjectText ~= "" then return pr.ObjectText end
    end
    if model and model.Name ~= "Model" then return model.Name end
    return inst.Name
end

local itemDropBtn = makeButton(pageItem, 0, "Pilih Item ▼",
    Color3.fromRGB(42,46,60), function()
        itemList.Visible = not itemList.Visible
        if not itemList.Visible then return end
        for _, c in ipairs(itemList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local seen = {}
        local count = 0
        for _, obj in ipairs(Workspace:GetChildren()) do
            if count >= 40 then break end
            local part
            if obj:IsA("Tool") and obj:FindFirstChild("Handle") then part = obj.Handle
            elseif obj:IsA("Model") then part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            elseif obj:IsA("BasePart") then part = obj end
            if part and not seen[part] then
                seen[part] = true
                local nm = obj.Name:lower()
                if nm:find("egg") or nm:find("item") or nm:find("coin") or nm:find("gem") or obj:IsA("Tool") then
                    count = count + 1
                    local ib = Instance.new("TextButton")
                    ib.Size = UDim2.new(1, 0, 0, 28)
                    ib.BackgroundColor3 = Color3.fromRGB(34,38,48)
                    ib.BorderSizePixel = 0
                    ib.Text = getItemName(obj)
                    ib.TextColor3 = Color3.fromRGB(220,220,220)
                    ib.Font = Enum.Font.Gotham
                    ib.TextSize = 11
                    ib.Parent = itemList
                    corner(ib, 4)
                    ib.MouseButton1Click:Connect(function()
                        selectedItem = part
                        itemDropBtn.Text = getItemName(obj)
                        itemList.Visible = false
                        setStatus("Item: " .. getItemName(obj), false, false)
                    end)
                end
            end
        end
    end, 34)

local itemList = makeScroll(pageItem, 42, 180)
itemList.Visible = false

local function getItemTarget()
    if not selectedItem or not selectedItem.Parent then
        error("Pilih item dulu / item hilang!")
    end
    return selectedItem.CFrame * CFrame.new(0, 2.5, 0)
end

makeButton(pageItem, 232, "Teleport ke Item", Color3.fromRGB(45,125,230), function()
    local ok, res = pcall(getItemTarget)
    if ok then safeTeleport(res); setStatus("TP OK", true, false)
    else setStatus("Skip: " .. tostring(res), false, true) end
end)
makeButton(pageItem, 274, "Terbang ke Item", Color3.fromRGB(36,175,105), function()
    local ok, res = pcall(getItemTarget)
    if ok then safeFly(res, function() setStatus("Sampai!", true, false) end); setStatus("Flying...", false, false)
    else setStatus("Skip: " .. tostring(res), false, true) end
end)

--=====================================================================
-- [21] PAGE 4 — WAYPOINT
--=====================================================================
local pageWP = pages[4]
local wpCF = nil

local wpLabel = Instance.new("TextLabel")
wpLabel.Size = UDim2.new(1, 0, 0, 34)
wpLabel.BackgroundColor3 = Color3.fromRGB(34,38,48)
wpLabel.Text = "Belum ada posisi"
wpLabel.TextColor3 = Color3.fromRGB(180,185,195)
wpLabel.Font = Enum.Font.Gotham
wpLabel.TextSize = 12
wpLabel.Parent = pageWP
corner(wpLabel, 6)

makeButton(pageWP, 44, "📍 Tandai Posisi Sekarang", Color3.fromRGB(220,140,40), function()
    local myRoot = getLocalRoot()
    if not myRoot then error("Karakter belum siap!") end
    wpCF = myRoot.CFrame
    local p = wpCF.Position
    wpLabel.Text = string.format("(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
    wpLabel.TextColor3 = Color3.fromRGB(255,215,120)
    setStatus("Posisi ditandai!", true, false)
end)
makeButton(pageWP, 90, "Teleport ke Waypoint", Color3.fromRGB(45,125,230), function()
    if not wpCF then error("Tandai posisi dulu!") end
    safeTeleport(wpCF)
    setStatus("TP WP OK", true, false)
end)
makeButton(pageWP, 132, "Terbang ke Waypoint", Color3.fromRGB(36,175,105), function()
    if not wpCF then error("Tandai posisi dulu!") end
    safeFly(wpCF, function() setStatus("Sampai!", true, false) end)
    setStatus("Flying...", false, false)
end)

--=====================================================================
-- [22] PAGE 5 — ESP
--=====================================================================
local pageESP = pages[5]
local espY = 0

local espToggles = {
    {"🥚 ESP Egg",      function() return Config.espEgg end,      function(v) Config.espEgg = v end,      "Egg"},
    {"⚠️ ESP Trap",     function() return Config.espTrap end,     function(v) Config.espTrap = v end,     "Trap"},
    {"👹 ESP Hostile",  function() return Config.espHostile end,  function(v) Config.espHostile = v end,  "Hostile"},
    {"👤 ESP Player",   function() return Config.espPlayer end,   function(v) Config.espPlayer = v end,   "Player"},
    {"👽 ESP Parasite", function() return Config.espParasite end, function(v) Config.espParasite = v end, "Parasite"},
}
for _, t in ipairs(espToggles) do
    local label, getter, setter, kind = t[1], t[2], t[3], t[4]
    makeToggle(pageESP, espY, label, getter, function(v)
        setter(v)
        if not v then clearESP(kind) end
    end, 28)
    espY = espY + 32
end

local rangeLbl = Instance.new("TextLabel")
rangeLbl.Size = UDim2.new(1, 0, 0, 18)
rangeLbl.Position = UDim2.new(0, 0, 0, espY + 6)
rangeLbl.BackgroundTransparency = 1
rangeLbl.Text = "ESP Range: " .. Config.espRange
rangeLbl.TextColor3 = Color3.fromRGB(200,210,230)
rangeLbl.Font = Enum.Font.Gotham
rangeLbl.TextSize = 11
rangeLbl.TextXAlignment = Enum.TextXAlignment.Left
rangeLbl.Parent = pageESP

local rangeInput = Instance.new("TextBox")
rangeInput.Size = UDim2.new(0, 100, 0, 26)
rangeInput.Position = UDim2.new(0, 0, 0, espY + 28)
rangeInput.BackgroundColor3 = Color3.fromRGB(20,22,28)
rangeInput.BorderSizePixel = 0
rangeInput.Text = tostring(Config.espRange)
rangeInput.TextColor3 = Color3.fromRGB(255,215,100)
rangeInput.Font = Enum.Font.GothamBold
rangeInput.TextSize = 12
rangeInput.Parent = pageESP
corner(rangeInput, 4)
rangeInput.FocusLost:Connect(function()
    local n = tonumber(rangeInput.Text)
    if n and n > 0 then
        Config.espRange = n
        rangeLbl.Text = "ESP Range: " .. n
    else
        rangeInput.Text = tostring(Config.espRange)
    end
end)

--=====================================================================
-- [23] PAGE 6 — FARM
--=====================================================================
local pageFarm = pages[6]
local farmY = 0
local farmToggles = {
    {"🥚 Auto Hatch",       function() return Config.autoHatch end,       function(v) Config.autoHatch = v end},
    {"🎁 Auto Claim Chest", function() return Config.autoClaim end,       function(v) Config.autoClaim = v end},
    {"🏃 Auto Treadmill",   function() return Config.autoTreadmill end,   function(v) Config.autoTreadmill = v end},
    {"💰 Auto Sell Pet",    function() return Config.autoSell end,        function(v) Config.autoSell = v end},
    {"⬆️ Auto Upgrade",     function() return Config.autoUpgrade end,     function(v) Config.autoUpgrade = v end},
    {"🍖 Auto Feed Monster",function() return Config.autoFeedMonster end, function(v) Config.autoFeedMonster = v end},
}
for _, t in ipairs(farmToggles) do
    makeToggle(pageFarm, farmY, t[1], t[2], t[3], 28)
    farmY = farmY + 32
end

-- Speed control
local speedLbl = Instance.new("TextLabel")
speedLbl.Size = UDim2.new(1, 0, 0, 16)
speedLbl.Position = UDim2.new(0, 0, 0, farmY + 6)
speedLbl.BackgroundTransparency = 1
speedLbl.Text = "Kecepatan Fly:"
speedLbl.TextColor3 = Color3.fromRGB(200,210,230)
speedLbl.Font = Enum.Font.Gotham
speedLbl.TextSize = 11
speedLbl.TextXAlignment = Enum.TextXAlignment.Left
speedLbl.Parent = pageFarm

local speedInput = Instance.new("TextBox")
speedInput.Size = UDim2.new(0, 100, 0, 26)
speedInput.Position = UDim2.new(0, 0, 0, farmY + 26)
speedInput.BackgroundColor3 = Color3.fromRGB(20,22,28)
speedInput.BorderSizePixel = 0
speedInput.Text = tostring(State.flySpeed)
speedInput.TextColor3 = Color3.fromRGB(255,215,100)
speedInput.Font = Enum.Font.GothamBold
speedInput.TextSize = 12
speedInput.Parent = pageFarm
corner(speedInput, 4)
speedInput.FocusLost:Connect(function()
    local n = tonumber(speedInput.Text)
    if n and n > 0 then
        State.flySpeed = math.clamp(math.floor(n), 10, 1500)
        speedInput.Text = tostring(State.flySpeed)
    else
        speedInput.Text = tostring(State.flySpeed)
    end
end)

makeToggle(pageFarm, farmY + 60, "🔒 Lock X/Y (Z dulu)", function() return State.lockXY end,
    function(v) State.lockXY = v end, 28)

makeToggle(pageFarm, farmY + 92, "🛡️ Kill Guard",
    function() return Config.blockKill end,
    function(v) Config.blockKill = v end, 28)

makeToggle(pageFarm, farmY + 124, "🚫 Anti-Kick",
    function() return Config.blockKick end,
    function(v) Config.blockKick = v end, 28)

--=====================================================================
-- [24] MINIMIZE
--=====================================================================
local minimized = false
local floatingBtn
btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    root.Visible = not minimized
    if minimized and not floatingBtn then
        floatingBtn = Instance.new("TextButton")
        floatingBtn.Size = UDim2.new(0, 50, 0, 50)
        floatingBtn.Position = UDim2.new(0, 30, 0, 200)
        floatingBtn.BackgroundColor3 = Color3.fromRGB(45,125,230)
        floatingBtn.Text = "🥚"
        floatingBtn.TextColor3 = Color3.new(1,1,1)
        floatingBtn.Font = Enum.Font.GothamBold
        floatingBtn.TextSize = 22
        floatingBtn.Draggable = true
        floatingBtn.Parent = screenGui
        corner(floatingBtn, 25)
        floatingBtn.MouseButton1Click:Connect(function()
            minimized = false
            root.Visible = true
            floatingBtn.Visible = false
        end)
    end
    if floatingBtn then floatingBtn.Visible = minimized end
end)

--=====================================================================
-- [25] BOOTSTRAP
--=====================================================================
-- Install hooks SETELAH semua helper ada
task.defer(function()
    pcall(installHooks)
    if HookStatus.namecall or HookStatus.metamethod then
        setStatus(string.format("Hook ON → NC:%s Meta:%s",
            HookStatus.namecall and "Y" or "N",
            HookStatus.metamethod and "Y" or "N"), true, false)
    else
        setStatus("Hook gagal (executor tidak support)", false, true)
    end
end)

-- Start ESP loop
startESPLoop()

-- Periodic egg refresh
task.spawn(function()
    while task.wait(2.5) do
        pcall(refreshEggList)
    end
end)

-- Periodic status update
task.spawn(function()
    while task.wait(3) do
        if Config.autoSteal then
            setStatus(string.format("Steal: %d | Fail: %d | Last: %s",
                State.stolen, State.fails, tostring(State.lastEgg):sub(1,20)), false, false)
        end
    end
end)

print("╔══════════════════════════════════════════╗")
print("║  🥚 Steal An Egg Hub v2 — LOADED         ║")
print("║  Hooks : NC=" .. tostring(HookStatus.namecall)
    .. " Meta=" .. tostring(HookStatus.metamethod))
print("║  Config: " .. tostring(ENV.Config ~= nil))
print("╚══════════════════════════════════════════╝")