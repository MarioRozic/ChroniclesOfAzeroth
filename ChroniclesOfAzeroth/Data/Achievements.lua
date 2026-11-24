--[[
  Chronicles of Azeroth - Data/Achievements.lua  (Phase 2)

  Milestone definitions. Independent of Blizzard's achievement system.

  Fields:
    id        unique, never renamed (it is the saved-data key)
    category  one of CATEGORIES below
    name, desc
    icon      an Interface\Icons texture
    target    number to reach
    progress  function(char) -> current number (from recorded data only)
    title     optional title reward, worn as "<Name>, <title>" in the tome
    requires  optional function(char) -> bool; when false the milestone is
              shown as unavailable instead of being judged on missing data

  Every condition reads data the addon actually records, so a milestone can
  never be unlocked by something that was not detected.
]]

local _, CoA = ...
local Data = {}
CoA.AchievementData = Data

Data.CATEGORIES = {
    { key = "exploration", label = "Exploration" },
    { key = "combat",      label = "Combat" },
    { key = "dungeons",    label = "Dungeons" },
    { key = "progression", label = "Progression" },
    { key = "deeds",       label = "Deeds" },
    { key = "adversity",   label = "Adversity" },
    { key = "chronicle",   label = "Chronicle" },
}

local I = "Interface\\Icons\\"

local function Stat(name)
    return function(char) return char.stats[name] or 0 end
end

local function Level(char) return char.progress.level or 1 end

local function Regions(char)
    local n = 0
    for _, z in pairs(char.exploration.zones) do
        if not z.isInstance then n = n + 1 end
    end
    return n
end

local function Continents(char)
    local seen, n = {}, 0
    for _, z in pairs(char.exploration.zones) do
        if z.continent and not z.isInstance and not seen[z.continent] then
            seen[z.continent] = true
            n = n + 1
        end
    end
    return n
end

local function MostSubzonesInOneZone(char)
    local best = 0
    for _, z in pairs(char.exploration.zones) do
        local n = 0
        for _ in pairs(z.subzones or {}) do n = n + 1 end
        if n > best then best = n end
    end
    return best
end

local function MostQuestsInOneZone(char)
    local best = 0
    for _, z in pairs(char.exploration.zones) do
        if (z.quests or 0) > best then best = z.quests end
    end
    return best
end

local function CreatureTypes(char)
    local n = 0
    for _ in pairs(char.combat.creatureTypes) do n = n + 1 end
    return n
end

local function DistinctDungeons(char)
    local n = 0
    for _ in pairs(char.combat.dungeons) do n = n + 1 end
    return n
end

local function DeathlessDungeons(char)
    local n = 0
    for _, d in pairs(char.combat.dungeons) do n = n + (d.deathless or 0) end
    return n
end

local function DaysRecorded(char)
    local days, n = {}, 0
    for _, e in ipairs(char.feed.entries) do
        local k = date("%Y-%m-%d", e.t)
        if not days[k] then days[k] = true; n = n + 1 end
    end
    return n
end

-- Only fair for characters whose whole journey was recorded.
local function RecordedFromLevelOne(char) return char.meta.startLevel == 1 end

