local S = {}
local page

local ok = pcall(require, "PZAPI/ModOptions")
if ok and PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:getOptions("PZHordeDirector")
        or PZAPI.ModOptions:create("PZHordeDirector", "PZ Horde Director")
    local function tick(key, label, default)
        if not page:getOption(key) then page:addTickBox(key, label, default, "") end
    end
    local function slider(key, label, min, max, step, default)
        if not page:getOption(key) then page:addSlider(key, label, min, max, step, default, "") end
    end
    tick("enabled", "Enable roaming hordes", true)
    slider("hordeCount", "Number of hordes", 1, 8, 1, 3)
    slider("maxSize", "Maximum zombies per squad", 4, 64, 2, 16)
    slider("interval", "Spawn interval, seconds", 10, 300, 10, 45)
    slider("radius", "Spawn radius, tiles", 4, 30, 1, 14)
    tick("targetPlayers", "Hunt players", true)
    tick("targetNPCs", "Hunt NPCs", true)
    tick("infectHouses", "Infect entered houses", true)
    tick("climbFences", "Zombies may cross fences", true)
    tick("climbRopes", "Zombies may use ropes", false)
    tick("crawl", "Some zombies crawl", false)
    tick("edgeReset", "Respawn squad at map edge when wiped", true)
end

local function read(key, fallback)
    local option = page and page:getOption(key)
    if option then
        local okv, value = pcall(function() return option:getValue() end)
        if okv and value ~= nil then return value end
    end
    return fallback
end

function S.enabled() return read("enabled", true) == true end
function S.squadCount()
    return tonumber(read("hordeCount", read("squadCount", 3))) or 3
end
function S.maxSize() return tonumber(read("maxSize", 16)) or 16 end
function S.interval() return tonumber(read("interval", 45)) or 45 end
function S.radius() return tonumber(read("radius", 14)) or 14 end
function S.targetPlayers() return read("targetPlayers", true) == true end
function S.targetNPCs() return read("targetNPCs", true) == true end
function S.infectHouses() return read("infectHouses", true) == true end
function S.climbFences() return read("climbFences", true) == true end
function S.climbRopes() return read("climbRopes", false) == true end
function S.crawl() return read("crawl", false) == true end
function S.edgeReset() return read("edgeReset", true) == true end

return S
