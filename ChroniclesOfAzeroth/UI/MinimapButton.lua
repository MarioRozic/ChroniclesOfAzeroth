--[[
  Chronicles of Azeroth - UI/MinimapButton.lua

  A small book icon on the minimap edge (drag to move it around the rim),
  plus the Addon Compartment entry declared in the .toc. No LibDBIcon.
]]

local _, CoA = ...
local Theme = CoA.Theme
local MinimapButton = CoA:NewModule("MinimapButton")

local RADIUS_PAD = 10

local function UpdatePosition(button)
    local angle = math.rad(CoA.db.settings.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + RADIUS_PAD
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function ShowTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Chronicles of Azeroth", Theme.C.gold[1], Theme.C.gold[2], Theme.C.gold[3])
    GameTooltip:AddLine("Left-click: open your chronicle", 0.9, 0.85, 0.7)
    GameTooltip:AddLine("Right-click: event history", 0.9, 0.85, 0.7)
    GameTooltip:AddLine("Drag: move this button", 0.6, 0.55, 0.45)
    GameTooltip:Show()
end

function MinimapButton:OnEnable()
    if not Minimap or CoA.db.settings.minimap.hide then return end
    self:Create()
end

function MinimapButton:Create()
    if self.button or not Minimap then return end
    local b = CreateFrame("Button", "ChroniclesOfAzerothMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then CoA.UI:Toggle("history") else CoA.UI:Toggle() end
    end)
    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            CoA.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    UpdatePosition(b)
    self.button = b
end

function MinimapButton:SetShown(show)
    CoA.db.settings.minimap.hide = not show
    if show then
        self:Create()
        if self.button then self.button:Show() end
    elseif self.button then
        self.button:Hide()
    end
end

-- Addon Compartment (the addons button by the minimap on Mainline clients).
-- These globals are referenced by name from the .toc.
function ChroniclesOfAzeroth_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then CoA.UI:Toggle("history") else CoA.UI:Toggle() end
end

function ChroniclesOfAzeroth_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowTooltip(menuButtonFrame)
end

function ChroniclesOfAzeroth_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end
