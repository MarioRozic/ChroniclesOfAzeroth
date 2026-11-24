--[[
  Chronicles of Azeroth - Core/Bootstrap.lua  (loaded last)

  Startup sequence:
    ADDON_LOADED (ours)     -> SavedVariables ready: Database:Initialize(),
                               modules' OnInitialize()
    PLAYER_LOGIN            -> character data reliable: LoadCharacter(),
                               modules' OnEnable()
    PLAYER_ENTERING_WORLD   -> every loading screen: modules' OnEnterWorld()
  Also defines the /coa and /chronicles slash commands.
]]

local ADDON_NAME, CoA = ...
local Boot = {}
local firstEnterWorld = true

CoA:RegisterEvent("ADDON_LOADED", Boot, function(_, _, name)
    if name ~= ADDON_NAME then return end
    CoA:UnregisterEvent("ADDON_LOADED", Boot)
    CoA.Database:Initialize()
    CoA:CallModules("OnInitialize")
end)

CoA:RegisterEvent("PLAYER_LOGIN", Boot, function()
    CoA.Database:LoadCharacter()
    CoA:CallModules("OnEnable")
    CoA.ready = true
    if CoA.isFirstInstall then
        CoA:Print("Your chronicle has begun. Type |cffd4af37/coa|r to open it.")
    end
end)

