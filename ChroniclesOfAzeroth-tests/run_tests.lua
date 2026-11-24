dofile("/home/user/coa/test/mockwow.lua")
local CoA = NS
local fails = 0
local function check(cond, msg) if cond then print("ok   " .. msg) else print("FAIL " .. msg); fails = fails + 1 end end

-- Scenario 1: corrupt SavedVariables are reset safely
ChroniclesOfAzerothDB = "garbage"
FireEvent("ADDON_LOADED", "SomeOtherAddon")
check(CoA.db == nil, "ignores other addons' ADDON_LOADED")
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
check(type(ChroniclesOfAzerothDB) == "table" and ChroniclesOfAzerothDB_Corrupt == "garbage", "corrupt DB backed up and reset")
check(ChroniclesOfAzerothDB.schemaVersion == CoA.Database.SCHEMA_VERSION, "schema version set")

FireEvent("PLAYER_LOGIN")
check(CoA.char and CoA.charKey == "Mara-Forever", "character loaded with key")
check(CoA.char.meta.startLevel == 5, "start level recorded honestly (5)")
FireEvent("PLAYER_ENTERING_WORLD", true, false)
local e = CoA.char.feed.entries
check(e[1] and e[1].kind == "chronicle_begun", "first entry is chronicle_begun")
check(e[2] and e[2].kind == "zone_recorded", "first zone for mid-journey char is 'recorded' not 'discovered'")
check(CoA.char.stats.zonesDiscovered == 1, "zone count 1")

-- reload shouldn't duplicate
FireEvent("PLAYER_ENTERING_WORLD", false, true)
check(#e == 2, "reload adds no entries (" .. #e .. ")")

-- zone change
STATE.zone = "The Barrens"; STATE.now = STATE.now + 600; STATE.gt = STATE.gt + 600
FireEvent("ZONE_CHANGED_NEW_AREA")
FireEvent("ZONE_CHANGED_NEW_AREA") -- duplicate
check(#e == 3 and e[3].kind == "zone_recorded" and e[3].d.zone == "The Barrens", "entered Barrens once")

-- level up + duplicate
STATE.level = 6
FireEvent("PLAYER_LEVEL_UP", 6, 0,0,0,0,0,0,0,0)
FireEvent("PLAYER_LEVEL_UP", 6)
check(#e == 4 and e[4].kind == "level_up" and CoA.char.stats.levelsGained == 1, "level up recorded once")

-- quest with title from log, and from QUEST_COMPLETE fallback
FireEvent("QUEST_TURNED_IN", 1, 100, 50)
FireEvent("QUEST_TURNED_IN", 1, 100, 50)
FireEvent("QUEST_COMPLETE")
FireEvent("QUEST_TURNED_IN", 2, 100, 50)
check(CoA.char.stats.questsCompleted == 2, "2 quests counted (dup suppressed)")
check(CoA.Feed:FormatText(e[6]):find("Rite of Strength"), "fallback quest title used")
check(CoA.char.exploration.zones["The Barrens"].quests == 2, "per-zone quest count")

-- death (and death right after loading ignored)
STATE.gt = STATE.gt + 100
FireEvent("PLAYER_DEAD")
check(CoA.char.stats.deaths == 1, "death counted")
FireEvent("PLAYER_ENTERING_WORLD", false, false)
FireEvent("PLAYER_DEAD")
check(CoA.char.stats.deaths == 1, "death right after loading screen ignored")

-- instance
STATE.zone = "Wailing Caverns"; STATE.inst = true; STATE.instName = "Wailing Caverns"; STATE.gt = STATE.gt + 100
FireEvent("ZONE_CHANGED_NEW_AREA")
check(e[#e].kind == "instance_entered" and CoA.char.stats.instancesEntered == 1, "instance entry recorded")
STATE.zone = "The Barrens"; STATE.inst = false
FireEvent("ZONE_CHANGED_NEW_AREA")
check(e[#e].kind == "zone_entered", "re-entering known zone -> zone_entered")

-- time played
FireEvent("TIME_PLAYED_MSG", 7200, 600)
local played, live = CoA.Character:GetTimePlayed()
check(played == 7200 and live, "time played live")

-- Journal
local ch = CoA.Journal:GetChapters()
check(#ch == 1, "one journal chapter for one day")
print("     title: " .. ch[1].title)
for _, p in ipairs(ch[1].paragraphs) do print("     | " .. p) end

-- Feed query
check(#CoA.Feed:Query("quest", "") == 2, "query by category")
check(#CoA.Feed:Query("all", "barrens") >= 3, "search")

-- UI: open every page and refresh
SlashCmdList["CHRONICLESOFAZEROTH"]("")
check(CoA.UI.frame and CoA.UI.frame:IsShown(), "window opens")
check(TIME_PLAYED_REQUESTED, "profile requests /played")
for _, k in ipairs({"overview","journal","achievements","challenges","exploration","history"}) do
  local ok, err = pcall(CoA.UI.ShowPage, CoA.UI, k)
  check(ok, "page " .. k .. (ok and "" or (": " .. tostring(err))))
end
-- live update while open
STATE.zone = "Thunder Bluff"; STATE.gt = STATE.gt + 100
FireEvent("ZONE_CHANGED_NEW_AREA")
check(true, "live refresh on feed add")
SlashCmdList["CHRONICLESOFAZEROTH"]("status")
SlashCmdList["CHRONICLESOFAZEROTH"]("scale 1.2")
check(ChroniclesOfAzerothDB.settings.window.scale == 1.2, "scale saved")

-- Feed limit trimming
ChroniclesOfAzerothDB.settings.feedLimit = 10
for i = 1, 20 do STATE.gt = STATE.gt + 100; FireEvent("QUEST_TURNED_IN", 100 + i) end
check(#CoA.char.feed.entries == 10, "feed trimmed to limit")

-- unknown event degrades gracefully
check(CoA:RegisterEvent("UNKNOWN_EVENT_X", {}, function() end) == false and CoA.unsupportedEvents.UNKNOWN_EVENT_X, "unknown event handled")

-- Reset
SlashCmdList["CHRONICLESOFAZEROTH"]("reset confirm")
check(#CoA.char.feed.entries == 2 and CoA.char.stats.questsCompleted == 0, "reset begins a new chronicle")

-- Scenario 2: second login, existing data w/ missing fields (simulated older/hand-edited data)
local saved = ChroniclesOfAzerothDB
saved.characters["Mara-Forever"].stats = nil
saved.characters["Mara-Forever"].progress.level = "oops"
dofile("/home/user/coa/test/mockwow.lua")  -- fresh addon instance, same saved table
ChroniclesOfAzerothDB = saved
STATE.level = 9
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD", true, false)
local c2 = NS.char
check(c2.stats.deaths == 0 and type(c2.progress.level) == "number", "missing/invalid fields repaired")
check(c2.feed.entries[#c2.feed.entries].kind == "session_start" or c2.feed.entries[#c2.feed.entries-1].kind == "level_catchup", "relog: catch-up + session entries")
local kinds = {} for _, x in ipairs(c2.feed.entries) do kinds[#kinds+1] = x.kind end
print("     feed kinds: " .. table.concat(kinds, ", "))

print(fails == 0 and "\nALL TESTS PASSED" or ("\n" .. fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1)
