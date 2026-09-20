--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║      STEAL AN EGG + MULTI-TELEPORT HUB + HOOK (MERGED)           ║
    ║      Game ID: 1789906834                                          ║
    ║      Merged: Delta Hub Analysis + Teleport/Fly/ESP GUI + Hooks   ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  FITUR:                                                           ║
    ║  • Auto Steal Egg (Remote Path: RF/EggWorld/*)                   ║
    ║  • Teleport/Fly ke Pemain, Item, Waypoint                        ║
    ║  • ESP Item + Egg + Trap + Hostile + Parasite                    ║
    ║  • Hook: Anti-Kick, Anti-Kill, WalkSpeed Spoof                   ║
    ║  • Auto Farm (Hatch, Claim, Sell, Upgrade, Treadmill)            ║
    ║  • Auto Feed Monster Parasite                                     ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  PERINGATAN: Gunakan akun alternatif. Risiko ban selalu ada.     ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

--========== SERVICES ==========
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RS               = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local LP               = Players.LocalPlayer
local PlayerGui        = LP:WaitChild and LP:WaitForChild("PlayerGui") or LP:WaitForChild("PlayerGui")

--========== HOOK HELPERS & FALLBACKS ==========
local hookfunction        = hookfunction or hookfunc
local getrawmetatable     = getrawmetatable or debug.getmetatable
local setreadonly         = setreadonly or make_writeable
local getnamecallmethod   = getnamecallmethod or function() return nil end
local checkcaller         = checkcaller or function() return true end
local newcclosure         = newcclosure or function(f) return f end

local function logHook(msg) print("[HOOK] " .. tostring(msg)) end

--========== CONFIG ==========
getgenv().Config = {
    -- Steal
    autoSteal       = false,
    returnToBase    = true,
    stealSpeed      = 200,
    stealDelay      = 0.35,
    maxRange        = 5000,
    approachDist    = 6,
    grabTries       = 3,
    blindFire       = false,
    baseGuardRadius = 60,

    -- Rarity filter
    rarity = {
        Common    = false, Uncommon  = false, Rare      = false,
        Epic      = false, Legendary = false, Mythic    = false,
        Cosmic    = false, Secret    = true,  Eternal   = true,
        Divine    = true,
    },

    -- Movement
    walkMode        = false,
    speed           = 200,
    antiTrap        = true,
    antiHostile     = true,
    antiRagdoll     = true,
    noFall          = true,
    avoidRadius     = 30,

    -- ESP
    espEgg          = false,
    espTrap         = false,
    espHostile      = false,
    espPlayer       = false,
    espItem         = false,
    espRange        = 3000,
    espShowUnknown  = true,
    espMinRarity    = 6,

    -- Farm
    autoHatch       = false,
    autoClaim       = false,
    autoTreadmill   = false,
    autoSell        = false,
    autoUpgrade     = false,

    -- Monster
    autoFeedMonster = false,
    parasiteEsp     = false,
}
local C = getgenv().Config

--========== STATE ==========
local State = {
    status     = "idle",
    stolen     = 0,
    fails      = 0,
    lastEgg    = "-",
    lastGrab   = "-",
    menuOpen   = true,
    moving     = false,
}

--========== HOOK FLAGS ==========
local FLAGS = {
    blockKick        = true,
    spoofWalkSpeed   = true,
    blockWalkSpeedWr = false,
    blockKill        = true,
}
local realWalkSpeed = 16

local hookStatus = { namecall = false, metamethod = false, killGuard = false }

--========== UTILITY ==========
local function char()  return LP.Character end
local function hrp()   local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum()   local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h = hum(); return h and h.Health > 0 end
local function dist(a, b) return (a - b).Magnitude end
local function posOf(obj)
    if obj:IsA("BasePart") then return obj.Position end
    return obj.PrimaryPart and obj.PrimaryPart.Position or nil
end

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

--========== HOOK: NAME CALL ==========
local originalNamecall = nil

local function installNamecallHook()
    local mt = getrawmetatable(game)
    if not mt then logHook("Gagal ambil metatable game"); return false end
    setreadonly(mt, false)
    originalNamecall = mt.__namecall

    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if FLAGS.blockKick and method == "Kick" and not checkcaller() then
            logHook("🚫 Blocked Kick() → " .. tostring(args[1]))
            return nil
        end
        if FLAGS.blockKill and method == "TakeDamage" then
            if typeof(self) == "Instance" and self:IsA("Humanoid")
                and LP.Character and self:IsDescendantOf(LP.Character) and not checkcaller() then
                logHook("🚫 Blocked TakeDamage → " .. tostring(args[1]))
                return nil
            end
        end
        if FLAGS.blockKill and method == "BreakJoints" then
            if typeof(self) == "Instance" and self == LP.Character and not checkcaller() then
                logHook("🚫 Blocked BreakJoints")
                return nil
            end
        end
        if FLAGS.blockKill and method == "Destroy" then
            if typeof(self) == "Instance" and self:IsA("Humanoid")
                and LP.Character and self:IsDescendantOf(LP.Character) and not checkcaller() then
                logHook("🚫 Blocked Destroy() on Humanoid")
                return nil
            end
        end

        return originalNamecall(self, ...)
    end)
    setreadonly(mt, true)
    logHook("✅ Namecall hook terpasang")
    return true
end

--========== HOOK: METAMETHOD ==========
local originalIndex, originalNewIndex = nil, nil

local function installMetamethodHook()
    local mt = getrawmetatable(game)
    if not mt then logHook("Gagal ambil metatable game"); return false end
    setreadonly(mt, false)
    originalIndex    = mt.__index
    originalNewIndex = mt.__newindex

    mt.__index = newcclosure(function(self, key)
        if FLAGS.spoofWalkSpeed and key == "WalkSpeed" then
            if typeof(self) == "Instance" and self:IsA("Humanoid")
                and LP.Character and self:IsDescendantOf(LP.Character) and not checkcaller() then
                return realWalkSpeed
            end
        end
        return originalIndex(self, key)
    end)

    mt.__newindex = newcclosure(function(self, key, value)
        if FLAGS.blockWalkSpeedWr and key == "WalkSpeed" then
            if typeof(self) == "Instance" and self:IsA("Humanoid")
                and LP.Character and self:IsDescendantOf(LP.Character) and not checkcaller() then
                logHook("🚫 Blocked WalkSpeed write: " .. tostring(value))
                return
            end
        end
        if key == "WalkSpeed" then
            if typeof(self) == "Instance" and self:IsA("Humanoid")
                and LP.Character and self:IsDescendantOf(LP.Character) and checkcaller() then
                realWalkSpeed = value
            end
        end
        return originalNewIndex(self, key, value)
    end)

    setreadonly(mt, true)
    logHook("✅ Metamethod hook terpasang")
    return true
end

do
    local ok1 = pcall(installNamecallHook)
    if ok1 then hookStatus.namecall = true end
    local ok2 = pcall(installMetamethodHook)
    if ok2 then hookStatus.metamethod = true end
    hookStatus.killGuard = hookStatus.namecall
    print(string.format("[HOOK] Namecall:%s Meta:%s KillGuard:%s",
        tostring(hookStatus.namecall), tostring(hookStatus.metamethod), tostring(hookStatus.killGuard)))
end

--========== REMOTE HANDLES ==========
local RemoteCache = {}
local function findRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    local netPath = RS:FindFirstChild("Packages")
    if netPath then
        netPath = netPath:FindFirstChild("Networking")
        if netPath then
            local remote = netPath:FindFirstChild(name)
            if remote then RemoteCache[name] = remote; return remote end
            remote = netPath:FindFirstChild(name, true)
            if remote then RemoteCache[name] = remote; return remote end
        end
    end
    for _, obj in pairs(RS:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
            and obj.Name:lower():find(name:lower()) then
            RemoteCache[name] = obj; return obj
        end
    end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
            and obj.Name:lower():find(name:lower()) then
            RemoteCache[name] = obj; return obj
        end
    end
    return nil
end

local function fireSafe(remote, ...)
    if not remote then return false end
    local ok = pcall(function()
        if remote:IsA("RemoteFunction") then return remote:InvokeServer(...)
        else return remote:FireServer(...) end
    end)
    return ok
end

local function fireMatch(keywords, ...)
    local count = 0
    for _, obj in pairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if nm:find(kw:lower()) then
                    pcall(function()
                        if obj:IsA("RemoteFunction") then obj:InvokeServer(...)
                        else obj:FireServer(...) end
                    end)
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

--========== ZONE DETECTION ==========
local ZONES = {
    {name="Forest",         minX=553.42,  maxX=646.49},
    {name="Lake",           minX=653.01,  maxX=793.51},
    {name="Desert",         minX=796.48,  maxX=1005.04},
    {name="Jungle",         minX=1008.56, maxX=1240.12},
    {name="Snow",           minX=1244.13, maxX=1564.18},
    {name="Volcano",        minX=1568.33, maxX=1949.58},
    {name="Abyss Ocean",    minX=1953.30, maxX=2378.73},
    {name="Prehistoric",    minX=2382.87, maxX=2884.09},
    {name="Cosmic",         minX=2888.03, maxX=3523.51},
    {name="Cherry Blossom", minX=3527.67, maxX=4263.53},
    {name="Titan Temple",   minX=4268.09, maxX=5123.06},
}
local function zoneOf(pos)
    if not pos then return nil end
    for _, z in ipairs(ZONES) do
        if pos.X >= z.minX and pos.X <= z.maxX then return z.name end
    end
    return nil
end

--========== BASE DETECTION ==========
local baseCache, baseCacheT = nil, -1e9
local function myBase()
    if tick() - baseCacheT < 5 then return baseCache end
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local isMine = false
            for _, key in ipairs({"Owner","OwnerName","Player","PlayerName"}) do
                local o = plot:FindFirstChild(key)
                if o and o:IsA("ValueBase") and tostring(o.Value) == LP.Name then isMine = true; break end
            end
            if not isMine then
                for k, v in pairs(plot:GetAttributes() or {}) do
                    if tostring(v) == LP.Name then isMine = true; break end
                end
            end
            if not isMine then
                for _, d in ipairs(plot:GetDescendants()) do
                    if d:IsA("TextLabel") and tostring(d.Text):find(LP.Name, 1, true) then
                        isMine = true; break
                    end
                end
            end
            if isMine then
                local p = plot:IsA("Model") and plot:GetPivot().Position
                    or (plot:FindFirstChildWhichIsA("BasePart") or {}).Position
                if p then baseCache, baseCacheT = p, tick(); return p end
            end
        end
        local h = hrp()
        if h then
            local best, bestD = nil, math.huge
            for _, plot in ipairs(plots:GetChildren()) do
                local sp = plot:FindFirstChild("SpawnLocation")
                if sp and sp:IsA("BasePart") then
                    local d = dist(h.Position, sp.Position)
                    if d < bestD then bestD, best = d, sp.Position end
                end
            end
            if best then baseCache, baseCacheT = best, tick(); return best end
        end
    end
    local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
    return sp and sp.Position or nil
end

--========== PET DATABASE ==========
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
    tralaledon={Rarity="Secret",Income=32000000,Zone="Prehistoric"},
    mosasaurus={Rarity="Eternal",Income=180000000,Zone="Prehistoric"},
    cosmicskeletonboss={Rarity="Secret",Income=45000000,Zone="Cosmic"},
    cosmicdragon={Rarity="Secret",Income=60000000,Zone="Cosmic"},
    eternallunardragon={Rarity="Eternal",Income=250000000,Zone="Cosmic"},
    unicorn={Rarity="Divine",Income=1000000000,Zone="Cosmic"},
    kitsune={Rarity="Divine",Income=1800000000,Zone="Cherry"},
    onitiger={Rarity="Eternal",Income=600000000,Zone="Cherry"},
    stag={Rarity="Secret",Income=145000000,Zone="Cherry"},
    gorillaking={Rarity="Eternal",Income=880000000,Zone="Titan"},
    nightflame={Rarity="Divine",Income=nil,Zone="Titan"},
    mantaris={Rarity="Cosmic",Income=11000000,Zone="Titan"},
    rhinotaur={Rarity="Cosmic",Income=17500000,Zone="Titan"},
    mutantshark={Rarity="Secret",Income=215000000,Zone="Titan"},
    bladehide={Rarity="Mythic",Income=750000,Zone="Titan"},
    spideron={Rarity="Legendary",Income=95000,Zone="Titan"},
    crustacia={Rarity="Legendary",Income=130000,Zone="Titan"},
}

local function lookupPet(name)
    local n = name:lower():gsub("[^%a]", "")
    n = n:gsub("^spiritbloom",""):gsub("^rainbow",""):gsub("^golden","")
    n = n:gsub("^bloom",""):gsub("^silver","")
    return PET_DB[n]
end
local function isParasiteEgg(obj)
    return obj:FindFirstChild("MonsterParasiteVisual", true) ~= nil
        or obj:GetAttribute("MonsterParasite") ~= nil
        or obj:GetAttribute("Parasite") ~= nil
end
local function isRareEgg(obj)
    return obj:FindFirstChild("RareAreaEggHighlight", true) ~= nil
end

--========== EGG SCANNER ==========
local function scanEggs()
    local out = {}
    local h = hrp()
    local base = myBase()
    local hPos = h and h.Position or Vector3.new(0,0,0)

    local slotFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if slotFolder then
        for _, slot in ipairs(slotFolder:GetChildren()) do
            if slot:IsA("Model") or slot:IsA("BasePart") then
                local part = slot:FindFirstChild("Plane")
                    or slot:FindFirstChild("Hitbox")
                    or (slot:IsA("BasePart") and slot)
                    or slot:FindFirstChildWhichIsA("BasePart")
                if part then
                    local pos = part.Position
                    local rar, petName, zone = nil, nil, zoneOf(pos)
                    local income, isPar, isRare = nil, isParasiteEgg(slot), isRareEgg(slot)
                    local dbEntry = lookupPet(slot.Name)
                    if dbEntry then
                        rar, income = dbEntry.Rarity, dbEntry.Income
                        zone = dbEntry.Zone or zone
                        petName = slot.Name
                    end
                    for k, v in pairs(slot:GetAttributes() or {}) do
                        if type(v) == "string" then
                            local db = lookupPet(v)
                            if db then rar, income, petName = db.Rarity, db.Income, v end
                        end
                    end
                    local inMyBase = false
                    if base and dist(pos, base) < C.baseGuardRadius then inMyBase = true end
                    if slot.Parent == char() then inMyBase = true end
                    local owned = false
                    local p = slot.Parent
                    while p and p ~= Workspace do
                        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then
                            local pl = Players:GetPlayerFromCharacter(p)
                            if pl and pl ~= LP then owned = true end
                        end
                        p = p.Parent
                    end
                    if not rar and slot.Name:match("^%x+$") and #slot.Name > 16 then
                        rar = "Rare"
                    end
                    if rar or isPar or isRare then
                        table.insert(out, {
                            obj=slot, part=part, pos=pos, rar=rar, income=income,
                            pet=petName, zone=zone, isParasite=isPar, isRare=isRare,
                            dist=dist(hPos, pos), inMyBase=inMyBase, owned=owned, uid=slot.Name,
                        })
                    end
                end
            end
        end
    end

    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("Hitbox") then
            local already = false
            for _, e in ipairs(out) do if e.obj == obj then already = true; break end end
            if not already then
                local part = obj.Hitbox
                if part then
                    table.insert(out, {
                        obj=obj, part=part, pos=part.Position, rar=nil, income=nil,
                        pet=nil, zone=zoneOf(part.Position), isParasite=isParasiteEgg(obj),
                        isRare=isRareEgg(obj), dist=dist(hPos, part.Position),
                        inMyBase=false, owned=false, uid=obj.Name,
                    })
                end
            end
        end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("egg") then
            local already = false
            for _, e in ipairs(out) do if e.part == obj then already = true; break end end
            if not already then
                table.insert(out, {
                    obj=obj, part=obj, pos=obj.Position, rar=nil, income=nil,
                    pet=nil, zone=zoneOf(obj.Position), dist=dist(hPos, obj.Position),
                    inMyBase=false, owned=false, uid=obj.Name,
                })
            end
        end
    end
    return out
end

--========== TRAP/HOSTILE SCANNER ==========
local function scanTraps()
    local out = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if (v:IsA("BasePart") or v:IsA("Model"))
            and (n:find("trap") or n:find("spike") or n:find("mine")
                or n:find("snare") or n:find("bomb")) then
            local p = posOf(v)
            if p then table.insert(out, {obj=v, pos=p}) end
        end
    end
    return out
end

local function scanHostile()
    local out = {}
    local base = myBase()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
            local pl = Players:GetPlayerFromCharacter(v)
            if not pl then
                local p = posOf(v)
                if p then table.insert(out, {obj=v, pos=p}) end
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

--========== ESP DRAWER ==========
local ESPStore = {}
local function clearESP(kind)
    for uid, data in pairs(ESPStore) do
        if not kind or data.kind == kind then
            pcall(function()
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
            end)
            ESPStore[uid] = nil
        end
    end
end

local function drawESP(kind, uid, adornee, part, label, color)
    if ESPStore[uid] then
        ESPStore[uid].lastSeen = tick()
        return
    end
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_"..kind
    hl.Adornee = adornee or part
    hl.FillColor = color
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_BB_"..kind
    bb.Adornee = part
    bb.Size = UDim2.new(0, 160, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true

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
        kind = kind, Highlight = hl, Billboard = bb, Label = lbl,
        Adornee = part, lastSeen = tick()
    }
    hl.Parent = PlayerGui or CoreGui
    bb.Parent = PlayerGui or CoreGui
end

--========== MAIN ESP LOOP ==========
local espLoopConn
local function startESPLoop()
    if espLoopConn then return end
    espLoopConn = RunService.RenderStepped:Connect(function()
        local h = hrp()
        if not h then return end
        local hPos = h.Position

        -- Purge stale
        for uid, data in pairs(ESPStore) do
            local expired = (tick() - data.lastSeen) > 1.5
            local gone = not data.Adornee or not data.Adornee.Parent
            if expired or gone then
                pcall(function()
                    data.Highlight:Destroy()
                    data.Billboard:Destroy()
                end)
                ESPStore[uid] = nil
            end
        end

        -- Eggs
        if C.espEgg then
            for _, e in ipairs(scanEggs()) do
                if e.dist <= C.espRange and not e.inMyBase then
                    local rar = e.rar or "?"
                    local ridx = table.find(RARITY_ORDER, rar) or 0
                    if e.isParasite or ridx >= (C.espMinRarity or 0) or C.espShowUnknown then
                        local color = RARITY_COLOR[rar] or Color3.fromRGB(200,200,200)
                        local tag = e.isParasite and "[PAR]" or (e.isRare and "[RARE]" or "")
                        local label = string.format("%s %s\n[%s] %s",
                            tag, e.pet or e.obj.Name, rar, e.zone or "?")
                        drawESP("Egg", "E_"..tostring(e.obj), e.obj, e.part, label, color)
                    end
                end
            end
        end

        -- Traps
        if C.espTrap then
            for _, t in ipairs(scanTraps()) do
                local d = dist(hPos, t.pos)
                if d <= C.espRange then
                    drawESP("Trap", "T_"..tostring(t.obj), t.obj,
                        t.obj:IsA("BasePart") and t.obj or t.obj.PrimaryPart or t.obj:FindFirstChildWhichIsA("BasePart"),
                        "TRAP", Color3.fromRGB(255,80,80))
                end
            end
        end

        -- Hostile
        if C.espHostile then
            for _, v in ipairs(scanHostile()) do
                local d = dist(hPos, v.pos)
                if d <= C.espRange then
                    drawESP("Hostile", "H_"..tostring(v.obj), v.obj,
                        v.obj:FindFirstChild("HumanoidRootPart") or v.obj.PrimaryPart,
                        "MOB", Color3.fromRGB(255,120,20))
                end
            end
        end

        -- Players
        if C.espPlayer then
            for _, p in ipairs(scanPlayers()) do
                local d = dist(hPos, p.pos)
                if d <= C.espRange then
                    drawESP("Player", "P_"..p.plr.Name, p.plr.Character, p.part,
                        p.plr.DisplayName, Color3.fromRGB(120,220,255))
                end
            end
        end
    end)
end

--========== MOVEMENT HELPERS ==========
local currentFlySpeed = 200
local lockXYMode = false

local function getLocalRoot()
    local ch = LP.Character or LP.CharacterAdded:Wait()
    return ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChildOfClass("Humanoid")
end

local function safeTeleport(targetCFrame)
    local success, err = pcall(function()
        local myRoot = getLocalRoot()
        if not myRoot then error("Karakter belum siap!") end
        if not targetCFrame then error("Posisi invalid!") end
        myRoot.CFrame = targetCFrame
    end)
    return success, err
end

local function safeFly(targetCFrame, onDone)
    local success, err = pcall(function()
        local myRoot, humanoid = getLocalRoot()
        if not myRoot or not humanoid then error("Karakter belum siap!") end
        local effectiveSpeed = math.max(currentFlySpeed, 10)
        local startPos = myRoot.Position
        local targetPos = targetCFrame.Position
        humanoid.PlatformStand = true

        if lockXYMode then
            local distZ = math.abs(targetPos.Z - startPos.Z)
            if distZ > 4 then
                local midPos = Vector3.new(startPos.X, startPos.Y, targetPos.Z)
                local durZ = math.clamp(distZ / effectiveSpeed, 0.1, 40)
                local midCFrame = CFrame.new(midPos, midPos + (targetPos.Z > startPos.Z and Vector3.new(0,0,1) or Vector3.new(0,0,-1)))
                local tweenZ = TweenService:Create(myRoot, TweenInfo.new(durZ, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = midCFrame})
                tweenZ:Play()
                tweenZ.Completed:Connect(function()
                    pcall(function()
                        local distF = (targetPos - myRoot.Position).Magnitude
                        local durF = math.clamp(distF / effectiveSpeed, 0.1, 40)
                        local tweenF = TweenService:Create(myRoot, TweenInfo.new(durF, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCFrame})
                        tweenF:Play()
                        tweenF.Completed:Connect(function()
                            pcall(function()
                                humanoid.PlatformStand = false
                                if onDone then onDone() end
                            end)
                        end)
                    end)
                end)
            else
                local distDirect = (targetPos - startPos).Magnitude
                local durDirect = math.clamp(distDirect / effectiveSpeed, 0.1, 40)
                local tween = TweenService:Create(myRoot, TweenInfo.new(durDirect, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCFrame})
                tween:Play()
                tween.Completed:Connect(function()
                    pcall(function()
                        humanoid.PlatformStand = false
                        if onDone then onDone() end
                    end)
                end)
            end
        else
            local distance = (targetPos - startPos).Magnitude
            local duration = math.clamp(distance / effectiveSpeed, 0.1, 60)
            local tween = TweenService:Create(myRoot, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCFrame})
            tween:Play()
            tween.Completed:Connect(function()
                pcall(function()
                    humanoid.PlatformStand = false
                    if onDone then onDone() end
                end)
            end)
        end
    end)
    return success, err
end

--========== STEAL FUNCTIONS ==========
local function grabEgg(egg)
    if not egg or not egg.obj or not egg.obj.Parent then
        State.fails = State.fails + 1
        return false
    end
    if not alive() then return false end

    -- Teleport near
    local myRoot = hrp()
    if myRoot then
        local offset = Vector3.new(0, 0, -C.approachDist)
        myRoot.CFrame = CFrame.new(egg.pos + offset, egg.pos)
    end
    task.wait(0.05)

    -- Fire remote
    local remote = findRemote("AskFieldEggCarry")
        or findRemote("AskFieldEgg")
    if not remote then
        -- fallback: fire match
        fireMatch({"FieldEggCarry","AskFieldEgg","EggCarry","StealEgg"}, egg.obj)
    else
        fireSafe(remote, egg.obj)
    end
    task.wait(C.stealDelay)

    State.stolen = State.stolen + 1
    State.lastEgg = egg.pet or egg.obj.Name
    State.lastGrab = os.date("%H:%M:%S")
    return true
end

local stealLoopConn
local function startStealLoop()
    if stealLoopConn then return end
    stealLoopConn = task.spawn(function()
        while C.autoSteal do
            task.wait(0.1)
            if not alive() then task.wait(1); continue end

            local eggs = scanEggs()
            -- Filter by rarity config & ownership
            local candidates = {}
            for _, e in ipairs(eggs) do
                if not e.inMyBase and not e.owned and e.dist <= C.maxRange then
                    local rar = e.rar
                    local pass = false
                    if e.isParasite then pass = true
                    elseif rar and C.rarity[rar] then pass = true
                    elseif C.blindFire then pass = true end
                    if pass then table.insert(candidates, e) end
                end
            end
            table.sort(candidates, function(a, b)
                local ra = table.find(RARITY_ORDER, a.rar or "") or 0
                local rb = table.find(RARITY_ORDER, b.rar or "") or 0
                if ra ~= rb then return ra > rb end
                return a.dist < b.dist
            end)

            if #candidates > 0 then
                State.status = "stealing"
                grabEgg(candidates[1])
                if C.returnToBase then
                    local base = myBase()
                    if base then
                        local h = hrp()
                        if h and dist(h.Position, base) > C.baseGuardRadius * 0.5 then
                            safeTeleport(CFrame.new(base + Vector3.new(0,5,0)))
                        end
                    end
                end
                task.wait(C.stealDelay)
            else
                State.status = "idle"
                task.wait(0.5)
            end
        end
        State.status = "idle"
    end)
end

local function stopStealLoop()
    if stealLoopConn then stealLoopConn = nil end
end

--========== AUTO FARM FUNCTIONS ==========
local farmLoopConn = task.spawn(function()
    while true do
        task.wait(1)
        if C.autoHatch then
            fireMatch({"HatchEgg","Hatch","OpenEgg"}, "basic")
        end
        if C.autoClaim then
            fireMatch({"ClaimChest","ChestClaim","Claim"}, )
        end
        if C.autoTreadmill then
            fireMatch({"Treadmill","StartTreadmill"}, )
        end
        if C.autoSell then
            fireMatch({"SellPet","Sell","SellAll"}, )
        end
        if C.autoUpgrade then
            fireMatch({"Upgrade","UpgradeBase"}, )
        end
        if C.autoFeedMonster then
            fireMatch({"AskFeed","MonsterFeed","Feed"}, )
        end
    end
end)

--========== GUI SETUP ==========
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MergedHubGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 380, 0, 620)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -310)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 32)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🥚 Steal An Egg Hub v1"
titleLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 18)
statusLabel.Position = UDim2.new(0, 10, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Siap digunakan"
statusLabel.TextColor3 = Color3.fromRGB(170, 175, 190)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local function setStatus(msg, isSuccess, isError)
    statusLabel.Text = msg
    if isSuccess then statusLabel.TextColor3 = Color3.fromRGB(90, 240, 140)
    elseif isError then statusLabel.TextColor3 = Color3.fromRGB(250, 90, 90)
    else statusLabel.TextColor3 = Color3.fromRGB(130, 200, 255) end
end

task.defer(function()
    if hookStatus.namecall or hookStatus.metamethod then
        setStatus(string.format("Hook ON → NC:%s Meta:%s",
            hookStatus.namecall and "Y" or "N", hookStatus.metamethod and "Y" or "N"), true, false)
    else
        setStatus("Hook gagal (executor tidak support)", false, true)
    end
end)

--========== MINIMIZE BUTTON ==========
local btnMinimize = Instance.new("TextButton")
btnMinimize.Size = UDim2.new(0, 28, 0, 28)
btnMinimize.Position = UDim2.new(1, -32, 0, 2)
btnMinimize.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
btnMinimize.BorderSizePixel = 0
btnMinimize.Text = "—"
btnMinimize.TextColor3 = Color3.fromRGB(255,255,255)
btnMinimize.Font = Enum.Font.GothamBold
btnMinimize.TextSize = 16
btnMinimize.Parent = mainFrame
local cMin = Instance.new("UICorner"); cMin.CornerRadius = UDim.new(0, 6); cMin.Parent = btnMinimize

local minimized = false
local origSize = mainFrame.Size
local origPos = mainFrame.Position
local floatingBtn

btnMinimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        mainFrame.Visible = false
        if not floatingBtn then
            floatingBtn = Instance.new("TextButton")
            floatingBtn.Size = UDim2.new(0, 50, 0, 50)
            floatingBtn.Position = UDim2.new(0, 20, 0, 200)
            floatingBtn.BackgroundColor3 = Color3.fromRGB(45, 125, 230)
            floatingBtn.BorderSizePixel = 0
            floatingBtn.Text = "🥚"
            floatingBtn.TextColor3 = Color3.fromRGB(255,255,255)
            floatingBtn.Font = Enum.Font.GothamBold
            floatingBtn.TextSize = 24
            floatingBtn.Draggable = true
            floatingBtn.Parent = screenGui
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 25); fc.Parent = floatingBtn
            floatingBtn.MouseButton1Click:Connect(function()
                minimized = false
                mainFrame.Visible = true
                floatingBtn.Visible = false
            end)
        end
        floatingBtn.Visible = true
    else
        mainFrame.Visible = true
        if floatingBtn then floatingBtn.Visible = false end
    end
end)

--========== TAB CONTAINER ==========
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, -20, 0, 30)
tabContainer.Position = UDim2.new(0, 10, 0, 52)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabContainer

local function createTabButton(text, width)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width or 70, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.Parent = tabContainer
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn
    return btn
end

local btnTabEgg      = createTabButton("🥚 Egg", 62)
local btnTabPlayer   = createTabButton("👤 Pemain", 72)
local btnTabItem     = createTabButton("📦 Item", 62)
local btnTabWaypoint = createTabButton("📍 WP", 55)
local btnTabESP      = createTabButton("👁️ ESP", 55)
local btnTabFarm     = createTabButton("⚙️ Farm", 60)

--========== SPEED CONTROL PANEL ==========
local speedFrame = Instance.new("Frame")
speedFrame.Size = UDim2.new(1, -20, 0, 72)
speedFrame.Position = UDim2.new(0, 10, 0, 88)
speedFrame.BackgroundColor3 = Color3.fromRGB(30, 33, 44)
speedFrame.BorderSizePixel = 0
speedFrame.Parent = mainFrame
local sfc = Instance.new("UICorner"); sfc.CornerRadius = UDim.new(0, 8); sfc.Parent = speedFrame

local lblSpeed = Instance.new("TextLabel")
lblSpeed.Size = UDim2.new(0, 130, 0, 22)
lblSpeed.Position = UDim2.new(0, 8, 0, 4)
lblSpeed.BackgroundTransparency = 1
lblSpeed.Text = "Kecepatan Terbang:"
lblSpeed.TextColor3 = Color3.fromRGB(220, 220, 230)
lblSpeed.Font = Enum.Font.GothamMedium
lblSpeed.TextSize = 11
lblSpeed.TextXAlignment = Enum.TextXAlignment.Left
lblSpeed.Parent = speedFrame

local btnMinus = Instance.new("TextButton")
btnMinus.Size = UDim2.new(0, 24, 0, 22)
btnMinus.Position = UDim2.new(0, 145, 0, 5)
btnMinus.BackgroundColor3 = Color3.fromRGB(45, 49, 64)
btnMinus.BorderSizePixel = 0
btnMinus.Text = "-"
btnMinus.TextColor3 = Color3.fromRGB(255,255,255)
btnMinus.Font = Enum.Font.GothamBold; btnMinus.TextSize = 14
btnMinus.Parent = speedFrame
local cm1 = Instance.new("UICorner"); cm1.CornerRadius = UDim.new(0,4); cm1.Parent = btnMinus

local speedInput = Instance.new("TextBox")
speedInput.Size = UDim2.new(0, 52, 0, 22)
speedInput.Position = UDim2.new(0, 173, 0, 5)
speedInput.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
speedInput.BorderSizePixel = 0
speedInput.Text = tostring(currentFlySpeed)
speedInput.TextColor3 = Color3.fromRGB(255, 215, 100)
speedInput.Font = Enum.Font.GothamBold; speedInput.TextSize = 12
speedInput.ClearTextOnFocus = false
speedInput.Parent = speedFrame
local cm2 = Instance.new("UICorner"); cm2.CornerRadius = UDim.new(0,4); cm2.Parent = speedInput

local btnPlus = Instance.new("TextButton")
btnPlus.Size = UDim2.new(0, 24, 0, 22)
btnPlus.Position = UDim2.new(0, 229, 0, 5)
btnPlus.BackgroundColor3 = Color3.fromRGB(45, 49, 64)
btnPlus.BorderSizePixel = 0
btnPlus.Text = "+"
btnPlus.TextColor3 = Color3.fromRGB(255,255,255)
btnPlus.Font = Enum.Font.GothamBold; btnPlus.TextSize = 14
btnPlus.Parent = speedFrame
local cm3 = Instance.new("UICorner"); cm3.CornerRadius = UDim.new(0,4); cm3.Parent = btnPlus

local btnToggleLock = Instance.new("TextButton")
btnToggleLock.Size = UDim2.new(0, 160, 0, 22)
btnToggleLock.Position = UDim2.new(0, 8, 0, 32)
btnToggleLock.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
btnToggleLock.BorderSizePixel = 0
btnToggleLock.Text = "🔒 Lock X/Y: OFF"
btnToggleLock.TextColor3 = Color3.fromRGB(210,215,230)
btnToggleLock.Font = Enum.Font.GothamMedium; btnToggleLock.TextSize = 10
btnToggleLock.Parent = speedFrame
local cTL = Instance.new("UICorner"); cTL.CornerRadius = UDim.new(0,6); cTL.Parent = btnToggleLock

local btnKillGuard = Instance.new("TextButton")
btnKillGuard.Size = UDim2.new(0, 160, 0, 22)
btnKillGuard.Position = UDim2.new(0, 174, 0, 32)
btnKillGuard.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
btnKillGuard.BorderSizePixel = 0
btnKillGuard.Text = "🛡️ Kill Guard: ON"
btnKillGuard.TextColor3 = Color3.fromRGB(255,255,255)
btnKillGuard.Font = Enum.Font.GothamMedium; btnKillGuard.TextSize = 10
btnKillGuard.Parent = speedFrame
local cKG = Instance.new("UICorner"); cKG.CornerRadius = UDim.new(0,6); cKG.Parent = btnKillGuard

local function applySpeedInput()
    local num = tonumber(speedInput.Text)
    if num and num > 0 then
        currentFlySpeed = math.clamp(math.floor(num), 10, 1500)
        speedInput.Text = tostring(currentFlySpeed)
        setStatus("Speed: "..currentFlySpeed, false, false)
    else speedInput.Text = tostring(currentFlySpeed) end
end
speedInput.FocusLost:Connect(applySpeedInput)
btnMinus.MouseButton1Click:Connect(function()
    currentFlySpeed = math.max(currentFlySpeed - 25, 10)
    speedInput.Text = tostring(currentFlySpeed)
end)
btnPlus.MouseButton1Click:Connect(function()
    currentFlySpeed = math.min(currentFlySpeed + 25, 1500)
    speedInput.Text = tostring(currentFlySpeed)
end)
btnToggleLock.MouseButton1Click:Connect(function()
    lockXYMode = not lockXYMode
    if lockXYMode then
        btnToggleLock.Text = "🔒 Lock X/Y: ON"
        btnToggleLock.BackgroundColor3 = Color3.fromRGB(30, 110, 180)
    else
        btnToggleLock.Text = "🔒 Lock X/Y: OFF"
        btnToggleLock.BackgroundColor3 = Color3.fromRGB(42, 48, 62)
    end
end)
btnKillGuard.MouseButton1Click:Connect(function()
    FLAGS.blockKill = not FLAGS.blockKill
    if FLAGS.blockKill then
        btnKillGuard.Text = "🛡️ Kill Guard: ON"
        btnKillGuard.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
    else
        btnKillGuard.Text = "🛡️ Kill Guard: OFF"
        btnKillGuard.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    end
end)

--========== CONTENT FRAMES ==========
local function createContentFrame()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -20, 0, 415)
    f.Position = UDim2.new(0, 10, 0, 168)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = mainFrame
    return f
end

local frameEgg      = createContentFrame()
local framePlayer   = createContentFrame()
local frameItem     = createContentFrame()
local frameWaypoint = createContentFrame()
local frameESP      = createContentFrame()
local frameFarm     = createContentFrame()

local allFrames = {frameEgg, framePlayer, frameItem, frameWaypoint, frameESP, frameFarm}
local allBtns   = {btnTabEgg, btnTabPlayer, btnTabItem, btnTabWaypoint, btnTabESP, btnTabFarm}

local function switchTab(activeFrame, activeBtn)
    for _, f in ipairs(allFrames) do f.Visible = false end
    for _, b in ipairs(allBtns) do b.BackgroundColor3 = Color3.fromRGB(36, 40, 52) end
    activeFrame.Visible = true
    activeBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 220)
end

btnTabEgg.MouseButton1Click:Connect(function() switchTab(frameEgg, btnTabEgg) end)
btnTabPlayer.MouseButton1Click:Connect(function() switchTab(framePlayer, btnTabPlayer) end)
btnTabItem.MouseButton1Click:Connect(function() switchTab(frameItem, btnTabItem) end)
btnTabWaypoint.MouseButton1Click:Connect(function() switchTab(frameWaypoint, btnTabWaypoint) end)
btnTabESP.MouseButton1Click:Connect(function() switchTab(frameESP, btnTabESP) end)
btnTabFarm.MouseButton1Click:Connect(function() switchTab(frameFarm, btnTabFarm) end)
switchTab(frameEgg, btnTabEgg)

--========== HELPER: TOGGLE BUTTON ==========
local function makeToggle(parent, posY, text, initial, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.Position = UDim2.new(0, 0, 0, posY)
    btn.BackgroundColor3 = initial and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 49, 64)
    btn.BorderSizePixel = 0
    btn.Text = text .. ": " .. (initial and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12
    btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = btn
    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 49, 64)
        if callback then callback(state) end
    end)
    return btn, function() return state end
end

--========== TAB EGG ==========
local eggScroll = Instance.new("ScrollingFrame")
eggScroll.Size = UDim2.new(1, 0, 0, 200)
eggScroll.Position = UDim2.new(0, 0, 0, 0)
eggScroll.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
eggScroll.BorderSizePixel = 0
eggScroll.ScrollBarThickness = 4
eggScroll.Parent = frameEgg
local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0,8); ec.Parent = eggScroll
local eLayout = Instance.new("UIListLayout"); eLayout.Padding = UDim.new(0,3); eLayout.Parent = eggScroll

local eggCountLabel = Instance.new("TextLabel")
eggCountLabel.Size = UDim2.new(1, -12, 0, 20)
eggCountLabel.Position = UDim2.new(0, 6, 0, 4)
eggCountLabel.BackgroundTransparency = 1
eggCountLabel.Text = "Mencari egg..."
eggCountLabel.TextColor3 = Color3.fromRGB(180, 200, 240)
eggCountLabel.Font = Enum.Font.Gotham; eggCountLabel.TextSize = 11
eggCountLabel.TextXAlignment = Enum.TextXAlignment.Left
eggCountLabel.Parent = eggScroll

-- ScrollContentContainer
local eggList = Instance.new("Frame")
eggList.Size = UDim2.new(1, -12, 0, 0)
eggList.Position = UDim2.new(0, 6, 0, 28)
eggList.BackgroundTransparency = 1
eggList.Parent = eggScroll
local eLayout2 = Instance.new("UIListLayout"); eLayout2.Padding = UDim.new(0,3); eLayout2.Parent = eggList

-- Refresh egg list periodically
local function refreshEggList()
    for _, c in ipairs(eggList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local eggs = scanEggs()
    -- sort by rarity
    table.sort(eggs, function(a, b)
        local ra = table.find(RARITY_ORDER, a.rar or "") or 0
        local rb = table.find(RARITY_ORDER, b.rar or "") or 0
        if ra ~= rb then return ra > rb end
        return a.dist < b.dist
    end)
    local count = 0
    for _, e in ipairs(eggs) do
        if not e.inMyBase and not e.owned and e.dist <= C.maxRange then
            count = count + 1
            if count > 30 then break end
            local eb = Instance.new("TextButton")
            eb.Size = UDim2.new(1, 0, 0, 34)
            eb.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
            eb.BorderSizePixel = 0
            eb.Text = string.format("%s | %s | %s | %.0fm",
                (e.isParasite and "[PAR]" or (e.isRare and "[RARE]" or "")),
                (e.pet or e.obj.Name):sub(1, 22),
                (e.rar or "?"), e.dist)
            eb.TextColor3 = RARITY_COLOR[e.rar] or Color3.fromRGB(220,220,220)
            eb.Font = Enum.Font.Gotham; eb.TextSize = 10
            eb.TextXAlignment = Enum.TextXAlignment.Left
            eb.Parent = eggList
            local ebc = Instance.new("UICorner"); ebc.CornerRadius = UDim.new(0,4); ebc.Parent = eb
            eb.MouseButton1Click:Connect(function()
                setStatus("Fly ke: "..(e.pet or e.obj.Name), false, false)
                safeFly(CFrame.new(e.pos + Vector3.new(0,5,0)), function()
                    setStatus("Sampai! Grab...", true, false)
                    grabEgg(e)
                end)
            end)
        end
    end
    eggCountLabel.Text = "Ditemukan: "..count.." egg (tap untuk fly+grab)"
    eggScroll.CanvasSize = UDim2.new(0, 0, 0, 30 + count * 37)
end

task.spawn(function()
    while task.wait(2) do
        pcall(refreshEggList)
    end
end)

-- Toggle Auto Steal
local _, getAutoSteal = makeToggle(frameEgg, 210, "🥚 Auto Steal Egg", false, function(state)
    C.autoSteal = state
    if state then startStealLoop() else stopStealLoop() end
end)

local _, getReturnToBase = makeToggle(frameEgg, 245, "🏠 Return To Base", C.returnToBase, function(state)
    C.returnToBase = state
end)

-- Rarity Filter Buttons
local rarityBtnHolder = Instance.new("Frame")
rarityBtnHolder.Size = UDim2.new(1, 0, 0, 160)
rarityBtnHolder.Position = UDim2.new(0, 0, 0, 282)
rarityBtnHolder.BackgroundTransparency = 1
rarityBtnHolder.Parent = frameEgg

local rarityTitle = Instance.new("TextLabel")
rarityTitle.Size = UDim2.new(1, 0, 0, 16)
rarityTitle.BackgroundTransparency = 1
rarityTitle.Text = "Filter Rarity (tap untuk toggle):"
rarityTitle.TextColor3 = Color3.fromRGB(180, 200, 240)
rarityTitle.Font = Enum.Font.Gotham; rarityTitle.TextSize = 11
rarityTitle.TextXAlignment = Enum.TextXAlignment.Left
rarityTitle.Parent = rarityBtnHolder

local rGrid = Instance.new("Frame")
rGrid.Size = UDim2.new(1, 0, 0, 140)
rGrid.Position = UDim2.new(0, 0, 0, 20)
rGrid.BackgroundTransparency = 1
rGrid.Parent = rarityBtnHolder
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 84, 0, 24)
gridLayout.CellPadding = UDim2.new(0, 2, 0, 2)
gridLayout.Parent = rGrid

for _, r in ipairs(RARITY_ORDER) do
    local state = C.rarity[r]
    local rb = Instance.new("TextButton")
    rb.Size = UDim2.new(0, 84, 0, 24)
    rb.BackgroundColor3 = state and RARITY_COLOR[r] or Color3.fromRGB(40, 44, 56)
    rb.Text = r
    rb.TextColor3 = state and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    rb.Font = Enum.Font.GothamBold; rb.TextSize = 10
    rb.BorderSizePixel = 0
    rb.Parent = rGrid
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,4); rc.Parent = rb
    rb.MouseButton1Click:Connect(function()
        C.rarity[r] = not C.rarity[r]
        local on = C.rarity[r]
        rb.BackgroundColor3 = on and RARITY_COLOR[r] or Color3.fromRGB(40, 44, 56)
        rb.TextColor3 = on and Color3.fromRGB(20,20,20) or Color3.fromRGB(200,200,200)
    end)
end

--========== TAB PEMAIN ==========
local selectedPlayerName = nil

local playerDropBtn = Instance.new("TextButton")
playerDropBtn.Size = UDim2.new(1, 0, 0, 36)
playerDropBtn.Position = UDim2.new(0, 0, 0, 8)
playerDropBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
playerDropBtn.BorderSizePixel = 0
playerDropBtn.Text = "Pilih Pemain ▼"
playerDropBtn.TextColor3 = Color3.fromRGB(240,240,240)
playerDropBtn.Font = Enum.Font.GothamMedium; playerDropBtn.TextSize = 13
playerDropBtn.Parent = framePlayer
local c1p = Instance.new("UICorner"); c1p.CornerRadius = UDim.new(0,8); c1p.Parent = playerDropBtn

local playerDropList = Instance.new("ScrollingFrame")
playerDropList.Size = UDim2.new(1, 0, 0, 200)
playerDropList.Position = UDim2.new(0, 0, 0, 48)
playerDropList.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
playerDropList.BorderSizePixel = 0
playerDropList.Visible = false
playerDropList.ZIndex = 8
playerDropList.ScrollBarThickness = 4
playerDropList.Parent = framePlayer
local pLayout = Instance.new("UIListLayout"); pLayout.Padding = UDim.new(0,2); pLayout.Parent = playerDropList

local function refreshPlayerDropdown()
    for _, c in ipairs(playerDropList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local count = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            count = count + 1
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
            item.BorderSizePixel = 0
            item.Text = p.DisplayName .. " (@" .. p.Name .. ")"
            item.TextColor3 = Color3.fromRGB(220,220,220)
            item.Font = Enum.Font.Gotham; item.TextSize = 12
            item.ZIndex = 9
            item.Parent = playerDropList
            item.MouseButton1Click:Connect(function()
                selectedPlayerName = p.Name
                playerDropBtn.Text = p.DisplayName
                playerDropList.Visible = false
                setStatus("Pemain: "..p.DisplayName, false, false)
            end)
        end
    end
    playerDropList.CanvasSize = UDim2.new(0, 0, 0, count * 30)
end

playerDropBtn.MouseButton1Click:Connect(function()
    playerDropList.Visible = not playerDropList.Visible
    if playerDropList.Visible then refreshPlayerDropdown() end
end)

local function getPlayerTargetCFrame()
    if not selectedPlayerName then error("Pilih pemain dulu!") end
    local t = Players:FindFirstChild(selectedPlayerName)
    if not t then error("Pemain keluar!") end
    local ch = t.Character
    local h = ch and ch:FindFirstChild("HumanoidRootPart")
    if not h then error("Target belum spawn!") end
    return h.CFrame * CFrame.new(0, 0, -3)
end

local btnPlayerTP = Instance.new("TextButton")
btnPlayerTP.Size = UDim2.new(1, 0, 0, 40)
btnPlayerTP.Position = UDim2.new(0, 0, 0, 258)
btnPlayerTP.BackgroundColor3 = Color3.fromRGB(45, 125, 230)
btnPlayerTP.BorderSizePixel = 0
btnPlayerTP.Text = "Teleport ke Pemain (Instan)"
btnPlayerTP.TextColor3 = Color3.fromRGB(255,255,255)
btnPlayerTP.Font = Enum.Font.GothamBold; btnPlayerTP.TextSize = 13
btnPlayerTP.Parent = framePlayer
local cTPp = Instance.new("UICorner"); cTPp.CornerRadius = UDim.new(0,8); cTPp.Parent = btnPlayerTP

local btnPlayerFly = Instance.new("TextButton")
btnPlayerFly.Size = UDim2.new(1, 0, 0, 40)
btnPlayerFly.Position = UDim2.new(0, 0, 0, 308)
btnPlayerFly.BackgroundColor3 = Color3.fromRGB(36, 175, 105)
btnPlayerFly.BorderSizePixel = 0
btnPlayerFly.Text = "Terbang ke Pemain"
btnPlayerFly.TextColor3 = Color3.fromRGB(255,255,255)
btnPlayerFly.Font = Enum.Font.GothamBold; btnPlayerFly.TextSize = 13
btnPlayerFly.Parent = framePlayer
local cFlyp = Instance.new("UICorner"); cFlyp.CornerRadius = UDim.new(0,8); cFlyp.Parent = btnPlayerFly

btnPlayerTP.MouseButton1Click:Connect(function()
    local ok, res = pcall(getPlayerTargetCFrame)
    if ok then safeTeleport(res); setStatus("TP pemain OK", true, false)
    else setStatus("Skip: "..tostring(res), false, true) end
end)
btnPlayerFly.MouseButton1Click:Connect(function()
    local ok, res = pcall(getPlayerTargetCFrame)
    if ok then safeFly(res, function() setStatus("Sampai!", true, false) end); setStatus("Flying...", false, false)
    else setStatus("Skip: "..tostring(res), false, true) end
end)

--========== TAB ITEM ==========
local selectedItemPart = nil

local function getDetailedItemName(instance)
    local targetModel = instance:IsA("Model") and instance or instance:FindFirstAncestorOfClass("Model")
    local checkList = { instance }
    if targetModel and targetModel ~= Workspace then table.insert(checkList, targetModel) end
    for _, obj in ipairs(checkList) do
        for _, attr in ipairs({"EggName","ItemName","DisplayName","Type","Rarity","Tier","Name"}) do
            local val = obj:GetAttribute(attr)
            if val and tostring(val) ~= "" and tostring(val):lower() ~= "egg" and tostring(val):lower() ~= "part" then
                return tostring(val)
            end
        end
    end
    for _, obj in ipairs(checkList) do
        for _, valName in ipairs({"EggName","ItemName","DisplayName","Type","Rarity","Tier"}) do
            local cv = obj:FindFirstChild(valName)
            if cv and (cv:IsA("StringValue") or cv:IsA("ValueBase")) and tostring(cv.Value) ~= "" then
                return tostring(cv.Value)
            end
        end
    end
    for _, obj in ipairs(checkList) do
        local pr = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pr then
            if pr.ObjectText and pr.ObjectText ~= "" and pr.ObjectText:lower() ~= "egg" then return pr.ObjectText
            elseif pr.ActionText and pr.ActionText ~= "" then return pr.ActionText .. " (" .. obj.Name .. ")" end
        end
    end
    for _, obj in ipairs(checkList) do
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" and #d.Text > 1 then
                local t = d.Text:gsub("^%[.-%]", ""):gsub("^%s+",""):gsub("%s+$","")
                if #t > 1 and t:lower() ~= "e" and t:lower() ~= "egg" then return t end
            end
        end
    end
    if targetModel and targetModel ~= Workspace and targetModel.Name ~= "Model" then return targetModel.Name end
    return instance.Name
end

local itemDropBtn = Instance.new("TextButton")
itemDropBtn.Size = UDim2.new(1, 0, 0, 36)
itemDropBtn.Position = UDim2.new(0, 0, 0, 8)
itemDropBtn.BackgroundColor3 = Color3.fromRGB(42, 46, 60)
itemDropBtn.BorderSizePixel = 0
itemDropBtn.Text = "Pilih Item / Collectible ▼"
itemDropBtn.TextColor3 = Color3.fromRGB(240,240,240)
itemDropBtn.Font = Enum.Font.GothamMedium; itemDropBtn.TextSize = 13
itemDropBtn.Parent = frameItem
local cIB = Instance.new("UICorner"); cIB.CornerRadius = UDim.new(0,8); cIB.Parent = itemDropBtn

local itemDropList = Instance.new("ScrollingFrame")
itemDropList.Size = UDim2.new(1, 0, 0, 200)
itemDropList.Position = UDim2.new(0, 0, 0, 48)
itemDropList.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
itemDropList.BorderSizePixel = 0
itemDropList.Visible = false
itemDropList.ZIndex = 8
itemDropList.ScrollBarThickness = 4
itemDropList.Parent = frameItem
local iLayout = Instance.new("UIListLayout"); iLayout.Padding = UDim.new(0,2); iLayout.Parent = itemDropList

local function getAllCurrentItems()
    local items = {}
    local seen = {}
    pcall(function()
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                local h = obj.Handle
                if not seen[h] then
                    seen[h] = true
                    table.insert(items, {Name = getDetailedItemName(obj), Part = h, ParentModel = obj})
                end
            end
        end
        for _, pr in ipairs(Workspace:GetDescendants()) do
            if #items >= 35 then break end
            if pr:IsA("ProximityPrompt") and pr.Parent and pr.Parent:IsA("BasePart") then
                local part = pr.Parent
                if not seen[part] then
                    seen[part] = true
                    table.insert(items, {Name = getDetailedItemName(part), Part = part, ParentModel = part.Parent})
                end
            end
        end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if #items >= 35 then break end
            local ln = obj.Name:lower()
            if ln:find("egg") or ln:find("item") or ln:find("coin") or ln:find("gem") then
                local tp = (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))) or (obj:IsA("BasePart") and obj)
                if tp and not seen[tp] then
                    seen[tp] = true
                    table.insert(items, {Name = getDetailedItemName(obj), Part = tp, ParentModel = obj})
                end
            end
        end
    end)
    return items
end

local function refreshItemDropdown()
    for _, c in ipairs(itemDropList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local items = getAllCurrentItems()
    if #items == 0 then
        local eb = Instance.new("TextButton")
        eb.Size = UDim2.new(1, 0, 0, 28)
        eb.BackgroundTransparency = 1
        eb.Text = "(Tidak ada item terdeteksi)"
        eb.TextColor3 = Color3.fromRGB(150,150,150)
        eb.Font = Enum.Font.Gotham; eb.TextSize = 11
        eb.Parent = itemDropList
    else
        for _, d in ipairs(items) do
            local ib = Instance.new("TextButton")
            ib.Size = UDim2.new(1, 0, 0, 28)
            ib.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
            ib.BorderSizePixel = 0
            ib.Text = d.Name
            ib.TextColor3 = Color3.fromRGB(220,220,220)
            ib.Font = Enum.Font.Gotham; ib.TextSize = 11
            ib.ZIndex = 9
            ib.Parent = itemDropList
            ib.MouseButton1Click:Connect(function()
                selectedItemPart = d.Part
                itemDropBtn.Text = d.Name
                itemDropList.Visible = false
                setStatus("Item: "..d.Name, false, false)
            end)
        end
    end
    itemDropList.CanvasSize = UDim2.new(0, 0, 0, math.max(#items, 1) * 30)
end

itemDropBtn.MouseButton1Click:Connect(function()
    itemDropList.Visible = not itemDropList.Visible
    if itemDropList.Visible then refreshItemDropdown() end
end)

local function getItemTargetCFrame()
    if not selectedItemPart or not selectedItemPart.Parent then
        error("Pilih item dulu / item hilang!")
    end
    return selectedItemPart.CFrame * CFrame.new(0, 2.5, 0)
end

local btnItemTP = Instance.new("TextButton")
btnItemTP.Size = UDim2.new(1, 0, 0, 40)
btnItemTP.Position = UDim2.new(0, 0, 0, 258)
btnItemTP.BackgroundColor3 = Color3.fromRGB(45, 125, 230)
btnItemTP.BorderSizePixel = 0
btnItemTP.Text = "Teleport ke Item (Instan)"
btnItemTP.TextColor3 = Color3.fromRGB(255,255,255)
btnItemTP.Font = Enum.Font.GothamBold; btnItemTP.TextSize = 13
btnItemTP.Parent = frameItem
local cITP = Instance.new("UICorner"); cITP.CornerRadius = UDim.new(0,8); cITP.Parent = btnItemTP

local btnItemFly = Instance.new("TextButton")
btnItemFly.Size = UDim2.new(1, 0, 0, 40)
btnItemFly.Position = UDim2.new(0, 0, 0, 308)
btnItemFly.BackgroundColor3 = Color3.fromRGB(36, 175, 105)
btnItemFly.BorderSizePixel = 0
btnItemFly.Text = "Terbang ke Item"
btnItemFly.TextColor3 = Color3.fromRGB(255,255,255)
btnItemFly.Font = Enum.Font.GothamBold; btnItemFly.TextSize = 13
btnItemFly.Parent = frameItem
local cIFly = Instance.new("UICorner"); cIFly.CornerRadius = UDim.new(0,8); cIFly.Parent = btnItemFly

btnItemTP.MouseButton1Click:Connect(function()
    local ok, res = pcall(getItemTargetCFrame)
    if ok then safeTeleport(res); setStatus("TP item OK", true, false)
    else setStatus("Skip: "..tostring(res), false, true) end
end)
btnItemFly.MouseButton1Click:Connect(function()
    local ok, res = pcall(getItemTargetCFrame)
    if ok then safeFly(res, function() setStatus("Sampai!", true, false) end); setStatus("Flying...", false, false)
    else setStatus("Skip: "..tostring(res), false, true) end
end)

--========== TAB WAYPOINT ==========
local savedWaypointCFrame = nil

local wpStatus = Instance.new("TextLabel")
wpStatus.Size = UDim2.new(1, 0, 0, 36)
wpStatus.Position = UDim2.new(0, 0, 0, 8)
wpStatus.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
wpStatus.Text = "Belum ada posisi ditandai"
wpStatus.TextColor3 = Color3.fromRGB(180,185,195)
wpStatus.Font = Enum.Font.Gotham; wpStatus.TextSize = 12
wpStatus.Parent = frameWaypoint
local cWS = Instance.new("UICorner"); cWS.CornerRadius = UDim.new(0,8); cWS.Parent = wpStatus

local btnMarkPos = Instance.new("TextButton")
btnMarkPos.Size = UDim2.new(1, 0, 0, 42)
btnMarkPos.Position = UDim2.new(0, 0, 0, 56)
btnMarkPos.BackgroundColor3 = Color3.fromRGB(220, 140, 40)
btnMarkPos.BorderSizePixel = 0
btnMarkPos.Text = "📍 Tandai Posisi Sekarang"
btnMarkPos.TextColor3 = Color3.fromRGB(255,255,255)
btnMarkPos.Font = Enum.Font.GothamBold; btnMarkPos.TextSize = 13
btnMarkPos.Parent = frameWaypoint
local cMark = Instance.new("UICorner"); cMark.CornerRadius = UDim.new(0,8); cMark.Parent = btnMarkPos

btnMarkPos.MouseButton1Click:Connect(function()
    local ok, err = pcall(function()
        local myRoot = getLocalRoot()
        if not myRoot then error("Karakter belum siap!") end
        savedWaypointCFrame = myRoot.CFrame
        local p = savedWaypointCFrame.Position
        wpStatus.Text = string.format("Tersimpan: (%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
        wpStatus.TextColor3 = Color3.fromRGB(255, 215, 120)
        setStatus("Posisi ditandai!", true, false)
    end)
    if not ok then setStatus("Gagal: "..tostring(err), false, true) end
end)

local btnWaypointTP = Instance.new("TextButton")
btnWaypointTP.Size = UDim2.new(1, 0, 0, 40)
btnWaypointTP.Position = UDim2.new(0, 0, 0, 258)
btnWaypointTP.BackgroundColor3 = Color3.fromRGB(45, 125, 230)
btnWaypointTP.BorderSizePixel = 0
btnWaypointTP.Text = "Teleport ke Waypoint (Instan)"
btnWaypointTP.TextColor3 = Color3.fromRGB(255,255,255)
btnWaypointTP.Font = Enum.Font.GothamBold; btnWaypointTP.TextSize = 13
btnWaypointTP.Parent = frameWaypoint
local cWTP = Instance.new("UICorner"); cWTP.CornerRadius = UDim.new(0,8); cWTP.Parent = btnWaypointTP

local btnWaypointFly = Instance.new("TextButton")
btnWaypointFly.Size = UDim2.new(1, 0, 0, 40)
btnWaypointFly.Position = UDim2.new(0, 0, 0, 308)
btnWaypointFly.BackgroundColor3 = Color3.fromRGB(36, 175, 105)
btnWaypointFly.BorderSizePixel = 0
btnWaypointFly.Text = "Terbang ke Waypoint"
btnWaypointFly.TextColor3 = Color3.fromRGB(255,255,255)
btnWaypointFly.Font = Enum.Font.GothamBold; btnWaypointFly.TextSize = 13
btnWaypointFly.Parent = frameWaypoint
local cWFly = Instance.new("UICorner"); cWFly.CornerRadius = UDim.new(0,8); cWFly.Parent = btnWaypointFly

btnWaypointTP.MouseButton1Click:Connect(function()
    if not savedWaypointCFrame then setStatus("Tandai posisi dulu!", false, true); return end
    safeTeleport(savedWaypointCFrame); setStatus("TP WP OK", true, false)
end)
btnWaypointFly.MouseButton1Click:Connect(function()
    if not savedWaypointCFrame then setStatus("Tandai posisi dulu!", false, true); return end
    safeFly(savedWaypointCFrame, function() setStatus("Sampai!", true, false) end)
    setStatus("Flying...", false, false)
end)

--========== TAB ESP ==========
local espToggles = {}
local espY = 8
local function addESPToggle(label, getter, setter)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.Position = UDim2.new(0, 0, 0, espY)
    b.BackgroundColor3 = getter() and Color3.fromRGB(40, 140, 80) or Color3.fromRGB(45, 49, 64)
    b.BorderSizePixel = 0
    b.Text = label .. ": " .. (getter() and "ON" or "OFF")
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamMedium; b.TextSize = 12
    b.Parent = frameESP
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = b
    b.MouseButton1Click:Connect(function()
        setter(not getter())
        b.Text = label .. ": " .. (getter() and "ON" or "OFF")
        b.BackgroundColor3 = getter() and Color3.fromRGB(40,140,80) or Color3.fromRGB(45,49,64)
        if getter() then startESPLoop() end
        setStatus(label..": "..(getter() and "ON" or "OFF"), getter(), false)
    end)
    espY = espY + 34
    table.insert(espToggles, b)
end

addESPToggle("🥚 ESP Egg",      function() return C.espEgg end,     function(v) C.espEgg = v end)
addESPToggle("⚠️ ESP Trap",     function() return C.espTrap end,    function(v) C.espTrap = v end)
addESPToggle("👹 ESP Hostile",  function() return C.espHostile end, function(v) C.espHostile = v end)
addESPToggle("👤 ESP Player",   function() return C.espPlayer end,  function(v) C.espPlayer = v end)
addESPToggle("👽 ESP Parasite", function() return C.parasiteEsp end,function(v) C.parasiteEsp = v end)

-- ESP Range slider (simple)
local rangeLbl = Instance.new("TextLabel")
rangeLbl.Size = UDim2.new(1, 0, 0, 22)
rangeLbl.Position = UDim2.new(0, 0, 0, espY + 8)
rangeLbl.BackgroundTransparency = 1
rangeLbl.Text = "ESP Range: "..C.espRange.." studs"
rangeLbl.TextColor3 = Color3.fromRGB(200, 210, 230)
rangeLbl.Font = Enum.Font.Gotham; rangeLbl.TextSize = 11
rangeLbl.Parent = frameESP

local rangeInput = Instance.new("TextBox")
rangeInput.Size = UDim2.new(0, 100, 0, 24)
rangeInput.Position = UDim2.new(0, 0, 0, espY + 32)
rangeInput.BackgroundColor3 = Color3.fromRGB(20,22,28)
rangeInput.BorderSizePixel = 0
rangeInput.Text = tostring(C.espRange)
rangeInput.TextColor3 = Color3.fromRGB(255,215,100)
rangeInput.Font = Enum.Font.GothamBold; rangeInput.TextSize = 12
rangeInput.Parent = frameESP
local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,4); rc.Parent = rangeInput
rangeInput.FocusLost:Connect(function()
    local n = tonumber(rangeInput.Text)
    if n and n > 0 then C.espRange = n; rangeLbl.Text = "ESP Range: "..n.." studs" end
end)

--========== TAB FARM ==========
local farmY = 8
local function addFarmToggle(label, getter, setter)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.Position = UDim2.new(0, 0, 0, farmY)
    b.BackgroundColor3 = getter() and Color3.fromRGB(40,140,80) or Color3.fromRGB(45,49,64)
    b.BorderSizePixel = 0
    b.Text = label .. ": " .. (getter() and "ON" or "OFF")
    b.TextColor3 = Color3.fromRGB(240,240,240)
    b.Font = Enum.Font.GothamMedium; b.TextSize = 12
    b.Parent = frameFarm
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = b
    b.MouseButton1Click:Connect(function()
        setter(not getter())
        b.Text = label .. ": " .. (getter() and "ON" or "OFF")
        b.BackgroundColor3 = getter() and Color3.fromRGB(40,140,80) or Color3.fromRGB(45,49,64)
        setStatus(label..": "..(getter() and "ON" or "OFF"), getter(), false)
    end)
    farmY = farmY + 38
end

addFarmToggle("🥚 Auto Hatch",      function() return C.autoHatch end,      function(v) C.autoHatch = v end)
addFarmToggle("🎁 Auto Claim Chest",function() return C.autoClaim end,      function(v) C.autoClaim = v end)
addFarmToggle("🏃 Auto Treadmill",  function() return C.autoTreadmill end,  function(v) C.autoTreadmill = v end)
addFarmToggle("💰 Auto Sell Pet",   function() return C.autoSell end,       function(v) C.autoSell = v end)
addFarmToggle("⬆️ Auto Upgrade",    function() return C.autoUpgrade end,    function(v) C.autoUpgrade = v end)
addFarmToggle("🍖 Auto Feed Monster",function() return C.autoFeedMonster end,function(v) C.autoFeedMonster = v end)

--========== ANTI-TRAP / ANTI-FALL LOOP ==========
RunService.Heartbeat:Connect(function()
    if not alive() then return end
    local h = hrp()
    if not h then return end

    -- Anti-fall
    if C.noFall and h.Velocity.Y < -100 then
        h.Velocity = Vector3.new(h.Velocity.X, 0, h.Velocity.Z)
    end

    -- Anti-trap (push player away from traps)
    if C.antiTrap then
        local traps = scanTraps()
        for _, t in ipairs(traps) do
            local d = dist(h.Position, t.pos)
            if d < C.avoidRadius then
                local dir = (h.Position - t.pos).Unit
                h.Velocity = h.Velocity + dir * 50
            end
        end
    end
end)

--========== ALIVE LOOP ==========
task.spawn(function()
    while task.wait(3) do
        if not C.autoSteal then
            State.status = "idle"
        end
        -- Update status bar
        if C.autoSteal then
            setStatus(string.format("Steal: %d | Fail: %d | Last: %s",
                State.stolen, State.fails, State.lastEgg:sub(1,20)), false, false)
        end
    end
end)

print("========================================")
print("🥚 Steal An Egg + Multi Hub — LOADED")
print("========================================")
print("Hook Status:", hookStatus)
print("Auto Steal:", C.autoSteal)
print("Return To Base:", C.returnToBase)
print("========================================")