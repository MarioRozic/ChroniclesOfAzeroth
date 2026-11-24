--[[
  Chronicles of Azeroth - UI/Pages/Journal.lua

  The Adventure Journal: one diary chapter per day, newest first, written
  from what actually happened (see Modules/Journal.lua). Paged, 15 chapters
  at a time, so long chronicles stay light.
]]

local _, CoA = ...
local Theme, Widgets = CoA.Theme, CoA.Widgets
local C = Theme.C

local PER_PAGE = 15

local function CreateChapterFrame(parent)
    local ch = CreateFrame("Frame", nil, parent)
    ch.title = Theme.Heading(ch, 21)
    ch.title:SetPoint("TOPLEFT", 0, 0)
    ch.year = Theme.Text(ch, 11, C.inkFaint, Theme.FONT_HEADING)
    ch.year:SetPoint("BOTTOMLEFT", ch.title, "BOTTOMRIGHT", 8, 2)
    ch.rule = Theme.HGradientTexture(ch, "ARTWORK", C.goldFaint, { 0, 0, 0, 0 })
    ch.rule:SetHeight(1)
    ch.rule:SetPoint("TOPLEFT", ch.title, "BOTTOMLEFT", 0, -5)
    ch.rule:SetPoint("RIGHT", ch, "RIGHT", 0, 0)
    ch.body = Theme.Text(ch, 13, C.ink)
    ch.body:SetPoint("TOPLEFT", ch.rule, "BOTTOMLEFT", 0, -10)
    if ch.body.SetSpacing then ch.body:SetSpacing(4) end
    return ch
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)

    local intro = Theme.Text(page, 12, C.inkMuted, Theme.FONT_HEADING)
    intro:SetPoint("TOPLEFT", 2, 0)
    intro:SetPoint("RIGHT", page, "RIGHT", -200, 0)
    intro:SetText("Written from your own deeds, one day at a time.")

    page.prev = Widgets.Button(page, "Newer", 80, 22)
    page.next = Widgets.Button(page, "Older", 80, 22)
    page.next:SetPoint("TOPRIGHT", -14, 2)
    page.prev:SetPoint("RIGHT", page.next, "LEFT", -8, 0)
    page.pageLabel = Theme.Text(page, 11, C.inkFaint)
    page.pageLabel:SetPoint("RIGHT", page.prev, "LEFT", -10, 0)
    page.pageLabel:SetJustifyV("MIDDLE")
    page.pageIndex = 1
    page.prev:SetScript("OnClick", function() page.pageIndex = page.pageIndex - 1; page:Render(true) end)
    page.next:SetScript("OnClick", function() page.pageIndex = page.pageIndex + 1; page:Render(true) end)

    local area = Widgets.ScrollArea(page)
    area:SetPoint("TOPLEFT", 0, -32)
    area:SetPoint("BOTTOMRIGHT", 0, 0)
    page.area = area
    page.chapters = {}

    page.empty = Theme.Text(area.content, 13, C.inkFaint)
    page.empty:SetPoint("TOPLEFT", 4, -8)
    page.empty:SetWidth(520)
    page.empty:SetText("The pages are still blank. Travel, fight and help the people of Azeroth, and your journal will fill itself with what you have truly done.")

    area.OnWidthChanged = function() page:Render(false) end

    function page:Render(scrollTop)
        local chapters = CoA.Journal:GetChapters()
        local pages = math.max(1, math.ceil(#chapters / PER_PAGE))
        self.pageIndex = math.max(1, math.min(pages, self.pageIndex))
        self.prev:SetShown(self.pageIndex > 1)
        self.next:SetShown(self.pageIndex < pages)
        self.pageLabel:SetText(pages > 1 and string.format("Page %d of %d", self.pageIndex, pages) or "")
        self.empty:SetShown(#chapters == 0)

        local width = area.content:GetWidth()
        local y = 4
        local first = (self.pageIndex - 1) * PER_PAGE
        for i = 1, PER_PAGE do
            local data = chapters[first + i]
            local ch = self.chapters[i]
            if data then
                if not ch then
                    ch = CreateChapterFrame(area.content)
                    self.chapters[i] = ch
                end
                ch:ClearAllPoints()
                ch:SetPoint("TOPLEFT", area.content, "TOPLEFT", 4, -y)
                ch:SetWidth(math.max(100, width - 8))
                ch.title:SetText(data.title)
                ch.year:SetText(data.year)
                -- Explicit width so GetStringHeight() is correct immediately.
                ch.body:SetWidth(math.max(80, width - 12))
                ch.body:SetText(table.concat(data.paragraphs, "\n\n"))
                local h = (ch.title:GetStringHeight() or 22) + 16 + (ch.body:GetStringHeight() or 14)
                ch:SetHeight(h)
                ch:Show()
                y = y + h + 26
            elseif ch then
                ch:Hide()
            end
        end
        area:SetContentHeight(#chapters == 0 and 60 or y)
        if scrollTop then area:ScrollToTop() end
    end
    return page
end

CoA.UI:RegisterPage("journal", {
    label = "Journal", icon = "Interface\\Icons\\INV_Misc_Book_11", order = 2,
    create = Create,
    refresh = function(page) page:Render(false) end,
})
