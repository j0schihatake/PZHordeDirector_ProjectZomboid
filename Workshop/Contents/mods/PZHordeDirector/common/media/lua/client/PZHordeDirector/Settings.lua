local S = {}
local page

local function tr(key, fallback)
    local ok, value = pcall(getText, key)
    if ok and value and value ~= key then return value end
    return fallback
end

local ok = pcall(require, "PZAPI/ModOptions")
if ok and PZAPI and PZAPI.ModOptions then
    page = PZAPI.ModOptions:getOptions("PZHordeDirector")
        or PZAPI.ModOptions:create("PZHordeDirector", tr("UI_PZHordeDirector_Title", "PZ Horde Director"))
    local function tick(key, label, default)
        if not page:getOption(key) then page:addTickBox(key, label, default, "") end
    end
    local function slider(key, label, min, max, step, default)
        if not page:getOption(key) then page:addSlider(key, label, min, max, step, default, "") end
    end
    tick("enabled", tr("UI_PZHordeDirector_Enabled", "Enable roaming hordes"), true)
    slider("hordeCount", tr("UI_PZHordeDirector_HordeCount", "Number of hordes"), 1, 32, 1, 8)
    slider("maxSize", tr("UI_PZHordeDirector_MaxSize", "Maximum zombies per squad"), 4, 64, 2, 16)
    slider("interval", tr("UI_PZHordeDirector_Interval", "Spawn interval"), 10, 300, 10, 45)
    slider("radius", tr("UI_PZHordeDirector_Radius", "Spawn radius"), 4, 30, 1, 14)
    slider("visionRadius", tr("UI_PZHordeDirector_VisionRadius", "Vision radius"), 8, 80, 1, 30)
    slider("roamRadius", tr("UI_PZHordeDirector_RoamRadius", "Roam radius"), 100, 1200, 50, 500)
    slider("infectRadius", tr("UI_PZHordeDirector_InfectRadius", "House search radius"), 20, 120, 5, 60)
    slider("housesToInfect", tr("UI_PZHordeDirector_HousesToInfect", "Houses to infect near player"), 1, 10, 1, 3)
    slider("crawlerPercent", tr("UI_PZHordeDirector_CrawlerPercent", "Crawler chance, %"), 0, 100, 5, 12)
    tick("targetPlayers", tr("UI_PZHordeDirector_TargetPlayers", "Hunt players"), true)
    tick("targetNPCs", tr("UI_PZHordeDirector_TargetNPCs", "Hunt NPCs"), true)
    tick("infectHouses", tr("UI_PZHordeDirector_InfectHouses", "Infect entered houses"), true)
    tick("climbFences", tr("UI_PZHordeDirector_ClimbFences", "Zombies cross fences"), true)
    tick("climbRopes", tr("UI_PZHordeDirector_ClimbRopes", "Zombies use ropes"), false)
    tick("crawl", tr("UI_PZHordeDirector_Crawl", "Some zombies crawl"), false)
    tick("pathfinding", tr("UI_PZHordeDirector_Pathfinding", "Use road pathfinding"), true)
    tick("edgeReset", tr("UI_PZHordeDirector_EdgeReset", "Respawn at map edge after wipe"), true)
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
function S.squadCount() return tonumber(read("hordeCount", read("squadCount", 3))) or 3 end
function S.maxSize() return tonumber(read("maxSize", 16)) or 16 end
function S.interval() return tonumber(read("interval", 45)) or 45 end
function S.radius() return tonumber(read("radius", 14)) or 14 end
function S.visionRadius() return tonumber(read("visionRadius", 30)) or 30 end
function S.roamRadius() return tonumber(read("roamRadius", 500)) or 500 end
function S.infectRadius() return tonumber(read("infectRadius", 60)) or 60 end
function S.housesToInfect() return tonumber(read("housesToInfect", 3)) or 3 end
function S.crawlerPercent() return tonumber(read("crawlerPercent", 12)) or 12 end
function S.targetPlayers() return read("targetPlayers", true) == true end
function S.targetNPCs() return read("targetNPCs", true) == true end
function S.infectHouses() return read("infectHouses", true) == true end
function S.climbFences() return read("climbFences", true) == true end
function S.climbRopes() return read("climbRopes", false) == true end
function S.crawl() return read("crawl", false) == true end
function S.pathfinding() return read("pathfinding", true) == true end
function S.edgeReset() return read("edgeReset", true) == true end

return S
