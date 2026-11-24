--[[
  Chronicles of Azeroth - UI/Pages/EventHistory.lua

  The chronological adventure feed as a book: the left page holds the
  search box and the categories (with counts), the right page lists every
  matching entry, newest first. A virtual list keeps thousands of entries
  smooth.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local ROW_H = 44

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.accent = Theme.SolidTexture(row, "ARTWORK", C.bookHead)
    row.accent:SetPoint("TOPLEFT", 0, -4); row.accent:SetPoint("BOTTOMLEFT", 0, 4); row.accent:SetWidth(2)
    row.icon = Theme.Icon(row, 28)
    row.icon:SetPoint("LEFT", 8, 0)
    row.text = Theme.Ink(row, 13, C.bookInk)
    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    if row.text.SetWordWrap then row.text:SetWordWrap(false) end
    row.meta = Theme.Ink(row, 11, C.bookFaint)
    row.meta:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -4)
    row.meta:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    if row.meta.SetWordWrap then row.meta:SetWordWrap(false) end
    row.rule = Theme.InkRule(row)
    row.rule:SetPoint("BOTTOMLEFT", 8, 0); row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    return row
end

-- Category accents darkened so they read on parchment.
local function Accent(cat)
    local cc = Theme.CATEGORY_COLORS[cat] or Theme.CATEGORY_COLORS.system
    return cc[1] * 0.6, cc[2] * 0.6, cc[3] * 0.6
end

local function UpdateRow(row, e)
    local r, g, b = Accent(e.cat)
    row.accent:SetColorTexture(r, g, b, 1)
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
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Event History")
    page.count = Theme.Ink(L, 12, C.bookMuted)
    page.count:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)

    page.searchBox = Widgets.SearchBox(L, 200, function(text)
        page.search = text
        page:Render()
    end)
    page.searchBox:SetPoint("TOPLEFT", 6, -56)
    page.searchBox:SetPoint("RIGHT", L, "RIGHT", -6, 0)

    page.cats = Widgets.SelectList(L, 24, function(item)
        page.category = item.key
        page:Render()
    end)
    page.cats:SetPoint("TOPLEFT", 0, -86)
    page.cats:SetPoint("BOTTOMRIGHT", 0, 0)

    page.listTitle = Theme.BookTitle(R, 20)
    page.listTitle:SetPoint("TOPLEFT", 2, 0)
    local rule = Theme.InkRule(R)
    rule:SetPoint("TOPLEFT", 2, -28); rule:SetPoint("RIGHT", R, "RIGHT", -4, 0)
    page.list = Widgets.VirtualList(R, ROW_H, CreateRow, UpdateRow)
    page.list:SetPoint("TOPLEFT", 0, -34)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)
    page.empty = Theme.Ink(R, 13, C.bookMuted)
    page.empty:SetPoint("TOPLEFT", page.list, "TOPLEFT", 4, -10)
    page.empty:SetPoint("RIGHT", R, "RIGHT", -10, 0)

    function page:Render()
        local total = #CoA.Feed:GetEntries()
        local catItems = {}
        local label = "All entries"
        for _, cat in ipairs(CoA.Feed.CATEGORIES) do
            local n = #CoA.Feed:Query(cat.key, "")
            catItems[#catItems + 1] = { key = cat.key, text = cat.label, right = Util.FormatNumber(n) }
            if cat.key == self.category then label = cat.key == "all" and "All entries" or cat.label end
        end
        self.cats.selectedKey = self.category
        self.cats:SetSelectableItems(catItems)

        local items = CoA.Feed:Query(self.category, self.search)
        self.listTitle:SetText(label)
        self.list:SetItems(items)
        if #items == total then
            self.count:SetText(string.format("%s entries in your chronicle", Util.FormatNumber(total)))
        else
            self.count:SetText(string.format("Showing %s of %s entries", Util.FormatNumber(#items), Util.FormatNumber(total)))
        end
        self.empty:SetShown(#items == 0)
        self.empty:SetText(total == 0 and "No events have been recorded yet." or "No entries match this filter.")
    end
    return page
end

CoA.UI:RegisterPage("history", {
    label = "Event History", order = 6,
    create = Create,
    refresh = function(page) page:Render() end,
})
