--[[
  Chronicles of Azeroth - Modules/Combat.lua  (Phase 2)

  Kills, elites, rare creatures, bosses and dungeon completions.

  The Forever client closes the combat log to addons and hides creature
  identity (names, GUIDs) inside instances, so this module combines several
  sources and only counts what it can attribute with confidence:

  Kills (open world):
    1. PARTY_KILL (attackerGUID, targetGUID) - your or your pet's killing blow.
    2. UNIT_DIED (unitGUID) - a creature you were fighting (your target while
       in combat, not tapped by someone else) died, whoever landed the blow.
    3. Fallback when UNIT_DIED is missing: your target is seen dead.
    Each creature GUID is credited at most once.
  Inside instances GUIDs are secret, so dungeon trash is not counted.

  Rares: UnitClassification "rare"/"rareelite" on your target, mouseover or
  a nameplate records a sighting; a credited kill of one records a rare kill.

  Bosses: ENCOUNTER_END with success = 1.
  Dungeon completed: the instance's last Encounter Journal boss is defeated,
  every listed boss is defeated, or LFG_COMPLETION_REWARD fires.
]]

local _, CoA = ...
local Compat = CoA.Compat
local Combat = CoA:NewModule("Combat")
CoA.Combat = Combat

local engaged = {}   -- [guid] = creature info, fought = bool, seen = GetTime()
local credited = {}  -- [guid] = true (this session; GUIDs are session-unique)
local engagedCount = 0
local run            -- the current dungeon run, see StartRun()

local RARE = { rare = true, rareelite = true }

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function Combat:OnEnable()
    CoA:RegisterEvent("PARTY_KILL", self, "OnPartyKill")
    self.hasUnitDied = CoA:RegisterEvent("UNIT_DIED", self, "OnUnitDied")
    CoA:RegisterEvent("PLAYER_TARGET_CHANGED", self, "OnTargetChanged")
    CoA:RegisterEvent("UNIT_FLAGS", self, "OnUnitFlags")
    CoA:RegisterEvent("PLAYER_REGEN_DISABLED", self, "OnEnterCombat")
    CoA:RegisterEvent("UPDATE_MOUSEOVER_UNIT", self, "OnMouseover")
    CoA:RegisterEvent("NAME_PLATE_UNIT_ADDED", self, "OnNameplate")
    CoA:RegisterEvent("ENCOUNTER_END", self, "OnEncounterEnd")
    CoA:RegisterEvent("LFG_COMPLETION_REWARD", self, "OnLFGComplete")
    CoA:On("LOCATION_CHANGED", self, self.OnLocationChanged)
    self:OnLocationChanged()
end

local function Prune()
    if engagedCount < 200 then return end
    local cutoff = GetTime() - 600
    for guid, info in pairs(engaged) do
        if info.seen < cutoff then
            engaged[guid] = nil
            engagedCount = engagedCount - 1
        end
    end
end

---------------------------------------------------------------------------
-- Watching creatures
---------------------------------------------------------------------------
local function Remember(unit, fought)
    local info = Compat.GetCreatureInfo(unit)
    if not info then return nil end
    local known = engaged[info.guid]
    if known then
        known.tapDenied = info.tapDenied
        known.dead = info.dead
        known.fought = known.fought or fought
        known.seen = GetTime()
        info = known
    else
        info.fought = fought
        info.seen = GetTime()
        engaged[info.guid] = info
        engagedCount = engagedCount + 1
        Prune()
    end
    if RARE[info.classification] then Combat:SeeRare(info) end
    return info
end

local function InCombatWith(unit)
    return (UnitAffectingCombat and Compat.Safe(UnitAffectingCombat("player")))
       and (UnitAffectingCombat and Compat.Safe(UnitAffectingCombat(unit))) and true or false
end

function Combat:OnTargetChanged()
    -- Fallback for clients without UNIT_DIED: the previous target may have
    -- died; re-check everything we know is dead but not yet credited.
    local info = Remember("target", InCombatWith("target"))
    if info and info.dead then self:TryCreditDead(info) end
end

function Combat:OnEnterCombat()
    Remember("target", true)
    Remember("focus", true)
end

function Combat:OnUnitFlags(_, unit)
    if unit ~= "target" then return end
    local info = Remember("target", InCombatWith("target"))
    if info and info.dead then self:TryCreditDead(info) end
end

function Combat:OnMouseover()
    Remember("mouseover", false)
