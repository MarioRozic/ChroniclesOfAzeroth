--[[
  Chronicles of Azeroth - Modules/EventFeed.lua

  The chronological adventure feed. Other modules call Feed:Add(kind, data)
  when something real happens; the feed stores a compact record and fires
  "FEED_ENTRY_ADDED" so open UI pages can refresh.

  Entries store the *facts* (kind + data), not the final sentence. Text is
  produced at display time by the kind's formatter, so wording can be
  improved or localised later without touching saved data.

  Stored entry:  { id, t = time(), kind, cat, zone, level, d = { ...data } }
]]

local _, CoA = ...
local Util = CoA.Util
local Feed = CoA:NewModule("Feed")
CoA.Feed = Feed

---------------------------------------------------------------------------
-- Categories (used for filtering and colouring)
---------------------------------------------------------------------------
Feed.CATEGORIES = {
    { key = "all",      label = "All" },
    { key = "travel",   label = "Travels" },
    { key = "progress", label = "Growth" },
    { key = "quest",    label = "Deeds" },
    { key = "combat",   label = "Battles" },
    { key = "system",   label = "Chronicle" },
}

---------------------------------------------------------------------------
-- Kinds. Each kind defines its category, icon and two text formatters:
--   text(d, e)     -> short feed line ("You have entered The Barrens.")
--   journal(d, e)  -> a first-person diary sentence, or nil to skip
-- Modules in later phases register their own kinds (achievements, etc.).
---------------------------------------------------------------------------
Feed.kinds = {}

function Feed:RegisterKind(kind, def)
    def.category = def.category or "system"
    def.icon = def.icon or "Interface\\Icons\\INV_Misc_Note_01"
    self.kinds[kind] = def
end

function Feed:GetKind(kind)
    return self.kinds[kind]
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
function Feed:GetEntries()
    return CoA.char and CoA.char.feed.entries or {}
end

local lastAdded = {}   -- [dedupeKey] = GetTime(); session-only

