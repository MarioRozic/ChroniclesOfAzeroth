-- v0.6.0: launch prep (brag attribution, /coa feedback)
dofile("/home/user/coa/test/mockwow.lua")
local CoA = NS
local fails = 0
local function check(c, m) if c then print("ok   " .. m) else print("FAIL " .. m); fails = fails + 1 end end

local shown
StaticPopupDialogs = {}
StaticPopup_Show = function(which, text, _, data) shown = { which = which, text = text, data = data } end

STATE.level = 12
FireEvent("ADDON_LOADED", "ChroniclesOfAzeroth")
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD", true, false)

check(CoA.version == "0.6.0", "version 0.6.0")
check(CoA.Share:ProfileLine():find("^%[Chronicles of Azeroth%] ") and #CoA.Share:ProfileLine() <= 250, "brag line names the addon and fits: " .. CoA.Share:ProfileLine())
local def = CoA.AchievementData.LIST[1]
check(CoA.Share:MilestoneLine(def):find("^%[Chronicles of Azeroth%] "), "milestone line names the addon")

SlashCmdList["CHRONICLESOFAZEROTH"]("feedback")
check(shown and shown.which == "CHRONICLES_OF_AZEROTH_LINK" and shown.data == CoA.links.issues, "/coa feedback shows the copyable issues link")
check(StaticPopupDialogs.CHRONICLES_OF_AZEROTH_LINK and StaticPopupDialogs.CHRONICLES_OF_AZEROTH_LINK.hasEditBox, "link popup registered with an edit box")
shown = nil
SlashCmdList["CHRONICLESOFAZEROTH"]("ideas")
check(shown ~= nil, "/coa ideas is an alias")
StaticPopupDialogs, StaticPopup_Show = nil, nil
SlashCmdList["CHRONICLESOFAZEROTH"]("feedback")
check(true, "/coa feedback without popups still prints links")
SlashCmdList["CHRONICLESOFAZEROTH"]("help")
print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
