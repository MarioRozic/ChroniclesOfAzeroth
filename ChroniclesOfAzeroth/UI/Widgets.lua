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
