--[[
  Chronicles of Azeroth - Core/Compat.lua

  Every call into the game client that is not 100% guaranteed on the WoW
  Forever client goes through this file. Each wrapper checks that the API
  exists before calling it and falls back to an older/equivalent API, or to
  "unknown", instead of erroring. If a Forever patch renames something, this
  is the one file to fix.

  Research notes (Nov 2026):
  * WoW Forever 1.60.x is a Mainline game type ("camelot"/"forever") sharing
    the Midnight 12.1.x code base. Interface number 16001.
  * It is NOT the 1.12 Vanilla client: no `this`/`arg1` globals, modern
    C_* namespaces exist, combat-log events are closed to addons (Midnight
    "addon disarmament"), and some combat values are "secret".
]]

local _, CoA = ...
local Compat = {}
CoA.Compat = Compat

-- WOW_PROJECT_CAMELOT is the documented project id of the Forever client.
function Compat.IsForeverClient()
    return WOW_PROJECT_ID ~= nil and WOW_PROJECT_CAMELOT ~= nil
        and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

function Compat.GetClientInfo()
    local version, build, buildDate, interface
    if GetBuildInfo then
        version, build, buildDate, interface = GetBuildInfo()
    end
    return version or "?", build or "?", buildDate or "?", interface or 0
end

function Compat.GetAddOnMetadata(addon, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addon, field)
    elseif GetAddOnMetadata then
        return GetAddOnMetadata(addon, field)
    end
end

-- Midnight introduced "secret values" that addons may not inspect. Our data
-- (zone names, quest titles, level) is not secret out of combat, but guard
-- anyway so a secret value is never written into SavedVariables.
function Compat.IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        return ok and secret
    end
    return false
end

local function Clean(value)
    if value == nil or Compat.IsSecret(value) then return nil end
    if type(value) == "string" and value == "" then return nil end
    return value
end

