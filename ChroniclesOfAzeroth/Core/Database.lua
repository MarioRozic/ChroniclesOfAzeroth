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

DB.SCHEMA_VERSION = 1

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
    },
    stats = {
        sessions = 0,
        deaths = 0,
        questsCompleted = 0,
        levelsGained = 0,         -- levels gained while the addon was installed
        zonesDiscovered = 0,
        instancesEntered = 0,
        -- Reserved for Phase 2 (need verification on the Forever client):
        kills = 0, rareKills = 0, dungeonsCompleted = 0, bossesDefeated = 0,
    },
    location = { zone = "", subzone = "", mapID = 0, instance = "" },
    feed = { nextId = 1, entries = {} },
    exploration = { zones = {} },  -- [zoneName] = { firstVisit, lastVisit, visits, mapID }
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
    -- [2] = function(db)
    --     for key, char in pairs(db.characters) do ... end
    -- end,
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

function DB:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "UnknownRealm"
    return name .. "-" .. realm
end

-- Called on PLAYER_LOGIN, when unit information is reliable.
function DB:LoadCharacter()
    local key = self:GetCharacterKey()
    local chars = CoA.db.characters
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
