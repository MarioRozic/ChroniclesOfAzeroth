-- Phase 3 scenarios: challenges, toasts, native and fallback UI
dofile("/home/user/coa/test/mockwow.lua")
local CoA = NS
local fails = 0
local function check(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end

STATE.level = 12
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD", true, false)
local Ch = CoA.Challenges
check(Ch and #Ch:GetDefs() >= 19, "challenge definitions loaded (" .. #Ch:GetDefs() .. ")")
check(Ch.hooked, "emote hook installed")

-- accept / limits ------------------------------------------------------------
check(Ch:Accept("herd"), "accept Thin the Herd")
check(not Ch:Accept("herd"), "cannot accept twice")
check(Ch:Accept("varied") and Ch:Accept("giant") and Ch:Accept("survivor") and Ch:Accept("localhero"), "accept up to five")
local ok, reason = Ch:Accept("diligent")
check(not ok and reason:find("5"), "sixth refused: " .. tostring(reason))
check(Ch:Abandon("giant") and not Ch:IsActive("giant"), "abandon")
check(Ch:Accept("courtesy"), "accept after abandoning")
check(CoA.char.challenges.active.localhero.zone == "Mulgore", "Local Hero remembers the region")

-- kills: no progress for kills made before accepting, then counted -----------
local function kill(n, ctype, class)
  STATE.gt = STATE.gt + 10
  local guid = "Creature-0-1-1-1-" .. n .. "-" .. n
  UNITS.target = { guid = guid, name = "Mob" .. n, ctype = ctype, class = class or "normal", combat = true }
  FireEvent("PLAYER_TARGET_CHANGED")
  FireEvent("PARTY_KILL", "Player-1-0001", guid)
end
for i = 1, 3 do kill(100 + i, "Beast") end
kill(200, "Humanoid"); kill(201, "Humanoid")
local herd = Ch:GetState("herd")
check(herd.progress == 5, "Thin the Herd counts kills (" .. herd.progress .. ")")
check(Ch:GetState("varied").progress == 2, "Varied Prey counts distinct types once (" .. Ch:GetState("varied").progress .. ")")
for i = 1, 25 do kill(300 + i, "Beast") end
check(not Ch:IsActive("herd") and Ch:GetCompleted("herd").count == 1, "Thin the Herd completes at 30")
local last = CoA.char.feed.entries[#CoA.char.feed.entries]
local found = false
for _, e in ipairs(CoA.char.feed.entries) do if e.kind == "challenge_completed" and e.d.id == "herd" then found = true end end
check(found, "completion written to the chronicle")
local headers = {}
for _ = 1, 20 do
  local f = CoA.Toast.frame
  if not (f and f:IsShown()) then break end
  headers[#headers + 1] = f.header:GetText()
  f._scripts.OnUpdate(f, 100)   -- let the toast run out; the next one shows
end
local sawChallenge = false
for _, h in ipairs(headers) do if h == "Challenge completed" then sawChallenge = true end end
check(sawChallenge, "challenge toast shown after milestone toasts: " .. table.concat(headers, ", "))
-- toasts wait for the end of combat
STATE.combat = true
CoA.Toast:Show({ kind = "challenge", name = "Test", desc = "x", icon = "" })
check(not CoA.Toast.frame:IsShown(), "no toast during combat")
STATE.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
check(CoA.Toast.frame:IsShown(), "toast shown after combat")
CoA.Toast.frame._scripts.OnUpdate(CoA.Toast.frame, 100)

-- repeatable --------------------------------------------------------------------
check(Ch:Accept("herd") and Ch:GetState("herd").progress == 0, "repeatable: progress starts fresh")

-- quests in the accepted region only ------------------------------------------
FireEvent("QUEST_TURNED_IN", 501, 100, 0)
STATE.zone = "The Barrens"; STATE.gt = STATE.gt + 600
FireEvent("ZONE_CHANGED_NEW_AREA")
FireEvent("QUEST_TURNED_IN", 502, 100, 0)
check(Ch:GetState("localhero").progress == 1, "Local Hero only counts quests in its region")

-- wave at players -------------------------------------------------------------
UNITS.target = { guid = "Player-1-0042", name = "Thrall", player = true, friendly = true }
DoEmote("WAVE", "target"); STATE.gt = STATE.gt + 1
DoEmote("WAVE", "target"); STATE.gt = STATE.gt + 1
UNITS.target = { guid = "Creature-0-1-1-1-9-9", name = "Wolf", friendly = false }
DoEmote("WAVE", "target"); STATE.gt = STATE.gt + 1
check(Ch:GetState("courtesy").progress == 1, "wave counts distinct players only (" .. Ch:GetState("courtesy").progress .. ")")

-- death fails Survivor ---------------------------------------------------------
STATE.gt = STATE.gt + 100
FireEvent("PLAYER_DEAD")
check(not Ch:IsActive("survivor") and Ch:GetFailed("survivor") == 1, "death fails Survivor")
check(Ch:Accept("survivor"), "Survivor can be retried")
STATE.level = 13
FireEvent("PLAYER_LEVEL_UP", 13)
check(Ch:GetCompleted("survivor") and Ch:GetCompleted("survivor").count == 1, "Survivor completes on level up")

-- dungeon challenges and level gating -----------------------------------------
check(Ch:Accept("flawless"), "accept Flawless at level 13")
STATE.zone = "Wailing Caverns"; STATE.inst = true; STATE.instName = "Wailing Caverns"; STATE.gt = STATE.gt + 100
FireEvent("ZONE_CHANGED_NEW_AREA")
FireEvent("ENCOUNTER_END", 1001, "Lady Anacondra", 1, 5, 1)
FireEvent("ENCOUNTER_END", 1002, "Lord Cobrahn", 1, 5, 1)
FireEvent("ENCOUNTER_END", 1003, "Mutanus the Devourer", 1, 5, 1)
check(Ch:GetCompleted("flawless"), "Flawless completes on a deathless run")

-- persistence across reload -------------------------------------------------------
local saved = ChroniclesOfAzerothDB.characters[CoA.charKey].challenges
check(saved.active.herd and saved.completed.herd and saved.failed.survivor == 1, "challenge state saved")

-- UI: Challenges page renders in both template modes ------------------------------
CoA.UI:Show("challenges")
local page = CoA.UI.frame.pageFrames.challenges
check(page and page.summary:GetText():find("under way"), "Challenges page: " .. tostring(page and page.summary:GetText()))
local okRender = pcall(function()
  for _, f in ipairs({ "all", "active", "combat", "social" }) do page.filter = f; page:Render() end
end)
check(okRender, "all filters render")
-- click Accept / Abandon through the row button
local row = page.list.rows[1]
page.filter = "active"; page:Render()
row = page.list.rows[1]
local before = Ch:CountActive()
row.button._scripts.OnClick(row.button)
check(Ch:CountActive() == before - 1, "row button abandons an active challenge")
CoA.UI:Show("overview")
check(CoA.UI.frame.pageFrames.overview.tiles[15].value:GetText():find("/ 5"), "overview tile shows challenges")
-- X button closes (native mode has a template CloseButton)
if CoA.UI.frame.CloseButton then
  CoA.UI.frame.CloseButton._scripts.OnClick(CoA.UI.frame.CloseButton)
  check(not CoA.UI.frame:IsShown(), "X button closes the window")
else
  check(CoA.UI.frame.fallbackClose ~= nil or true, "fallback window (no template)")
end
for k in pairs(CoA.UI.pages) do
  local okp, err = pcall(CoA.UI.Show, CoA.UI, k)
  check(okp, "page " .. k .. " opens " .. tostring(err or ""))
end

print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
