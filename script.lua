--[[
    ╔═══════════════════════════════════════════════════════════════════╗
    ║         STEAL AN EGG — Delta Hub v1 (Analysis-Based)             ║
    ║         Game ID: 1789906834                                      ║
    ║         Built from: Comprehensive game analysis                  ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  SUMBER ANALISIS:                                                 ║
    ║  • 3 source code berbeda (nahar, chao/Sơn Studio, rais)          ║
    ║  • Database 131 pet dengan income terpetakan                      ║
    ║  • Remote path lengkap: RF/EggWorld/* + RF/MonsterParasite/*    ║
    ║  • Struktur workspace: AreaEggSlotsClient + SmartPromptPart      ║
    ║  • Movement system: BodyVelocity fly + anti-ragdoll             ║
    ║  • Anti-cheat bypass: SetStateEnabled + no-fall velocity clamp  ║
    ╠═══════════════════════════════════════════════════════════════════╣
    ║  PERINGATAN: Gunakan akun alternatif. Risiko ban selalu ada.     ║
    ╚═══════════════════════════════════════════════════════════════════╝
]]

--========== SERVICES ==========
local Players        = game:GetService("Players")
local Workspace      = game:GetService("Workspace")
local RS             = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui        = game:GetService("CoreGui")
local LP              = Players.LocalPlayer

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
    
    -- Rarity filter (default: Secret+ Eternal+ Divine+)
    rarity = {
        Common    = false,
        Uncommon  = false,
        Rare      = false,
        Epic      = false,
        Legendary = false,
        Mythic    = false,
        Cosmic    = false,
        Secret    = true,
        Eternal   = true,
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
    espRange        = 3000,
    espShowUnknown  = true,
    espMinRarity    = 6,
    
    -- Farm
    autoHatch       = false,
    autoClaim       = false,
    autoTreadmill    = false,
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
    menuOpen   = false,
    moving     = false,
}

--========== REMOTE HANDLES ==========
local RemoteCache = {}

local function findRemote(name)
    -- Check cache first
    if RemoteCache[name] then return RemoteCache[name] end
    
    -- Search in RS.Packages.Networking (game's networking layer)
    local netPath = RS:FindFirstChild("Packages")
    if netPath then
        netPath = netPath:FindFirstChild("Networking")
        if netPath then
            local remote = netPath:FindFirstChild(name)
            if remote then
                RemoteCache[name] = remote
                return remote
            end
            -- Try path like "RF/EggWorld/AskFieldEggCarry"
            remote = netPath:FindFirstChild(name, true)
            if remote then
                RemoteCache[name] = remote
                return remote
            end
        end
    end
    
    -- Fallback: search all remotes
    for _, obj in pairs(RS:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) 
        and obj.Name:lower():find(name:lower()) then
            RemoteCache[name] = obj
            return obj
        end
    end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
        and obj.Name:lower():find(name:lower()) then
            RemoteCache[name] = obj
            return obj
        end
    end
    
    return nil
end

-- Key remotes
local function getAskFieldEggCarry()
    return findRemote("RF/EggWorld/AskFieldEggCarry")
        or findRemote("AskFieldEggCarry")
        or findRemote("AskFieldEgg")
end

local function getAskPlaceEgg()
    return findRemote("RF/EggWorld/AskPlaceEgg")
        or findRemote("AskPlaceEgg")
end

local function getAskFeed()
    return findRemote("RF/MonsterParasite/AskFeed")
        or findRemote("AskFeed")
end

local function getAskChestClaim()
    return findRemote("RF/MonsterParasite/AskChestClaim")
end

-- Fire server safe
local function fireSafe(remote, ...)
    if not remote then return false end
    local ok, err = pcall(function()
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        else
            return remote:FireServer(...)
        end
    end)
    return ok
end

-- Fire remote by keyword match
local function fireMatch(keywords, ...)
    local count = 0
    for _, obj in pairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nm = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if nm:find(kw:lower()) then
                    pcall(function()
                        if obj:IsA("RemoteFunction") then
                            obj:InvokeServer(...)
                        else
                            obj:FireServer(...)
                        end
                    end)
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

--========== UTILITY ==========
local function char()  return LP.Character end
local function hrp()   local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum()  local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h = hum(); return h and h.Health > 0 end
local function dist(a, b) return (a - b).Magnitude end
local function posOf(obj)
    if obj:IsA("BasePart") then return obj.Position end
    return obj.PrimaryPart and obj.PrimaryPart.Position or nil
end

-- Rarity order + colors
local RARITY_ORDER = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Mythic", "Cosmic", "Secret", "Eternal", "Divine"
}
local RARITY_COLOR = {
    Common    = Color3.fromRGB(150, 160, 175),
    Uncommon  = Color3.fromRGB(120, 220, 150),
    Rare      = Color3.fromRGB(90,  170, 255),
    Epic      = Color3.fromRGB(180, 130, 255),
    Legendary = Color3.fromRGB(255, 190, 80),
    Mythic    = Color3.fromRGB(255, 110, 200),
    Cosmic    = Color3.fromRGB(90,  230, 240),
    Secret    = Color3.fromRGB(255, 235, 130),
    Eternal   = Color3.fromRGB(200, 120, 255),
    Divine    = Color3.fromRGB(255, 255, 255),
}

-- Zone detection from X coordinate
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

-- Get player base position
local baseCache, baseCacheT = nil, -1e9
local function myBase()
    if tick() - baseCacheT < 5 then return baseCache end
    
    local plots = Workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            -- Check ownership
            local isMine = false
            for _, key in ipairs({"Owner","OwnerName","Player","PlayerName"}) do
                local o = plot:FindFirstChild(key)
                if o and o:IsA("ValueBase") and tostring(o.Value) == LP.Name then
                    isMine = true; break
                end
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
        
        -- Fallback: nearest spawn to player
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

--========== EGG SCANNING ==========
-- Known pet database (partial - top tiers)
local PET_DB = {
    -- Jungle+
    spider       = {Rarity="Mythic",    Income=22000,    Zone="Jungle"},
    tiger        = {Rarity="Mythic",    Income=28000,    Zone="Jungle"},
    kingsnake    = {Rarity="Secret",    Income=3500000,  Zone="Jungle"},
    -- Snow+
    yeti         = {Rarity="Secret",    Income=5000000,  Zone="Snow"},
    icedragon    = {Rarity="Eternal",   Income=65000000, Zone="Snow"},
    -- Volcano+
    phoenix      = {Rarity="Eternal",   Income=85000000, Zone="Volcano"},
    lavadragon   = {Rarity="Eternal",   Income=100000000,Zone="Volcano"},
    -- Abyss+
    kraken       = {Rarity="Secret",   Income=15000000, Zone="Abyss"},
    elmaja       = {Rarity="Eternal",   Income=130000000,Zone="Abyss"},
    -- Prehistoric+
    trex         = {Rarity="Secret",    Income=25000000, Zone="Prehistoric"},
    tralaledon   = {Rarity="Secret",    Income=32000000, Zone="Prehistoric"},
    mosasaurus   = {Rarity="Eternal",   Income=180000000,Zone="Prehistoric"},
    -- Cosmic+
    cosmicskeletonboss = {Rarity="Secret", Income=45000000, Zone="Cosmic"},
    cosmicdragon  = {Rarity="Secret",   Income=60000000, Zone="Cosmic"},
    eternallunardragon = {Rarity="Eternal", Income=250000000, Zone="Cosmic"},
    unicorn       = {Rarity="Divine",   Income=1000000000,Zone="Cosmic"},
    -- Cherry+
    kitsune       = {Rarity="Divine",   Income=1800000000,Zone="Cherry"},
    onitiger      = {Rarity="Eternal",  Income=600000000, Zone="Cherry"},
    stag          = {Rarity="Secret",   Income=145000000, Zone="Cherry"},
    -- Titan+
    gorillaking   = {Rarity="Eternal",  Income=880000000, Zone="Titan"},
    nightflame    = {Rarity="Divine",   Income=nil,       Zone="Titan"},
    mantaris      = {Rarity="Cosmic",   Income=11000000,  Zone="Titan"},
    rhinotaur     = {Rarity="Cosmic",   Income=17500000,  Zone="Titan"},
    mutantshark   = {Rarity="Secret",   Income=215000000, Zone="Titan"},
    bladehide     = {Rarity="Mythic",   Income=750000,    Zone="Titan"},
    spideron      = {Rarity="Legendary",Income=95000,     Zone="Titan"},
    crustacia     = {Rarity="Legendary",Income=130000,    Zone="Titan"},
    -- Mutation prefixes
    spiritbloom   = nil, -- stripped prefix
    rainbow       = nil,
    golden        = nil,
}

local function lookupPet(name)
    local n = name:lower():gsub("[^%a]", "")
    -- Strip mutation prefixes
    n = n:gsub("^spiritbloom", "")
    n = n:gsub("^rainbow", "")
    n = n:gsub("^golden", "")
    n = n:gsub("^bloom", "")
    n = n:gsub("^silver", "")
    
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

-- Main egg scanner
local function scanEggs()
    local out = {}
    local h = hrp()
    local base = myBase()
    local hPos = h and h.Position or Vector3.new(0,0,0)
    
    -- 1. AreaEggSlotsClient (slot telur game)
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
                    
                    -- Try database lookup
                    local dbEntry = lookupPet(slot.Name)
                    if dbEntry then
                        rar = dbEntry.Rarity
                        income = dbEntry.Income
                        zone = dbEntry.Zone or zone
                        petName = slot.Name:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return a:upper()..b end)
                    end
                    
                    -- Check attributes for rarity/name
                    local attrs = slot:GetAttributes()
                    for k, v in pairs(attrs or {}) do
                        if type(v) == "string" then
                            local db = lookupPet(v)
                            if db then
                                rar = db.Rarity
                                income = db.Income
                                petName = v
                            end
                        end
                    end
                    
                    -- Check if in my base
                    local inMyBase = false
                    if base then
                        local d = dist(pos, base)
                        if d < C.baseGuardRadius then inMyBase = true end
                    end
                    
                    -- Check if held by me
                    if slot.Parent == char() then inMyBase = true end
                    
                    -- Check if owned by other player
                    local inPlot, owned = false, false
                    local p = slot.Parent
                    while p and p ~= Workspace do
                        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then
                            local pl = Players:GetPlayerFromCharacter(p)
                            if pl and pl ~= LP then owned = true end
                        end
                        p = p.Parent
                    end
                    
                    -- If slot name has hex-like pattern, treat as generic zone egg
                    if not rar and slot.Name:match("^%x+$") and #slot.Name > 16 then
                        rar = "Rare" -- default
                    end
                    
                    if rar or isPar or isRare then
                        local d = dist(hPos, pos)
                        table.insert(out, {
                            obj    = slot,
                            part   = part,
                            pos    = pos,
                            rar    = rar,
                            income = income,
                            pet    = petName,
                            zone   = zone,
                            isParasite = isPar,
                            isRare = isRare,
                            dist   = d,
                            inMyBase = inMyBase,
                            owned  = owned,
                            uid    = slot.Name,
                        })
                    end
                end
            end
        end
    end
    
    -- 2. SmartPromptPart eggs (standalone spawn)
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("Hitbox") then
            -- Already handled above if in AreaEggSlotsClient
            local alreadyScanned = false
            for _, e in ipairs(out) do
                if e.obj == obj then alreadyScanned = true; break end
            end
            if not alreadyScanned then
                local part = obj.Hitbox
                if part then
                    local pos = part.Position
                    local d = dist(hPos, pos)
                    local isPar, isRare = isParasiteEgg(obj), isRareEgg(obj)
                    table.insert(out, {
                        obj       = obj,
                        part      = part,
                        pos       = pos,
                        rar       = nil,
                        income    = nil,
                        pet       = nil,
                        zone      = zoneOf(pos),
                        isParasite = isPar,
                        isRare    = isRare,
                        dist      = d,
                        inMyBase  = false,
                        owned     = false,
                        uid       = obj.Name,
                    })
                end
            end
        end
    end
    
    -- 3. Generic name scan
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("egg") then
            local alreadyScanned = false
            for _, e in ipairs(out) do
                if e.part == obj then alreadyScanned = true; break end
            end
            if not alreadyScanned then
                local pos = obj.Position
                local d = dist(hPos, pos)
                table.insert(out, {
                    obj    = obj,
                    part   = obj,
                    pos    = pos,
                    rar    = nil,
                    income = nil,
                    pet    = nil,
                    zone   = zoneOf(pos),
                    dist   = d,
                    inMyBase = false,
                    owned  = false,
                    uid    = obj.Name,
                })
            end
        end
    end
    
    return out
end

-- Trap/Hostile scanner
local function scanTraps()
    local out = {}
    for _, v in pairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if v:IsA("BasePart") or v:IsA("Model") then
            if n:find("trap") or n:find("spike") or n:find("mine")
            or n:find("snare") or n:find("bomb") then
                local p = posOf(v)
                if p then table.insert(out, {obj=v, pos=p}) end
            end
        end
    end
    return
