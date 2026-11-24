--[[
  Chronicles of Azeroth - Modules/Tracker.lua

  Turns real game events into chronicle facts: travel, instances, quests and
  deaths. Phase 1 records these into the event feed and the exploration
  table; Phase 2 builds achievements and the exploration UI on top of them.

  Events used (standard Mainline events):
    ZONE_CHANGED_NEW_AREA          - player moved to another zone
    ZONE_CHANGED, ZONE_CHANGED_INDOORS - sub-zone changed (no feed entry)
    QUEST_COMPLETE                 - quest reward frame opened (title capture)
    QUEST_TURNED_IN (questID, xp, money)
    PLAYER_DEAD
  PLAYER_ENTERING_WORLD is dispatched by Bootstrap as OnEnterWorld().

  Deliberately NOT used: COMBAT_LOG_EVENT_UNFILTERED / CHAT_MSG_COMBAT_*.
  Combat-log events are closed to addons on the Midnight-based Forever
  client, so kill tracking needs a different, verified source (Phase 2).
]]

local _, CoA = ...
local Compat = CoA.Compat
local Tracker = CoA:NewModule("Tracker")
CoA.Tracker = Tracker

local enteredWorldAt = 0
local pendingQuestTitle   -- title captured at QUEST_COMPLETE

function Tracker:OnEnable()
    CoA:RegisterEvent("ZONE_CHANGED_NEW_AREA", self, "OnZoneChanged")
    CoA:RegisterEvent("ZONE_CHANGED", self, "OnSubZoneChanged")
    CoA:RegisterEvent("ZONE_CHANGED_INDOORS", self, "OnSubZoneChanged")
    CoA:RegisterEvent("QUEST_COMPLETE", self, "OnQuestComplete")
    CoA:RegisterEvent("QUEST_TURNED_IN", self, "OnQuestTurnedIn")
    CoA:RegisterEvent("PLAYER_DEAD", self, "OnPlayerDead")
    -- Phase 2: fires when a new area of the world map is revealed.
    CoA:RegisterEvent("MAP_EXPLORATION_UPDATED", self, "OnMapExplored")
end

function Tracker:OnEnterWorld(isFirstOfSession, isInitialLogin)
    enteredWorldAt = GetTime()
    self:UpdateLocation()
    if isFirstOfSession and isInitialLogin and not CoA.isNewCharacter then
        CoA.Feed:Add("session_start", {}, { dedupe = "session", window = 60 })
    end
end

---------------------------------------------------------------------------
-- Location
---------------------------------------------------------------------------
function Tracker:OnZoneChanged()
    self:UpdateLocation()
end

function Tracker:OnSubZoneChanged()
    local loc = CoA.char.location
    loc.subzone = Compat.GetSubZone() or ""
    self:RecordSubZone()
end

-- Remembers each named sub-zone (village, cave, camp) visited per zone.
function Tracker:RecordSubZone()
    local char = CoA.char
    local loc = char.location
    local rec = loc.zone ~= "" and char.exploration.zones[loc.zone]
    if not rec or rec.isInstance then return end
    local sub = loc.subzone
    if sub == "" or sub == loc.zone then return end
    rec.subzones = rec.subzones or {}
    if not rec.subzones[sub] then
        rec.subzones[sub] = time()
        char.stats.subzonesDiscovered = char.stats.subzonesDiscovered + 1
        CoA:Fire("STATS_CHANGED", "subzone")
        CoA:Fire("DEED", "subzone", { name = sub })
    end
end

-- A new part of the world map was revealed by walking there.
function Tracker:OnMapExplored()
    local char = CoA.char
    local loc = char.location
    local area = Compat.GetSubZone() or (loc.zone ~= "" and loc.zone) or nil
    local entry = CoA.Feed:Add("area_discovered", { area = area, zone = loc.zone ~= "" and loc.zone or nil },
        { dedupe = "area" .. tostring(area), window = 30 })
    if not entry then return end
    char.stats.areasDiscovered = char.stats.areasDiscovered + 1
    local rec = loc.zone ~= "" and char.exploration.zones[loc.zone]
    if rec then
        rec.areasDiscovered = (rec.areasDiscovered or 0) + 1
        rec.revealed = Compat.GetRevealedAreaCount(rec.mapID) or rec.revealed
    end
    CoA:Fire("STATS_CHANGED", "area")
    CoA:Fire("DEED", "area", {})
end

local function GetZoneRecord(name, mapID, isInstance)
    local zones = CoA.char.exploration.zones
    local rec = zones[name]
    local isNew = false
    if type(rec) ~= "table" then
        rec = { firstVisit = time(), lastVisit = 0, visits = 0, quests = 0, deaths = 0 }
        zones[name] = rec
        isNew = true
    end
    if mapID then
        rec.mapID = mapID
        rec.continent = rec.continent or Compat.GetContinentName(mapID)
        rec.revealed = Compat.GetRevealedAreaCount(mapID) or rec.revealed
    end
    rec.kills = rec.kills or 0
    rec.subzones = rec.subzones or {}
    rec.isInstance = isInstance or nil
    return rec, isNew
