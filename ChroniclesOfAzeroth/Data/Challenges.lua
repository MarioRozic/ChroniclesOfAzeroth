--[[
  Chronicles of Azeroth - Data/Challenges.lua

  Personal challenges: goals the player chooses to take on. Progress only
  counts from the moment a challenge is accepted, and only from deeds the
  addon can observe reliably (see Modules/Challenges.lua for the deed list).

  Fields:
    id, category, name, desc, icon, target
    on       deed that advances it: kill, rare_seen, boss, dungeon, quest,
             level, zone_new, area, subzone, emote
    test     optional function(ctx, state) -> true if this deed counts
    key      optional function(ctx) -> value; each distinct value counts once
    failOn   optional "death": dying while the challenge is active fails it
    minLevel optional level required to accept it
]]

local _, CoA = ...

CoA.ChallengeData = {}
local D = CoA.ChallengeData

D.CATEGORIES = {
    { key = "exploration", label = "Exploration" },
    { key = "combat",      label = "Combat" },
    { key = "dungeons",    label = "Dungeons" },
    { key = "collection",  label = "Collection" },
    { key = "social",      label = "Social" },
    { key = "general",     label = "General" },
}

D.MAX_ACTIVE = 5

local function Elite(ctx)
    local c = ctx.classification
    return c == "elite" or c == "rareelite" or c == "worldboss"
end

local function Rare(ctx)
    local c = ctx.classification
    return c == "rare" or c == "rareelite"
end

local function Grouped()
    return IsInGroup and IsInGroup() and true or false
end

D.LIST = {
    -- Exploration ------------------------------------------------------------
    { id = "wayfarer", category = "exploration", name = "Wayfarer's Road",
      desc = "Uncover 5 hidden places on your world map.",
      icon = "Interface\\Icons\\INV_Misc_Spyglass_02", target = 5, on = "area" },
    { id = "unknown", category = "exploration", name = "Into the Unknown",
      desc = "Set foot in a region your chronicle has never recorded.",
      icon = "Interface\\Icons\\INV_Misc_Map_01", target = 1, on = "zone_new" },
    { id = "errand", category = "exploration", name = "Cartographer's Errand",
      desc = "Note 8 named places you have not visited before.",
      icon = "Interface\\Icons\\INV_Misc_Map02", target = 8, on = "subzone" },

    -- Combat -----------------------------------------------------------------
    { id = "herd", category = "combat", name = "Thin the Herd",
      desc = "Defeat 30 enemies in the open world.",
      icon = "Interface\\Icons\\Ability_DualWield", target = 30, on = "kill" },
    { id = "varied", category = "combat", name = "Varied Prey",
      desc = "Defeat enemies of 5 different creature types.",
      icon = "Interface\\Icons\\Ability_Hunter_SniperShot", target = 5, on = "kill",
      key = function(ctx) return ctx.creatureType end },
    { id = "giant", category = "combat", name = "Giant Slayer",
      desc = "Defeat 3 elite enemies in the open world.",
      icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike", target = 3, on = "kill", test = Elite },
    { id = "legend", category = "combat", name = "Hunter of Legends",
      desc = "Slay a rare creature.",
      icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", target = 1, on = "kill", test = Rare },
    { id = "tracker", category = "combat", name = "Rare Tracker",
      desc = "Spot 3 rare creatures you have never seen before.",
      icon = "Interface\\Icons\\Ability_Hunter_EagleEye", target = 3, on = "rare_seen" },

    -- Dungeons ---------------------------------------------------------------
    { id = "delver", category = "dungeons", name = "Delver",
      desc = "Complete a dungeon.",
      icon = "Interface\\Icons\\INV_Misc_Key_03", target = 1, on = "dungeon", minLevel = 10 },
    { id = "flawless", category = "dungeons", name = "Flawless",
      desc = "Complete a dungeon without dying inside it.",
      icon = "Interface\\Icons\\Spell_Holy_DivineProtection", target = 1, on = "dungeon", minLevel = 10,
      test = function(ctx) return ctx.deaths == 0 end },
    { id = "bosshunter", category = "dungeons", name = "Boss Hunter",
      desc = "Defeat 5 dungeon or raid bosses.",
      icon = "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01", target = 5, on = "boss", minLevel = 10 },

    -- Collection -------------------------------------------------------------
    { id = "bestiary", category = "collection", name = "Bestiary Page",
      desc = "Defeat 2 kinds of creature you have never defeated before.",
      icon = "Interface\\Icons\\INV_Misc_Book_11", target = 2, on = "kill",
      test = function(ctx) return ctx.newType end },
    { id = "collector", category = "collection", name = "Rare Collector",
      desc = "Add 2 new rare creatures to your chronicle.",
      icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04", target = 2, on = "rare_seen" },

    -- Social -----------------------------------------------------------------
    { id = "fellowship", category = "social", name = "Fellowship",
      desc = "Complete 5 quests while in a group.",
      icon = "Interface\\Icons\\Spell_Holy_PrayerOfSpirit", target = 5, on = "quest", test = Grouped },
    { id = "shoulder", category = "social", name = "Shoulder to Shoulder",
      desc = "Defeat 20 enemies while in a group.",
      icon = "Interface\\Icons\\Ability_Warrior_BattleShout", target = 20, on = "kill", test = Grouped },
    { id = "courtesy", category = "social", name = "Courtesy of the Road",
      desc = "Target 3 different adventurers and /wave to them.",
      icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", target = 3, on = "emote",
      test = function(ctx) return ctx.token == "WAVE" and ctx.targetIsPlayer end,
      key = function(ctx) return ctx.targetGUID end },

    -- General ----------------------------------------------------------------
    { id = "diligent", category = "general", name = "Diligent",
      desc = "Complete 10 quests.",
      icon = "Interface\\Icons\\INV_Misc_Note_02", target = 10, on = "quest" },
    { id = "localhero", category = "general", name = "Local Hero",
      desc = "Complete 5 quests in the region where you accepted this challenge.",
      icon = "Interface\\Icons\\INV_Misc_Note_06", target = 5, on = "quest",
      test = function(ctx, state) return state.zone ~= nil and state.zone ~= "" and ctx.zone == state.zone end },
    { id = "survivor", category = "general", name = "Survivor",
      desc = "Gain a level without dying. Dying fails the challenge.",
      icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight", target = 1, on = "level", failOn = "death" },
}

D.byId = {}
for i, def in ipairs(D.LIST) do
    def.order = i
    D.byId[def.id] = def
end
