--[[
  Chronicles of Azeroth - UI/Pages/Exploration.lua

  The Exploration chapter as a book, an atlas of where you have been. The
  left page lists one of three views, the right page shows the chosen entry:
    Regions          - every region by continent, with first visit, visits,
                       named places walked, quests, kills and deaths
    Dungeons         - instances entered, bosses defeated, completions
    Rare creatures   - rares spotted and slain

  No exploration percentage is shown: the client offers no total to divide
  by. "Map areas revealed" is the client's own count of uncovered overlays.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local function Plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
end

---------------------------------------------------------------------------
-- Item builders for the three views
---------------------------------------------------------------------------
local function RegionItems(char)
    local byContinent, order = {}, {}
    for name, z in pairs(char.exploration.zones) do
        if not z.isInstance then
            local cont = z.continent or "Uncharted lands"
            if not byContinent[cont] then byContinent[cont] = {}; order[#order + 1] = cont end
            local subs = Util.CountKeys(z.subzones)
            local right = Plural(z.visits or 0, "visit") .. "   " .. Plural(z.quests or 0, "quest") ..
                "\n" .. Plural(z.kills or 0, "kill") .. "   " .. Plural(z.deaths or 0, "death")
            local detail = "Discovered " .. Util.FormatLongDate(z.firstVisit or 0) ..
                "   \194\183   " .. Plural(subs, "named place")
            if z.revealed then detail = detail .. "   \194\183   " .. Plural(z.revealed, "map area") .. " revealed" end
            local list = byContinent[cont]
            local places = {}
            for sub in pairs(z.subzones or {}) do places[#places + 1] = sub end
            table.sort(places)
            list[#list + 1] = { name = name, first = z.firstVisit or 0, icon = "Interface\\Icons\\INV_Misc_Map_01",
                                detail = detail, right = right, sub = cont,
                                pairs = {
                                    { "First visit", Util.FormatLongDate(z.firstVisit or 0) },
                                    { "Visits", Util.FormatNumber(z.visits or 0) },
                                    { "Quests", Util.FormatNumber(z.quests or 0) },
                                    { "Enemies defeated", Util.FormatNumber(z.kills or 0) },
                                    { "Deaths", Util.FormatNumber(z.deaths or 0) },
                                    { "Map areas revealed", z.revealed and Util.FormatNumber(z.revealed) or "-" },
                                },
                                listTitle = "Named places walked", list = places }
        end
    end
    table.sort(order)
    local items = {}
    for _, cont in ipairs(order) do
        items[#items + 1] = { header = cont }
        table.sort(byContinent[cont], function(a, b) return a.first < b.first end)
        for _, it in ipairs(byContinent[cont]) do items[#items + 1] = it end
    end
    return items
end

local function DungeonItems(char)
    local items = {}
    local bossesByInstance = {}
    for boss, b in pairs(char.combat.bosses) do
        if b.instance then
            bossesByInstance[b.instance] = bossesByInstance[b.instance] or {}
            table.insert(bossesByInstance[b.instance], boss)
        end
    end
    for name, z in pairs(char.exploration.zones) do
        if z.isInstance then
            local d = char.combat.dungeons[name]
            local bosses = bossesByInstance[name] or {}
            table.sort(bosses)
            local detail = #bosses > 0 and ("Bosses defeated: " .. table.concat(bosses, ", "))
                or "No boss defeats recorded yet"
            local right = Plural(z.visits or 0, "visit")
            if d then
                right = right .. "   " .. Plural(d.completions, "completion") ..
                    (d.fastest and ("\nFastest " .. Util.FormatDuration(d.fastest)) or "") ..
                    ((d.deathless or 0) > 0 and ("   " .. d.deathless .. " flawless") or "")
            end
            items[#items + 1] = { name = name, first = z.firstVisit or 0, detail = detail, right = right,
                icon = d and "Interface\\Icons\\INV_Misc_Key_03" or "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar",
                dim = not d, sub = "Dungeon",
                pairs = {
                    { "First entered", Util.FormatLongDate(z.firstVisit or 0) },
                    { "Visits", Util.FormatNumber(z.visits or 0) },
                    { "Completions", d and Util.FormatNumber(d.completions) or "0" },
                    { "Flawless runs", d and Util.FormatNumber(d.deathless or 0) or "0" },
                    { "Fastest run", d and d.fastest and Util.FormatDuration(d.fastest) or "-" },
                },
                listTitle = "Bosses defeated", list = bosses }
        end
    end
    table.sort(items, function(a, b) return a.first > b.first end)
    return items
end

local function RareItems(char)
    local items = {}
    for name, r in pairs(char.combat.rares) do
        local detail = "Spotted " .. Util.FormatLongDate(r.firstSeen or 0) ..
            (r.zone and r.zone ~= "" and ("   \194\183   " .. r.zone) or "") ..
            (r.level and ("   \194\183   level " .. r.level) or "")
        local slain = (r.kills or 0) > 0
        items[#items + 1] = {
            sub = r.elite and "Rare elite" or "Rare creature",
            pairs = {
                { "First spotted", Util.FormatLongDate(r.firstSeen or 0) },
                { "Where", (r.zone and r.zone ~= "") and r.zone or "-" },
                { "Level", r.level and tostring(r.level) or "-" },
                { "Times slain", Util.FormatNumber(r.kills or 0) },
            },
            name = name .. (r.elite and "  (elite)" or ""), first = r.firstSeen or 0, detail = detail,
            right = slain and ("Slain " .. Plural(r.kills, "time")) or "Still roaming",
            icon = slain and "Interface\\Icons\\Ability_Hunter_SniperShot" or "Interface\\Icons\\INV_Misc_Head_Dragon_01",
            dim = not slain,
        }
    end
    table.sort(items, function(a, b) return a.first > b.first end)
    return items
end

local VIEWS = {
    { key = "regions", label = "Regions", build = RegionItems,
      empty = "No regions recorded yet. Every region you enter is written here." },
    { key = "dungeons", label = "Dungeons", build = DungeonItems,
      empty = "No dungeons entered yet." },
    { key = "rares", label = "Rare creatures", build = RareItems,
      empty = "No rare creatures spotted yet. Target or hover over one, or let its nameplate appear, to record it." },
}

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.view = "regions"
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Exploration")
    page.summary = Theme.Ink(L, 12, C.bookMuted)
    page.summary:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)
    page.summary:SetPoint("RIGHT", L, "RIGHT", -4, 0)

    page.chips = {}
    local prev
    for _, v in ipairs(VIEWS) do
        local chip = Widgets.Chip(L, v.label)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", 0, -60) end
        chip.key = v.key
        chip:SetScript("OnClick", function() page.view = v.key; page:Render() end)
        page.chips[#page.chips + 1] = chip
        prev = chip
    end

    page.list = Widgets.SelectList(L, 24, function() page:Render() end)
    page.list:SetPoint("TOPLEFT", 0, -88)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.doc = Widgets.Document(R)
    page.doc.area:SetAllPoints()
    page.doc.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end

    function page:Render()
        local char = CoA.char
        local s = char.stats
        local regions, continents = 0, {}
        for _, z in pairs(char.exploration.zones) do
            if not z.isInstance then
                regions = regions + 1
                if z.continent then continents[z.continent] = true end
            end
        end
        self.summary:SetText(string.format("%s  \194\183  %s\n%s  \194\183  %s",
            Plural(regions, "region"), Plural(Util.CountKeys(continents), "continent"),
            Plural(s.areasDiscovered, "hidden place"), Plural(s.subzonesDiscovered, "named place")))

        local view
        for _, v in ipairs(VIEWS) do
            if v.key == self.view then view = v end
        end
        for _, chip in ipairs(self.chips) do chip:SetSelected(chip.key == self.view) end
        local items = view.build(char)
        for _, it in ipairs(items) do
            if not it.header then
                it.key = self.view .. ":" .. it.name
                it.text = it.name
                it.right = nil
            end
        end
        local sel = self.list:SetSelectableItems(items)

        local d = self.doc
        d:Begin()
        if not sel then
            d:Title(view.label)
            d:Rule()
            d:Para(view.empty, C.bookMuted)
        else
            d:Title(sel.name)
            if sel.sub then d:Sub(sel.sub) end
            d:Rule()
            d:Pairs(sel.pairs or {})
            if sel.listTitle then
                d:Heading(sel.listTitle)
                if sel.list and #sel.list > 0 then
                    d:Para(table.concat(sel.list, ", ") .. ".")
                else
                    d:Para("None recorded yet.", C.bookMuted)
                end
            end
        end
        d:End(self.lastKey ~= (sel and sel.key))
        self.lastKey = sel and sel.key
    end
    return page
end

CoA.UI:RegisterPage("exploration", {
    label = "Exploration", order = 5,
    create = Create,
    refresh = function(page) page:Render() end,
})
