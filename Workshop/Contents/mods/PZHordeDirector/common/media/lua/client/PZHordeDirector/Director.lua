-- PZ Horde Director: lightweight virtual squads that seed vanilla zombie swarms.
local S = require "PZHordeDirector/Settings"

local KEY = "PZHordeDirector"
local TICK_MS = 5000
local lastTick = 0

local function now() return getTimestampMs() end
local function rnd(n) return ZombRand(n) end

local function player()
    return getSpecificPlayer(0)
end

local function store()
    local p = player()
    if not p then return nil end
    local md = p:getModData()
    if not md[KEY] then md[KEY] = { squads = {} } end
    return md[KEY]
end

local function newSquad(i, p)
    return {
        id = i, x = p:getX() + rnd(80) - 40, y = p:getY() + rnd(80) - 40,
        z = 0, size = 4, spawned = 0, cooldown = 0, state = "roam",
        targetX = p:getX(), targetY = p:getY(),
    }
end

local function edgePoint(p)
    local side = rnd(4)
    local d = 180 + rnd(80)
    if side == 0 then return p:getX() + d, p:getY() end
    if side == 1 then return p:getX() - d, p:getY() end
    if side == 2 then return p:getX(), p:getY() + d end
    return p:getX(), p:getY() - d
end

local function markNear(x, y, group)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and not z:isDead() then
            local dx, dy = z:getX() - x, z:getY() - y
            if dx * dx + dy * dy <= 144 then
                local md = z:getModData()
                if not md.hordeGroup then md.hordeGroup = group end
            end
        end
    end
end

local function spawnAt(x, y, count, group)
    if not x or not y then return 0 end
    local ok = pcall(function()
        getWorld():CreateSwarm(math.floor(x), math.floor(y), 1, 1, count)
    end)
    if not ok then
        pcall(function() IsoWorld.instance:CreateSwarm(math.floor(x), math.floor(y), 1, 1, count) end)
    end
    markNear(x, y, group)
    return count
end

local function alive(group)
    local n = 0
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and not z:isDead() and z:getModData().hordeGroup == group then
            n = n + 1
            if S.crawl() and rnd(100) < 12 then pcall(function() z:setCrawler(true) end) end
            if S.climbFences() then pcall(function() z:setCanWalk(true) end) end
            if S.climbRopes() then pcall(function() z:setCanCrawlUnderVehicle(true) end) end
        end
    end
    return n
end

local function targetFor(s, p, focus)
    if focus then
        local dead = false
        pcall(function() dead = focus:isDead() end)
        if not dead then
            s.targetX, s.targetY = focus:getX(), focus:getY()
            s.target = focus
            return
        end
    end
    if S.targetNPCs() then
        local survivors = getCell():getSurvivorList()
        if survivors then
            local best, bestD
            for i = 0, survivors:size() - 1 do
                local npc = survivors:get(i)
                local dead = false
                pcall(function() dead = npc:isDead() end)
                if not dead then
                    local dx, dy = npc:getX() - p:getX(), npc:getY() - p:getY()
                    local d = dx * dx + dy * dy
                    if not bestD or d < bestD then best, bestD = npc, d end
                end
            end
            if best then
                s.targetX, s.targetY = best:getX(), best:getY()
                s.target = best
                return
            end
        end
    end
    if S.targetPlayers() then
        s.targetX, s.targetY = p:getX(), p:getY()
        s.target = p
    end
end


local function roadAt(x, y, z)
    local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
    if not square then return false end
    local floor = nil
    pcall(function() floor = square:getFloor() end)
    if not floor then return false end
    local name = ''
    pcall(function() name = floor:getSpriteName() or floor:getName() or '' end)
    name = string.lower(tostring(name))
    return string.find(name, 'street', 1, true) ~= nil
        or string.find(name, 'road', 1, true) ~= nil
        or string.find(name, 'asphalt', 1, true) ~= nil
        or string.find(name, 'blends_street', 1, true) ~= nil
end

local function stepToward(s, tx, ty)
    for step = 1, 2 do
        local dx, dy = tx - s.x, ty - s.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 1 then return end
        local nx, ny = s.x + dx / distance, s.y + dy / distance
        -- Prefer an adjacent road tile; the horde should use streets, not cut through fields.
        local bestX, bestY, bestD = nil, nil, nil
        for ox = -1, 1 do
            for oy = -1, 1 do
                if ox ~= 0 or oy ~= 0 then
                    local cx, cy = s.x + ox, s.y + oy
                    if roadAt(cx, cy, s.z) then
                        local ddx, ddy = tx - cx, ty - cy
                        local d = ddx * ddx + ddy * ddy
                        if not bestD or d < bestD then bestX, bestY, bestD = cx, cy, d end
                    end
                end
            end
        end
        if bestX then
            s.x, s.y = bestX, bestY
        else
            s.x, s.y = nx, ny
        end
    end
end

local function tick()
    if isClient() or not S.enabled() then return end
    local p = player()
    if not p or p:isDead() then return end
    local state = store()
    if not state then return end
    local count = math.max(1, math.min(8, S.squadCount()))
    while #state.squads < count do state.squads[#state.squads + 1] = newSquad(#state.squads + 1, p) end
    for i = count + 1, #state.squads do state.squads[i] = nil end
    local t = now()
    if state.focus then
        local dead = false
        pcall(function() dead = state.focus:isDead() end)
        if dead then state.focus = nil end
    end
    for _, s in ipairs(state.squads) do
        if not state.focus and s.target and instanceof(s.target, "IsoSurvivor") then
            local dead = false
            pcall(function() dead = s.target:isDead() end)
            if not dead then state.focus = s.target end
        end
    end
    for _, s in ipairs(state.squads) do
        local living = alive(s.id)
        if living == 0 and s.spawned > 0 then
            if S.edgeReset() then
                s.x, s.y = edgePoint(p)
                s.size = 1
                s.spawned = 0
                s.state = "regroup"
                s.cooldown = t + 15000
            else
                s.state = "regroup"
            end
        end
        s.targetX, s.targetY = p:getX(), p:getY()
        targetFor(s, p, state.focus)
        stepToward(s, s.targetX or p:getX(), s.targetY or p:getY())
        if t >= s.cooldown then
            s.size = math.min(S.maxSize(), (s.size or 1) + 1)
            local wanted = math.min(S.maxSize(), s.size)
            local countSpawn = math.max(1, math.min(6, wanted - living))
            spawnAt(s.x, s.y, countSpawn, s.id)
            s.spawned = s.spawned + countSpawn
            s.cooldown = t + S.interval() * 1000
            if S.infectHouses() then
                local square = getCell():getGridSquare(math.floor(s.x), math.floor(s.y), s.z or 0)
                local building = nil
                if square then pcall(function() building = square:getBuilding() end) end
                if building then spawnAt(s.x, s.y, 2, s.id) end
            end
        end
    end
    p:getModData()[KEY] = state
end

local function install()
    Events.OnGameStart.Add(function()
        lastTick = 0
        local p = player()
        if p then
            local md = p:getModData()
            local s = md[KEY]
            -- Old squads are intentionally not trusted after a reload.
            if not s or not s.squads then md[KEY] = { squads = {} } end
        end
        print("[PZHordeDirector] loaded")
    end)
    Events.OnPlayerUpdate.Add(function()
        local t = now()
        if t - lastTick < TICK_MS then return end
        lastTick = t
        local ok, err = pcall(tick)
        if not ok then print("[PZHordeDirector] tick error " .. tostring(err)) end
    end)
end

Events.OnGameStart.Add(install)
