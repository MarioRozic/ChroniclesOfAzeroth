--[[
  Chronicles of Azeroth - UI/Toast.lua  (Phase 2; polished further in Phase 3)

  A small RPG-style notification for unlocked milestones: icon, name, short
  description and an optional sound, fading in and out.

  It is never shown during combat: unlocks earned mid-fight are queued and
  shown one by one after PLAYER_REGEN_ENABLED. The frame is a plain,
  non-secure, non-interactive frame, so it cannot cause taint.
]]

local _, CoA = ...
local Theme, Compat = CoA.Theme, CoA.Compat
local C = Theme.C
local Toast = CoA:NewModule("Toast")
CoA.Toast = Toast

local queue = {}
local FADE_IN, HOLD, FADE_OUT = 0.4, 4.5, 0.9

local function Create()
    local f = CreateFrame("Frame", "ChroniclesOfAzerothToast", UIParent)
    f:SetSize(380, 78)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(false)
    f:Hide()

    local bg = Theme.GradientTexture(f, "BACKGROUND", C.parchmentTop, C.leather)
    bg:SetAllPoints()
    Theme.Border(f, C.gold)
    Theme.Border(f, C.goldFaint, 3)
    for _, p in ipairs({ "LEFT", "RIGHT" }) do
        local d = Theme.Diamond(f, 8)
        d:SetPoint("CENTER", f, p, 0, 0)
    end

    f.icon = Theme.Icon(f, 50)
    f.icon:SetPoint("LEFT", 14, 0)
    Theme.SetBorderColor(f.icon.edges, C.gold)

    f.header = Theme.Text(f, 11, C.inkMuted, Theme.FONT_HEADING)
    f.header:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, 0)
    f.header:SetText("Milestone earned")
    f.name = Theme.Heading(f, 19)
    f.name:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -2)
    f.name:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.desc = Theme.Text(f, 11, C.ink)
    f.desc:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.desc:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    if f.desc.SetWordWrap then f.desc:SetWordWrap(false) end

    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        local t = self.elapsed
        if t < FADE_IN then
            self:SetAlpha(t / FADE_IN)
        elseif t < FADE_IN + HOLD then
            self:SetAlpha(1)
        elseif t < FADE_IN + HOLD + FADE_OUT then
            self:SetAlpha(1 - (t - FADE_IN - HOLD) / FADE_OUT)
        else
            self:Hide()
            Toast:Next()
        end
    end)
    return f
end

function Toast:OnEnable()
    CoA:RegisterEvent("PLAYER_REGEN_ENABLED", self, "Next")
end

function Toast:Show(def)
    queue[#queue + 1] = def
    if not (self.frame and self.frame:IsShown()) then self:Next() end
end

local function InCombat()
    return Compat.InCombat() or (UnitAffectingCombat and Compat.Safe(UnitAffectingCombat("player")))
end

function Toast:Next()
    if #queue == 0 or InCombat() then return end
    if self.frame and self.frame:IsShown() then return end
    local def = table.remove(queue, 1)
    self.frame = self.frame or Create()
    local f = self.frame
    f.icon.icon:SetTexture(def.icon)
    f.name:SetText(def.name)
    f.desc:SetText(def.title and (def.desc .. "  Title earned: " .. def.title) or def.desc)
    f.elapsed = 0
    f:SetAlpha(0)
    f:Show()
    if CoA.db.settings.playSounds then
        Compat.PlaySound("IG_QUEST_LIST_COMPLETE", nil)  -- only plays if the kit exists
    end
end

-- Used by "/coa toast" to preview the notification.
function Toast:Preview()
    self:Show({ name = "Wanderer", desc = "Visit 5 different regions.",
                icon = "Interface\\Icons\\Ability_Tracking" })
end
