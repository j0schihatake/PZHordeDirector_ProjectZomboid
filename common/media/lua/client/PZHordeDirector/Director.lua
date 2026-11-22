-- PZ Horde Director: virtual horde squads with search, infection and focus states.
local S = require "PZHordeDirector/Settings"

local KEY = "PZHordeDirector"
local TICK_MS = 5000
local lastTick = 0

local function now() return getTimestampMs() end
local function rnd(n) return ZombRand(n) end
local function player() return getSpecificPlayer(0) end

local function store()
    local p = player()
    if not p then return nil end
    local md = p:getModData()
    if not md[KEY] then md[KEY] = { squads = {}, infected = {}, focusNpc = nil, attack = false } end
    local state = md[KEY]
    state.squads = state.squads or {}
    state.infected = state.infected or {}
    return state
end

local function newSquad(i, p)
    return {
        id = i, x = p:getX() + rnd(200) - 100, y = p:getY() + rnd(200) - 100,
        z = 0, size = 2, spawned = 0, cooldown = 0, mode = "roam",
        roamX = nil, roamY = nil, roamUntil = 0,
    }
end

local function edgePoint(p)
    local side = rnd(4)
    local d = 220 + rnd(120)
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
    if not x or not y or count <= 0 then return 0 end
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
            if S.crawl() and rnd(100) < S.crawlerPercent() then pcall(function() z:setCrawler(true) end) end
            if S.climbFences() then pcall(function() z:setCanWalk(true) end) end
        end
    end
    return n
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