end

function Combat:OnNameplate(_, unit)
    if unit then Remember(unit, false) end
end

---------------------------------------------------------------------------
-- Kill attribution
---------------------------------------------------------------------------
function Combat:OnPartyKill(_, attackerGUID, targetGUID)
    attackerGUID, targetGUID = Compat.Safe(attackerGUID), Compat.Safe(targetGUID)
    if not (attackerGUID and targetGUID) then return end
    local me, pet = Compat.PlayerGUID(), Compat.UnitGUID("pet")
    if attackerGUID ~= me and attackerGUID ~= pet then return end
    self:Credit(targetGUID, engaged[targetGUID])
end

function Combat:OnUnitDied(_, guid)
    guid = Compat.Safe(guid)
    if not guid then return end
    local info = engaged[guid]
    if info then self:TryCreditDead(info) end
end

function Combat:TryCreditDead(info)
    if info.fought and not info.tapDenied then
        self:Credit(info.guid, info)
    end
end

function Combat:Credit(guid, info)
    if credited[guid] then return end
    -- Only creatures (not players, pets or totems) count as enemies defeated.
    if not (string.find(guid, "^Creature") or string.find(guid, "^Vehicle")) then return end
    credited[guid] = true

    local char = CoA.char
    local s, c = char.stats, char.combat
    s.kills = s.kills + 1
    local day = CoA.Util.DayKey(time())
    c.killsByDay[day] = (c.killsByDay[day] or 0) + 1

    local zone = char.location.zone
    local zrec = zone ~= "" and char.exploration.zones[zone]
    if zrec then zrec.kills = (zrec.kills or 0) + 1 end

    local newType = false
    if info then
        if info.creatureType then
            newType = (c.creatureTypes[info.creatureType] or 0) == 0
            c.creatureTypes[info.creatureType] = (c.creatureTypes[info.creatureType] or 0) + 1
        end
        local class = info.classification
        if class == "elite" or class == "rareelite" or class == "worldboss" then
            s.eliteKills = s.eliteKills + 1
        end
        if RARE[class] then
            s.rareKills = s.rareKills + 1
            local r = self:SeeRare(info)
            r.kills = (r.kills or 0) + 1
            r.lastKill = time()
            CoA.Feed:Add("rare_killed", { name = info.name, elite = class == "rareelite" })
        elseif class == "worldboss" then
            CoA.Feed:Add("worldboss_killed", { name = info.name })
        end
    end
    CoA:Fire("STATS_CHANGED", "kill")
    CoA:Fire("DEED", "kill", {
        name = info and info.name, classification = info and info.classification,
        creatureType = info and info.creatureType, newType = newType,
    })
end

---------------------------------------------------------------------------
-- Rare creatures
---------------------------------------------------------------------------
function Combat:SeeRare(info)
    local rares = CoA.char.combat.rares
    local r = rares[info.name]
    if not r then
        r = { firstSeen = time(), zone = CoA.char.location.zone, level = info.level,
              elite = info.classification == "rareelite", kills = 0 }
        rares[info.name] = r
        CoA.char.stats.raresSeen = CoA.char.stats.raresSeen + 1
        CoA.Feed:Add("rare_seen", { name = info.name, elite = r.elite })
        CoA:Fire("STATS_CHANGED", "rare")
        CoA:Fire("DEED", "rare_seen", { name = info.name })
    end
    return r
end

---------------------------------------------------------------------------
-- Bosses and dungeon runs
---------------------------------------------------------------------------
local function StartRun(name, instanceType)
    run = {
        name = name, instanceType = instanceType, started = time(),
        defeated = {}, defeatedCount = 0, deaths = 0, completed = false,
        encounters = Compat.GetInstanceEncounters(),
    }
end

function Combat:OnLocationChanged()
    local loc = CoA.char and CoA.char.location
    if not loc then return end
    local instName, instanceType = Compat.GetInstance()
    if instName and (instanceType == "party" or instanceType == "raid") then
        if not run or run.name ~= instName then StartRun(instName, instanceType) end
    end
    -- Leaving the instance keeps the run until a different one is entered, so
    -- a corpse run or a quick trip outside does not reset progress.
end

function Combat:OnPlayerDiedInRun()
    if run and Compat.GetInstance() == run.name then run.deaths = run.deaths + 1 end
end

function Combat:GetRun()
    return run
end

