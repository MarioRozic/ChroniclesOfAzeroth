--[[
  Chronicles of Azeroth - Modules/Journal.lua

  Builds the travel-diary view from the event feed. Nothing here is invented:
  each chapter is one calendar day, and every sentence is derived from feed
  entries recorded that day. Days with no recorded events produce no chapter.

  Chapter: { dayKey, t, title = "November 24 - The Barrens", zones = {...},
             paragraphs = { "...", "..." }, entryCount }
]]

local _, CoA = ...
local Util = CoA.Util
local Journal = CoA:NewModule("Journal")
CoA.Journal = Journal

local cache, dirty = nil, true

function Journal:OnInitialize()
    CoA:On("FEED_ENTRY_ADDED", self, function() dirty = true end)
end

local function JoinList(list)
    local n = #list
    if n == 0 then return "" end
    if n == 1 then return list[1] end
    if n == 2 then return list[1] .. " and " .. list[2] end
    return table.concat(list, ", ", 1, n - 1) .. " and " .. list[n]
end

-- Kinds that are summarised per day instead of written one by one.
local SUMMARISED = { quest_completed = true, player_died = true, zone_entered = true, session_start = true,
                     zone_discovered = true, zone_recorded = true }

local function BuildChapter(dayKey, entries)
    local Feed = CoA.Feed
    local zoneOrder, zoneSeen, zoneCount = {}, {}, {}
    local quests, questTitles, deaths = 0, {}, 0
    local discovered, recorded = {}, {}
    local sentences, sentenceSeen = {}, {}

    for _, e in ipairs(entries) do
        local z = (e.d and (e.d.zone)) or e.zone
        if z and not (e.kind == "instance_entered") then
            if not zoneSeen[z] then
                zoneSeen[z] = true
                zoneOrder[#zoneOrder + 1] = z
            end
            zoneCount[z] = (zoneCount[z] or 0) + 1
        end

        if e.kind == "quest_completed" then
            quests = quests + 1
            if e.d.title and #questTitles < 3 then questTitles[#questTitles + 1] = "\"" .. e.d.title .. "\"" end
        elseif e.kind == "player_died" then
            deaths = deaths + 1
        elseif e.kind == "zone_discovered" and e.d.zone then
            discovered[#discovered + 1] = e.d.zone
        elseif e.kind == "zone_recorded" and e.d.zone then
            recorded[#recorded + 1] = e.d.zone
        elseif not SUMMARISED[e.kind] then
            local s = Feed:FormatJournal(e)
            if s and not sentenceSeen[s] then
                sentenceSeen[s] = true
                sentences[#sentences + 1] = s
            end
        end
    end

    -- Chapter title: the region where most of the day's events happened.
    local mainZone, best = nil, 0
    for _, z in ipairs(zoneOrder) do
        if zoneCount[z] > best then mainZone, best = z, zoneCount[z] end
    end

    local paragraphs = {}
    if #zoneOrder > 1 then
        paragraphs[#paragraphs + 1] = "My road took me through " .. JoinList(zoneOrder) .. "."
    elseif #zoneOrder == 1 then
        paragraphs[#paragraphs + 1] = "I spent my time in " .. zoneOrder[1] .. "."
    end

    if #discovered > 0 then
        table.insert(sentences, 1, "For the first time, I set foot in " .. JoinList(discovered) .. ".")
    end
    if #recorded > 0 then
        sentences[#sentences + 1] = "I made note of " .. JoinList(recorded) .. " in my journal."
    end
    if #sentences > 0 then
        paragraphs[#paragraphs + 1] = table.concat(sentences, " ")
    end

    local deeds = {}
    if quests == 1 then
        deeds[#deeds + 1] = "I completed a task for the people of these lands" ..
            (questTitles[1] and (": " .. questTitles[1]) or "") .. "."
    elseif quests > 1 then
        deeds[#deeds + 1] = string.format("I completed %d tasks for the people of these lands%s.",
            quests, #questTitles > 0 and (", among them " .. JoinList(questTitles)) or "")
    end
    if deaths == 1 then
        deeds[#deeds + 1] = "Once, I fell in battle and had to return from the spirit world."
    elseif deaths > 1 then
        deeds[#deeds + 1] = string.format("I fell in battle %d times, yet each time I rose again.", deaths)
    end
    if #deeds > 0 then paragraphs[#paragraphs + 1] = table.concat(deeds, " ") end

    local t = entries[1].t
    return {
        dayKey = dayKey,
        t = t,
        title = Util.FormatDay(t) .. (mainZone and (" - " .. mainZone) or ""), -- plain hyphen: Morpheus lacks an em dash glyph
        year = date("%Y", t),
        zones = zoneOrder,
        paragraphs = paragraphs,
        entryCount = #entries,
    }
end

-- Returns chapters newest first.
function Journal:GetChapters()
    if cache and not dirty then return cache end
    local entries = CoA.Feed:GetEntries()
    local chapters, dayEntries, order = {}, {}, {}
    for _, e in ipairs(entries) do
        local key = Util.DayKey(e.t)
        if not dayEntries[key] then
            dayEntries[key] = {}
            order[#order + 1] = key
        end
        local list = dayEntries[key]
        list[#list + 1] = e
    end
    for i = #order, 1, -1 do
        local key = order[i]
        local chapter = BuildChapter(key, dayEntries[key])
        if #chapter.paragraphs > 0 then
            chapters[#chapters + 1] = chapter
        end
    end
    cache, dirty = chapters, false
    return chapters
end

function Journal:Invalidate()
    dirty = true
end
