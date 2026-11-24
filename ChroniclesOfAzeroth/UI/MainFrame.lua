--[[
  Chronicles of Azeroth - UI/MainFrame.lua

  The main "tome" window: a leather-bound frame with a gold double border,
  a title plate, chapter navigation on the left and a content page on the
  right. Movable (drag the title), resizable (bottom-right grip), closes
  with Escape, remembers its position, size and last chapter.

  Pages register themselves with UI:RegisterPage(key, def):
    def = { label, icon, order, create = function(parent) -> frame,
            refresh = function(frame) }   -- refresh is optional
  Pages are created lazily the first time they are shown.
]]

local _, CoA = ...
local Theme, Widgets, Compat = CoA.Theme, CoA.Widgets, CoA.Compat
local C = Theme.C

local UI = {}
CoA.UI = UI

UI.pages = {}
UI.pageOrder = {}

local NAV_WIDTH = 188
local HEADER_HEIGHT = 62
local MIN_W, MIN_H, MAX_W, MAX_H = 720, 480, 1600, 1100

function UI:RegisterPage(key, def)
    def.key = key
    self.pages[key] = def
    self.pageOrder[#self.pageOrder + 1] = def
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
local function CreateCornerOrnaments(frame)
    local inset = 5
    for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local d = Theme.Diamond(frame, 9, C.gold, "OVERLAY")
        local x = string.find(p, "LEFT") and inset or -inset
        local y = string.find(p, "TOP") and -inset or inset
        d:SetPoint("CENTER", frame, p, x, y)
    end
end

local function CreateNavButton(parent, def)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(40)

    local sel = Theme.HGradientTexture(b, "BACKGROUND", C.selected, { C.gold[1], C.gold[2], C.gold[3], 0 })
    sel:SetAllPoints()
    sel:Hide()
    b.sel = sel
    local marker = Theme.SolidTexture(b, "ARTWORK", C.gold)
    marker:SetPoint("TOPLEFT", 0, -6); marker:SetPoint("BOTTOMLEFT", 0, 6); marker:SetWidth(2)
    marker:Hide()
    b.marker = marker

    local hl = Theme.HGradientTexture(b, "HIGHLIGHT", C.highlight, { C.gold[1], C.gold[2], C.gold[3], 0 })
    hl:SetAllPoints()

    local icon = Theme.Icon(b, 26, def.icon)
    icon:SetPoint("LEFT", 12, 0)
    b.iconFrame = icon

    local label = Theme.Text(b, 15, C.inkMuted, Theme.FONT_HEADING)
    label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    label:SetJustifyV("MIDDLE")
    label:SetText(def.label)
    b.label = label

    if def.badge then
        local badge = Theme.Text(b, 9, C.inkFaint)
        badge:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
        badge:SetText(def.badge)
    end

    function b:SetSelected(on)
        self.sel:SetShown(on)
        self.marker:SetShown(on)
        local c = on and C.gold or C.inkMuted
        self.label:SetTextColor(c[1], c[2], c[3])
        self.iconFrame.icon:SetDesaturated(not on)
        if self.iconFrame.icon.SetVertexColor then
            local v = on and 1 or 0.75
            self.iconFrame.icon:SetVertexColor(v, v, v)
        end
    end
    b:SetScript("OnClick", function() UI:ShowPage(def.key) end)
    return b
end

function UI:CreateMainFrame()
    if self.frame then return self.frame end
    local settings = CoA.db.settings.window

    local f = CreateFrame("Frame", "ChroniclesOfAzerothFrame", UIParent)
    f:SetSize(settings.width, settings.height)
    f:SetPoint(settings.point, UIParent, settings.relPoint, settings.x, settings.y)
    f:SetScale(settings.scale or 1)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    Compat.SetResizeBounds(f, MIN_W, MIN_H, MAX_W, MAX_H)
    f:EnableMouse(true)
    f:Hide()

    -- Leather body + outer and inner gold rules (double border).
    local body = Theme.SolidTexture(f, "BACKGROUND", C.leather, -8)
    body:SetAllPoints()
    local shade = Theme.GradientTexture(f, "BACKGROUND", { 0, 0, 0, 0 }, { 0, 0, 0, 0.35 }, -7)
    shade:SetAllPoints()
    Theme.Border(f, C.goldDim, 0, "BORDER")
    Theme.Border(f, C.goldFaint, 4, "BORDER")
    CreateCornerOrnaments(f)

    -- Escape closes the window (standard, taint-free mechanism).
    if UISpecialFrames then table.insert(UISpecialFrames, f:GetName()) end

    -- Header (drag handle) ------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(HEADER_HEIGHT)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        UI:SavePosition()
    end)

    local title = Theme.Heading(header, 26)
    title:SetPoint("TOP", 0, -6)
    title:SetJustifyH("CENTER")
    title:SetText("Chronicles of Azeroth")

    local subtitle = Theme.Text(header, 13, C.inkMuted, Theme.FONT_HEADING)
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetJustifyH("CENTER")
    f.subtitle = subtitle

    local divider = Theme.Divider(header, 420)
    divider:SetPoint("BOTTOM", 0, 0)

    local close = Widgets.IconButton(f, 22, "x")
    close:SetPoint("TOPRIGHT", -14, -12)
    close:SetScript("OnClick", function() UI:Hide() end)

    -- Navigation (chapters) --------------------------------------------------
    local nav = CreateFrame("Frame", nil, f)
    nav:SetPoint("TOPLEFT", 12, -(HEADER_HEIGHT + 16))
    nav:SetPoint("BOTTOMLEFT", 12, 12)
    nav:SetWidth(NAV_WIDTH)
    f.nav = nav

    local navLine = Theme.SolidTexture(f, "BORDER", C.goldFaint)
    navLine:SetPoint("TOPLEFT", nav, "TOPRIGHT", 6, 0)
    navLine:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 6, 0)
    navLine:SetWidth(1)

    f.navButtons = {}
    for i, def in ipairs(self.pageOrder) do
        local b = CreateNavButton(nav, def)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 44)
        b:SetPoint("RIGHT", nav, "RIGHT", 0, 0)
        f.navButtons[def.key] = b
    end

    local footer = Theme.Text(nav, 10, C.inkFaint)
    footer:SetPoint("BOTTOMLEFT", 4, 2)
    footer:SetPoint("BOTTOMRIGHT", -4, 2)
    footer:SetText("v" .. CoA.version .. "  \194\183  /coa help")

    -- Content host ----------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 20, 0)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    f.content = content
    f.pageFrames = {}

    -- Resize grip -------------------------------------------------------------
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        UI:SavePosition()
    end)

    f:SetScript("OnShow", function()
        Compat.PlaySound("IG_SPELLBOOK_OPEN", 829)
        UI:RefreshHeader()
        UI:RefreshCurrent()
    end)
    f:SetScript("OnHide", function()
        Compat.PlaySound("IG_SPELLBOOK_CLOSE", 830)
    end)

    -- Keep the open page live as the chronicle grows.
    CoA:On("FEED_ENTRY_ADDED", UI, function() if f:IsShown() then UI:RefreshCurrent() end end)
    CoA:On("CHARACTER_UPDATED", UI, function() if f:IsShown() then UI:RefreshHeader(); UI:RefreshCurrent() end end)
    CoA:On("LOCATION_CHANGED", UI, function() if f:IsShown() then UI:RefreshCurrent() end end)

    self.frame = f
    return f
