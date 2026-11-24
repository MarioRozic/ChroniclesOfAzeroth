-- Minimal WoW API mock (Lua 5.1) to load and exercise the addon headlessly.
local ADDON_DIR = arg[1]
local strict = {}
-- Generic widget object: records calls, returns sensible defaults.
local W = {}
W.__index = function(t, k)
  local v = rawget(W, k); if v then return v end
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

_G.CreateFrame = function(kind, name, parent) return newObj(kind, name, parent) end
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
InCombatLockdown = function() return false end
SetPortraitTexture = function() end
issecretvalue = function() return false end

-- Game state the tests manipulate
STATE = { level = 5, zone = "Mulgore", sub = "Bloodhoof Village", inst = false, instName = nil, now = 1795000000, gt = 100 }
UnitName = function() return "Mara" end
UnitFullName = function() return "Mara", nil end
GetRealmName = function() return "Forever" end
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
  GetMapInfo = function(id) return { mapID = id, mapType = 3, parentMapID = 12, name = STATE.zone } end,
}
C_QuestLog = { GetTitleForQuestID = function(id) if id == 1 then return "The Hunt Begins" end end }
GetTitleText = function() return "Rite of Strength" end
RequestTimePlayed = function() TIME_PLAYED_REQUESTED = true end
GetTime = function() return STATE.gt end
date = os.date; local realTime = os.time
time = function(t) if t then return realTime(t) end return STATE.now end
GetMaxLevelForPlayerExpansion = function() return 60 end

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
