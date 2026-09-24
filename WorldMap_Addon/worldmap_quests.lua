-- WorldMap_Addon/worldmap_quests.lua
--
-- v2.1: puente de SOLO LECTURA con LOTRO_Quest_Assistant (pedido del
-- usuario: "Mapa + Quest Assistant"). v2.1.1: solo las misiones ACTIVAS
-- (el usuario no quiere ver completadas ni puntos de recoleccion). Al pasar
-- el mouse por una zona, el cartel dice cuantas misiones activas tienes
-- ahi; con un clic (sin arrastrar) se abre la lista de esas activas, y un
-- clic en una mision la abre en la ventana de Quest Assistant.
--
-- Como se conectan los dos addons: ninguno de los dos declara Apartment en
-- su .plugin, asi que comparten el mismo entorno global de Lua. Este
-- archivo solo LEE las tablas globales que Quest Assistant ya publica
-- (QuestDB.quests, QuestStateManager, QuestLocResolver) y llama a MainWindow:FocusQuest,
-- el MISMO punto de entrada que usa su propio rastreador (QuestTrackerHUD).
-- Nunca escribe nada en Quest Assistant ni guarda nada propio. Si Quest
-- Assistant no esta cargado, todo esto queda apagado en silencio y el mapa
-- funciona exactamente igual que antes.
--
-- Las misiones de la base de Quest Assistant traen la zona en INGLES
-- (quest.zone, p.ej. "The Trollshaws", "Croftlands") y a veces un area mas
-- fina (quest.area). Las tablas de abajo las asignan a las 59 zonas del
-- mapa por su nombre_original. Una zona de la base que no esta en la tabla
-- (eventos, festivales, regiones que el mapa no dibuja) simplemente no se
-- cuenta en ninguna zona -- mejor no contar que contar mal.

_G.WorldMapAddon = _G.WorldMapAddon or {}
WorldMapAddon.Quests = WorldMapAddon.Quests or {}
local Q = WorldMapAddon.Quests

