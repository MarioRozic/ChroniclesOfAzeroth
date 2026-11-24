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
function Compat.GetPlayerIdentity()
    local name, realm = UnitFullName and UnitFullName("player")
    name = Clean(name) or UnitName("player")
    realm = Clean(realm) or (GetRealmName and GetRealmName()) or "UnknownRealm"

    local className, classFile = UnitClass("player")
    local raceName, raceFile = UnitRace("player")
    local faction, factionLocalized = UnitFactionGroup("player")

    return {
        name = name or "Unknown",
        realm = realm,
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
