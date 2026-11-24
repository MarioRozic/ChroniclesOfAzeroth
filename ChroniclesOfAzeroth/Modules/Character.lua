--[[
  Chronicles of Azeroth - Modules/Character.lua

  Keeps the character's identity, level and time played up to date.

  Events used (all standard Mainline events, present in the Midnight code
  base that Forever is built on):
    PLAYER_LEVEL_UP (newLevel, ...)
    TIME_PLAYED_MSG (totalTimePlayed, timePlayedThisLevel)
    PLAYER_LOGOUT
]]

local _, CoA = ...
local Compat, Util = CoA.Compat, CoA.Util
local Character = CoA:NewModule("Character")
CoA.Character = Character

local sessionStart = time()
local timePlayedRequested = false

function Character:OnEnable()
    local char = CoA.char
    self:RefreshIdentity()

    char.stats.sessions = char.stats.sessions + 1

    CoA:RegisterEvent("PLAYER_LEVEL_UP", self, "OnLevelUp")
    CoA:RegisterEvent("TIME_PLAYED_MSG", self, "OnTimePlayed")
    CoA:RegisterEvent("PLAYER_LOGOUT", self, "OnLogout")
end

-- First PLAYER_ENTERING_WORLD of the session (location is known by now).
function Character:OnEnterWorld(isFirstOfSession)
    if not isFirstOfSession then return end
    local char = CoA.char

    -- First time this character is seen: open the chronicle.
    if CoA.isNewCharacter then
        CoA.Feed:Add("chronicle_begun", { name = char.meta.name, level = char.meta.startLevel })
    end

    -- Levels gained while the addon was disabled are recorded honestly as a
    -- single catch-up entry, never as individual fake level-up moments.
    local level = UnitLevel("player") or 1
    if level > char.progress.highestLevelSeen then
        CoA.Feed:Add("level_catchup", { level = level, from = char.progress.highestLevelSeen })
        char.progress.highestLevelSeen = level
    end
    char.progress.level = level
end

-- Race/class/faction can change (race or faction change services), so the
-- identity is refreshed on every login rather than stored once.
function Character:RefreshIdentity()
    local id = Compat.GetPlayerIdentity()
    local meta = CoA.char.meta
    meta.name = id.name
    meta.realm = id.realm
    meta.className = id.className
    meta.classFile = id.classFile
    meta.raceName = id.raceName
    meta.raceFile = id.raceFile
    meta.faction = id.faction
    meta.factionLocalized = id.factionLocalized
    meta.sex = id.sex
    meta.lastSeen = time()
    CoA.char.progress.level = id.level
end

function Character:OnLevelUp(_, newLevel)
    local char = CoA.char
    newLevel = tonumber(newLevel) or ((UnitLevel("player") or 0) + 1)
    char.progress.level = newLevel
    if newLevel > char.progress.highestLevelSeen then
        char.progress.highestLevelSeen = newLevel
        char.stats.levelsGained = char.stats.levelsGained + 1
        char.progress.levelHistory[newLevel] = {
            t = time(), zone = char.location.zone ~= "" and char.location.zone or nil,
        }
        CoA.Feed:Add("level_up", { level = newLevel }, { dedupe = "level" .. newLevel, window = 30 })
        CoA:Fire("DEED", "level", { level = newLevel })
    end
    CoA:Fire("CHARACTER_UPDATED")
    CoA:Fire("STATS_CHANGED", "level")
end

function Character:OnTimePlayed(_, total, thisLevel)
    if type(total) ~= "number" or Compat.IsSecret(total) then return end
    local p = CoA.char.progress
    p.timePlayedTotal = total
    p.timePlayedLevel = tonumber(thisLevel) or 0
    p.timePlayedStamp = time()
    CoA:Fire("CHARACTER_UPDATED")
end

function Character:OnLogout()
    CoA.char.meta.lastSeen = time()
end

-- Asks the server for /played. The client prints the standard "Total time
-- played" line in chat as a side effect, so we only ask once per session
-- and only when the player actually looks at their profile.
function Character:RequestTimePlayed()
    if timePlayedRequested or not CoA.db.settings.requestTimePlayed then return end
    if not RequestTimePlayed then return end
    timePlayedRequested = true
    RequestTimePlayed()
end

-- Returns seconds played (live while the session is running), and whether
-- the value is live or a stored snapshot. nil when never received.
function Character:GetTimePlayed()
    local p = CoA.char.progress
    if not p.timePlayedTotal or p.timePlayedTotal <= 0 then return nil end
    if p.timePlayedStamp >= sessionStart then
        return p.timePlayedTotal + (time() - p.timePlayedStamp), true
    end
    return p.timePlayedTotal, false
end

-- RPG title: a title earned from a milestone if one is worn (see
-- Achievements:WearTitle), otherwise a title that follows the level.
local LEVEL_TITLES = {
    { 60, "Champion of Azeroth" },
    { 50, "the Renowned" },
    { 40, "the Valiant" },
    { 30, "the Veteran" },
    { 20, "the Seasoned" },
    { 10, "the Wayfarer" },
    { 1,  "the Untested" },
}

function Character:GetTitle()
    local custom = CoA.char.profile.customTitle
    if custom and custom ~= "" then return custom end
    local level = CoA.char.progress.level or 1
    for _, row in ipairs(LEVEL_TITLES) do
        if level >= row[1] then return row[2] end
    end
    return LEVEL_TITLES[#LEVEL_TITLES][2]
end

function Character:GetAdventureDays()
    return Util.DaysBetween(CoA.char.meta.chronicleStarted, time()) + 1
end
