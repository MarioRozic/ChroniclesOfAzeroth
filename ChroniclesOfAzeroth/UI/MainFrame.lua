--[[
  Chronicles of Azeroth - UI/MainFrame.lua

  The main window, built like Blizzard's own panels (v0.3.0 redesign):
    * ButtonFrameTemplate: stone frame, round player portrait, title bar,
      the standard close button and an inset content area
    * PanelTabButtonTemplate tabs along the bottom edge, as on the
      character and spellbook windows
  Movable (drag anywhere on the frame border/title), resizable (bottom-right
  grip), closes with Escape or the X, remembers position, size and tab.
  If a template is missing on the client, a plain fallback frame is drawn.

  Pages register themselves with UI:RegisterPage(key, def):
    def = { label, icon, order, create = function(parent) -> frame,
            refresh = function(frame) }   -- refresh is optional
  Pages are created lazily the first time they are shown.
]]

local _, CoA = ...
local Theme, Compat = CoA.Theme, CoA.Compat
local C = Theme.C

local UI = {}
CoA.UI = UI

UI.pages = {}
UI.pageOrder = {}

local MIN_W, MIN_H, MAX_W, MAX_H = 700, 480, 1600, 1100
local DEFAULT_W, DEFAULT_H = 820, 580

function UI:RegisterPage(key, def)
    def.key = key
    self.pages[key] = def
    self.pageOrder[#self.pageOrder + 1] = def
    table.sort(self.pageOrder, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
local function BuildFallbackChrome(f)
    -- Drawn only if ButtonFrameTemplate is unavailable on this client.
    local body = Theme.SolidTexture(f, "BACKGROUND", C.leather, -8)
    body:SetAllPoints()
    Theme.Border(f, C.goldDim, 0, "BORDER")
    local title = Theme.Heading(f, 14)
    title:SetPoint("TOP", 0, -6)
    title:SetJustifyH("CENTER")
    f.fallbackTitle = title
    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    local x = Theme.Text(close, 16, C.gold)
    x:SetPoint("CENTER")
    x:SetText("x")
    f.CloseButton = close
    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT", 8, -60)
    inset:SetPoint("BOTTOMRIGHT", -8, 8)
    Theme.Panel(inset, "inset")
    f.Inset = inset
    local portrait = f:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(50, 50)
    portrait:SetPoint("TOPLEFT", 8, -6)
    f.fallbackPortrait = portrait
end

local function SetWindowTitle(f, text)
    if f.SetTitle then
        pcall(f.SetTitle, f, text)
    elseif f.TitleContainer and f.TitleContainer.TitleText then
        f.TitleContainer.TitleText:SetText(text)
    elseif f.TitleText then
        f.TitleText:SetText(text)
    elseif f.fallbackTitle then
        f.fallbackTitle:SetText(text)
    end
end

local function SetWindowPortrait(f)
    if f.SetPortraitToUnit then
        if pcall(f.SetPortraitToUnit, f, "player") then return end
    end
    local tex = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait or f.fallbackPortrait
    if tex and SetPortraitTexture then SetPortraitTexture(tex, "player") end
end

local function CreateTabs(f)
    f.tabs = {}
    local name = f:GetName()
    local prev
    for i, def in ipairs(UI.pageOrder) do
        local tab, native = Theme.TryCreate("Button", name .. "Tab" .. i, f, "PanelTabButtonTemplate")
        tab:SetID(i)
        tab.pageKey = def.key
        if native then
            tab:SetText(def.label)
            if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
        else
            tab:SetSize(108, 28)
            local bg = Theme.SolidTexture(tab, "BACKGROUND", C.leatherLight)
            bg:SetAllPoints()
            Theme.Border(tab, C.goldDim)
            tab.fallbackLabel = Theme.Text(tab, 12, C.gold)
            tab.fallbackLabel:SetPoint("CENTER")
            tab.fallbackLabel:SetText(def.label)
        end
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", native and 3 or 4, 0)
        else
            tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
        end
        tab:SetScript("OnClick", function()
            Compat.PlaySound("IG_CHARACTER_INFO_TAB", 841)
            UI:ShowPage(def.key)
        end)
        f.tabs[i] = tab
        prev = tab
    end
    f.numTabs = #f.tabs
    f.Tabs = f.tabs
    if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, f, #f.tabs) end
end

local function SelectTab(f, key)
    for i, tab in ipairs(f.tabs) do
        if tab.pageKey == key then
            if PanelTemplates_SetTab and pcall(PanelTemplates_SetTab, f, i) then return end
        end
        if tab.fallbackLabel then
            local c = tab.pageKey == key and C.ink or C.gold
            tab.fallbackLabel:SetTextColor(c[1], c[2], c[3])
        end
    end
end

-- Gentle fade when the window opens (Blizzard AnimationGroup API).
local function AddOpenAnimation(f)
    if not f.CreateAnimationGroup then return end
    local ok, group = pcall(f.CreateAnimationGroup, f)
    if not ok or not group then return end
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.15)
    if fade.SetSmoothing then fade:SetSmoothing("OUT") end
    f.openAnim = group
end

function UI:CreateMainFrame()
    if self.frame then return self.frame end
    local settings = CoA.db.settings.window
    if settings.width < MIN_W or settings.height < MIN_H then
        settings.width, settings.height = DEFAULT_W, DEFAULT_H
    end

    local f, native = Theme.TryCreate("Frame", "ChroniclesOfAzerothFrame", UIParent, "ButtonFrameTemplate")
    f.native = native
    if native then
        if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    else
        BuildFallbackChrome(f)
    end
    f:SetSize(settings.width, settings.height)
    f:ClearAllPoints()
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
    SetWindowTitle(f, "Chronicles of Azeroth")

    -- Drag to move (title bar and frame border).
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI:SavePosition()
    end)

    -- Close button: the template's button calls HideUIPanel, which ignores
    -- frames that are not registered UI panels - that was the v0.2.0 bug.
    -- Bind it to our own Hide explicitly and keep it above the content.
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function() UI:Hide() end)
        f.CloseButton:SetFrameLevel(f:GetFrameLevel() + 20)
    end

    -- Escape closes the window (standard, taint-free mechanism).
    if UISpecialFrames then table.insert(UISpecialFrames, f:GetName()) end

    -- Header line under the title bar, beside the portrait.
    local subtitle = Theme.Text(f, 12, C.gold)
    subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -32)
    subtitle:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    if subtitle.SetWordWrap then subtitle:SetWordWrap(false) end
    f.subtitle = subtitle

    -- Content host inside the inset.
    local content = CreateFrame("Frame", nil, f)
    local inset = f.Inset or f
    content:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    content:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -8, 8)
    f.content = content
    f.pageFrames = {}

    CreateTabs(f)

    -- Resize grip (Blizzard's chat size grabber art).
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        UI:SavePosition()
    end)

    AddOpenAnimation(f)

    f:SetScript("OnShow", function(self)
        Compat.PlaySound("IG_CHARACTER_INFO_OPEN", 839)
        SetWindowPortrait(self)
        if self.openAnim then self.openAnim:Play() end
        UI:RefreshHeader()
        UI:RefreshCurrent()
    end)
    f:SetScript("OnHide", function()
        Compat.PlaySound("IG_CHARACTER_INFO_CLOSE", 840)
    end)

    -- Keep the open page live as the chronicle grows.
    CoA:On("FEED_ENTRY_ADDED", UI, function() if f:IsShown() then UI:RefreshCurrent() end end)
    CoA:On("CHARACTER_UPDATED", UI, function() if f:IsShown() then UI:RefreshHeader(); UI:RefreshCurrent() end end)
    CoA:On("LOCATION_CHANGED", UI, function() if f:IsShown() then UI:RefreshCurrent() end end)
    CoA:On("CHALLENGES_CHANGED", UI, function() if f:IsShown() then UI:RefreshCurrent() end end)

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
    local level = CoA.char.progress.level or 1
    self.frame.subtitle:SetText(string.format("%s, %s  %s|  Level %d %s %s|r", m.name, CoA.Character:GetTitle(),
        Theme.Hex(C.ink), level, m.raceName, m.className))
end

---------------------------------------------------------------------------
-- Page switching
---------------------------------------------------------------------------
function UI:ShowPage(key)
    local f = self:CreateMainFrame()
    if not self.pages[key] then key = self.pageOrder[1].key end
    local def = self.pages[key]

    for k, frame in pairs(f.pageFrames) do frame:SetShown(k == key) end
    SelectTab(f, key)

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
    s.width, s.height, s.scale = DEFAULT_W, DEFAULT_H, 1
    if self.frame then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER")
        self.frame:SetSize(DEFAULT_W, DEFAULT_H)
        self.frame:SetScale(1)
    end
end

function UI:SetScale(scale)
    scale = math.max(0.6, math.min(1.5, scale))
    CoA.db.settings.window.scale = scale
    if self.frame then self.frame:SetScale(scale) end
end
