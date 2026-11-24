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
}

local function PrintHelp()
    CoA:Print("commands:")
    local lines = {
        "/coa - open or close the chronicle",
        "/coa journal | profile | history | exploration - open a chapter",
        "/coa scale <0.6-1.5> - window scale",
        "/coa resetpos - reset window position and size",
        "/coa minimap on|off - show or hide the minimap button",
        "/coa status - client and data diagnostics",
        "/coa reset confirm - erase this character's chronicle",
    }
    for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("   " .. l) end
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
    elseif cmd == "status" then
        PrintStatus()
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
