--[[
  Chronicles of Azeroth - UI/Widgets.lua

  Reusable widgets in Blizzard's native style:
    Widgets.Button(parent, text, width, height)
    Widgets.ScrollArea(parent)          - scrollable content of any height
    Widgets.VirtualList(parent, rowHeight, createRow, updateRow)
                                        - fast list for thousands of rows
    Widgets.SearchBox(parent, width, onChanged)
    Widgets.Chip(parent, text)          - small toggle used for filters
    Widgets.ProgressBar(parent, width, height)

  Buttons and the search box use Blizzard templates (UIPanelButtonTemplate,
  SearchBoxTemplate) through Theme.TryCreate, with a drawn fallback if a
  template is ever missing.
]]

local _, CoA = ...
local Theme = CoA.Theme
local Util = CoA.Util
local C = Theme.C
local Widgets = {}
CoA.Widgets = Widgets

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Button: Blizzard's red panel button (UIPanelButtonTemplate).
---------------------------------------------------------------------------
function Widgets.Button(parent, text, width, height)
    local b, native = Theme.TryCreate("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, height or 22)
    if native then
        b:SetText(text or "")
        b.label = b:GetFontString()
        return b
    end
    -- Fallback look
    local bg = Theme.GradientTexture(b, "BACKGROUND", { 0.45, 0.05, 0.03, 1 }, { 0.25, 0.02, 0.01, 1 })
    bg:SetAllPoints()
    b.edges = Theme.Border(b, C.goldDim)
    local hl = Theme.SolidTexture(b, "HIGHLIGHT", C.highlight)
    hl:SetAllPoints()
    local label = Theme.Text(b, 12, C.gold)
    label:SetPoint("CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(text or "")
    b.label = label
    function b:SetText(t) self.label:SetText(t) end
    function b:GetText() return self.label:GetText() end
    return b
end

-- Thin vertical scrollbar (shared by ScrollArea and VirtualList)
---------------------------------------------------------------------------
local function CreateScrollbar(parent, onScrollTo)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(8)
    local track = Theme.SolidTexture(bar, "BACKGROUND", { 0, 0, 0, 0.35 })
    track:SetPoint("TOP"); track:SetPoint("BOTTOM"); track:SetWidth(2)

    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(6)
    thumb:SetPoint("TOP")
    thumb:EnableMouse(true)
    local tex = Theme.SolidTexture(thumb, "ARTWORK", { 0.45, 0.45, 0.45, 1 })
    tex:SetAllPoints()
    bar.thumb, bar.thumbTex = thumb, tex

    thumb:SetScript("OnEnter", function() tex:SetColorTexture(0.75, 0.75, 0.75, 1) end)
    thumb:SetScript("OnLeave", function() tex:SetColorTexture(0.45, 0.45, 0.45, 1) end)

    -- Dragging: convert cursor movement into a 0..1 fraction.
    thumb:SetScript("OnMouseDown", function(self)
        local _, cursorY = GetCursorPosition()
        self.dragStartY = cursorY / self:GetEffectiveScale()
        self.dragStartFrac = bar.fraction or 0
        self:SetScript("OnUpdate", function(s)
            local _, y = GetCursorPosition()
            y = y / s:GetEffectiveScale()
            local travel = bar:GetHeight() - s:GetHeight()
            if travel <= 0 then return end
            local frac = s.dragStartFrac + (s.dragStartY - y) / travel
            onScrollTo(math.max(0, math.min(1, frac)))
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

    -- visibleFrac: share of content that fits; fraction: scroll position 0..1
    function bar:Update(visibleFrac, fraction)
        self.fraction = fraction
        if visibleFrac >= 1 then self:Hide() return end
        self:Show()
        local h = self:GetHeight()
        local thumbH = math.max(24, h * visibleFrac)
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", self, "TOP", 0, -((h - thumbH) * fraction))
    end
    return bar
end

---------------------------------------------------------------------------
-- ScrollArea: a ScrollFrame whose child (`area.content`) can be any height.
-- Call area:SetContentHeight(h) after laying out the content.
---------------------------------------------------------------------------
function Widgets.ScrollArea(parent)
    local area = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, area)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -14, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    area.scroll, area.content = scroll, content

    local function Range()
        return math.max(0, (content:GetHeight() or 0) - scroll:GetHeight())
    end

    local bar = CreateScrollbar(area, function(frac)
        scroll:SetVerticalScroll(Range() * frac)
        area:UpdateBar()
    end)
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)

    function area:UpdateBar()
        local range = Range()
        local h = scroll:GetHeight()
        local total = content:GetHeight()
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
        bar:Update(total > 0 and h / total or 1, range > 0 and scroll:GetVerticalScroll() / range or 0)
    end

    function area:SetContentHeight(h)
        content:SetHeight(math.max(1, h))
        self:UpdateBar()
    end

    function area:ScrollToTop()
        scroll:SetVerticalScroll(0)
        self:UpdateBar()
    end

    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(self, delta)
        local new = scroll:GetVerticalScroll() - delta * 40
        scroll:SetVerticalScroll(math.max(0, math.min(Range(), new)))
        self:UpdateBar()
    end)
    -- Keep the content as wide as the visible area so text wraps properly.
    scroll:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
        if area.OnWidthChanged then area:OnWidthChanged(w) end
        area:UpdateBar()
    end)
    return area
