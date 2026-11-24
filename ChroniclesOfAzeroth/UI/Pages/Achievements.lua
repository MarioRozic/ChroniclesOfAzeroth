--[[
  Chronicles of Azeroth - UI/Pages/Achievements.lua  (Phase 2)

  The Milestones chapter: overall progress, the title you wear, category
  filters, and every milestone with its progress or its unlock date.
  Order: earned (newest first), then closest to completion, then unavailable.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local ROW_H = 62

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local bg = Theme.SolidTexture(row, "BACKGROUND", { 1, 1, 1, 0.025 })
    bg:SetPoint("TOPLEFT", 0, -3); bg:SetPoint("BOTTOMRIGHT", 0, 3)
    row.bg = bg
    row.accent = Theme.SolidTexture(row, "ARTWORK", C.gold)
    row.accent:SetPoint("TOPLEFT", 0, -3); row.accent:SetPoint("BOTTOMLEFT", 0, 3); row.accent:SetWidth(2)

    row.icon = Theme.Icon(row, 42)
    row.icon:SetPoint("LEFT", 12, 0)
    row.name = Theme.Heading(row, 14)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -2)
    row.name:SetPoint("RIGHT", row, "RIGHT", -190, 0)
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.desc = Theme.Text(row, 12, C.ink)
    row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.desc:SetPoint("RIGHT", row, "RIGHT", -190, 0)
    if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
    row.reward = Theme.Text(row, 10, C.goldDim)
    row.reward:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -3)

    row.bar = Widgets.ProgressBar(row, 170, 14)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    row.date = Theme.Text(row, 12, C.gold, Theme.FONT_HEADING)
    row.date:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -14)
    row.date:SetJustifyH("RIGHT")
    row.where = Theme.Text(row, 10, C.inkFaint)
    row.where:SetPoint("TOPRIGHT", row.date, "BOTTOMRIGHT", 0, -3)
    row.where:SetJustifyH("RIGHT")
    return row
end

local function UpdateRow(row, item, index)
    local A = CoA.Achievements
    local def, unlocked = item.def, item.unlocked
    row.bg:SetShown(index % 2 == 0)
    row.icon.icon:SetTexture(def.icon)
    row.icon.icon:SetDesaturated(not unlocked)
    Theme.SetBorderColor(row.icon.edges, unlocked and C.gold or C.goldFaint)
    row.accent:SetShown(unlocked and true or false)
    row.name:SetText(def.name)
    local nc = unlocked and C.gold or C.inkMuted
    row.name:SetTextColor(nc[1], nc[2], nc[3])
    row.desc:SetText(def.desc)
    local dc = unlocked and C.ink or C.inkFaint
    row.desc:SetTextColor(dc[1], dc[2], dc[3])
    row.reward:SetText(def.title and ("Title reward: " .. def.title) or "")

    if unlocked then
        row.bar:Hide()
        row.date:Show(); row.where:Show()
        row.date:SetText("Earned " .. Util.FormatLongDate(unlocked.t))
        local where = unlocked.level and ("Level " .. unlocked.level) or ""
        if unlocked.zone then where = where .. (where ~= "" and "  \194\183  " or "") .. unlocked.zone end
        row.where:SetText(where)
    elseif not item.available then
        row.bar:Hide()
        row.date:Show(); row.where:Hide()
        row.date:SetText("Unavailable")
        row.date:SetTextColor(C.inkFaint[1], C.inkFaint[2], C.inkFaint[3])
        return
    else
        row.date:Hide(); row.where:Hide()
        row.bar:Show()
        row.bar:SetProgress(item.current, def.target,
            Util.FormatNumber(item.current) .. " / " .. Util.FormatNumber(def.target))
    end
    row.date:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    if not A then return end
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.category = "all"

    page.summary = Theme.Heading(page, 16)
    page.summary:SetPoint("TOPLEFT", 2, 0)
    page.total = Widgets.ProgressBar(page, 240, 14)
    page.total:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -8)

    page.titleLabel = Theme.Text(page, 12, C.inkMuted)
    page.titleLabel:SetPoint("TOPRIGHT", -112, -2)
    page.titleLabel:SetJustifyH("RIGHT")
    page.titleButton = Widgets.Button(page, "Change title", 96, 22)
    page.titleButton:SetPoint("TOPRIGHT", -14, 0)
    page.titleButton:SetScript("OnClick", function()
        -- Cycles: level title -> each earned title -> level title.
        local A = CoA.Achievements
        local titles = A:GetEarnedTitles()
        local current = CoA.char.profile.customTitle
        local nextTitle = titles[1]
        for i, t in ipairs(titles) do
            if t == current then nextTitle = titles[i + 1] end
        end
        A:WearTitle(nextTitle)
        page:Render()
    end)

    page.chips = {}
    local prev
    local cats = { { key = "all", label = "All" } }
    for _, c in ipairs(CoA.AchievementData.CATEGORIES) do cats[#cats + 1] = c end
    for _, cat in ipairs(cats) do
        local chip = Widgets.Chip(page, cat.label)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 5, 0) else chip:SetPoint("TOPLEFT", 0, -50) end
        chip.key = cat.key
        chip:SetScript("OnClick", function() page.category = cat.key; page:Render() end)
        page.chips[#page.chips + 1] = chip
        prev = chip
    end

    page.list = Widgets.VirtualList(page, ROW_H, CreateRow, UpdateRow)
    page.list:SetPoint("TOPLEFT", 0, -82)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    function page:Render()
        local A = CoA.Achievements
        for _, chip in ipairs(self.chips) do chip:SetSelected(chip.key == self.category) end

        local earned, total = A:CountUnlocked()
        self.summary:SetText(string.format("%d of %d milestones earned", earned, total))
        self.total:SetProgress(earned, total, earned .. " / " .. total)

        local titles = A:GetEarnedTitles()
        self.titleButton:SetShown(#titles > 0)
        self.titleLabel:SetText(#titles > 0
            and ("Wearing: " .. Theme.Hex(C.gold) .. CoA.Character:GetTitle() .. "|r")
            or "Earn a milestone with a title reward to wear it.")
        self.titleLabel:ClearAllPoints()
        self.titleLabel:SetPoint("TOPRIGHT", #titles > 0 and -118 or -14, -4)

        local items = {}
        for _, def in ipairs(CoA.AchievementData.LIST) do
            if self.category == "all" or def.category == self.category then
                local unlocked = A:IsUnlocked(def.id)
                local available = A:IsAvailable(def)
                local current = (not unlocked and available) and A:GetProgress(def) or 0
                items[#items + 1] = { def = def, unlocked = unlocked, available = available, current = current }
            end
        end
        table.sort(items, function(a, b)
            if (a.unlocked ~= nil) ~= (b.unlocked ~= nil) then return a.unlocked ~= nil end
            if a.unlocked and b.unlocked then return a.unlocked.t > b.unlocked.t end
            if a.available ~= b.available then return a.available end
            local fa, fb = a.current / a.def.target, b.current / b.def.target
            if fa ~= fb then return fa > fb end
            return a.def.name < b.def.name
        end)
        self.list:SetItems(items)
    end
    return page
end

CoA.UI:RegisterPage("achievements", {
    label = "Milestones", icon = "Interface\\Icons\\Spell_Holy_ChampionsBond", order = 3,
    create = Create,
    refresh = function(page) page:Render() end,
})