end

function UI:SavePosition()
    local f = self.frame
    local s = CoA.db.settings.window
    local point, _, relPoint, x, y = f:GetPoint(1)
    s.point, s.relPoint, s.x, s.y = point or "CENTER", relPoint or "CENTER", x or 0, y or 0
    s.width, s.height = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
end

function UI:RefreshHeader()
    local m = CoA.char and CoA.char.meta
    if not (self.frame and m) then return end
    self.frame.subtitle:SetText("The journey of " .. m.name .. ", " .. CoA.Character:GetTitle())
end

---------------------------------------------------------------------------
-- Page switching
---------------------------------------------------------------------------
function UI:ShowPage(key)
    local f = self:CreateMainFrame()
    if not self.pages[key] then key = self.pageOrder[1].key end
    local def = self.pages[key]

    for k, frame in pairs(f.pageFrames) do frame:SetShown(k == key) end
    for k, b in pairs(f.navButtons) do b:SetSelected(k == key) end

    local page = f.pageFrames[key]
    if not page then
        page = def.create(f.content)
        page:SetAllPoints(f.content)
        f.pageFrames[key] = page
    end
    page:Show()
    self.current = key
    CoA.db.settings.window.lastTab = key
    if def.refresh then def.refresh(page) end
end

function UI:RefreshCurrent()
    if not self.current then return end
    local def = self.pages[self.current]
    local page = self.frame and self.frame.pageFrames[self.current]
    if def and def.refresh and page then def.refresh(page) end
end

function UI:Show(key)
    if not CoA.ready then return end  -- e.g. compartment clicked during loading
    local f = self:CreateMainFrame()
    f:Show()
    self:ShowPage(key or self.current or CoA.db.settings.window.lastTab)
end

function UI:Hide()
    if self.frame then self.frame:Hide() end
end

function UI:Toggle(key)
    if self.frame and self.frame:IsShown() and (not key or key == self.current) then
        self:Hide()
    else
        self:Show(key)
    end
end

function UI:ResetPosition()
    local s = CoA.db.settings.window
    s.point, s.relPoint, s.x, s.y = "CENTER", "CENTER", 0, 0
    s.width, s.height, s.scale = 860, 600, 1
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER")
        self.frame:SetSize(860, 600)
        self.frame:SetScale(1)
    end
end

function UI:SetScale(scale)
    scale = math.max(0.6, math.min(1.5, scale))
    CoA.db.settings.window.scale = scale
    if self.frame then self.frame:SetScale(scale) end
end
