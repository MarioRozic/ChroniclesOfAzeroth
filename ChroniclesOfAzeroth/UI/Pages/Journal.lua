--[[
  Chronicles of Azeroth - UI/Pages/Journal.lua

  The Adventure Journal as a book: the left page lists one chapter per day
  (newest first, grouped by month), the right page holds the chosen
  chapter, written from what actually happened (see Modules/Journal.lua).
]]

local _, CoA = ...
local Theme, Widgets = CoA.Theme, CoA.Widgets
local C = Theme.C

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Journal")
    page.intro = Theme.Ink(L, 12, C.bookMuted)
    page.intro:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)
    page.intro:SetPoint("RIGHT", L, "RIGHT", -4, 0)
    page.intro:SetText("Written from your own deeds, one day at a time.")
    local rule = Theme.InkRule(L)
    rule:SetPoint("TOPLEFT", 2, -48); rule:SetPoint("RIGHT", L, "RIGHT", -4, 0)

    page.list = Widgets.SelectList(L, 24, function() page:Render() end)
    page.list:SetPoint("TOPLEFT", 0, -54)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.doc = Widgets.Document(R)
    page.doc.area:SetAllPoints()
    page.doc.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end

    function page:Render()
        local chapters = CoA.Journal:GetChapters()
        local items, byKey, month = {}, {}, nil
        for i, ch in ipairs(chapters) do
            local key = ch.dayKey or ch.title or tostring(i)
            local m = ch.year and (ch.title:match("^(%a+)") or "") .. " " .. ch.year or nil
            if m and m ~= month then
                items[#items + 1] = { header = m }
                month = m
            end
            local date, zone = (ch.title or ""):match("^(.-) %- (.+)$")
            local it = { key = key, text = ch.title, chapter = ch }
            if zone then it.text = date .. "  " .. Theme.Hex(C.bookMuted) .. zone .. "|r" end
            items[#items + 1] = it
            byKey[key] = it
        end
        local selected = self.list:SetSelectableItems(items)

        local d = self.doc
        d:Begin()
        if not selected then
            d:Title("The pages are still blank")
            d:Rule()
            d:Para("Travel, fight and help the people of Azeroth, and your journal will fill itself with what you have truly done.")
        else
            local ch = selected.chapter
            d:Title(ch.title)
            if ch.year then d:Sub(tostring(ch.year)) end
            d:Rule()
            for _, para in ipairs(ch.paragraphs) do d:Para(para) end
        end
        d:End(self.lastKey ~= (selected and selected.key))
        self.lastKey = selected and selected.key
    end
    return page
end

CoA.UI:RegisterPage("journal", {
    label = "Journal", order = 2,
    create = Create,
    refresh = function(page) page:Render() end,
})