end

---------------------------------------------------------------------------
-- VirtualList: only as many row frames as fit on screen are created, and
-- they are re-filled while scrolling. Handles thousands of feed entries.
--   createRow(parent) -> row frame
--   updateRow(row, item, index)
---------------------------------------------------------------------------
function Widgets.VirtualList(parent, rowHeight, createRow, updateRow)
    local list = CreateFrame("Frame", nil, parent)
    list.rows, list.items, list.offset = {}, {}, 0
    list.rowHeight = rowHeight

    local bar = CreateScrollbar(list, function(frac)
        local maxOffset = math.max(0, #list.items - list:VisibleCount())
        list.offset = math.floor(maxOffset * frac + 0.5)
        list:Refresh()
    end)
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)

    function list:VisibleCount()
        return math.max(1, math.floor((self:GetHeight() or 0) / self.rowHeight))
    end

    function list:SetItems(items)
        self.items = items or {}
        self.offset = 0
        self:Refresh()
    end

    function list:Refresh()
        local visible = self:VisibleCount()
        local maxOffset = math.max(0, #self.items - visible)
        if self.offset > maxOffset then self.offset = maxOffset end

        for i = 1, visible do
            local row = self.rows[i]
            if not row then
                row = createRow(self)
                row:SetHeight(self.rowHeight)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowHeight)
                row:SetPoint("RIGHT", self, "RIGHT", -14, 0)
                self.rows[i] = row
            end
            local index = self.offset + i
            local item = self.items[index]
            if item then
                updateRow(row, item, index)
                row:Show()
            else
                row:Hide()
            end
        end
        for i = visible + 1, #self.rows do self.rows[i]:Hide() end

        bar:Update(#self.items > 0 and visible / #self.items or 1,
            maxOffset > 0 and self.offset / maxOffset or 0)
    end

    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, #self.items - self:VisibleCount())
        self.offset = math.max(0, math.min(maxOffset, self.offset - delta * 3))
        self:Refresh()
    end)
    list:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    return list
end

---------------------------------------------------------------------------
-- Search box: Blizzard's SearchBoxTemplate (magnifier, hint, clear button).
---------------------------------------------------------------------------
function Widgets.SearchBox(parent, width, onChanged)
    local box, native = Theme.TryCreate("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width or 180, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    if native then
        if box.Instructions then box.Instructions:SetText("Search the chronicle") end
        box:HookScript("OnTextChanged", function(self)
            if onChanged then onChanged(self:GetText() or "") end
        end)
        return box
    end
    box:SetFont(Theme.FONT_BODY, 12, "")
    box:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    box:SetTextInsets(8, 8, 0, 0)
    local bg = Theme.SolidTexture(box, "BACKGROUND", C.inset)
    bg:SetAllPoints()
    box.edges = Theme.Border(box, C.goldDim)
    local hint = Theme.Text(box, 12, C.inkFaint)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetJustifyV("MIDDLE")
    hint:SetText("Search the chronicle")
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if onChanged then onChanged(text) end
    end)
    return box
end

---------------------------------------------------------------------------
-- Chip: a filter toggle, drawn as a small Blizzard panel button whose
-- highlight stays lit while selected.
---------------------------------------------------------------------------
function Widgets.Chip(parent, text)
    local b = Widgets.Button(parent, text, 60, 22)
    local fs = b.label or (b.GetFontString and b:GetFontString())
    local w = fs and fs:GetStringWidth() or (#text * 7)
    b:SetWidth(math.max(50, w + 24))
    function b:SetSelected(on)
        self.selected = on
        if self.LockHighlight then
            if on then self:LockHighlight() else self:UnlockHighlight() end
        end
        local label = self.label or (self.GetFontString and self:GetFontString())
        if label then
            local c = on and C.ink or C.gold
            label:SetTextColor(c[1], c[2], c[3])
        end
    end
    return b
end

---------------------------------------------------------------------------
-- ProgressBar: Blizzard status bar (as in the achievement and reputation
-- frames) with the "12 / 50" text on the bar.
---------------------------------------------------------------------------
function Widgets.ProgressBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 120, height or 14)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.0, 0.6, 0.1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local bg = Theme.SolidTexture(bar, "BACKGROUND", { 0, 0, 0, 0.6 })
    bg:SetAllPoints()
    bar.edges = Theme.Border(bar, { 0.45, 0.45, 0.45, 1 }, -1, "OVERLAY")
    bar.label = Theme.Text(bar, 10, C.ink)
    bar.label:SetPoint("CENTER", 0, 0)
    bar.label:SetJustifyH("CENTER")
    bar.label:SetJustifyV("MIDDLE")

    function bar:SetProgress(current, max, text)
        max = (max and max > 0) and max or 1
        self:SetMinMaxValues(0, max)
        self:SetValue(math.max(0, math.min(max, current or 0)))
        self.label:SetText(text or "")
    end
    return bar
