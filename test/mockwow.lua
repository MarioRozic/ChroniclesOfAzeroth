-- Minimal WoW API mock (Lua 5.1) to load and exercise the addon headlessly.
local ADDON_DIR = arg[1]
local strict = {}
-- Generic widget object: records calls, returns sensible defaults.
local W = {}
-- Template child regions: nil unless a template created them (as in the client).
local CHILD_FIELDS = { CloseButton=1, Inset=1, TitleContainer=1, PortraitContainer=1, NineSlice=1,
  TitleText=1, Instructions=1, Text=1, Left=1, Right=1, Middle=1, Bg=1, portrait=1, clearButton=1 }
W.__index = function(t, k)
  local v = rawget(W, k); if v then return v end
  if CHILD_FIELDS[k] or not k:match("^%u") then return nil end   -- data fields are nil until set
  return function() end   -- any unknown method is a no-op
end
local frames = {}
local function newObj(kind, name, parent)
  local o = setmetatable({ _kind = kind, _scripts = {}, _events = {}, _w = 100, _h = 100, _shown = true, _text = "", _points = {} }, W)
  if name then _G[name] = o end
  frames[#frames + 1] = o
  return o
end
function W:SetScript(k, fn) self._scripts[k] = fn end
function W:GetScript(k) return self._scripts[k] end
function W:HookScript(k, fn) self._scripts[k] = fn end
function W:RegisterEvent(e)
  if e:find("UNKNOWN") then error("Attempt to register unknown event") end
  self._events[e] = true
end
function W:UnregisterEvent(e) self._events[e] = nil end
function W:CreateTexture() return newObj("Texture") end
function W:CreateMaskTexture() return newObj("Texture") end
function W:CreateFontString() return newObj("FontString") end
function W:SetSize(w, h) self._w, self._h = w, h end
function W:SetWidth(w) self._w = w end
function W:SetHeight(h) self._h = h end
function W:GetWidth() return self._w end
function W:GetHeight() return self._h end
function W:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
function W:Hide() self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end
function W:SetShown(s) if s then self:Show() else self:Hide() end end
function W:IsShown() return self._shown end
function W:SetText(t) self._text = t == nil and "" or tostring(t) end
function W:GetText() return self._text end
function W:GetStringHeight() return 14 end
function W:GetStringWidth() return #self._text * 6 end
function W:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function W:SetPoint(...) self._points[#self._points+1] = {...} end
function W:GetVerticalScroll() return 0 end
function W:GetEffectiveScale() return 1 end
function W:GetFrameLevel() return 1 end
function W:GetCenter() return 0, 0 end
function W:SetScrollChild(c) self._child = c end
function W:SetGradient() end
function W:GetName() return "ChroniclesOfAzerothFrame" end
function W:SetChecked(v) self._checked = v and true or false end
function W:GetChecked() return self._checked end
function W:Enable() self._disabled = false end
function W:Disable() self._disabled = true end
function W:IsEnabled() return not self._disabled end

-- MOCK_NATIVE = true makes Blizzard templates "exist" and build their children;
-- otherwise every template is missing, so the addon's fallbacks are exercised.
MOCK_TEMPLATES_USED = {}
_G.CreateFrame = function(kind, name, parent, template)
  if template and template ~= "BackdropTemplate" then
    MOCK_TEMPLATES_USED[template] = true
    if not MOCK_NATIVE then error("Couldn't find inherited node \"" .. template .. "\"") end
  end
  local o = newObj(kind, name, parent)
  o._template = template
  if MOCK_NATIVE and template == "ButtonFrameTemplate" then
    o.CloseButton = newObj("Button"); o.Inset = newObj("Frame")
    o.TitleContainer = newObj("Frame"); o.TitleContainer.TitleText = newObj("FontString")
    o.PortraitContainer = newObj("Frame"); o.PortraitContainer.portrait = newObj("Texture")
  elseif MOCK_NATIVE and template == "SearchBoxTemplate" then
    o.Instructions = newObj("FontString")
  elseif MOCK_NATIVE and template == "PanelTabButtonTemplate" then
    o.Text = newObj("FontString")
  end
  return o
end
UIParent = newObj("Frame"); Minimap = newObj("Frame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. m) end }
GameTooltip = newObj("GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { IG_SPELLBOOK_OPEN = 829, IG_SPELLBOOK_CLOSE = 830 }
PlaySound = function() end
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18
GetBuildInfo = function() return "1.60.1", "70685", "Nov 1 2026", 16001 end
C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
Enum = { UIMapType = { Cosmic=0, World=1, Continent=2, Zone=3, Dungeon=4, Micro=5, Orphan=6 } }
CreateColor = function(r,g,b,a) return {r,g,b,a} end
GetCursorPosition = function() return 0, 0 end
InCombatLockdown = function() return STATE.combat and true or false end
SetPortraitTexture = function() end
issecretvalue = function() return false end

-- Game state the tests manipulate
STATE = { level = 5, zone = "Mulgore", sub = "Bloodhoof Village", inst = false, instName = nil, now = 1795000000, gt = 100 }
UnitName = function(u) if u == nil or u == "player" then return "Mara" end local x = UNITS[u] return x and x.name end
UnitFullName = function() return "Mara", nil end
GetRealmName = function() return STATE.realm or "" end  -- Forever build 71037 returns ""
UnitClass = function() return "Druid", "DRUID" end
UnitRace = function() return "Tauren", "Tauren" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitSex = function() return 3 end
UnitLevel = function() return STATE.level end
GetRealZoneText = function() return STATE.zone end
GetZoneText = function() return STATE.zone end
GetSubZoneText = function() return STATE.sub end
IsInInstance = function() return STATE.inst, STATE.inst and "party" or "none" end
GetInstanceInfo = function()
  if STATE.inst then return STATE.instName, "party", 1, "Normal", 5, 0, false, 43 end
  return STATE.zone, "none", 0, "", 0, 0, false, 1
end
C_Map = {
  GetBestMapForUnit = function() return 7 end,
  GetMapInfo = function(id) if id == 12 then return { mapID = 12, mapType = 2, parentMapID = 0, name = "Kalimdor" } end return { mapID = id, mapType = 3, parentMapID = 12, name = STATE.zone } end,
}
UNITS = {}   -- tests put unit tables here: UNITS.target = { guid=..., name=..., class=..., ... }
SECRET = {}
local function U(unit) return UNITS[unit] end
UnitExists = function(u) return U(u) ~= nil or u == "player" end
UnitGUID = function(u) if u == "player" then return "Player-1-0001" end local x = U(u) return x and x.guid end
UnitIsPlayer = function(u) if u == "player" then return true end local x = U(u) return x and x.player or false end
UnitCanAttack = function(a, u) local x = U(u) return x and not x.friendly end
UnitClassification = function(u) local x = U(u) return x and x.class or "normal" end
UnitCreatureType = function(u) local x = U(u) return x and x.ctype end
UnitIsTapDenied = function(u) local x = U(u) return x and x.tapDenied end
UnitIsDead = function(u) local x = U(u) return x and x.dead end
UnitAffectingCombat = function(u) if u == "player" then return STATE.combat end local x = U(u) return x and x.combat end
issecretvalue = function(v) return SECRET[v] == true end
TIMERS = {}
C_Timer = { After = function(delay, fn)
  if MOCK_DEFER then TIMERS[#TIMERS + 1] = { fn = fn, delay = delay or 0 } return end
  fn()
end }
-- Runs queued timers with delay <= maxDelay (default: all), in order.
function RunTimers(maxDelay)
  for _ = 1, 500 do
    local idx
    for i, t in ipairs(TIMERS) do if not maxDelay or t.delay <= maxDelay then idx = i break end end
    if not idx then return end
    table.remove(TIMERS, idx).fn()
  end
end
C_MapExplorationInfo = { GetExploredMapTextures = function() return { {}, {}, {} } end }
EJ_GetInstanceForMap = function() if STATE.inst then return 240 end return 0 end
EJ_GetEncounterInfoByIndex = function(i) local b = ({ "Lady Anacondra", "Lord Cobrahn", "Mutanus the Devourer" })[i] if b then return b, "", 100 + i, 0, 0, 0, 1000 + i end end
C_QuestLog = { GetTitleForQuestID = function(id) if id == 1 then return "The Hunt Begins" end end }
GetTitleText = function() return "Rite of Strength" end
RequestTimePlayed = function() TIME_PLAYED_REQUESTED = true end
GetTime = function() return STATE.gt end
date = os.date; local realTime = os.time
time = function(t) if t then return realTime(t) end return STATE.now end
GetMaxLevelForPlayerExpansion = function() return 60 end
IsInGroup = function(cat) if cat then return false end return STATE.group and true or false end
IsInGuild = function() return STATE.guild and true or false end
UnitIsUnit = function(a, b) return a == b end
GetUnitName = function(u) local x = UNITS[u] if u == "player" then return "Mara" end return x and x.name end
LE_PARTY_CATEGORY_INSTANCE = 2
CHAT_SENT, ADDON_SENT = {}, {}
C_ChatInfo = {
  SendChatMessage = function(msg, chatType) CHAT_SENT[#CHAT_SENT + 1] = { msg = msg, chatType = chatType } end,
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chatType, target)
    if STATE.throttle and STATE.throttle > 0 then STATE.throttle = STATE.throttle - 1; return 3 end
    ADDON_SENT[#ADDON_SENT + 1] = { prefix = prefix, msg = msg, chatType = chatType, target = target }
    return 0
  end,
}
DoEmote = function(token, target) EMOTES_DONE = (EMOTES_DONE or 0) + 1 end
hooksecurefunc = function(a, b, c)
  local t, name, fn = _G, a, b
  if type(a) == "table" then t, name, fn = a, b, c end
  local orig = t[name]
  t[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
end

-- Load the addon in .toc order
local ns = {}
local toc = io.open(ADDON_DIR .. "/ChroniclesOfAzeroth.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:match("^%s*#") and line:match("%.lua%s*$") then
    local path = ADDON_DIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")
    local chunk = assert(loadfile(path))
    chunk("ChroniclesOfAzeroth", ns)
  end
end

function FireEvent(event, ...)
  for _, f in ipairs(frames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end
NS = ns