Data.LIST = {
    -- Exploration ----------------------------------------------------------
    { id = "first_steps", category = "exploration", name = "First Steps", target = 1,
      desc = "Record your first region of Azeroth.", icon = I .. "INV_Misc_Map_01", progress = Regions },
    { id = "wanderer", category = "exploration", name = "Wanderer", target = 5,
      desc = "Visit 5 different regions.", icon = I .. "Ability_Tracking", progress = Regions },
    { id = "world_traveler", category = "exploration", name = "World Traveler", target = 15,
      desc = "Visit 15 different regions.", icon = I .. "Spell_Nature_Swiftness", progress = Regions },
    { id = "azeroth_explorer", category = "exploration", name = "Azeroth Explorer", target = 30,
      desc = "Visit 30 different regions.", icon = I .. "Spell_Nature_FarSight", progress = Regions,
      title = "the Explorer" },
    { id = "across_the_sea", category = "exploration", name = "Across the Great Sea", target = 2,
      desc = "Set foot on two different continents.", icon = I .. "INV_Misc_Map_01", progress = Continents },
    { id = "pathfinder", category = "exploration", name = "Pathfinder", target = 10,
      desc = "Uncover 10 hidden places on the world map.", icon = I .. "INV_Misc_Spyglass_02",
      progress = Stat("areasDiscovered") },
    { id = "cartographer", category = "exploration", name = "Cartographer", target = 50,
      desc = "Uncover 50 hidden places on the world map.", icon = I .. "INV_Misc_Spyglass_02",
      progress = Stat("areasDiscovered") },
    { id = "mapmaker", category = "exploration", name = "Mapmaker of the Realm", target = 150,
      desc = "Uncover 150 hidden places on the world map.", icon = I .. "INV_Misc_Spyglass_02",
      progress = Stat("areasDiscovered"), title = "the Cartographer" },
    { id = "local_guide", category = "exploration", name = "Local Guide", target = 10,
      desc = "Walk through 10 named places within a single region.", icon = I .. "Ability_Tracking",
      progress = MostSubzonesInOneZone },

    -- Combat -------------------------------------------------------------
    { id = "first_blood", category = "combat", name = "First Blood", target = 1,
      desc = "Defeat your first enemy.", icon = I .. "INV_Sword_04", progress = Stat("kills") },
    { id = "slayer", category = "combat", name = "Slayer", target = 100,
      desc = "Defeat 100 enemies.", icon = I .. "Ability_DualWield", progress = Stat("kills") },
    { id = "veteran", category = "combat", name = "Veteran", target = 1000,
      desc = "Defeat 1,000 enemies.", icon = I .. "Ability_Warrior_Savageblow", progress = Stat("kills") },
    { id = "scourge_of_the_wilds", category = "combat", name = "Scourge of the Wilds", target = 5000,
      desc = "Defeat 5,000 enemies.", icon = I .. "Ability_Warrior_Rampage", progress = Stat("kills"),
      title = "the Relentless" },
    { id = "giant_slayer", category = "combat", name = "Giant Slayer", target = 1,
      desc = "Defeat an elite enemy.", icon = I .. "Ability_Warrior_DecisiveStrike", progress = Stat("eliteKills") },
    { id = "elite_hunter", category = "combat", name = "Bane of Champions", target = 50,
      desc = "Defeat 50 elite enemies.", icon = I .. "Ability_Warrior_DecisiveStrike", progress = Stat("eliteKills") },
    { id = "rare_sighting", category = "combat", name = "Rare Sighting", target = 1,
      desc = "Spot a rare creature.", icon = I .. "INV_Misc_Head_Dragon_01", progress = Stat("raresSeen") },
    { id = "rare_collector", category = "combat", name = "Keen Eye", target = 10,
      desc = "Spot 10 different rare creatures.", icon = I .. "INV_Misc_Spyglass_02", progress = Stat("raresSeen") },
    { id = "trophy_hunter", category = "combat", name = "Trophy Hunter", target = 1,
      desc = "Slay a rare creature.", icon = I .. "Ability_Hunter_SniperShot", progress = Stat("rareKills") },
    { id = "monster_hunter", category = "combat", name = "Monster Hunter", target = 10,
      desc = "Slay 10 rare creatures.", icon = I .. "Ability_Hunter_SniperShot", progress = Stat("rareKills"),
      title = "the Monster Hunter" },
    { id = "diverse_foes", category = "combat", name = "Know Thy Enemy", target = 8,
      desc = "Defeat enemies of 8 different creature types.", icon = I .. "INV_Misc_Book_11",
      progress = CreatureTypes },

    -- Dungeons -------------------------------------------------------------
    { id = "into_the_depths", category = "dungeons", name = "Into the Depths", target = 1,
      desc = "Enter your first dungeon.", icon = I .. "Spell_Arcane_PortalOrgrimmar", progress = Stat("instancesEntered") },
    { id = "boss_slayer", category = "dungeons", name = "Boss Slayer", target = 1,
      desc = "Defeat a dungeon boss.", icon = I .. "Ability_Warrior_DecisiveStrike", progress = Stat("bossesDefeated") },
    { id = "bane_of_tyrants", category = "dungeons", name = "Bane of Tyrants", target = 50,
      desc = "Defeat 50 dungeon bosses.", icon = I .. "INV_Misc_Bone_ElfSkull_01", progress = Stat("bossesDefeated"),
      title = "Tyrantsbane" },
    { id = "first_descent", category = "dungeons", name = "First Descent", target = 1,
      desc = "Complete your first dungeon.", icon = I .. "INV_Misc_Key_03", progress = Stat("dungeonsCompleted") },
    { id = "dungeon_veteran", category = "dungeons", name = "Dungeon Veteran", target = 10,
      desc = "Complete 10 dungeons.", icon = I .. "INV_Misc_Key_03", progress = Stat("dungeonsCompleted") },
    { id = "dungeon_master", category = "dungeons", name = "Dungeon Master", target = 25,
      desc = "Complete 25 dungeons.", icon = I .. "INV_Misc_Key_03", progress = Stat("dungeonsCompleted"),
      title = "Dungeon Master" },
    { id = "many_halls", category = "dungeons", name = "Many Halls", target = 5,
      desc = "Complete 5 different dungeons.", icon = I .. "Spell_Arcane_PortalOrgrimmar", progress = DistinctDungeons },
    { id = "flawless", category = "dungeons", name = "Flawless Delve", target = 1,
      desc = "Complete a dungeon without dying once.", icon = I .. "Spell_Holy_PowerWordShield",
      progress = DeathlessDungeons },

    -- Progression ------------------------------------------------------------
    { id = "level_10", category = "progression", name = "A New Beginning", target = 10,
      desc = "Reach level 10.", icon = I .. "Spell_Holy_SurgeOfLight", progress = Level },
    { id = "level_20", category = "progression", name = "Becoming Stronger", target = 20,
      desc = "Reach level 20.", icon = I .. "Spell_Holy_InnerFire", progress = Level },
    { id = "level_30", category = "progression", name = "Tempered by the Road", target = 30,
      desc = "Reach level 30.", icon = I .. "Spell_Holy_BlessingOfStrength", progress = Level },
    { id = "level_40", category = "progression", name = "Veteran Adventurer", target = 40,
      desc = "Reach level 40.", icon = I .. "Spell_Holy_HolyBolt", progress = Level },
    { id = "level_50", category = "progression", name = "Hardened Hero", target = 50,
      desc = "Reach level 50.", icon = I .. "Spell_Holy_DivineIntervention", progress = Level },
    { id = "level_60", category = "progression", name = "Champion of Azeroth", target = 60,
      desc = "Reach level 60.", icon = I .. "INV_Crown_01", progress = Level, title = "Champion of Azeroth" },

    -- Deeds (quests) ---------------------------------------------------------
    { id = "helping_hand", category = "deeds", name = "A Helping Hand", target = 1,
      desc = "Complete a quest.", icon = I .. "INV_Misc_Note_02", progress = Stat("questsCompleted") },
    { id = "trusted_ally", category = "deeds", name = "Trusted Ally", target = 50,
      desc = "Complete 50 quests.", icon = I .. "INV_Letter_15", progress = Stat("questsCompleted") },
    { id = "hero_of_the_people", category = "deeds", name = "Hero of the People", target = 250,
      desc = "Complete 250 quests.", icon = I .. "INV_Scroll_03", progress = Stat("questsCompleted") },
    { id = "living_legend", category = "deeds", name = "Living Legend", target = 500,
      desc = "Complete 500 quests.", icon = I .. "INV_Misc_Book_09", progress = Stat("questsCompleted"),
      title = "the Steadfast" },
    { id = "local_hero", category = "deeds", name = "Local Hero", target = 10,
      desc = "Complete 10 quests in a single region.", icon = I .. "INV_Misc_Bag_10", progress = MostQuestsInOneZone },

    -- Adversity ------------------------------------------------------------
    { id = "not_invincible", category = "adversity", name = "Not So Invincible", target = 1,
      desc = "Fall in battle for the first time.", icon = I .. "INV_Misc_Bone_HumanSkull_01", progress = Stat("deaths") },
    { id = "spirit_walker", category = "adversity", name = "Spirit Walker", target = 25,
      desc = "Return from the spirit world 25 times.", icon = I .. "Spell_Holy_Resurrection", progress = Stat("deaths") },
    { id = "unbroken", category = "adversity", name = "Unbroken", target = 20,
      desc = "Reach level 20 having died no more than 3 times. Requires a chronicle begun at level 1.",
      icon = I .. "Spell_Holy_PowerWordShield", title = "the Unbroken",
      requires = RecordedFromLevelOne,
      progress = function(char) return (char.stats.deaths <= 3) and Level(char) or 0 end },

    -- Chronicle ------------------------------------------------------------
    { id = "dear_diary", category = "chronicle", name = "Dear Diary", target = 7,
      desc = "Fill your journal on 7 different days.", icon = I .. "INV_Misc_Book_11", progress = DaysRecorded },
    { id = "faithful_chronicler", category = "chronicle", name = "Faithful Chronicler", target = 30,
      desc = "Fill your journal on 30 different days.", icon = I .. "INV_Misc_Book_09", progress = DaysRecorded,
      title = "the Chronicler" },
    { id = "campfire_tales", category = "chronicle", name = "Campfire Tales", target = 50,
      desc = "Return to your adventure 50 times.", icon = I .. "Spell_Fire_Fire", progress = Stat("sessions") },
}
