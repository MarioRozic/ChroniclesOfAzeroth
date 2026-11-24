--[[
  Chronicles of Azeroth - UI/Toast.lua

  A small notification in Blizzard's tooltip style for milestones and
  completed challenges: icon, header, name, short description and an
  optional sound. It glides down while fading in, then fades out.

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

local HEADERS = {
    milestone = "Milestone earned",
    challenge = "Challenge completed",
    summary   = "Chronicle updated",
}
local SLIDE = 18   -- pixels the toast glides down while fading in

local function Create()
    local f = CreateFrame("Frame", "ChroniclesOfAzerothToast", UIParent)
    f:SetSize(360, 72)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(false)
    f:Hide()

    -- Blizzard tooltip-style box (BackdropTemplate), with a plain fallback.
    if not Theme.ApplyBackdrop(f, { 0.03, 0.03, 0.03, 0.92 }, C.gold) then
        local bg = Theme.SolidTexture(f, "BACKGROUND", { 0.03, 0.03, 0.03, 0.92 })
        bg:SetAllPoints()
        Theme.Border(f, C.gold)
    end
    local glow = Theme.GradientTexture(f, "BORDER", { 1, 0.82, 0, 0.12 }, { 1, 0.82, 0, 0 })
    glow:SetPoint("TOPLEFT", 4, -4)
    glow:SetPoint("TOPRIGHT", -4, -4)
    glow:SetHeight(30)

    f.icon = Theme.Icon(f, 46)
    f.icon:SetPoint("LEFT", 13, 0)
    Theme.SetBorderColor(f.icon.edges, C.gold)

    f.header = Theme.Text(f, 11, C.inkMuted)
    f.header:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, -1)
    f.name = Theme.Heading(f, 16)
    f.name:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -3)
    f.name:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.desc = Theme.Text(f, 11, C.ink)
    f.desc:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
    f.desc:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    if f.desc.SetWordWrap then f.desc:SetWordWrap(false) end

    f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        local t = self.elapsed
        local alpha, slide
        if t < FADE_IN then
            local p = t / FADE_IN
            alpha, slide = p, (1 - p) * (1 - p) * SLIDE   -- ease out
        elseif t < FADE_IN + HOLD then
            alpha, slide = 1, 0
        elseif t < FADE_IN + HOLD + FADE_OUT then
            alpha, slide = 1 - (t - FADE_IN - HOLD) / FADE_OUT, 0
        else
            self:Hide()
            Toast:Next()
            return
        end
        self:SetAlpha(alpha)
        self:ClearAllPoints()
        self:SetPoint("TOP", UIParent, "TOP", 0, -150 + slide)
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
    f.header:SetText(HEADERS[def.kind or "milestone"] or HEADERS.milestone)
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
