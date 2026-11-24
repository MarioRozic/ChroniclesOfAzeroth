-- v0.5.0: sharing (announcements, brag, inspect)
dofile("/home/user/coa/test/mockwow.lua")
local CoA = NS
local fails = 0
local function check(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end

STATE.level = 12
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD", true, false)
local Share = CoA.Share
check(Share.prefixOK, "addon prefix registered")
local set = CoA.db.settings.share
check(set.announceGuild == false and set.announceParty == false and set.allowInspect == true, "announcements off by default, inspect allowed")

MOCK_DEFER = true
local function kill(n)
  STATE.gt = STATE.gt + 10
  local guid = "Creature-0-1-1-1-" .. n .. "-" .. n
  UNITS.target = { guid = guid, name = "Mob" .. n, ctype = "Beast", class = "normal", combat = true }
  FireEvent("PLAYER_TARGET_CHANGED")
  FireEvent("PARTY_KILL", "Player-1-0001", guid)
end

-- 1. Announcements ---------------------------------------------------------------
kill(1); RunTimers()
check(CoA.Achievements:IsUnlocked("first_blood") and #CHAT_SENT == 0, "nothing announced while announcements are off")
set.announceGuild = true; set.announceParty = true
STATE.guild = true; STATE.group = true
local L = CoA.AchievementData.LIST
local function count(t) local g, p = 0, 0 for _, m in ipairs(CHAT_SENT) do if m.chatType == "GUILD" then g = g + 1 elseif m.chatType == "PARTY" then p = p + 1 end end return g, p end
CoA.Achievements:Unlock(L[20]); RunTimers()
local guild, party = count()
check(guild == 1 and party == 1, "one line each to guild and party: " .. (CHAT_SENT[1] and CHAT_SENT[1].msg or "none"))
check(CHAT_SENT[1] and CHAT_SENT[1].msg:find("^%[Chronicles of Azeroth%] Mara earned the milestone") and #CHAT_SENT[1].msg <= 255, "announcement text fits a chat line")
local before = #CHAT_SENT
CoA.Achievements:Unlock(L[21]); RunTimers()
check(#CHAT_SENT == before, "second announcement within a minute is held back")
STATE.now = STATE.now + 120
CoA.Achievements:Unlock(L[22]); CoA.Achievements:Unlock(L[23]); RunTimers()
check(#CHAT_SENT == before + 2 and CHAT_SENT[#CHAT_SENT].msg:find("earned 2 milestones"), "two unlocks gathered into one line: " .. tostring(CHAT_SENT[#CHAT_SENT].msg))
-- quiet unlocks (login catch-up) are never announced
before = #CHAT_SENT
STATE.now = STATE.now + 120
CoA.Achievements:Unlock(CoA.AchievementData.LIST[24], true)
RunTimers()
check(#CHAT_SENT == before, "quiet unlocks are not announced")
-- combat holds the line until combat ends
STATE.now = STATE.now + 120
STATE.combat = true
CoA.Achievements:Unlock(CoA.AchievementData.LIST[25])
RunTimers()
check(#CHAT_SENT == before, "held during combat")
STATE.combat = false
FireEvent("PLAYER_REGEN_ENABLED")
RunTimers()
check(#CHAT_SENT == before + 2, "sent after combat")
-- hourly cap: 5 per channel
for i = 1, 6 do STATE.now = STATE.now + 120; CoA.Achievements:Unlock(L[25 + i]); RunTimers() end
local g = count()
check(g == 5, "at most 5 guild lines an hour (" .. g .. ")")

-- 2. Brag ---------------------------------------------------------------------------
before = #CHAT_SENT
check(Share:Brag(Share:ProfileLine(), "SAY") and #CHAT_SENT == before, "brag to say sends nothing itself")
check(CHAT_OPENED[#CHAT_OPENED] and CHAT_OPENED[#CHAT_OPENED]:find("^/s %[Chronicles of Azeroth%]"), "brag to say opens the chat box with /s")
print("     chat box: " .. tostring(CHAT_OPENED[#CHAT_OPENED]))
STATE.guild = false
check(not Share:Brag(Share:ProfileLine(), "GUILD"), "brag to guild refused when not in a guild")
print("     brag: " .. CHAT_SENT[#CHAT_SENT].msg)

-- 3. Inspect ------------------------------------------------------------------------
local profile = Share:BuildProfile()
local parsed = Share.ParseProfile(profile)
check(parsed.n == "Mara" and parsed.k == CoA.char.stats.kills and parsed.unlocked.first_blood, "profile round-trips")

-- request to a target
UNITS.target = { guid = "Player-1-0042", name = "Thrall", player = true, friendly = true }
local ok = Share:InspectTarget()
RunTimers(0.5)
check(ok and ADDON_SENT[#ADDON_SENT].msg == "Q" and ADDON_SENT[#ADDON_SENT].target == "Thrall"
  and ADDON_SENT[#ADDON_SENT].chatType == "WHISPER", "inspect request whispered to target")
check(Share.fellows.Thrall.status == "waiting", "waiting for an answer")

-- Thrall answers with a long profile in chunks (out of order)
local theirs = profile:gsub("n=Mara", "n=Thrall"):gsub("u=", "u=zzz_extra,") .. string.rep("x", 0)
local CH = 240
local n = math.ceil(#theirs / CH)
check(n >= 2, "profile needs " .. n .. " chunks")
for i = n, 1, -1 do
  FireEvent("CHAT_MSG_ADDON", "CoAChron", "P" .. i .. "/" .. n .. ":" .. theirs:sub((i - 1) * CH + 1, i * CH), "WHISPER", "Thrall")
end
check(Share.fellows.Thrall.status == "ok" and Share.fellows.Thrall.profile.n == "Thrall", "chunks reassembled")

-- answering a request: chunked, paced, rate-limited, refused when private
local sent0 = #ADDON_SENT
FireEvent("CHAT_MSG_ADDON", "CoAChron", "Q", "WHISPER", "Jaina")
RunTimers(0.5)
local chunks = #ADDON_SENT - sent0
check(chunks >= 2 and ADDON_SENT[sent0 + 1].msg:find("^P1/"), "answered with " .. chunks .. " chunks")
for i = sent0 + 1, #ADDON_SENT do
  check(#ADDON_SENT[i].msg <= 255, "chunk " .. (i - sent0) .. " fits (" .. #ADDON_SENT[i].msg .. " bytes)")
end
FireEvent("CHAT_MSG_ADDON", "CoAChron", "Q", "WHISPER", "Jaina")
RunTimers(0.5)
check(#ADDON_SENT == sent0 + chunks, "repeat request within 20 s ignored")
-- throttled sends are retried
sent0 = #ADDON_SENT
STATE.throttle = 2
FireEvent("CHAT_MSG_ADDON", "CoAChron", "Q", "WHISPER", "Anduin")
RunTimers()
check(#ADDON_SENT - sent0 == chunks, "throttled chunks retried until all sent")
set.allowInspect = false
FireEvent("CHAT_MSG_ADDON", "CoAChron", "Q", "WHISPER", "Sylvanas")
RunTimers()
check(ADDON_SENT[#ADDON_SENT].msg == "N", "private chronicle answers N")
-- unsolicited answers are ignored; messages from other prefixes too
FireEvent("CHAT_MSG_ADDON", "CoAChron", "P1/1:n=Fake", "WHISPER", "Stranger")
check(Share.fellows.Stranger == nil, "unsolicited profile ignored")
-- no reply -> timeout
UNITS.target = { guid = "Player-1-0099", name = "Garrosh", player = true }
Share:InspectTarget()
RunTimers()
check(Share.fellows.Garrosh.status == "noreply", "no answer after timeout")

-- UI ----------------------------------------------------------------------------------
CoA.UI:Show("fellows")
local page = CoA.UI.frame.pageFrames.fellows
CoA.UI:SelectFellow("Thrall")
check(page.list.selectedKey == "Thrall" and page.doc.area:IsShown(), "Fellows page shows Thrall")
local foundThrall = false
for _, fs in ipairs(page.doc.pools.pairR or {}) do if fs:IsShown() and fs:GetText() == "Thrall" then foundThrall = true end end
check(foundThrall, "comparison has a Thrall column")
page.list.selectedKey = "settings"; page:Render()
check(page.settings:IsShown() and page.checkGuild:GetChecked() == true, "settings page reflects options")
-- a real check button flips its own state before OnClick runs
if not page.checkParty.tick then page.checkParty:SetChecked(not page.checkParty:GetChecked()) end
page.checkParty._scripts.OnClick(page.checkParty)
check(set.announceParty == false, "toggling party announcements")
-- Brag buttons in footers
CoA.UI:Show("overview")
check(CoA.UI.frame.footer[1]:GetText() == "Brag", "Character page has Brag")
CoA.UI:Show("achievements")
check(CoA.UI.frame.footer[1]:GetText() == "Brag" and CoA.UI.frame.footer[2]:GetText() == "Change Title", "Milestones page has Brag and Change Title")
STATE.group = true
local b = CoA.UI.frame.footer[1]
if b:IsEnabled() ~= false then
  b._scripts.OnClick(b)
  local menu = ChroniclesOfAzerothChannelMenu
  check(menu and menu:IsShown(), "channel menu opens")
  before = #CHAT_SENT
  menu.buttons[2]._scripts.OnClick(menu.buttons[2])
  check(#CHAT_SENT == before + 1 and CHAT_SENT[#CHAT_SENT].chatType == "PARTY", "brag to party from the menu")
end
-- v0.5.1: the client blocks one of our chat sends -> fall back to the chat box
FireEvent("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "SendChatMessage()")
check(not Share.chatBlocked, "other addons' blocked actions are ignored")
FireEvent("ADDON_ACTION_BLOCKED", CoA.name, "C_ChatInfo.SendChatMessage()")
check(Share.chatBlocked, "our blocked chat send is noticed")
STATE.guild = true
before = #CHAT_SENT
local opened = #CHAT_OPENED
check(Share:Brag(Share:ProfileLine(), "GUILD") and #CHAT_SENT == before and #CHAT_OPENED == opened + 1
  and CHAT_OPENED[#CHAT_OPENED]:find("^/g "), "after a block, guild brag goes to the chat box")
STATE.now = STATE.now + 7200
CoA.Achievements:Unlock(L[40]); RunTimers()
check(#CHAT_SENT == before, "announcements pause after a block")
SlashCmdList["CHRONICLESOFAZEROTH"]("status")
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
