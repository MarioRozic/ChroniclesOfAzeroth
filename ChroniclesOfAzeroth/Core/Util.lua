--[[
  Chronicles of Azeroth - Core/Util.lua
  Small, dependency-free helpers (tables, time and date formatting).
  Only standard WoW Lua functions are used: date(), time(), string.*, table.*.
]]

local _, CoA = ...
local Util = {}
CoA.Util = Util

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------
function Util.DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = Util.DeepCopy(v)
    end
    return copy
end

-- Fills missing keys in `target` from `defaults` (recursively). Existing
-- values are kept, and a value of the wrong type is replaced by the default,
-- so corrupt or hand-edited SavedVariables cannot crash the addon.
function Util.ApplyDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = Util.ApplyDefaults(target[k], v)
        elseif target[k] == nil or type(target[k]) ~= type(v) then
            target[k] = v
        end
    end
    return target
end

function Util.CountKeys(t)
    local n = 0
    if type(t) == "table" then
        for _ in pairs(t) do n = n + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Time & dates
---------------------------------------------------------------------------
local MONTHS = {
    "January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December",
}

-- "November 24"
function Util.FormatDay(timestamp)
    local d = date("*t", timestamp)
    return MONTHS[d.month] .. " " .. d.day
end

-- "November 24, 2026"
function Util.FormatLongDate(timestamp)
    local d = date("*t", timestamp)
    return MONTHS[d.month] .. " " .. d.day .. ", " .. d.year
end

-- "14:05"
function Util.FormatClock(timestamp)
    return date("%H:%M", timestamp)
end

-- A key that groups timestamps by calendar day: "2026-11-24"
function Util.DayKey(timestamp)
    return date("%Y-%m-%d", timestamp)
end

-- 93784 -> "1d 2h 3m"
function Util.FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 60 then return "less than a minute" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local out = {}
    if days > 0 then out[#out + 1] = days .. "d" end
    if hours > 0 then out[#out + 1] = hours .. "h" end
    if minutes > 0 and days == 0 then out[#out + 1] = minutes .. "m" end
    return table.concat(out, " ")
end

-- Whole calendar days between two timestamps ("Day 1" is the first day).
function Util.DaysBetween(t1, t2)
    return math.floor((t2 - t1) / 86400)
end

-- 1234567 -> "1,234,567"
function Util.FormatNumber(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local formatted, k = s, 0
    repeat
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return formatted
end

function Util.Trim(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

function Util.Lower(s)
    return string.lower(s or "")
end
