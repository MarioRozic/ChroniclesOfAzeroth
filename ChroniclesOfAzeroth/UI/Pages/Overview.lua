--[[
  Chronicles of Azeroth - UI/Pages/Overview.lua

  The Character chapter, as two pages of the book:
    left   name, title, identity, days on the road, whereabouts
    right  Deeds & Tallies (label .... value lines) and the latest entries

  A value the client has not reported yet (time played) is shown as
  "Unknown", never as a made-up number.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local L, R = CoA.UI:PageAreas(page)
    page.left = Widgets.Document(L)
    page.left.area:SetAllPoints()
    page.right = Widgets.Document(R)
    page.right.area:SetAllPoints()
    page.left.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end
    page.right.area.OnWidthChanged = page.left.area.OnWidthChanged
    return page
end

local function Render(page)
    local char = CoA.char
    if not char then return end
    local m, p, s = char.meta, char.progress, char.stats
    local Character = CoA.Character
    Character:RequestTimePlayed()

    -- Left page ---------------------------------------------------------------
    local d = page.left
    d:Begin()
    d:Title(m.name)
    d:Sub(Character:GetTitle())
    d:Rule()
    d:Para(string.format("Level %d %s %s\n%s", p.level, m.raceName, m.className, m.factionLocalized or ""))
    if m.realm and m.realm ~= "" then d:Para("of " .. m.realm, C.bookMuted) end
    d:Heading("On the road")
    local days = Character:GetAdventureDays()
    d:Big(days .. (days == 1 and " day" or " days"))
    d:Para("Chronicle begun " .. Util.FormatLongDate(m.chronicleStarted), C.bookMuted)

    d:Heading("Whereabouts")
    local loc = char.location
    if loc.zone ~= "" then
        local where = loc.zone
        if loc.subzone ~= "" and loc.subzone ~= loc.zone then where = where .. ", " .. loc.subzone end
        d:Para(where)
        local rec = char.exploration.zones[loc.zone]
        if rec then
            d:Para(string.format("First recorded %s  \194\183  %d visit%s  \194\183  %d quest%s here",
                Util.FormatLongDate(rec.firstVisit), rec.visits, rec.visits == 1 and "" or "s",
                rec.quests or 0, (rec.quests or 0) == 1 and "" or "s"), C.bookMuted)
        end
    else
        d:Para("Your whereabouts are unknown.", C.bookMuted)
    end
    d:End()

    -- Right page --------------------------------------------------------------
    local r = page.right
    r:Begin()
    r:Title("Deeds & Tallies")
    r:Rule()
    local played = Character:GetTimePlayed()
    local zones = 0
    for _, z in pairs(char.exploration.zones) do
        if not z.isInstance then zones = zones + 1 end
    end
    local earned, totalMilestones = CoA.Achievements:CountUnlocked()
    local Ch = CoA.Challenges
    local N = Util.FormatNumber
    r:Pairs({
        { "Time played", played and Util.FormatDuration(played) or "Unknown" },
        { "Regions explored", N(zones) },
        { "Quests completed", N(s.questsCompleted) },
        { "Dungeons completed", N(s.dungeonsCompleted) },
        { "Levels gained", N(s.levelsGained) },
        { "Deaths", N(s.deaths) },
        { "Enemies defeated", N(s.kills) },
        { "Elites defeated", N(s.eliteKills) },
        { "Rares slain / spotted", s.rareKills .. " / " .. s.raresSeen },
        { "Bosses defeated", N(s.bossesDefeated) },
        { "Hidden places", N(s.areasDiscovered) },
        { "Named places", N(s.subzonesDiscovered) },
        { "Milestones earned", earned .. " / " .. totalMilestones },
        { "Challenges under way", Ch:CountActive() .. " / " .. Ch.MAX_ACTIVE },
        { "Challenges completed", N(Ch:CountCompleted()) },
        { "Nights at camp", N(s.sessions) },
    })
    r:Para("Enemies count only open-world kills: Forever hides creatures inside dungeons from addons.", C.bookFaint)

    r:Heading("Latest in the chronicle")
    local entries = char.feed.entries
    if #entries == 0 then
        r:Para("Nothing has been written yet. Go forth, and the chronicle will follow.", C.bookMuted)
    else
        for i = #entries, math.max(1, #entries - 5), -1 do
            local e = entries[i]
            r:Para(CoA.Feed:FormatText(e) .. "  " .. Theme.Hex(C.bookFaint) .. Util.FormatDay(e.t) .. "|r")
        end
    end
    r:End()
end

CoA.UI:RegisterPage("overview", {
    label = "Character", order = 1,
    create = function(parent)
        local page = Create(parent)
        page.Render = Render
        return page
    end,
    refresh = Render,
})
