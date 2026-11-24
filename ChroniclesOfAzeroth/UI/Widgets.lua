--[[
  Chronicles of Azeroth - UI/Widgets.lua

  Reusable, template-free widgets in the addon's visual style:
    Widgets.Button(parent, text, width, height)
    Widgets.ScrollArea(parent)          - scrollable content of any height
    Widgets.VirtualList(parent, rowHeight, createRow, updateRow)
                                        - fast list for thousands of rows
    Widgets.SearchBox(parent, width, onChanged)
    Widgets.Chip(parent, text)          - small toggle used for filters

  No Blizzard XML templates are used, so the widgets do not depend on
  template names that may differ between client versions.
]]

local _, CoA = ...
local Theme = CoA.Theme
local C = Theme.C
local Widgets = {}
CoA.Widgets = Widgets

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
function Widgets.Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 120, height or 24)
    local bg = Theme.GradientTexture(b, "BACKGROUND", C.leatherLight, C.leather)
    bg:SetAllPoints()
    b.edges = Theme.Border(b, C.goldDim)
    local hl = Theme.SolidTexture(b, "HIGHLIGHT", C.highlight)
    hl:SetAllPoints()

    local label = Theme.Text(b, 12, C.gold, Theme.FONT_HEADING)
    label:SetPoint("CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(text or "")
    b.label = label

    b:SetScript("OnEnter", function(self) Theme.SetBorderColor(self.edges, C.gold) end)
    b:SetScript("OnLeave", function(self) Theme.SetBorderColor(self.edges, C.goldDim) end)
    b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    return b
end

-- A flat icon button (close "x", etc.)
function Widgets.IconButton(parent, size, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local label = Theme.Text(b, size - 4, C.goldDim, Theme.FONT_HEADING)
    label:SetPoint("CENTER", 0, 1)
    label:SetJustifyH("CENTER")
    label:SetText(glyph)
    b.label = label
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
    b:SetScript("OnLeave", function(self) self.label:SetTextColor(C.goldDim[1], C.goldDim[2], C.goldDim[3]) end)
    return b
end

---------------------------------------------------------------------------
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
    local tex = Theme.SolidTexture(thumb, "ARTWORK", C.goldDim)
    tex:SetAllPoints()
    bar.thumb, bar.thumbTex = thumb, tex

    thumb:SetScript("OnEnter", function() tex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1) end)
    thumb:SetScript("OnLeave", function() tex:SetColorTexture(C.goldDim[1], C.goldDim[2], C.goldDim[3], 1) end)

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
-- Search box
---------------------------------------------------------------------------
function Widgets.SearchBox(parent, width, onChanged)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width or 180, 22)
    box:SetAutoFocus(false)
    box:SetFont(Theme.FONT_BODY, 12, "")
    box:SetTextColor(C.ink[1], C.ink[2], C.ink[3])
    box:SetTextInsets(8, 8, 0, 0)
    box:SetMaxLetters(60)
    local bg = Theme.SolidTexture(box, "BACKGROUND", C.inset)
    bg:SetAllPoints()
    box.edges = Theme.Border(box, C.goldFaint)

    local hint = Theme.Text(box, 12, C.inkFaint)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetJustifyV("MIDDLE")
    hint:SetText("Search the chronicle...")
    box.hint = hint

    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) Theme.SetBorderColor(self.edges, C.goldDim) end)
    box:SetScript("OnEditFocusLost", function(self) Theme.SetBorderColor(self.edges, C.goldFaint) end)
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if onChanged then onChanged(text) end
    end)
    return box
end

---------------------------------------------------------------------------
-- Chip: a small toggle used for category filters.
---------------------------------------------------------------------------
function Widgets.Chip(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    local label = Theme.Text(b, 12, C.inkMuted, Theme.FONT_HEADING)
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetText(text)
    b:SetWidth(label:GetStringWidth() + 22)
    b.label = label
    local sel = Theme.SolidTexture(b, "BACKGROUND", C.selected)
    sel:SetAllPoints()
    sel:Hide()
    b.sel = sel
    b.edges = Theme.Border(b, C.goldFaint)
    local hl = Theme.SolidTexture(b, "HIGHLIGHT", C.highlight)
    hl:SetAllPoints()

    function b:SetSelected(on)
        self.selected = on
        self.sel:SetShown(on)
        local c = on and C.gold or C.inkMuted
        self.label:SetTextColor(c[1], c[2], c[3])
        Theme.SetBorderColor(self.edges, on and C.goldDim or C.goldFaint)
    end
    return b
end

---------------------------------------------------------------------------
-- ProgressBar (Phase 2): thin gold bar with an optional "12 / 50" label.
---------------------------------------------------------------------------
function Widgets.ProgressBar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width or 120, height or 8)
    local bg = Theme.SolidTexture(bar, "BACKGROUND", C.inset)
    bg:SetAllPoints()
    bar.edges = Theme.Border(bar, C.goldFaint)
    local fill = Theme.HGradientTexture(bar, "ARTWORK", C.goldDim, C.gold)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", 1, 1)
    fill:SetWidth(1)
    bar.fill = fill
    bar.label = Theme.Text(bar, 10, C.inkMuted)
    bar.label:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 3)
    bar.label:SetJustifyH("RIGHT")

    function bar:SetProgress(current, max, text)
        local frac = (max and max > 0) and math.max(0, math.min(1, current / max)) or 0
        local w = math.max(1, (self:GetWidth() - 2) * frac)
        self.fill:SetWidth(w)
        self.fill:SetShown(frac > 0)
        self.label:SetText(text or "")
    end
    return bar
end
