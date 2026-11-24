--[[
  Chronicles of Azeroth - UI/Pages/EventHistory.lua

  The chronological adventure feed: every recorded event, newest first,
  filterable by category and searchable. Uses a virtual list, so thousands
  of entries scroll smoothly.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local ROW_H = 48

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local bg = Theme.SolidTexture(row, "BACKGROUND", { 1, 1, 1, 0.025 })
    bg:SetPoint("TOPLEFT", 0, -2); bg:SetPoint("BOTTOMRIGHT", 0, 2)
    row.bg = bg
    local accent = Theme.SolidTexture(row, "ARTWORK", C.gold)
    accent:SetPoint("TOPLEFT", 0, -2); accent:SetPoint("BOTTOMLEFT", 0, 2); accent:SetWidth(2)
    row.accent = accent
    row.icon = Theme.Icon(row, 30)
    row.icon:SetPoint("LEFT", 12, 0)
    row.text = Theme.Text(row, 13, C.ink)
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -1)
    row.text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end
    row.meta = Theme.Text(row, 11, C.inkFaint)
    row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
    row.meta:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    if row.meta.SetWordWrap then row.meta:SetWordWrap(false) end
    return row
end

local function UpdateRow(row, e, index)
    local cc = Theme.CATEGORY_COLORS[e.cat] or Theme.CATEGORY_COLORS.system
    row.accent:SetColorTexture(cc[1], cc[2], cc[3], 0.9)
    row.bg:SetShown(index % 2 == 0)
    row.icon.icon:SetTexture(CoA.Feed:GetIcon(e))
    row.text:SetText(CoA.Feed:FormatText(e))
    local meta = Util.FormatLongDate(e.t) .. ", " .. Util.FormatClock(e.t)
    if e.zone then meta = meta .. "   \194\183   " .. e.zone end
    if e.level then meta = meta .. "   \194\183   Level " .. e.level end
    row.meta:SetText(meta)
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.category = "all"
    page.search = ""

    -- Filter chips
    page.chips = {}
    local prev
    for _, cat in ipairs(CoA.Feed.CATEGORIES) do
        local chip = Widgets.Chip(page, cat.label)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 6, 0) else chip:SetPoint("TOPLEFT", 0, 0) end
        chip:SetScript("OnClick", function()
            page.category = cat.key
            page:Render()
        end)
        chip.key = cat.key
        page.chips[#page.chips + 1] = chip
        prev = chip
    end

    page.searchBox = Widgets.SearchBox(page, 190, function(text)
        page.search = text
        page:Render()
    end)
    page.searchBox:SetPoint("TOPRIGHT", -14, 0)

    page.count = Theme.Text(page, 11, C.inkFaint)
    page.count:SetPoint("TOPLEFT", 2, -32)

    local list = Widgets.VirtualList(page, ROW_H, CreateRow, UpdateRow)
    list:SetPoint("TOPLEFT", 0, -50)
    list:SetPoint("BOTTOMRIGHT", 0, 0)
    page.list = list

    page.empty = Theme.Text(page, 13, C.inkFaint)
    page.empty:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -10)
    page.empty:SetWidth(480)

    function page:Render()
        for _, chip in ipairs(self.chips) do chip:SetSelected(chip.key == self.category) end
        local items = CoA.Feed:Query(self.category, self.search)
        local total = #CoA.Feed:GetEntries()
        self.list:SetItems(items)
        if #items == total then
            self.count:SetText(string.format("%s entries in your chronicle", Util.FormatNumber(total)))
        else
            self.count:SetText(string.format("Showing %s of %s entries", Util.FormatNumber(#items), Util.FormatNumber(total)))
        end
        self.empty:SetShown(#items == 0)
        self.empty:SetText(total == 0
            and "No events have been recorded yet."
            or "No entries match this filter.")
    end
    return page
end

CoA.UI:RegisterPage("history", {
    label = "Event History", icon = "Interface\\Icons\\INV_Scroll_03", order = 6,
    create = Create,
    refresh = function(page) page:Render() end,
})
