--[[
  Chronicles of Azeroth - UI/Pages/Upcoming.lua

  Chapters that are not built yet, shown as "sealed" pages that say what
  they will contain instead of filling the UI with placeholder numbers.
  Since Phase 2 only Challenges (Phase 3) remains here.
]]

local _, CoA = ...
local Theme = CoA.Theme
local C = Theme.C

---------------------------------------------------------------------------
-- Sealed chapter (shared by Achievements and Challenges)
---------------------------------------------------------------------------
local function SealedPage(icon, heading, phase, lines)
    return function(parent)
        local page = CreateFrame("Frame", nil, parent)
        local box = CreateFrame("Frame", nil, page)
        box:SetSize(460, 300)
        box:SetPoint("CENTER", 0, 20)

        local iconFrame = Theme.Icon(box, 64, icon)
        iconFrame:SetPoint("TOP", 0, 0)
        iconFrame.icon:SetDesaturated(true)

        local h = Theme.Heading(box, 24)
        h:SetPoint("TOP", iconFrame, "BOTTOM", 0, -14)
        h:SetJustifyH("CENTER")
        h:SetText(heading)

        local p = Theme.Text(box, 12, C.inkMuted, Theme.FONT_HEADING)
        p:SetPoint("TOP", h, "BOTTOM", 0, -4)
        p:SetJustifyH("CENTER")
        p:SetText("This chapter is still sealed - " .. phase)

        local div = Theme.Divider(box, 300)
        div:SetPoint("TOP", p, "BOTTOM", 0, -12)

        local body = Theme.Text(box, 13, C.ink)
        body:SetPoint("TOP", div, "BOTTOM", 0, -14)
        body:SetWidth(440)
        body:SetJustifyH("CENTER")
        if body.SetSpacing then body:SetSpacing(4) end
        body:SetText(table.concat(lines, "\n"))
        return page
    end
end

CoA.UI:RegisterPage("challenges", {
    label = "Challenges", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 4,
    badge = "Phase 3",
    create = SealedPage("Interface\\Icons\\Ability_Warrior_BattleShout", "Challenges", "arrives in Phase 3", {
        "Optional personal trials you choose to pursue:",
        "exploration, combat, dungeons, collection, social and general.",
        "",
        Theme.Hex(C.inkFaint) .. "Only challenges the Forever client can reliably detect",
        "will be offered.|r",
    }),
})
