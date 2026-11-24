--[[
  Chronicles of Azeroth - Core/Database.lua

  SavedVariables layout (account-wide, declared in the .toc):

  ChroniclesOfAzerothDB = {
      schemaVersion = <number>,
      settings      = { ...account-wide UI settings... },
      characters    = {
          ["Name-Realm"] = { ...one chronicle per character, see CHAR_DEFAULTS... },
      },
  }

  Characters are stored side by side in one account-wide table (instead of
  SavedVariablesPerCharacter) so a future "Hall of Heroes" view can compare
  characters. Each character is fully independent.

  Versioning: SCHEMA_VERSION is bumped whenever the shape of the data
  changes, and a function is added to MIGRATIONS[newVersion] that upgrades a
  database from newVersion-1. Migrations run once, in order, at load time.
]]

local _, CoA = ...
local Util = CoA.Util
local DB = {}
CoA.Database = DB

DB.SCHEMA_VERSION = 2

local SETTINGS_DEFAULTS = {
    debug = false,
    feedLimit = 2000,          -- oldest feed entries are trimmed past this
    playSounds = true,
    requestTimePlayed = true,  -- ask the server for /played once per session
    window = {
        point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
        width = 860, height = 600,
        scale = 1.0,
        lastTab = "overview",
    },
    minimap = { hide = false, angle = 200 },
}

local CHAR_DEFAULTS = {
    version = 1,
    meta = {
        name = "", realm = "",
        className = "", classFile = "", raceName = "", raceFile = "",
        faction = "", factionLocalized = "", sex = 1,
        chronicleStarted = 0,     -- when this addon first saw the character
        startLevel = 1,           -- level at that moment (honest "joined at")
        lastSeen = 0,
    },
    progress = {
        level = 1,
        highestLevelSeen = 1,
        timePlayedTotal = 0,      -- seconds, from TIME_PLAYED_MSG (0 = unknown)
        timePlayedLevel = 0,
        timePlayedStamp = 0,      -- time() when the two values above were read
        levelHistory = {},        -- [level] = { t, zone } for levels reached while recorded
    },
    stats = {
        sessions = 0,
        deaths = 0,
        questsCompleted = 0,
        levelsGained = 0,         -- levels gained while the addon was installed
        zonesDiscovered = 0,
        instancesEntered = 0,
        -- Phase 2 (see Modules/Combat.lua and Tracker.lua for sources):
        kills = 0, eliteKills = 0, rareKills = 0, raresSeen = 0,
        dungeonsCompleted = 0, bossesDefeated = 0,
        areasDiscovered = 0, subzonesDiscovered = 0,
    },
    combat = {
        creatureTypes = {},   -- [creatureType] = kills
        rares = {},           -- [name] = { firstSeen, zone, level, elite, kills, lastKill }
        bosses = {},          -- [encounterName] = { first, last, count, instance }
        dungeons = {},        -- [instanceName] = { first, last, completions, fastest, deathless }
        killsByDay = {},      -- ["2026-11-24"] = kills, for the journal
    },
    location = { zone = "", subzone = "", mapID = 0, instance = "" },
    feed = { nextId = 1, entries = {} },
    -- [zoneName] = { firstVisit, lastVisit, visits, mapID, continent, quests,
    --               deaths, kills, subzones = { [name] = firstVisit }, revealed }
    exploration = { zones = {} },
    -- Reserved for later phases; created now so migrations stay trivial.
    achievements = { unlocked = {} },
    challenges = { active = {}, completed = {} },
    journal = { notes = {} },
    profile = { customTitle = "" },
}

DB.CHAR_DEFAULTS = CHAR_DEFAULTS

---------------------------------------------------------------------------
-- Migrations. MIGRATIONS[n] upgrades a schema n-1 database to schema n.
---------------------------------------------------------------------------
local MIGRATIONS = {
    -- v2 (addon 0.2.0): zone records gain kill and sub-zone tracking.
    [2] = function(db)
        for _, char in pairs(db.characters) do
            local zones = type(char) == "table" and type(char.exploration) == "table"
                and char.exploration.zones
            if type(zones) == "table" then
                for _, rec in pairs(zones) do
                    if type(rec) == "table" then
                        rec.kills = tonumber(rec.kills) or 0
                        if type(rec.subzones) ~= "table" then rec.subzones = {} end
                    end
                end
            end
        end
    end,
}

local function RunMigrations(db)
    local from = tonumber(db.schemaVersion) or 0
    if from >= DB.SCHEMA_VERSION then return end
    for v = from + 1, DB.SCHEMA_VERSION do
        local migrate = MIGRATIONS[v]
        if migrate then
            local ok, err = pcall(migrate, db)
            if not ok then
                CoA:Print("|cffff5555Data migration to version", v, "failed:|r", err)
                -- Stop here; defaults below still make the data usable.
                return
            end
        end
        db.schemaVersion = v
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- Called on ADDON_LOADED, once SavedVariables are available.
function DB:Initialize()
    local raw = _G.ChroniclesOfAzerothDB

    if raw ~= nil and type(raw) ~= "table" then
        -- Something overwrote our saved data with garbage. Keep a copy for
        -- inspection instead of silently throwing it away.
        _G.ChroniclesOfAzerothDB_Corrupt = raw
        CoA:Print("|cffff5555Saved data was unreadable and has been reset.|r")
        raw = nil
    end

    local isNew = (raw == nil)
    raw = raw or { schemaVersion = DB.SCHEMA_VERSION }
    if type(raw.characters) ~= "table" then raw.characters = {} end

    RunMigrations(raw)
    raw.settings = Util.ApplyDefaults(raw.settings, SETTINGS_DEFAULTS)

    _G.ChroniclesOfAzerothDB = raw
    CoA.db = raw
    CoA.isFirstInstall = isNew
end

-- When the client reports no realm name (seen on Forever build 71037) the
-- key becomes "Name-Forever". v0.1.0 stored such characters as "Name-";
-- LoadCharacter moves that record to the new key.
DB.NO_REALM = "Forever"

function DB:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    return name .. "-" .. (CoA.Compat.GetRealm() or DB.NO_REALM), name
end

-- Called on PLAYER_LOGIN, when unit information is reliable.
function DB:LoadCharacter()
    local key, name = self:GetCharacterKey()
    local chars = CoA.db.characters
    -- Carry over a v0.1.0 record saved without a realm ("Name-").
    local legacyKey = name .. "-"
    if type(chars[key]) ~= "table" and type(chars[legacyKey]) == "table" then
        chars[key] = chars[legacyKey]
        chars[legacyKey] = nil
    end
    local isNew = type(chars[key]) ~= "table"

    local char = Util.ApplyDefaults(chars[key], CHAR_DEFAULTS)
    chars[key] = char

    if isNew or char.meta.chronicleStarted == 0 then
        char.meta.chronicleStarted = time()
        char.meta.startLevel = UnitLevel("player") or 1
        char.progress.highestLevelSeen = char.meta.startLevel
    end

    CoA.char = char
    CoA.charKey = key
    CoA.isNewCharacter = isNew
    return char, isNew
end

function DB:GetSettings()
    return CoA.db.settings
end

-- For a future character selector; returns { key = char } of all chronicles.
function DB:GetAllCharacters()
    return CoA.db.characters
end

-- Wipes the current character's chronicle (used by "/coa reset confirm").
function DB:ResetCharacter()
    CoA.db.characters[CoA.charKey] = nil
    return self:LoadCharacter()
end