function Combat:OnEncounterEnd(_, encounterID, encounterName, _, _, success)
    if success ~= 1 and success ~= true then return end
    encounterName = Compat.Safe(encounterName) or "a mighty foe"
    local key = tostring(Compat.Safe(encounterID) or encounterName)
    if run and run.defeated[key] then return end -- duplicate event

    local char = CoA.char
    char.stats.bossesDefeated = char.stats.bossesDefeated + 1
    local b = char.combat.bosses[encounterName] or { first = time(), count = 0 }
    b.count = b.count + 1
    b.last = time()
    b.instance = Compat.GetInstance()
    char.combat.bosses[encounterName] = b
    CoA.Feed:Add("boss_defeated", { name = encounterName, instance = b.instance })

    if run then
        run.defeated[key] = true
        run.defeated[encounterName] = true
        run.defeatedCount = run.defeatedCount + 1
        self:CheckRunComplete(encounterName, Compat.Safe(encounterID))
    end
    CoA:Fire("STATS_CHANGED", "boss")
    CoA:Fire("DEED", "boss", { name = encounterName })
end

function Combat:CheckRunComplete(lastName, lastID)
    if not run or run.completed or run.instanceType ~= "party" then return end
    local list = run.encounters
    if not list then return end -- no journal data: rely on LFG_COMPLETION_REWARD
    local final = list[#list]
    local isFinal = (lastID and final.encounterID == lastID) or (final.name and final.name == lastName)
    local all = true
    for _, enc in ipairs(list) do
        if not (run.defeated[enc.name or ""] or (enc.encounterID and run.defeated[tostring(enc.encounterID)])) then
            all = false
            break
        end
    end
    if isFinal or all then self:CompleteRun("final boss") end
end

function Combat:OnLFGComplete()
    if run and not run.completed then self:CompleteRun("dungeon finder") end
end

function Combat:CompleteRun(how)
    run.completed = true
    local char = CoA.char
    char.stats.dungeonsCompleted = char.stats.dungeonsCompleted + 1
    local d = char.combat.dungeons[run.name] or { first = time(), completions = 0 }
    d.completions = d.completions + 1
    d.last = time()
    local duration = time() - run.started
    if not d.fastest or duration < d.fastest then d.fastest = duration end
    if run.deaths == 0 then d.deathless = (d.deathless or 0) + 1 end
    char.combat.dungeons[run.name] = d
    CoA.Feed:Add("dungeon_completed", { instance = run.name, duration = duration, deaths = run.deaths, how = how })
    CoA:Fire("STATS_CHANGED", "dungeon")
    CoA:Fire("DEED", "dungeon", { name = run.name, deaths = run.deaths })
end

---------------------------------------------------------------------------
-- Feed kinds
---------------------------------------------------------------------------
local Feed = CoA.Feed
Feed:RegisterKind("rare_seen", {
    category = "combat", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    text = function(d) return "You discovered a rare creature: " .. (d.name or "?") .. "." end,
    journal = function(d) return "I caught sight of " .. (d.name or "a rare beast") .. ", a creature few travellers ever see." end,
})
Feed:RegisterKind("rare_killed", {
    category = "combat", icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
    text = function(d) return "You slew the rare " .. (d.name or "creature") .. "." end,
    journal = function(d) return "I hunted down " .. (d.name or "a rare creature") .. " and returned with proof of the deed." end,
})
Feed:RegisterKind("worldboss_killed", {
    category = "combat", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
    text = function(d) return "You helped defeat " .. (d.name or "a world boss") .. "." end,
    journal = function(d) return "Alongside others, I stood against " .. (d.name or "a terrible foe") .. ", and we prevailed." end,
})
Feed:RegisterKind("boss_defeated", {
    category = "combat", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    text = function(d)
        return "You defeated " .. (d.name or "a boss") .. (d.instance and (" in " .. d.instance) or "") .. "."
    end,
    journal = function(d) return "In " .. (d.instance or "the depths") .. ", " .. (d.name or "a fearsome foe") .. " fell before us." end,
})
Feed:RegisterKind("dungeon_completed", {
    category = "combat", icon = "Interface\\Icons\\INV_Misc_Key_03",
    text = function(d)
        local extra = d.deaths == 0 and " without a single death" or ""
        return "You completed " .. (d.instance or "a dungeon") .. extra .. "."
    end,
    journal = function(d) return "We fought our way to the very end of " .. (d.instance or "the dungeon") .. "." end,
})
