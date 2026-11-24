--[[
  Chronicles of Azeroth - Modules/Achievements.lua  (Phase 2)

  Evaluates the milestones in Data/Achievements.lua against recorded data,
  stores unlocks with their date, level and place, writes them to the feed,
  shows a notification and manages earned titles.

  Evaluation is event-driven: modules fire "STATS_CHANGED" and a short
  debounce (C_Timer) batches bursts such as several kills in one pull, so
  there is no polling.

  Saved: char.achievements.unlocked[id] = { t, level, zone }
]]

local _, CoA = ...
local Data = CoA.AchievementData
local Achievements = CoA:NewModule("Achievements")
CoA.Achievements = Achievements

local byId = {}
for _, def in ipairs(Data.LIST) do byId[def.id] = def end
Achievements.byId = byId

local pending = false
local caughtUp = false   -- live evaluation starts after the quiet login catch-up

function Achievements:OnEnable()
    CoA:On("STATS_CHANGED", self, function()
        if caughtUp then Achievements:ScheduleEvaluate() end
    end)
end

function Achievements:OnEnterWorld(isFirstOfSession)
    -- Catch up once per session (e.g. stats recorded before milestones
    -- existed). These are unlocked quietly with a single summary notice
    -- instead of a burst of notifications at login.
    if isFirstOfSession then
        local n = self:Evaluate(true)
        caughtUp = true
        if n > 0 and CoA.Toast then
            CoA.Toast:Show({
                kind = "summary",
                name = n == 1 and "1 milestone recorded" or (n .. " milestones recorded"),
                desc = "Earned by deeds already in your chronicle. See the Milestones chapter.",
                icon = "Interface\\Icons\\Spell_Holy_ChampionsBond",
            })
        end
    end
end

function Achievements:ScheduleEvaluate()
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            pending = false
            Achievements:Evaluate()
        end)
    else
        pending = false
        self:Evaluate()
    end
end

function Achievements:IsUnlocked(id)
    local u = CoA.char and CoA.char.achievements.unlocked[id]
    return type(u) == "table" and u or nil
end

function Achievements:IsAvailable(def)
    return not def.requires or def.requires(CoA.char)
end

function Achievements:GetProgress(def)
    local ok, value = pcall(def.progress, CoA.char)
    value = ok and tonumber(value) or 0
    return math.min(value, def.target), def.target
end

-- Returns how many milestones were unlocked. `quiet` skips notifications.
function Achievements:Evaluate(quiet)
    local char = CoA.char
    if not char then return 0 end
    local count = 0
    for _, def in ipairs(Data.LIST) do
        if not self:IsUnlocked(def.id) and self:IsAvailable(def) then
            local current = self:GetProgress(def)
            if current >= def.target then
                self:Unlock(def, quiet)
                count = count + 1
            end
        end
    end
    return count
end

function Achievements:Unlock(def, quiet)
    local char = CoA.char
    char.achievements.unlocked[def.id] = {
        t = time(),
        level = UnitLevel("player"),
        zone = char.location.zone ~= "" and char.location.zone or nil,
    }
    CoA.Feed:Add("achievement", { id = def.id, name = def.name, title = def.title })
    if CoA.Toast and not quiet then CoA.Toast:Show(def) end
    CoA:Fire("ACHIEVEMENT_UNLOCKED", def)
end

function Achievements:CountUnlocked()
    local n = 0
    for _, def in ipairs(Data.LIST) do
        if self:IsUnlocked(def.id) then n = n + 1 end
    end
    return n, #Data.LIST
end

-- Titles ---------------------------------------------------------------------
function Achievements:GetEarnedTitles()
    local titles = {}
    for _, def in ipairs(Data.LIST) do
        if def.title and self:IsUnlocked(def.id) then titles[#titles + 1] = def.title end
    end
    return titles
end

-- Wear an earned title, or pass nil to return to the level-based title.
function Achievements:WearTitle(title)
    CoA.char.profile.customTitle = title or ""
    CoA:Fire("CHARACTER_UPDATED")
end

CoA.Feed:RegisterKind("achievement", {
    category = "progress",
    icon = function(d)
        local def = d.id and byId[d.id]
        return def and def.icon or "Interface\\Icons\\Spell_Holy_ChampionsBond"
    end,
    text = function(d)
        local t = "You earned the milestone \"" .. (d.name or "?") .. "\"."
        if d.title then t = t .. " New title: " .. d.title .. "." end
        return t
    end,
    journal = function(d) return "This deserves a line of its own: " .. (d.name or "a milestone") .. "." end,
})