end

function Tracker:UpdateLocation()
    local char = CoA.char
    local loc = char.location
    local name, mapID, inInstance = Compat.GetCurrentZone()
    if not name then return end  -- zone text not ready yet (loading screen)

    loc.subzone = Compat.GetSubZone() or ""
    if name == loc.zone then
        self:RecordSubZone()
        return  -- same zone (reload, re-zone) - no entry
    end

    loc.zone = name
    loc.mapID = mapID or 0

    local rec, isNew = GetZoneRecord(name, mapID, inInstance)
    local newZone = false
    rec.visits = rec.visits + 1
    rec.lastVisit = time()

    if inInstance then
        local instName, _, difficulty = Compat.GetInstance()
        instName = instName or name
        if instName ~= loc.instance then
            loc.instance = instName
            char.stats.instancesEntered = char.stats.instancesEntered + 1
            CoA.Feed:Add("instance_entered", { instance = instName, difficulty = difficulty },
                { dedupe = "inst" .. instName, window = 30 })
        end
    else
        loc.instance = ""
        if isNew then
            char.stats.zonesDiscovered = char.stats.zonesDiscovered + 1
            -- A character that was already past level 1 when the chronicle
            -- began may have been here before; don't claim a discovery.
            local kind = (char.meta.startLevel > 1) and "zone_recorded" or "zone_discovered"
            CoA.Feed:Add(kind, { zone = name })
            newZone = true
        else
            CoA.Feed:Add("zone_entered", { zone = name }, { dedupe = "zone" .. name, window = 20 })
        end
    end
    self:RecordSubZone()
    CoA:Fire("LOCATION_CHANGED", name)
    CoA:Fire("STATS_CHANGED", "zone")
    if newZone then CoA:Fire("DEED", "zone_new", { zone = name }) end
end

CoA.Feed:RegisterKind("zone_recorded", {
    category = "travel", icon = CoA.Feed.ICON.map,
    text = function(d) return (d.zone or "A region") .. " was added to your chronicle." end,
    journal = function(d) return "I made note of " .. (d.zone or "this place") .. " in my journal." end,
})

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
function Tracker:OnQuestComplete()
    pendingQuestTitle = Compat.GetOpenQuestTitle()
end

function Tracker:OnQuestTurnedIn(_, questID, xpReward, moneyReward)
    local char = CoA.char
    local title = Compat.GetQuestTitle(questID) or pendingQuestTitle
    pendingQuestTitle = nil

    local entry = CoA.Feed:Add("quest_completed",
        { questID = questID, title = title, xp = tonumber(xpReward), money = tonumber(moneyReward) },
        { dedupe = "quest" .. tostring(questID), window = 10 })
    if not entry then return end -- duplicate

    char.stats.questsCompleted = char.stats.questsCompleted + 1
    CoA:Fire("STATS_CHANGED", "quest")
    CoA:Fire("DEED", "quest", { zone = char.location.zone, questID = questID })
    local zone = char.location.zone
    if zone ~= "" and char.exploration.zones[zone] then
        local rec = char.exploration.zones[zone]
        rec.quests = (rec.quests or 0) + 1
    end
end

---------------------------------------------------------------------------
-- Death
---------------------------------------------------------------------------
function Tracker:OnPlayerDead()
    -- Ignore a PLAYER_DEAD that arrives right after a loading screen (e.g.
    -- logging in as a ghost) - that is not a new death.
    if GetTime() - enteredWorldAt < 5 then return end
    local char = CoA.char
    local entry = CoA.Feed:Add("player_died", {}, { dedupe = "death", window = 10 })
    if not entry then return end
    char.stats.deaths = char.stats.deaths + 1
    if CoA.Combat then CoA.Combat:OnPlayerDiedInRun() end
    CoA:Fire("STATS_CHANGED", "death")
    CoA:Fire("DEED", "death", {})
    local zone = char.location.zone
    if zone ~= "" and char.exploration.zones[zone] then
        local rec = char.exploration.zones[zone]
        rec.deaths = (rec.deaths or 0) + 1
    end
end

CoA.Feed:RegisterKind("area_discovered", {
    category = "travel", icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
    text = function(d)
        if d.area and d.zone and d.area ~= d.zone then
            return "You uncovered " .. d.area .. " in " .. d.zone .. "."
        end
        return "You uncovered " .. (d.area or "a hidden place") .. "."
    end,
    journal = function(d) return "I found my way to " .. (d.area or "a place unmarked on my map") .. "." end,
})
