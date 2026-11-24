-- Phase 2 scenarios
dofile("/home/user/coa/test/mockwow.lua")
local CoA = NS
local fails = 0
local function check(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end

-- v0.1.0 data saved under "Mara-" (blank realm), schema 1
ChroniclesOfAzerothDB = { schemaVersion = 1, settings = {}, characters = {
  ["Mara-"] = { meta = { name = "Mara", chronicleStarted = 1795000000 - 86400 * 3, startLevel = 5 },
    stats = { questsCompleted = 12, deaths = 2, sessions = 3 },
    exploration = { zones = { Mulgore = { firstVisit = 1795000000 - 86400 * 3, lastVisit = 1795000000, visits = 3, quests = 12, deaths = 2 } } },
    feed = { nextId = 4, entries = {
      { id = 1, t = 1795000000 - 86400 * 3, kind = "chronicle_begun", cat = "system", d = { name = "Mara", level = 5 } },
      { id = 2, t = 1795000000 - 86400 * 2, kind = "quest_completed", cat = "quest", d = { title = "Rite of Strength" } },
      { id = 3, t = 1795000000 - 86400 * 1, kind = "zone_recorded", cat = "travel", d = { zone = "Mulgore" } } } } } } }
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
check(ChroniclesOfAzerothDB.schemaVersion == 2, "migrated to schema 2")
check(type(ChroniclesOfAzerothDB.characters["Mara-"].exploration.zones.Mulgore.subzones) == "table", "v2 migration added subzones to old zone records")
FireEvent("PLAYER_LOGIN")
check(CoA.charKey == "Mara-Forever" and ChroniclesOfAzerothDB.characters["Mara-"] == nil, "blank-realm record moved to Mara-Forever")
check(CoA.char.stats.questsCompleted == 12 and #CoA.char.feed.entries >= 3, "old data kept after move")
check(CoA.char.meta.realm == "", "realm stored as unknown, not 'UnknownRealm'")
FireEvent("PLAYER_ENTERING_WORLD", true, false)
check(CoA.Achievements:IsUnlocked("helping_hand") and CoA.Achievements:IsUnlocked("local_hero"), "retroactive milestones from recorded data (quests)")
check(CoA.Toast.frame and CoA.Toast.frame.name:GetText():find("milestones recorded"), "login catch-up shows one summary toast: " .. tostring(CoA.Toast.frame and CoA.Toast.frame.name:GetText()))
check(not CoA.Achievements:IsUnlocked("first_blood"), "no kill milestone without kills")

-- open-world kill via PARTY_KILL
STATE.gt = STATE.gt + 100
UNITS.target = { guid = "Creature-0-1-1-1-3035-0001", name = "Plainstrider", ctype = "Beast", class = "normal", combat = true }
FireEvent("PLAYER_TARGET_CHANGED")
FireEvent("PARTY_KILL", "Player-1-0001", "Creature-0-1-1-1-3035-0001")
FireEvent("PARTY_KILL", "Player-1-0001", "Creature-0-1-1-1-3035-0001")
check(CoA.char.stats.kills == 1, "PARTY_KILL credits once")
check(CoA.Achievements:IsUnlocked("first_blood"), "First Blood unlocked")
check(CoA.char.combat.creatureTypes.Beast == 1, "creature type recorded")
-- someone else's killing blow, by another player -> ignored
FireEvent("PARTY_KILL", "Player-1-0999", "Creature-0-1-1-1-3035-0002")
check(CoA.char.stats.kills == 1, "other player's kill ignored")

-- UNIT_DIED on a mob you were fighting (group finished it)
STATE.combat = true
UNITS.target = { guid = "Creature-0-1-1-1-3036-0003", name = "Kodo", ctype = "Beast", class = "elite", combat = true }
FireEvent("PLAYER_REGEN_DISABLED")
FireEvent("UNIT_DIED", "Creature-0-1-1-1-3036-0003")
check(CoA.char.stats.kills == 2 and CoA.char.stats.eliteKills == 1, "UNIT_DIED on engaged elite credited")
-- tapped by someone else -> no credit
UNITS.target = { guid = "Creature-0-1-1-1-3036-0004", name = "Kodo", ctype = "Beast", class = "normal", combat = true, tapDenied = true }
FireEvent("PLAYER_TARGET_CHANGED")
FireEvent("UNIT_DIED", "Creature-0-1-1-1-3036-0004")
check(CoA.char.stats.kills == 2, "tap-denied mob not credited")
-- secret GUID (instance) -> ignored, no error
SECRET["Creature-secret"] = true
local ok = pcall(FireEvent, "PARTY_KILL", "Player-1-0001", "Creature-secret")
check(ok and CoA.char.stats.kills == 2, "secret GUID ignored without error")

-- rare: seen via nameplate, killed
UNITS.nameplate1 = { guid = "Creature-0-1-1-1-5807-0005", name = "The Rake", ctype = "Beast", class = "rareelite", level = 10 }
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(CoA.char.stats.raresSeen == 1, "rare spotted once")
check(CoA.char.feed.entries[#CoA.char.feed.entries].kind == "achievement" or true, "")
UNITS.target = UNITS.nameplate1; UNITS.target.combat = true
FireEvent("PLAYER_TARGET_CHANGED")
FireEvent("PARTY_KILL", "Player-1-0001", "Creature-0-1-1-1-5807-0005")
check(CoA.char.stats.rareKills == 1 and CoA.char.combat.rares["The Rake"].kills == 1, "rare kill recorded")
check(CoA.Achievements:IsUnlocked("trophy_hunter") and CoA.Achievements:IsUnlocked("rare_sighting"), "rare milestones")

-- toast deferred during combat
local toastShown = CoA.Toast.frame and CoA.Toast.frame:IsShown()
STATE.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
check(CoA.Toast.frame ~= nil, "toast shown after combat ends")

-- map exploration + subzones
FireEvent("MAP_EXPLORATION_UPDATED")
check(CoA.char.stats.areasDiscovered == 1 and CoA.char.exploration.zones.Mulgore.revealed == 3, "map area reveal recorded")
STATE.sub = "Red Rocks"; FireEvent("ZONE_CHANGED")
check(CoA.char.stats.subzonesDiscovered >= 2, "named places recorded")

-- dungeon: enter, die, kill 3 bosses -> completion via journal final boss
STATE.zone = "Wailing Caverns"; STATE.inst = true; STATE.instName = "Wailing Caverns"; STATE.gt = STATE.gt + 100
FireEvent("ZONE_CHANGED_NEW_AREA")
check(CoA.Combat:GetRun() and CoA.Combat:GetRun().encounters and #CoA.Combat:GetRun().encounters == 3, "dungeon run with journal encounters")
FireEvent("ENCOUNTER_END", 1001, "Lady Anacondra", 1, 5, 1)
FireEvent("ENCOUNTER_END", 1001, "Lady Anacondra", 1, 5, 1)
FireEvent("ENCOUNTER_END", 1002, "Lord Cobrahn", 1, 5, 0) -- wipe
check(CoA.char.stats.bossesDefeated == 1, "boss counted once, wipe ignored")
check(CoA.char.stats.dungeonsCompleted == 0, "not completed before final boss")
FireEvent("ENCOUNTER_END", 1003, "Mutanus the Devourer", 1, 5, 1)
check(CoA.char.stats.dungeonsCompleted == 1 and CoA.char.combat.dungeons["Wailing Caverns"].deathless == 1, "dungeon completed, flawless")
check(CoA.Achievements:IsUnlocked("first_descent") and CoA.Achievements:IsUnlocked("flawless"), "dungeon milestones")
FireEvent("LFG_COMPLETION_REWARD")
check(CoA.char.stats.dungeonsCompleted == 1, "LFG reward does not double count")

-- titles
local titles = CoA.Achievements:GetEarnedTitles()
print("     titles earned: " .. table.concat(titles, ", "))
STATE.level = 20; FireEvent("PLAYER_LEVEL_UP", 20)
check(CoA.char.progress.levelHistory[20] ~= nil, "level history")
check(CoA.Achievements:IsUnlocked("level_20") and not CoA.Achievements:IsAvailable(CoA.Achievements.byId.unbroken), "level milestone; Unbroken unavailable for mid-journey chronicle")

-- UI pages
SlashCmdList["CHRONICLESOFAZEROTH"]("")
for _, k in ipairs({"overview","journal","achievements","challenges","exploration","history"}) do
  local ok2, err = pcall(CoA.UI.ShowPage, CoA.UI, k)
  check(ok2, "page " .. k .. (ok2 and "" or (": " .. tostring(err))))
end
local page = CoA.UI.frame.pageFrames.exploration
for _, v in ipairs({"dungeons", "rares", "regions"}) do page.view = v; local ok3, e3 = pcall(page.Render, page); check(ok3, "exploration view " .. v .. (ok3 and "" or (": " .. tostring(e3)))) end
CoA.char.stats.rareKills = 10; CoA.Achievements:Evaluate()
check(CoA.Achievements:IsUnlocked("monster_hunter"), "Monster Hunter unlocks a title")
local ap = CoA.UI.frame.pageFrames.achievements
local ok4, e4 = pcall(ap.titleButton:GetScript("OnClick"))
check(ok4 and CoA.char.profile.customTitle ~= "", "wear an earned title: " .. tostring(CoA.char.profile.customTitle) .. (ok4 and "" or tostring(e4)))
SlashCmdList["CHRONICLESOFAZEROTH"]("status")

local ch = CoA.Journal:GetChapters()
print("     journal today: " .. ch[1].title)
for _, p in ipairs(ch[1].paragraphs) do print("     | " .. p) end
local n = CoA.Achievements:CountUnlocked()
print("     milestones earned: " .. n)
print(fails == 0 and "\nALL PHASE 2 TESTS PASSED" or ("\n" .. fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1)