local function roadPathStep(s, tx, ty)
    if not S.pathfinding() then return nil end
    local z = math.floor(s.z or 0)
    local sx, sy = math.floor(s.x), math.floor(s.y)
    if not roadAt(sx, sy, z) then return nil end
    -- If the target is off-road, aim for the closest road tile around it.
    local gx, gy = math.floor(tx), math.floor(ty)
    if not roadAt(gx, gy, z) then
        local found = false
        for r = 1, 3 do
            for ox = -r, r do
                for oy = -r, r do
                    if not found and roadAt(gx + ox, gy + oy, z) then
                        gx, gy, found = gx + ox, gy + oy, true
                    end
                end
            end
            if found then break end
        end
        if not found then return nil end
    end
    local startKey = sx .. ':' .. sy
    local goalKey = gx .. ':' .. gy
    local open = { startKey }
    local inOpen = { [startKey] = true }
    local came, gScore, fScore = {}, { [startKey] = 0 }, { [startKey] = math.abs(sx-gx)+math.abs(sy-gy) }
    local nodes = 0
    while #open > 0 and nodes < 300 do
        nodes = nodes + 1
        local best, bestF = 1, nil
        for i, key in ipairs(open) do
            local fv = fScore[key] or 1e9
            if not bestF or fv < bestF then best, bestF = i, fv end
        end
        local current = table.remove(open, best); inOpen[current] = nil
        if current == goalKey then
            local step = current
            while came[step] and came[step] ~= startKey do step = came[step] end
            local nx, ny = step:match('^(-?%d+):(-?%d+)$')
            return tonumber(nx), tonumber(ny)
        end
        local cx, cy = current:match('^(-?%d+):(-?%d+)$'); cx, cy = tonumber(cx), tonumber(cy)
        for ox = -1, 1 do
            for oy = -1, 1 do
                if ox ~= 0 or oy ~= 0 then
                    local nx, ny = cx + ox, cy + oy
                    if roadAt(nx, ny, z) then
                        local key = nx .. ':' .. ny
                        local tentative = (gScore[current] or 1e9) + ((ox == 0 or oy == 0) and 1 or 1.414)
                        if tentative < (gScore[key] or 1e9) then
                            came[key] = current; gScore[key] = tentative
                            fScore[key] = tentative + math.abs(nx-gx) + math.abs(ny-gy)
                            if not inOpen[key] then open[#open+1] = key; inOpen[key] = true end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function stepToward(s, tx, ty)
    if not tx or not ty then return end
    for _ = 1, 2 do
        local dx, dy = tx - s.x, ty - s.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= 1 then return end
        local nx, ny = s.x + dx / distance, s.y + dy / distance
        local ax, ay = roadPathStep(s, tx, ty)
        if ax and ay then
            s.x, s.y = ax, ay
        else
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
        if bestX then s.x, s.y = bestX, bestY else s.x, s.y = nx, ny end
        end
    end
end

local function dist2(s, o)
    local dx, dy = s.x - o:getX(), s.y - o:getY()
    return dx * dx + dy * dy
end

local function nearestNpc(s)
    if not S.targetNPCs() then return nil end
    local lists = {}
    pcall(function() lists[#lists+1] = getCell():getSurvivorList() end)
    pcall(function() lists[#lists+1] = getCell():getRemoteSurvivorList() end)
    local best, bestD = nil, nil
    local vision = S.visionRadius() * S.visionRadius()
    for _, survivors in ipairs(lists) do
        if survivors then
            for i = 0, survivors:size() - 1 do
                local npc = survivors:get(i)
                local dead = false
                pcall(function() dead = npc:isDead() end)
                if not dead then
                    local d = dist2(s, npc)
                    if d <= vision and (not bestD or d < bestD) then best, bestD = npc, d end
                end
            end
        end
    end
    return best
end

local function buildingAt(x, y, z)
    local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
    if not square then return nil end
    local building = nil
    pcall(function() building = square:getBuilding() end)
    return building
end

local function buildingKey(building, x, y)
    local key = nil
    pcall(function() key = building:getID() end)
    if key == nil then key = string.format('%d:%d', math.floor(x / 10), math.floor(y / 10)) end
    return tostring(key)
end

local function infect(state, s, x, y, count)
    local building = buildingAt(x, y, s.z)
    if not building then return false end
    -- Require a real room/interior, not just an outdoor building footprint.
    local square = getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(s.z or 0))
    local room = nil
    if square then pcall(function() room = square:getRoom() end) end
    if not room then return false end
    local key = buildingKey(building, x, y)
    local first = not state.infected[key]
    state.infected[key] = { x = x, y = y }
    spawnAt(x, y, count or 1, s.id)
    return first
end

local function infectNearby(state, s, radius, count)
    for r = 0, radius do
        for ox = -r, r do
            for oy = -r, r do
                if math.abs(ox) == r or math.abs(oy) == r then
                    local building = buildingAt(s.x + ox, s.y + oy, s.z)
                    if building then
                        return infect(state, s, s.x + ox, s.y + oy, count)
                    end
                end
            end
        end
    end
    return false
end

local function nearbyInfected(state, p, radius)
    local n, r2 = 0, radius * radius
    for _, point in pairs(state.infected) do
        local dx, dy = point.x - p:getX(), point.y - p:getY()
        if dx * dx + dy * dy <= r2 then n = n + 1 end
    end
    return n
end

local function chooseRoam(s, p)
    if not s.roamX or now() >= (s.roamUntil or 0) then
        local r = S.roamRadius()
        s.roamX = p:getX() + rnd(r * 2) - r
        s.roamY = p:getY() + rnd(r * 2) - r
        s.roamUntil = now() + 25000 + rnd(35000)
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

    -- If the squad that found an NPC is gone, release the global focus.
    if state.focusNpc then
        local dead = false
        pcall(function() dead = state.focusNpc:isDead() end)
        local focusAlive = false
        for _, s in ipairs(state.squads) do
            if s.id == state.focusSquad and alive(s.id) > 0 then focusAlive = true end
        end
        if dead or not focusAlive then
            state.focusNpc = nil
            state.focusSquad = nil
        end
    end

    local nearHouses = nearbyInfected(state, p, S.infectRadius())
    if nearHouses >= S.housesToInfect() then state.attack = true end
    if state.attack and p:isDead() then state.attack = false end

    for _, s in ipairs(state.squads) do
        local living = alive(s.id)
        if living == 0 and s.spawned > 0 then
            if S.edgeReset() then
                s.x, s.y = edgePoint(p)
                s.size = 1
                s.spawned = 0
                s.mode = 'roam'
                s.cooldown = t + 15000
                s.roamX, s.roamY, s.roamUntil = nil, nil, 0
            end
        end

        -- Detection. Without a detection a squad only searches and infects.
        local npc = nearestNpc(s)
        if npc and not state.focusNpc then
            state.focusNpc = npc
            state.focusSquad = s.id
            s.mode = 'npc'
        end
        if state.attack then
            s.mode = 'player'
        elseif state.focusNpc then
            s.mode = 'npc'
        elseif dist2(s, p) <= S.visionRadius() * S.visionRadius() then
            s.mode = 'player'
        elseif s.mode == 'player' and dist2(s, p) > (S.visionRadius() * 1.8) ^ 2 then
            s.mode = 'roam'
        end

        if s.mode == 'npc' and state.focusNpc then
            s.targetX, s.targetY = state.focusNpc:getX(), state.focusNpc:getY()
            if s.id == state.focusSquad then
                if not infect(state, s, s.targetX, s.targetY, 2) then
                    infectNearby(state, s, 8, 2)
                end
            end
        elseif s.mode == 'player' then
            s.targetX, s.targetY = p:getX(), p:getY()
        else
            s.mode = 'roam'
            chooseRoam(s, p)
            s.targetX, s.targetY = s.roamX, s.roamY
            infectNearby(state, s, 8, 1)
        end

        stepToward(s, s.targetX, s.targetY)

        if t >= s.cooldown then
            s.size = math.min(S.maxSize(), (s.size or 1) + 1)
            local wanted = math.min(S.maxSize(), s.size)
            local countSpawn = math.max(1, math.min(6, wanted - living))
            spawnAt(s.x, s.y, countSpawn, s.id)
            s.spawned = s.spawned + countSpawn
            s.cooldown = t + S.interval() * 1000
            if S.infectHouses() then infectNearby(state, s, 8, 1) end
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
            if not s or not s.squads then md[KEY] = { squads = {}, infected = {}, attack = false } end
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