-- Adds an entry. `opts.dedupe` (string) + `opts.window` (seconds) suppress
-- identical entries fired twice in quick succession (e.g. an event that
-- the client sends more than once).
function Feed:Add(kind, data, opts)
    local char = CoA.char
    if not char then return end
    local def = self.kinds[kind]
    if not def then
        CoA:Debug("unknown feed kind", kind)
        return
    end

    if opts and opts.dedupe then
        local now = GetTime()
        local prev = lastAdded[opts.dedupe]
        if prev and (now - prev) < (opts.window or 5) then return end
        lastAdded[opts.dedupe] = now
    end

    local feed = char.feed
    local entry = {
        id = feed.nextId,
        t = time(),
        kind = kind,
        cat = def.category,
        -- Ask the client directly so an entry made during a zone transition
        -- is stamped with where the player actually is.
        zone = CoA.Compat.GetCurrentZone() or (char.location.zone ~= "" and char.location.zone) or nil,
        level = UnitLevel("player"),
        d = data or {},
    }
    feed.nextId = feed.nextId + 1
    feed.entries[#feed.entries + 1] = entry

    -- Trim the oldest entries past the configured limit.
    local limit = CoA.db.settings.feedLimit
    local overflow = #feed.entries - limit
    if overflow > 0 then
        for _ = 1, overflow do table.remove(feed.entries, 1) end
    end

    CoA:Fire("FEED_ENTRY_ADDED", entry)
    return entry
end

function Feed:FormatText(entry)
    local def = self.kinds[entry.kind]
    if def and def.text then
        local ok, text = pcall(def.text, entry.d or {}, entry)
        if ok and text then return text end
    end
    return entry.kind
end

function Feed:FormatJournal(entry)
    local def = self.kinds[entry.kind]
    if def and def.journal then
        local ok, text = pcall(def.journal, entry.d or {}, entry)
        if ok then return text end
    end
end

function Feed:GetIcon(entry)
    local def = self.kinds[entry.kind]
    if def then
        if type(def.icon) == "function" then return def.icon(entry.d or {}, entry) end
        return def.icon
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Returns a new array (newest first) of entries matching a category and a
-- case-insensitive search string.
function Feed:Query(category, search)
    local results = {}
    local entries = self:GetEntries()
    search = Util.Lower(Util.Trim(search))
    for i = #entries, 1, -1 do
        local e = entries[i]
        if category == nil or category == "all" or e.cat == category then
            if search == "" then
                results[#results + 1] = e
            else
                local hay = Util.Lower(self:FormatText(e) .. " " .. (e.zone or ""))
                if string.find(hay, search, 1, true) then
                    results[#results + 1] = e
                end
            end
        end
    end
    return results
end

---------------------------------------------------------------------------
-- Built-in kinds used in Phase 1
---------------------------------------------------------------------------
local ICON = {
    book   = "Interface\\Icons\\INV_Misc_Book_09",
    map    = "Interface\\Icons\\INV_Misc_Map_01",
    road   = "Interface\\Icons\\Ability_Tracking",
    door   = "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar",
    level  = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
    quest  = "Interface\\Icons\\INV_Misc_Note_02",
    skull  = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    camp   = "Interface\\Icons\\Spell_Fire_Fire",
}
Feed.ICON = ICON

Feed:RegisterKind("chronicle_begun", {
    category = "system", icon = ICON.book,
    text = function(d)
        if (d.level or 1) > 1 then
            return string.format("The chronicle of %s begins, at level %d.", d.name or "a hero", d.level)
        end
        return string.format("The chronicle of %s begins.", d.name or "a hero")
    end,
    journal = function(d, e)
        local where = e.zone and (" in " .. e.zone) or ""
        if (d.level or 1) > 1 then
            return string.format("I begin this journal%s. I have walked these lands long enough to reach level %d, but from today every step will be written down.", where, d.level)
        end
        return string.format("I begin this journal%s, at the very start of my road.", where)
    end,
})

Feed:RegisterKind("session_start", {
    category = "system", icon = ICON.camp,
    text = function(d, e)
        if e.zone then return "You resume your journey in " .. e.zone .. "." end
        return "You resume your journey."
    end,
    journal = nil, -- too frequent to be interesting in the diary
})

Feed:RegisterKind("zone_discovered", {
    category = "travel", icon = ICON.map,
    text = function(d) return "You discovered " .. (d.zone or "a new land") .. "." end,
    journal = function(d) return "For the first time, I set foot in " .. (d.zone or "unknown lands") .. "." end,
})

Feed:RegisterKind("zone_entered", {
    category = "travel", icon = ICON.road,
    text = function(d) return "You have entered " .. (d.zone or "an unknown place") .. "." end,
    journal = function(d) return "My road led me back to " .. (d.zone or "familiar lands") .. "." end,
})

Feed:RegisterKind("instance_entered", {
    category = "travel", icon = ICON.door,
    text = function(d)
        local diff = d.difficulty and (" (" .. d.difficulty .. ")") or ""
        return "You descended into " .. (d.instance or "an instance") .. diff .. "."
    end,
    journal = function(d) return "I descended into " .. (d.instance or "the depths") .. ", not knowing what waited within." end,
})

Feed:RegisterKind("level_up", {
    category = "progress", icon = ICON.level,
    text = function(d) return "You have reached level " .. (d.level or "?") .. "." end,
    journal = function(d) return "I feel stronger. I have reached level " .. (d.level or "?") .. "." end,
})

Feed:RegisterKind("level_catchup", {
    category = "progress", icon = ICON.level,
    text = function(d)
        return string.format("You reached level %d while this chronicle was closed.", d.level or 0)
    end,
    journal = function(d)
        return string.format("Some days went unrecorded; by the time I opened this journal again I had reached level %d.", d.level or 0)
    end,
})

Feed:RegisterKind("quest_completed", {
    category = "quest", icon = ICON.quest,
    text = function(d)
        if d.title then return "You completed the quest \"" .. d.title .. "\"." end
        return "You completed a quest."
    end,
    journal = function(d)
        if d.title then return "I saw the task \"" .. d.title .. "\" through to its end." end
        return "I saw another task through to its end."
    end,
})

Feed:RegisterKind("player_died", {
    category = "combat", icon = ICON.skull,
    text = function(d, e)
        if e.zone then return "You were slain in " .. e.zone .. "." end
        return "You were slain."
    end,
    journal = function() return "I fell in battle, and had to find my way back from the spirit world." end,
})
