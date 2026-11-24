--[[
  Chronicles of Azeroth - UI/Pages/Exploration.lua  (Phase 2)

  The Exploration chapter, an atlas of where you have been:
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

local ROW_H = 46

local function Plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local bg = Theme.SolidTexture(row, "BACKGROUND", { 1, 1, 1, 0.025 })
    bg:SetPoint("TOPLEFT", 0, -2); bg:SetPoint("BOTTOMRIGHT", 0, 2)
    row.bg = bg
    row.icon = Theme.Icon(row, 30)
    row.icon:SetPoint("LEFT", 10, 0)
    row.name = Theme.Heading(row, 15)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
    row.name:SetPoint("RIGHT", row, "RIGHT", -230, 0)
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.detail = Theme.Text(row, 11, C.inkFaint)
    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.detail:SetPoint("RIGHT", row, "RIGHT", -230, 0)
    if row.detail.SetWordWrap then row.detail:SetWordWrap(false) end
    row.right = Theme.Text(row, 11, C.inkMuted)
    row.right:SetPoint("RIGHT", -12, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetJustifyV("MIDDLE")
    if row.right.SetSpacing then row.right:SetSpacing(3) end
    row.header = Theme.Heading(row, 17)
    row.header:SetPoint("BOTTOMLEFT", 4, 8)
    row.rule = Theme.HGradientTexture(row, "ARTWORK", C.goldFaint, { 0, 0, 0, 0 })
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 4, 4)
    row.rule:SetPoint("BOTTOMRIGHT", 0, 4)
    return row
end

local function UpdateRow(row, item, index)
    local isHeader = item.header ~= nil
    row.header:SetShown(isHeader); row.rule:SetShown(isHeader)
    row.icon:SetShown(not isHeader); row.name:SetShown(not isHeader)
    row.detail:SetShown(not isHeader); row.right:SetShown(not isHeader)
    row.bg:SetShown(not isHeader and index % 2 == 0)
    if isHeader then
        row.header:SetText(item.header)
        return
    end
    row.icon.icon:SetTexture(item.icon)
    row.icon.icon:SetDesaturated(item.dim and true or false)
    row.name:SetText(item.name)
    local c = item.dim and C.inkMuted or C.gold
    row.name:SetTextColor(c[1], c[2], c[3])
    row.detail:SetText(item.detail)
    row.right:SetText(item.right)
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
            list[#list + 1] = { name = name, first = z.firstVisit or 0, icon = "Interface\\Icons\\INV_Misc_Map_01",
                                detail = detail, right = right }
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
                dim = not d }
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

    -- Summary line of four figures
    page.figures = {}
    for i = 1, 4 do
        local f = CreateFrame("Frame", nil, page)
        f:SetSize(130, 40)
        f.value = Theme.Heading(f, 22)
        f.value:SetPoint("TOPLEFT", 0, 0)
        f.label = Theme.Text(f, 10, C.inkMuted)
        f.label:SetPoint("TOPLEFT", f.value, "BOTTOMLEFT", 0, -2)
        page.figures[i] = f
    end

    page.chips = {}
    local prev
    for _, v in ipairs(VIEWS) do
        local chip = Widgets.Chip(page, v.label)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 6, 0) else chip:SetPoint("TOPLEFT", 0, -50) end
        chip.key = v.key
        chip:SetScript("OnClick", function() page.view = v.key; page:Render() end)
        page.chips[#page.chips + 1] = chip
        prev = chip
    end

    page.list = Widgets.VirtualList(page, ROW_H, CreateRow, UpdateRow)
    page.list:SetPoint("TOPLEFT", 0, -82)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)
    page.empty = Theme.Text(page, 13, C.inkFaint)
    page.empty:SetPoint("TOPLEFT", page.list, "TOPLEFT", 4, -10)
    page.empty:SetWidth(480)

    function page:Render()
        local char = CoA.char
        local s = char.stats
        local regions, instances = 0, 0
        local continents = {}
        for _, z in pairs(char.exploration.zones) do
            if z.isInstance then instances = instances + 1 else
                regions = regions + 1
                if z.continent then continents[z.continent] = true end
            end
        end
        local fig = {
            { regions, "regions explored" },
            { Util.CountKeys(continents), "continents" },
            { s.areasDiscovered, "hidden places uncovered" },
            { s.subzonesDiscovered, "named places walked" },
        }
        local width = self:GetWidth() or 600
        local colW = math.max(110, (width - 14) / 4)
        for i, f in ipairs(self.figures) do
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", (i - 1) * colW, 0)
            f.value:SetText(Util.FormatNumber(fig[i][1]))
            f.label:SetText(fig[i][2])
        end

        local view
        for _, v in ipairs(VIEWS) do
            if v.key == self.view then view = v end
        end
        for _, chip in ipairs(self.chips) do chip:SetSelected(chip.key == self.view) end
        local items = view.build(char)
        self.list:SetItems(items)
        self.empty:SetShown(#items == 0)
        self.empty:SetText(view.empty)
    end
    return page
end

CoA.UI:RegisterPage("exploration", {
    label = "Exploration", icon = "Interface\\Icons\\INV_Misc_Map_01", order = 5,
    create = Create,
    refresh = function(page) page:Render() end,
})