CoA:RegisterEvent("PLAYER_ENTERING_WORLD", Boot, function(_, _, isInitialLogin, isReloadingUi)
    if not CoA.ready then return end
    local isFirst = firstEnterWorld
    firstEnterWorld = false
    -- Older payloads may be nil; then the first event of the session counts
    -- as the login unless it is a /reload.
    if isInitialLogin == nil then isInitialLogin = isFirst and not isReloadingUi end
    CoA:CallModules("OnEnterWorld", isFirst, isInitialLogin and true or false)
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local PAGES = {
    profile = "overview", character = "overview", overview = "overview",
    journal = "journal", achievements = "achievements", milestones = "achievements",
    challenges = "challenges", exploration = "exploration", explore = "exploration",
    history = "history", feed = "history", events = "history",
    fellows = "fellows", sharing = "fellows",
}

local function PrintHelp()
    CoA:Print("commands:")
    local lines = {
        "/coa - open or close the chronicle",
        "/coa journal | profile | challenges | history | exploration - open a chapter",
        "/coa scale <0.6-1.5> - window scale",
        "/coa resetpos - reset window position and size",
        "/coa minimap on|off - show or hide the minimap button",
        "/coa milestones - open the Milestones chapter",
        "/coa toast - preview a milestone notification",
        "/coa sound on|off - notification sounds",
        "/coa brag say|party|guild - post a summary of your journey",
        "/coa inspect - read your target's chronicle (they need the addon too)",
        "/coa announce guild|party on|off - announce new milestones",
        "/coa feedback - report a bug or suggest a milestone or challenge",
        "/coa status - client and data diagnostics",
        "/coa reset confirm - erase this character's chronicle",
    }
    for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("   " .. l) end
end

-- A small window with a link the player can copy (chat links are not clickable).
local LINK_POPUP = {
    text = "%s",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 320,
    OnShow = function(self, data)
        local eb = (self.GetEditBox and self:GetEditBox()) or self.editBox or self.EditBox
        if eb then
            eb:SetText(data or "")
            eb:SetFocus()
            eb:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ShowFeedback()
    local links = CoA.links
    CoA:Print("thank you for helping the chronicle grow!")
    DEFAULT_CHAT_FRAME:AddMessage("   Bugs and ideas: " .. links.issues)
    DEFAULT_CHAT_FRAME:AddMessage("   Discussion and milestone ideas: " .. links.ideas)
    DEFAULT_CHAT_FRAME:AddMessage("   Tip: /coa status shows the details to paste into a bug report.")
    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs["CHRONICLES_OF_AZEROTH_LINK"] = StaticPopupDialogs["CHRONICLES_OF_AZEROTH_LINK"] or LINK_POPUP
        StaticPopup_Show("CHRONICLES_OF_AZEROTH_LINK",
            "Chronicles of Azeroth: report a bug or suggest a milestone.\nPress Ctrl+C to copy the link.",
            nil, links.issues)
    end
end

local function PrintStatus()
    local version, build, _, interface = CoA.Compat.GetClientInfo()
    CoA:Print(string.format("v%s  \194\183  client %s (%s), interface %s%s", CoA.version, version, build,
        tostring(interface), CoA.Compat.IsForeverClient() and ", Forever" or ""))
    local char = CoA.char
    if char then
        CoA:Print(string.format("%s: %d feed entries, %d regions, schema v%d",
            CoA.charKey, #char.feed.entries, CoA.Util.CountKeys(char.exploration.zones), CoA.db.schemaVersion))
    end
    local s = char and char.stats
    if s then
        CoA:Print(string.format("kills %d, elites %d, rares %d/%d, bosses %d, dungeons %d, hidden places %d",
            s.kills, s.eliteKills, s.rareKills, s.raresSeen, s.bossesDefeated, s.dungeonsCompleted, s.areasDiscovered))
        CoA:Print(string.format("challenges: %d under way, %d completed; emote hook %s",
            CoA.Challenges:CountActive(), CoA.Challenges:CountCompleted(),
            CoA.Challenges.hooked and "active" or "unavailable"))
        CoA:Print(string.format("sharing: addon messages %s; announce guild %s, party %s; inspect %s",
            CoA.Share.prefixOK and "available" or "unavailable",
            CoA.db.settings.share.announceGuild and "on" or "off", CoA.db.settings.share.announceParty and "on" or "off",
            CoA.db.settings.share.allowInspect and "allowed" or "private"))
        local run = CoA.Combat:GetRun()
        CoA:Print("kill sources: PARTY_KILL" .. (CoA.unsupportedEvents.PARTY_KILL and " (missing)" or "") ..
            ", UNIT_DIED" .. (CoA.unsupportedEvents.UNIT_DIED and " (missing, using target fallback)" or "") ..
            "; dungeon journal: " .. (CoA.Compat.GetInstanceEncounters() and "available here" or "not available here") ..
            (run and ("; current run: " .. run.name .. ", " .. run.defeatedCount .. " bosses") or ""))
    end
    local missing = {}
    for event in pairs(CoA.unsupportedEvents) do missing[#missing + 1] = event end
    if #missing > 0 then
        CoA:Print("|cffff8844events not available on this client:|r", table.concat(missing, ", "))
    else
        CoA:Print("all tracked events registered successfully.")
    end
end

local function HandleSlash(msg)
    if not CoA.ready then
        CoA:Print("still loading, try again in a moment.")
        return
    end
    local cmd, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")

    if cmd == "" then
        CoA.UI:Toggle()
    elseif PAGES[cmd] then
        CoA.UI:Show(PAGES[cmd])
    elseif cmd == "help" then
        PrintHelp()
    elseif cmd == "feedback" or cmd == "ideas" or cmd == "bug" then
        ShowFeedback()
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "toast" then
        CoA.Toast:Preview()
    elseif cmd == "milestones" or cmd == "achievements" then
        CoA.UI:Show("achievements")
    elseif cmd == "sound" or cmd == "sounds" then
        CoA.db.settings.playSounds = rest ~= "off"
        CoA:Print("notification sounds", CoA.db.settings.playSounds and "on" or "off")
    elseif cmd == "brag" then
        local ch = string.upper(rest ~= "" and rest or CoA.db.settings.share.bragChannel)
        CoA.Share:Brag(CoA.Share:ProfileLine(), ch)
    elseif cmd == "inspect" then
        local ok, why = CoA.Share:InspectTarget()
        if ok then
            CoA.UI:Show("fellows")
            CoA.UI:SelectFellow(CoA.Compat.UnitFullName("target"))
        else
            CoA:Print(why)
        end
    elseif cmd == "announce" then
        local which, state = string.match(rest, "^(%a+)%s*(%a*)$")
        local key = which == "guild" and "announceGuild" or (which == "party" and "announceParty")
        if key then
            CoA.db.settings.share[key] = state ~= "off"
            CoA:Print("milestone announcements in " .. which .. " chat", CoA.db.settings.share[key] and "on" or "off")
        else
            CoA:Print("usage: /coa announce guild on")
        end
    elseif cmd == "scale" then
        local s = tonumber(rest)
        if s then CoA.UI:SetScale(s) else CoA:Print("usage: /coa scale 0.9") end
    elseif cmd == "resetpos" then
        CoA.UI:ResetPosition()
    elseif cmd == "minimap" then
        CoA:GetModule("MinimapButton"):SetShown(rest ~= "off")
    elseif cmd == "debug" then
        CoA.db.settings.debug = not CoA.db.settings.debug
        CoA:Print("debug", CoA.db.settings.debug and "on" or "off")
    elseif cmd == "reset" then
        if rest == "confirm" then
            CoA.UI:Hide()
            CoA.Database:ResetCharacter()
            CoA.Journal:Invalidate()
            CoA.Character:RefreshIdentity()
            CoA.Feed:Add("chronicle_begun", { name = CoA.char.meta.name, level = CoA.char.meta.startLevel })
            CoA.Tracker:UpdateLocation()
            CoA:Print("this character's chronicle has been erased and begun anew.")
        else
            CoA:Print("this erases this character's whole chronicle. Type |cffd4af37/coa reset confirm|r to proceed.")
        end
    else
        PrintHelp()
    end
end

SLASH_CHRONICLESOFAZEROTH1 = "/coa"
SLASH_CHRONICLESOFAZEROTH2 = "/chronicles"
SlashCmdList["CHRONICLESOFAZEROTH"] = HandleSlash