-- ---------------------------------------------------------------------
-- Normalizacion de nombres: minusculas, sin tildes (UTF-8), sin "the "
-- inicial y sin espacios sobrantes. Se aplica a AMBOS lados (base de
-- misiones, MoorMap y las claves de estas tablas).
-- ---------------------------------------------------------------------
local ACCENTS = {
    ["\195\161"] = "a", ["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a",
    ["\195\169"] = "e", ["\195\168"] = "e", ["\195\170"] = "e", ["\195\171"] = "e",
    ["\195\173"] = "i", ["\195\172"] = "i", ["\195\174"] = "i", ["\195\175"] = "i",
    ["\195\179"] = "o", ["\195\178"] = "o", ["\195\180"] = "o", ["\195\182"] = "o",
    ["\195\186"] = "u", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
    ["\195\129"] = "a", ["\195\137"] = "e", ["\195\141"] = "i", ["\195\147"] = "o",
    ["\195\154"] = "u", ["\195\155"] = "u", ["\195\130"] = "a", ["\195\177"] = "n",
}

local function Norm(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local s = string.lower(text)
    s = s:gsub("\195[\128-\191]", function(ch) return ACCENTS[ch] or ch end)
    s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    s = s:gsub("^the ", "")
    if s == "" then
        return nil
    end
    return s
end
Q.Norm = Norm

-- zona de la base de misiones (quest.zone) -> nombre_original del mapa
local BY_ZONE = {
    ["bree-land"] = "Bree-land",
    ["shire"] = "The Shire",
    ["ered luin"] = "Ered Luin",
    ["evendim"] = "Evendim",
    ["north downs"] = "North Downs",
    ["lone-lands"] = "Lone-lands",
    ["trollshaws"] = "Trollshaws",
    ["misty mountains"] = "Misty Mountains",
    ["angmar"] = "Angmar",
    ["forochel"] = "Forochel",
    ["cardolan"] = "Cardolan",
    ["eregion"] = "Eregion",
    ["moria"] = "Moria",
    ["lothlorien"] = "Lothlorien",
    ["mirkwood"] = "Mirkwood",
    ["enedwaith"] = "Enedwaith",
    ["dunland"] = "Dunland",
    ["swanfleet"] = "Swanfleet",
    ["great river"] = "Great River",
    ["vales of anduin"] = "Vales of Anduin",
    ["wildermore"] = "Wildermore",
    ["wold"] = "East Rohan",
    ["croftlands"] = "East Rohan",
    ["eastfold"] = "East Rohan",
    ["entwash"] = "East Rohan",
    ["rohan - eastemnet"] = "East Rohan",
    ["westfold"] = "West Rohan",
    ["rohan - westemnet"] = "West Rohan",
    ["western gondor"] = "Western Gondor",
    ["belfalas & dor-en-ernil"] = "Western Gondor",
    ["ringlo vale"] = "Western Gondor",
    ["central gondor"] = "Central Gondor",
    ["lebennin"] = "Central Gondor",
    ["lossarnach"] = "Central Gondor",
    ["eastern gondor"] = "Eastern Gondor",
    ["osgiliath"] = "Eastern Gondor",
    ["king's gondor"] = "King's Gondor",
    ["anfalas"] = "Outer Gondor",
    ["pinnath gelin"] = "Outer Gondor",
    ["anorien"] = "Old Anorien",
    ["old anorien"] = "Old Anorien",
    ["anorien (after battle)"] = "Old Anorien",
    ["far anorien"] = "Far Anorien",
    ["ithilien"] = "North Ithilien",
    ["wastes"] = "The Wastes",
    ["mordor"] = "Plateau of Gorgoroth",
    ["lhingris"] = "Plateau of Gorgoroth",
    ["agarnaith"] = "Plateau of Gorgoroth",
    ["imlad morgul"] = "Morgul Vale",
    ["mordor besieged"] = "Mordor Besieged",
    ["strongholds of the north"] = "Eryn Lasgalen and the Dale-lands",
    ["erebor"] = "Eryn Lasgalen and the Dale-lands",
    ["dwarf-holds"] = "Ered Mithrin and Withered Heath",
    ["gundabad"] = "Gundabad",
    ["elderslade"] = "Elderslade",
    ["wells of langflood"] = "Wells of Langflood",
    ["tales of yore: azanulbizar"] = "Azanulbizar",
    ["ettenmoors"] = "Ettenmoors (PvMP)",
    ["shield isles"] = "The Shield Isles",
    ["umbar"] = "Cape of Umbar",
    ["umbar-mokh"] = "Cape of Umbar",
    ["mur ghala: pahar hatokali"] = "Pahar Hatokali",
    ["mur ghala: kighan"] = "M\195\187r Ghala",
    ["kighan, the shornvale"] = "M\195\187r Ghala",
    ["restoring mur ghala"] = "M\195\187r Ghala",
    ["mur ghala instances"] = "M\195\187r Ghala",
    ["mission: mur ghala"] = "M\195\187r Ghala",
    ["sug nidar, the fearwater"] = "Sug Nidar",
}

-- area (quest.area) que manda sobre la zona, SOLO dentro de esa zona de
-- la base (el campo area trae ruido: p.ej. misiones de Bree con area
-- "Eastfold"), para las regiones que el mapa parte en dos
local BY_ZONE_AREA = {
    ["shire"] = { ["yondershire"] = "The Yondershire" },
    ["bree-land"] = { ["wildwood"] = "The Wildwood" },
    ["trollshaws"] = { ["angle of mitheithel"] = "The Angle of Mitheithel" },
    ["entwash"] = { ["broadacres"] = "West Rohan" },
    ["dunland"] = {
        ["nan curunir"] = "Nan Curunir",
        ["isengard"] = "Nan Curunir",
        ["isengard depths"] = "Nan Curunir",
    },
    ["rohan - westemnet"] = {
        ["nan curunir"] = "Nan Curunir",
        ["isengard"] = "Nan Curunir",
        ["isengard depths"] = "Nan Curunir",
    },
    ["wastes"] = { ["dead marshes"] = "Dead Marshes" },
    ["dwarf-holds"] = {
        ["ironfold"] = "Iron Hills",
        ["jarnfast"] = "Iron Hills",
        ["thikil-gundu, the steel keep"] = "Iron Hills",
    },
}

-- ---------------------------------------------------------------------
-- Acceso a Quest Assistant (todo opcional)
-- ---------------------------------------------------------------------

function Q.Available()
    return type(_G.QuestDB) == "table" and type(_G.QuestDB.quests) == "table"
        and type(_G.QuestStateManager) == "table"
end

-- zona del mapa (nombre_original) de una mision, o nil
function Q.ZoneOfQuest(quest)
    if type(quest) ~= "table" then
        return nil
    end
    local zoneKey = Norm(quest.zone)
    if zoneKey == nil then
        return nil
    end
    local areaKey = Norm(quest.area)
    if areaKey ~= nil then
        local king = areaKey:match("%(king's gondor%)$")
        if king ~= nil then
            return "King's Gondor"
        end
        local overrides = BY_ZONE_AREA[zoneKey]
        if overrides ~= nil and overrides[areaKey] ~= nil then
            return overrides[areaKey]
        end
    end
    return BY_ZONE[zoneKey]
end

-- indice nombre_original -> { ndx, ndx, ... } armado UNA vez (la base no
-- cambia durante la partida; ~15.000 misiones, se recorre una sola vez al
-- primer uso, no al cargar el addon)
function Q.BuildIndex()
    if Q.index ~= nil then
        return Q.index
    end
    if not Q.Available() then
        return nil
    end
    local index = {}
    for ndx, quest in pairs(QuestDB.quests) do
        local zoneName = Q.ZoneOfQuest(quest)
        if zoneName ~= nil then
            local list = index[zoneName]
            if list == nil then
                list = {}
                index[zoneName] = list
            end
            list[#list + 1] = ndx
        end
    end
    Q.index = index
    return index
end

local function QuestState(ndx)
    local ok, state = pcall(QuestStateManager.GetQuestState, ndx)
    if ok then
        return state
    end
    return "AVAILABLE"
end

-- v2.1.1: solo interesan las misiones ACTIVAS (pedido del usuario: sin
-- completadas ni puntos de recoleccion). v2.2: se recorren directamente
-- las activas de QuestStateManager (unas pocas) en vez de las ~15.000
-- misiones de la base -- asi el conteo es barato y se puede refrescar
-- seguido para las marcas doradas del mapa.
local function ActiveNdxList()
    local st = QuestStateManager.State
    local list = {}
    if type(st) ~= "table" or type(st.active) ~= "table" then
        return list
    end
    for ndx in pairs(st.active) do
        if QuestState(ndx) == "ACTIVE" then
            list[#list + 1] = ndx
        end
    end
    return list
end

local function QuestByNdx(ndx)
    return QuestDB.quests[ndx] or QuestDB.quests[tonumber(ndx) or -1]
end

-- { [nombre_original] = cantidad de misiones activas }
function Q.ActiveCounts()
    if not Q.Available() then
        return nil
    end
    local counts = {}
    for _, ndx in ipairs(ActiveNdxList()) do
        local zoneName = Q.ZoneOfQuest(QuestByNdx(ndx))
        if zoneName ~= nil then
            counts[zoneName] = (counts[zoneName] or 0) + 1
        end
    end
    return counts
end

-- v2.4: tipo de grupo de una mision segun Quest Assistant (GroupQuestDB,
-- tamaño oficial del juego): "raid" = incursion (12+), "dungeon" =
-- mazmorra o instancia de grupo (3/6). Escaramuzas, batallas epicas y
-- misiones de grupo en zona abierta no cuentan como mazmorra. nil = no es
-- de grupo o Quest Assistant no tiene el dato.
function Q.GroupKind(quest)
    local GQ = _G.GroupQuest
    if quest == nil or type(GQ) ~= "table" or type(GQ.Get) ~= "function" then
        return nil
    end
    local ok, g = pcall(GQ.Get, quest)
    if not ok or type(g) ~= "table" then
        return nil
    end
    if g.s == "R" then
        return "raid"
    end
    if g.k == "inst" or g.k == "pe" then
        return "dungeon"
    end
    return nil
end

-- { [nombre_original] = { count = n, dungeon = bool, raid = bool } }
function Q.ActiveInfo()
    if not Q.Available() then
        return nil
    end
    local info = {}
    for _, ndx in ipairs(ActiveNdxList()) do
        local quest = QuestByNdx(ndx)
        local zoneName = Q.ZoneOfQuest(quest)
        if zoneName ~= nil then
            local z = info[zoneName]
            if z == nil then
                z = { count = 0, dungeon = false, raid = false }
                info[zoneName] = z
            end
            z.count = z.count + 1
            local kind = Q.GroupKind(quest)
            if kind == "raid" then
                z.raid = true
            elseif kind == "dungeon" then
                z.dungeon = true
            end
        end
    end
    return info
end

function Q.Stats(zone)
    if zone == nil then
        return nil
    end
    local ok, counts = pcall(Q.ActiveCounts)
    if not ok or counts == nil then
        return nil
    end
    return { active = counts[zone.nombre_original] or 0 }
end

-- texto corto para el cartel de la zona ("" si no hay activas)
function Q.SummaryText(zone)
    local ok, stats = pcall(Q.Stats, zone)
    if not ok or stats == nil or stats.active == 0 then
        return ""
    end
    if stats.active == 1 then
        return "1 misi\195\179n activa"
    end
    return stats.active .. " misiones activas"
end

-- nombre en español cuando Quest Assistant lo tiene
function Q.QuestName(ndx, quest)
    if _G.QuestLocResolver ~= nil and QuestLocResolver.GetQuestNameES ~= nil then
        local ok, name = pcall(QuestLocResolver.GetQuestNameES, tonumber(ndx) or ndx, quest.nameEN)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return quest.nameEN or ("#" .. tostring(ndx))
end

local function LevelNumber(quest)
    local lvl = tonumber(quest.level)
    if lvl == nil then
        lvl = tonumber(quest.minlevel)
    end
    return lvl or 0
end

function Q.LevelText(quest)
    local lvl = tonumber(quest.level)
    if lvl ~= nil then
        return tostring(lvl)
    end
    if tonumber(quest.minlevel) ~= nil then
        return tostring(quest.minlevel) .. "+"
    end
    return "--"
end

-- filas para la lista: solo las misiones ACTIVAS de la zona, por nivel
function Q.Rows(zone)
    if zone == nil or not Q.Available() then
        return {}
    end
    local rows = {}
    for _, ndx in ipairs(ActiveNdxList()) do
        local quest = QuestByNdx(ndx)
        if quest ~= nil and Q.ZoneOfQuest(quest) == zone.nombre_original then
            rows[#rows + 1] = { ndx = ndx, quest = quest, state = "ACTIVE", level = LevelNumber(quest) }
        end
    end
    table.sort(rows, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return (tonumber(a.ndx) or 0) < (tonumber(b.ndx) or 0)
    end)
    return rows
end

-- abre la mision en la ventana de Quest Assistant (mismo camino que su
-- propio rastreador: MainWindow:SetVisible + FocusQuest)
function Q.OpenQuest(ndx)
    local win = _G.MainWindow
    if win == nil or win.FocusQuest == nil then
        return false
    end
    local ok = pcall(function()
        win:SetVisible(true)
        win:FocusQuest(tonumber(ndx) or ndx)
    end)
    return ok
end
