--[[
  Chronicles of Azeroth - UI/Pages/Upcoming.lua

  Phase 1 versions of the Exploration, Achievements and Challenges chapters.

  * Exploration already lists the regions recorded by the tracker (real data);
    Phase 2 adds the full exploration interface.
  * Achievements and Challenges are shown as sealed chapters that say what
    they will contain, instead of filling the UI with placeholder numbers.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
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

CoA.UI:RegisterPage("achievements", {
    label = "Milestones", icon = "Interface\\Icons\\Spell_Holy_ChampionsBond", order = 3,
    badge = "Phase 2",
    create = SealedPage("Interface\\Icons\\Spell_Holy_ChampionsBond", "Milestones", "arrives in Phase 2", {
        "Exploration, combat, dungeon and progression milestones,",
        "each with an icon, an unlock date and, for some, a title reward.",
        "",
        Theme.Hex(C.inkFaint) .. "Your chronicle is already recording the travels, levels, quests",
        "and deaths that these milestones will be judged on.|r",
    }),
})

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

---------------------------------------------------------------------------
-- Exploration (Phase 1: list of recorded regions)
---------------------------------------------------------------------------
local ROW_H = 40

local function CreateZoneRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local bg = Theme.SolidTexture(row, "BACKGROUND", { 1, 1, 1, 0.025 })
    bg:SetPoint("TOPLEFT", 0, -2); bg:SetPoint("BOTTOMRIGHT", 0, 2)
    row.bg = bg
    row.name = Theme.Heading(row, 15)
    row.name:SetPoint("TOPLEFT", 10, -5)
    row.detail = Theme.Text(row, 11, C.inkFaint)
    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.right = Theme.Text(row, 12, C.inkMuted)
    row.right:SetPoint("RIGHT", -12, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetJustifyV("MIDDLE")
    return row
end

local function UpdateZoneRow(row, z, index)
    row.bg:SetShown(index % 2 == 0)
    local c = z.isInstance and C.inkMuted or C.gold
    row.name:SetText(z.name)
    row.name:SetTextColor(c[1], c[2], c[3])
    row.detail:SetText((z.isInstance and "Instance  \194\183  " or "") ..
        "First recorded " .. Util.FormatLongDate(z.firstVisit) ..
        "   \194\183   last seen " .. Util.FormatLongDate(z.lastVisit))
    row.right:SetText(string.format("%d visit%s   %d quest%s   %d death%s",
        z.visits, z.visits == 1 and "" or "s",
        z.quests or 0, (z.quests or 0) == 1 and "" or "s",
        z.deaths or 0, (z.deaths or 0) == 1 and "" or "s"))
end

local function CreateExploration(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.summary = Theme.Heading(page, 18)
    page.summary:SetPoint("TOPLEFT", 2, 0)
    local note = Theme.Text(page, 11, C.inkFaint)
    note:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -4)
    note:SetText("Regions recorded by your chronicle. The full exploration atlas arrives in Phase 2.")

    page.list = Widgets.VirtualList(page, ROW_H, CreateZoneRow, UpdateZoneRow)
    page.list:SetPoint("TOPLEFT", 0, -46)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)
    return page
end

local function RefreshExploration(page)
    local items, regions, instances = {}, 0, 0
    for name, z in pairs(CoA.char.exploration.zones) do
        items[#items + 1] = {
            name = name, firstVisit = z.firstVisit or 0, lastVisit = z.lastVisit or 0,
            visits = z.visits or 0, quests = z.quests, deaths = z.deaths, isInstance = z.isInstance,
        }
        if z.isInstance then instances = instances + 1 else regions = regions + 1 end
    end
    table.sort(items, function(a, b) return a.lastVisit > b.lastVisit end)
    page.summary:SetText(string.format("%d region%s explored, %d instance%s entered",
        regions, regions == 1 and "" or "s", instances, instances == 1 and "" or "s"))
    page.list:SetItems(items)
end

CoA.UI:RegisterPage("exploration", {
    label = "Exploration", icon = "Interface\\Icons\\INV_Misc_Map_01", order = 5,
    create = CreateExploration, refresh = RefreshExploration,
})