---------------------------------------------------------------------------
-- Player identity
---------------------------------------------------------------------------
-- Realm name, or nil when the client does not report one. Verified in game
-- (build 71037): Forever returned an empty realm name, so every source is
-- tried and an empty string counts as "unknown".
function Compat.GetRealm()
    local candidates = {}
    if GetNormalizedRealmName then candidates[#candidates + 1] = GetNormalizedRealmName() end
    if GetRealmName then candidates[#candidates + 1] = GetRealmName() end
    if UnitFullName then
        local _, r = UnitFullName("player")
        candidates[#candidates + 1] = r
    end
    for _, r in ipairs(candidates) do
        r = Clean(r)
        if type(r) == "string" then return r end
    end
    return nil
end

function Compat.GetPlayerIdentity()
    local name = UnitFullName and UnitFullName("player")
    name = Clean(name) or UnitName("player")
    local realm = Compat.GetRealm()

    local className, classFile = UnitClass("player")
    local raceName, raceFile = UnitRace("player")
    local faction, factionLocalized = UnitFactionGroup("player")

    return {
        name = name or "Unknown",
        realm = realm or "",
        className = className or "Unknown",
        classFile = classFile or "WARRIOR",
        raceName = raceName or "Unknown",
        raceFile = raceFile or "Human",
        faction = faction or "Neutral",
        factionLocalized = factionLocalized or faction or "Neutral",
        sex = UnitSex and UnitSex("player") or 1,
        level = UnitLevel("player") or 1,
    }
end

function Compat.GetMaxPlayerLevel()
    if GetMaxLevelForPlayerExpansion then
        local ok, lvl = pcall(GetMaxLevelForPlayerExpansion)
        if ok and type(lvl) == "number" and lvl > 0 then return lvl end
    end
    if MAX_PLAYER_LEVEL and MAX_PLAYER_LEVEL > 0 then return MAX_PLAYER_LEVEL end
    return 60 -- Forever's announced level cap
end

function Compat.GetClassColor(classFile)
    local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
    local c = colors and colors[classFile]
    if c then return c.r, c.g, c.b end
    return 0.85, 0.75, 0.55
end

---------------------------------------------------------------------------
-- Location
---------------------------------------------------------------------------

-- Returns the zone the player is in (not the sub-zone):
--   name, mapID (or nil), isInstance, instanceType
function Compat.GetCurrentZone()
    local name = Clean(GetRealZoneText and GetRealZoneText())
                 or Clean(GetZoneText and GetZoneText())
    local mapID
    if C_Map and C_Map.GetBestMapForUnit then
        mapID = C_Map.GetBestMapForUnit("player")
        -- Climb from micro/sub-zone maps up to the zone-level map.
        if mapID and C_Map.GetMapInfo and Enum and Enum.UIMapType then
            local info = C_Map.GetMapInfo(mapID)
            local guard = 0
            while info and info.mapType and info.mapType > Enum.UIMapType.Zone
                  and info.parentMapID and info.parentMapID > 0 and guard < 5 do
                mapID = info.parentMapID
                info = C_Map.GetMapInfo(mapID)
                guard = guard + 1
            end
        end
    end
    local inInstance, instanceType = false, "none"
    if IsInInstance then
        inInstance, instanceType = IsInInstance()
    end
    return name, mapID, inInstance and true or false, instanceType or "none"
end

function Compat.GetSubZone()
    return Clean(GetSubZoneText and GetSubZoneText())
end

-- name, instanceType, difficultyName, instanceID  (or nil when not inside)
function Compat.GetInstance()
    if not GetInstanceInfo then return nil end
    local name, instanceType, _, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    if not instanceType or instanceType == "none" then return nil end
    return Clean(name), instanceType, Clean(difficultyName), instanceID
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
function Compat.GetQuestTitle(questID)
    if not questID then return nil end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = Clean(C_QuestLog.GetTitleForQuestID(questID))
        if title then return title end
    end
    if QuestUtils_GetQuestName then
        local ok, title = pcall(QuestUtils_GetQuestName, questID)
        if ok then return Clean(title) end
    end
    return nil
end

-- Title of the quest currently shown in the quest-giver reward frame.
function Compat.GetOpenQuestTitle()
    if GetTitleText then
        return Clean(GetTitleText())
    end
end

---------------------------------------------------------------------------
-- Sound / UI helpers
---------------------------------------------------------------------------
function Compat.PlaySound(kitName, fallbackID)
    if not PlaySound then return end
    local id = (SOUNDKIT and SOUNDKIT[kitName]) or fallbackID
    if id then pcall(PlaySound, id, "SFX") end
end

function Compat.SetResizeBounds(frame, minW, minH, maxW, maxH)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if frame.SetMinResize then frame:SetMinResize(minW, minH) end
        if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
    end
end

function Compat.InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

---------------------------------------------------------------------------
-- Units (Phase 2)
--
-- On Forever, creature names, GUIDs and IDs are "secret" inside instances,
-- and comparing a secret value raises a Lua error. Every unit value goes
-- through Safe(), which turns secrets into nil, before it is compared.
---------------------------------------------------------------------------
local function Safe(value)
    if value == nil or Compat.IsSecret(value) then return nil end
    return value
end
Compat.Safe = Safe

local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return Safe(a), Safe(b)
end

function Compat.UnitGUID(unit)
    return SafeCall(UnitGUID, unit)
end

local playerGUID
function Compat.PlayerGUID()
    playerGUID = playerGUID or Compat.UnitGUID("player")
    return playerGUID
end

-- Snapshot of an attackable creature, or nil if it is not one or its
-- identity is hidden. classification: "normal", "elite", "rare",
-- "rareelite", "worldboss", "trivial", "minus".
function Compat.GetCreatureInfo(unit)
    if not (UnitExists and UnitExists(unit)) then return nil end
    if UnitIsPlayer and SafeCall(UnitIsPlayer, unit) then return nil end
    if UnitCanAttack and not SafeCall(UnitCanAttack, "player", unit) then return nil end
    local guid = Compat.UnitGUID(unit)
    local name = SafeCall(UnitName, unit)
    if not guid or not name then return nil end
    -- Pets and other players' guardians are not creatures worth recording.
    if type(guid) ~= "string" or not (string.find(guid, "^Creature") or string.find(guid, "^Vehicle")) then
        return nil
    end
    return {
        guid = guid,
        name = name,
        classification = SafeCall(UnitClassification, unit) or "normal",
        creatureType = SafeCall(UnitCreatureType, unit),
        level = SafeCall(UnitLevel, unit),
        tapDenied = SafeCall(UnitIsTapDenied, unit) and true or false,
        dead = SafeCall(UnitIsDead, unit) and true or false,
    }
end

---------------------------------------------------------------------------
-- Map exploration (Phase 2). Returns the number of map overlays the client
-- reports as revealed for a zone map, or nil when the API is unavailable.
-- There is no API for the total, so no percentage is derived from this.
---------------------------------------------------------------------------
function Compat.GetRevealedAreaCount(mapID)
    if not (mapID and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then
        return nil
    end
    local ok, textures = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
    if ok and type(textures) == "table" then return #textures end
    return nil
end

-- Name of the continent a zone map belongs to, or nil.
function Compat.GetContinentName(mapID)
    if not (mapID and C_Map and C_Map.GetMapInfo and Enum and Enum.UIMapType) then return nil end
    local info = C_Map.GetMapInfo(mapID)
    local guard = 0
    while info and guard < 8 do
        if info.mapType == Enum.UIMapType.Continent then return Safe(info.name) end
        if not info.parentMapID or info.parentMapID == 0 then return nil end
        info = C_Map.GetMapInfo(info.parentMapID)
        guard = guard + 1
    end
    return nil
end

---------------------------------------------------------------------------
-- Dungeon structure via the Encounter Journal (Phase 2), if the client has
-- it. Returns an ordered list of encounter names for the current instance,
-- or nil. Used to recognise the final boss of a dungeon.
---------------------------------------------------------------------------
function Compat.GetInstanceEncounters()
    if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex and C_Map and C_Map.GetBestMapForUnit) then
        return nil
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local ok, journalInstanceID = pcall(EJ_GetInstanceForMap, mapID)
    if not ok or not journalInstanceID or journalInstanceID == 0 then return nil end
    local list = {}
    for i = 1, 30 do
        local ok2, name, _, journalEncounterID, _, _, _, dungeonEncounterID =
            pcall(EJ_GetEncounterInfoByIndex, i, journalInstanceID)
        if not ok2 or not name then break end
        list[#list + 1] = { name = Safe(name), journalID = journalEncounterID, encounterID = dungeonEncounterID }
    end
    if #list == 0 then return nil end
    return list
end

---------------------------------------------------------------------------
-- Chat and addon messages (v0.5.0)
---------------------------------------------------------------------------
-- 11.2+ moved SendChatMessage into C_ChatInfo; older names stay as fallback.
function Compat.SendChat(msg, chatType, target)
    local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not fn then return false end
    return pcall(fn, msg, chatType, nil, target)
end

-- Whether a chat channel can be used right now.
function Compat.CanUseChannel(chatType)
    if chatType == "GUILD" then return IsInGuild and IsInGuild() and true or false end
    if chatType == "PARTY" then return IsInGroup and IsInGroup() and true or false end
    if chatType == "INSTANCE_CHAT" then
        return IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and true or false
    end
    if chatType == "SAY" then return true end
    return false
end

-- Party chat inside a dungeon-finder group goes to INSTANCE_CHAT.
function Compat.GroupChannel()
    if Compat.CanUseChannel("INSTANCE_CHAT") then return "INSTANCE_CHAT" end
    if Compat.CanUseChannel("PARTY") then return "PARTY" end
end

function Compat.RegisterAddonPrefix(prefix)
    local fn = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
    if not fn then return false end
    local ok, result = pcall(fn, prefix)
    return ok and result ~= false
end

-- Returns the client's result code (Enum.SendAddonMessageResult: 0 is
-- success, 3 is throttled, 11 is the 12.0 encounter lockdown), or nil if
-- the client has no addon-message API.
function Compat.SendAddon(prefix, msg, chatType, target)
    local fn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if not fn then return nil end
    local ok, result = pcall(fn, prefix, msg, chatType, target)
    if not ok then return 9 end
    if result == nil or result == true then return 0 end
    if result == false then return 9 end
    return tonumber(result) or 0
end

function Compat.EncounterInProgress()
    return IsEncounterInProgress and Safe(IsEncounterInProgress()) and true or false
end

-- "Name-Realm" for a unit, suitable as a whisper target.
function Compat.UnitFullName(unit)
    if GetUnitName then
        local n = Safe(GetUnitName(unit, true))
        if n and n ~= "" then return n end
    end
    local name, realm = UnitName(unit)
    name, realm = Safe(name), Safe(realm)
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

function Compat.ShortName(full)
    if not full then return "?" end
    if Ambiguate then
        local ok, s = pcall(Ambiguate, full, "short")
        if ok and s then return s end
    end
    return (full:match("^[^-]+")) or full
end