end

---------------------------------------------------------------------------
-- SelectList (v0.4.0): the left page of the book, like the Quest Log list.
-- Items: { header = "Combat" }  or
--        { key, text, icon?, right?, dim?, color? }   (color = text colour)
-- list:SetItems(items, keepSelection); list.selectedKey; onSelect(item)
---------------------------------------------------------------------------
function Widgets.SelectList(parent, rowHeight, onSelect)
    rowHeight = rowHeight or 22
    local list

    local function CreateRow(host)
        local row = CreateFrame("Button", nil, host)
        row.sel = Theme.SolidTexture(row, "BACKGROUND", C.bookSelect)
        row.sel:SetAllPoints()
        row.hover = Theme.SolidTexture(row, "BACKGROUND", C.bookHover, 1)
        row.hover:SetAllPoints()
        row.hover:Hide()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(rowHeight - 6, rowHeight - 6)
        row.icon:SetPoint("LEFT", 6, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = Theme.Ink(row, 13, C.bookInk)
        row.text:SetJustifyV("MIDDLE")
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row.right = Theme.Ink(row, 11, C.bookMuted)
        row.right:SetPoint("RIGHT", -6, 0)
        row.right:SetJustifyH("RIGHT")
        row.right:SetJustifyV("MIDDLE")
        row.header = Theme.BookHeading(row, 12)
        row.header:SetPoint("BOTTOMLEFT", 4, 3)
        row:SetScript("OnEnter", function(self) if self.item and not self.item.header then self.hover:Show() end end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        row:SetScript("OnClick", function(self)
            local item = self.item
            if not item or item.header then return end
            list.selectedKey = item.key
            list:Refresh()
            CoA.Compat.PlaySound("IG_QUEST_LIST_SELECT", 875)
            if onSelect then onSelect(item) end
        end)
        return row
    end

    local function UpdateRow(row, item)
        row.item = item
        local isHeader = item.header ~= nil
        row.header:SetShown(isHeader)
        row.text:SetShown(not isHeader)
        row.right:SetShown(not isHeader)
        row.sel:SetShown(not isHeader and item.key == list.selectedKey)
        if isHeader then
            row.icon:Hide()
            row.header:SetText(item.header)
            return
        end
        row.text:ClearAllPoints()
        if item.icon then
            row.icon:SetTexture(item.icon)
            row.icon:SetDesaturated(item.dim and true or false)
            row.icon:Show()
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        else
            row.icon:Hide()
            row.text:SetPoint("LEFT", 10, 0)
        end
        row.text:SetPoint("RIGHT", row, "RIGHT", item.right and -54 or -6, 0)
        row.text:SetText(item.text or "")
        local c = item.color or (item.dim and C.bookFaint or C.bookInk)
        row.text:SetTextColor(c[1], c[2], c[3])
        row.right:SetText(item.right or "")
    end

    list = Widgets.VirtualList(parent, rowHeight, CreateRow, UpdateRow)

    -- Keeps the selection if its key is still listed, else selects the
    -- first selectable item. Returns the selected item.
    function list:SetSelectableItems(items)
        local selected, first
        for _, it in ipairs(items) do
            if not it.header then
                first = first or it
                if it.key == self.selectedKey then selected = it end
            end
        end
        selected = selected or first
        self.selectedKey = selected and selected.key or nil
        local offset = self.offset
        self:SetItems(items)
        -- SetItems scrolls to the top; keep the reader's place on refreshes.
        self.offset = offset or 0
        self:Refresh()
        return selected
    end
    return list
end

---------------------------------------------------------------------------
-- Document (v0.4.0): the right page of the book. A scrollable column of
-- titles, rules, headings, paragraphs, bars and "label .... value" lines,
-- rebuilt on every refresh from pooled regions.
--   doc:Begin()  doc:Title(t)  doc:Sub(t)  doc:Rule()  doc:Heading(t)
--   doc:Para(t, color)  doc:Big(t)  doc:Bar(cur, max)  doc:Pairs(list)
--   doc:Gap(px)  doc:End()
---------------------------------------------------------------------------
function Widgets.Document(parent)
    local area = Widgets.ScrollArea(parent)
    local content = area.content
    local doc = { area = area, pools = {}, used = {}, y = 0 }

    local makers = {
        title = function() return Theme.BookTitle(content, 20) end,
        big = function() return Theme.Ink(content, 30, C.bookHead, Theme.FONT_BOOK) end,
        sub = function() return Theme.Ink(content, 13, C.bookMuted) end,
        heading = function() return Theme.BookHeading(content, 14) end,
        para = function()
            local fs = Theme.Ink(content, 13, C.bookInk)
            if fs.SetSpacing then fs:SetSpacing(3) end
            return fs
        end,
        rule = function() return Theme.InkRule(content) end,
        bar = function()
            local b = Widgets.ProgressBar(content, 260, 16)
            return b
        end,
        pairL = function() return Theme.Ink(content, 13, C.bookInk) end,
        pairR = function()
            local fs = Theme.Ink(content, 13, C.bookHead)
            fs:SetJustifyH("RIGHT")
            return fs
        end,
        dots = function()
            local f = C.bookFaint
            local t = Theme.SolidTexture(content, "ARTWORK", { f[1], f[2], f[3], 0.35 })
            t:SetHeight(1)
            return t
        end,
    }

    local function Take(kind)
        doc.pools[kind] = doc.pools[kind] or {}
        doc.used[kind] = (doc.used[kind] or 0) + 1
        local r = doc.pools[kind][doc.used[kind]]
        if not r then
            r = makers[kind]()
            doc.pools[kind][doc.used[kind]] = r
        end
        r:ClearAllPoints()
        r:Show()
        return r
    end

    local function Width()
        local w = content:GetWidth() or 0
        if w < 50 then w = (area:GetWidth() or 300) - 14 end
        return math.max(80, w - 4)
    end

    local function Text(kind, text, color, gapBefore)
        doc.y = doc.y + (gapBefore or 0)
        local fs = Take(kind)
        fs:SetWidth(Width())
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -doc.y)
        fs:SetText(text or "")
        if color then fs:SetTextColor(color[1], color[2], color[3]) end
        doc.y = doc.y + (fs:GetStringHeight() or 14)
        return fs
    end

    function doc:Begin()
        for kind, pool in pairs(self.pools) do
            for _, r in ipairs(pool) do r:Hide() end
            self.used[kind] = 0
        end
        self.y = 2
    end
    function doc:Title(t, color) return Text("title", t, color or C.bookHead, 0) end
    function doc:Big(t) return Text("big", t, C.bookHead, 4) end
    function doc:Sub(t) return Text("sub", t, C.bookMuted, 4) end
    function doc:Heading(t) return Text("heading", t, C.bookHead, 16) end
    function doc:Para(t, color) return Text("para", t, color or C.bookInk, 8) end
    function doc:Gap(px) self.y = self.y + (px or 8) end
    function doc:Rule()
        self.y = self.y + 6
        local r = Take("rule")
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -self.y)
        r:SetWidth(Width())
        self.y = self.y + 4
    end
    function doc:Bar(cur, max, label)
        self.y = self.y + 8
        local b = Take("bar")
        b:SetWidth(math.min(300, Width()))
        b:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -self.y)
        b:SetProgress(cur, max, label or (Util.FormatNumber(cur) .. " / " .. Util.FormatNumber(max)))
        self.y = self.y + 18
    end
    -- Two columns of "label ..... value" lines when there is room.
    function doc:Pairs(list)
        local width = Width()
        local cols = width > 420 and 2 or 1
        local colW = (width - (cols - 1) * 20) / cols
        local rowH = 24
        local top = self.y + 6
        for i, p in ipairs(list) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local x, y = 2 + col * (colW + 20), top + row * rowH
            local l = Take("pairL")
            l:SetWidth(colW - 70)
            l:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(y + 4))
            l:SetText(p[1])
            if l.SetWordWrap then l:SetWordWrap(false) end
            local r = Take("pairR")
            r:SetWidth(70)
            r:SetPoint("TOPRIGHT", content, "TOPLEFT", x + colW, -(y + 4))
            r:SetText(p[2])
            local d = Take("dots")
            d:SetWidth(colW)
            d:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(y + rowH - 2))
        end
        self.y = top + math.ceil(#list / cols) * rowH
    end
    function doc:End(scrollTop)
        area:SetContentHeight(self.y + 12)
        if scrollTop then area:ScrollToTop() end
    end
    return doc
end
