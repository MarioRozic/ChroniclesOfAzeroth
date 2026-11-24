--[[
  Chronicles of Azeroth - UI/Pages/Challenges.lua  (Phase 3)

  The Challenges chapter: pick up to five personal challenges, follow their
  progress and abandon them. Challenges can be taken again after they are
  completed or failed.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local ROW_H = 64

local function CategoryLabel(key)
    for _, c in ipairs(CoA.ChallengeData.CATEGORIES) do
        if c.key == key then return c.label end
    end
    return key
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    local bg = Theme.SolidTexture(row, "BACKGROUND", { 1, 1, 1, 0.03 })
    bg:SetPoint("TOPLEFT", 0, -2); bg:SetPoint("BOTTOMRIGHT", 0, 2)
    row.bg = bg
    row.accent = Theme.SolidTexture(row, "ARTWORK", C.gold)
    row.accent:SetPoint("TOPLEFT", 0, -2); row.accent:SetPoint("BOTTOMLEFT", 0, 2); row.accent:SetWidth(2)

    row.icon = Theme.Icon(row, 40)
    row.icon:SetPoint("LEFT", 12, 0)
    row.name = Theme.Heading(row, 14)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -2)
    row.name:SetPoint("RIGHT", row, "RIGHT", -200, 0)
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.desc = Theme.Text(row, 12, C.ink)
    row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.desc:SetPoint("RIGHT", row, "RIGHT", -200, 0)
    if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
    row.meta = Theme.Text(row, 10, C.inkFaint)
    row.meta:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -4)
    row.meta:SetPoint("RIGHT", row, "RIGHT", -200, 0)
    if row.meta.SetWordWrap then row.meta:SetWordWrap(false) end

    row.bar = Widgets.ProgressBar(row, 170, 14)
    row.bar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -12)

    row.button = Widgets.Button(row, "Accept", 110, 22)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 10)
    row.button:SetScript("OnClick", function(self)
        local item = row.item
        if not item then return end
        local Ch = CoA.Challenges
        if Ch:IsActive(item.def.id) then
            Ch:Abandon(item.def.id)
            CoA.Compat.PlaySound("IG_QUEST_LOG_ABANDON_QUEST", 846)
        else
            local ok, reason = Ch:Accept(item.def.id)
            if ok then
                CoA.Compat.PlaySound("IG_QUEST_LIST_OPEN", 875)
            elseif reason then
                CoA:Print(reason)
            end
        end
    end)
    row.button:SetScript("OnEnter", function(self)
        if row.reason and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(row.reason, 1, 0.82, 0, true)
            GameTooltip:Show()
        end
    end)
    row.button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    row.note = Theme.Text(row, 10, C.inkFaint)
    row.note:SetPoint("BOTTOMRIGHT", row.button, "TOPRIGHT", 0, 4)
    row.note:SetJustifyH("RIGHT")
    return row
end

local function UpdateRow(row, item, index)
    local Ch = CoA.Challenges
    local def, state = item.def, item.state
    row.item = item
    row.bg:SetShown(index % 2 == 0)
    row.icon.icon:SetTexture(def.icon)
    row.icon.icon:SetDesaturated(not state and not item.canAccept)
    Theme.SetBorderColor(row.icon.edges, state and C.gold or { 0.35, 0.35, 0.35, 1 })
    row.accent:SetShown(state ~= nil)

    row.name:SetText(def.name)
    local nc = state and C.gold or (item.canAccept and C.gold or C.inkMuted)
    row.name:SetTextColor(nc[1], nc[2], nc[3])
    row.desc:SetText(def.desc)
    local dc = (state or item.canAccept) and C.ink or C.inkFaint
    row.desc:SetTextColor(dc[1], dc[2], dc[3])

    local meta = { CategoryLabel(def.category) }
    local done = Ch:GetCompleted(def.id)
    if done then
        meta[#meta + 1] = string.format("Completed %d time%s, last %s", done.count,
            done.count == 1 and "" or "s", Util.FormatLongDate(done.last))
    end
    local failed = Ch:GetFailed(def.id)
    if failed > 0 then meta[#meta + 1] = string.format("Failed %d", failed) end
    if def.failOn == "death" then meta[#meta + 1] = Theme.Hex(C.blood) .. "Fails if you die|r" end
    if state then meta[#meta + 1] = "Taken " .. Util.FormatDay(state.accepted) end
    if state and state.zone and def.id == "localhero" then meta[#meta + 1] = "Region: " .. state.zone end
    row.meta:SetText(table.concat(meta, "  \194\183  "))

    row.reason = nil
    if state then
        row.bar:Show()
        row.bar:SetProgress(state.progress or 0, def.target,
            string.format("%d / %d", state.progress or 0, def.target))
        row.button:SetText("Abandon")
        row.button:Enable()
        row.note:SetText("")
    else
        row.bar:Hide()
        row.button:SetText("Accept")
        if item.canAccept then
            row.button:Enable()
            row.note:SetText("")
        else
            row.button:Disable()
            row.reason = item.reason
            row.note:SetText(item.reason or "")
        end
    end
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.filter = "all"

    page.summary = Theme.Heading(page, 16)
    page.summary:SetPoint("TOPLEFT", 2, -2)
    page.sub = Theme.Text(page, 12, C.inkMuted)
    page.sub:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -5)
    page.sub:SetPoint("RIGHT", page, "RIGHT", -14, 0)

    page.chips = {}
    local filters = { { key = "all", label = "All" }, { key = "active", label = "Under way" } }
    for _, c in ipairs(CoA.ChallengeData.CATEGORIES) do filters[#filters + 1] = c end
    local prev
    for _, f in ipairs(filters) do
        local chip = Widgets.Chip(page, f.label)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", 0, -46) end
        chip.key = f.key
        chip:SetScript("OnClick", function() page.filter = f.key; page:Render() end)
        page.chips[#page.chips + 1] = chip
        prev = chip
    end

    page.list = Widgets.VirtualList(page, ROW_H, CreateRow, UpdateRow)
    page.list:SetPoint("TOPLEFT", 0, -78)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.empty = Theme.Text(page, 13, C.inkFaint)
    page.empty:SetPoint("TOP", page.list, "TOP", 0, -40)
    page.empty:SetJustifyH("CENTER")
    page.empty:SetText("No challenges under way. Choose one from All to begin.")

    function page:Render()
        local Ch = CoA.Challenges
        for _, chip in ipairs(self.chips) do chip:SetSelected(chip.key == self.filter) end

        local active = Ch:CountActive()
        self.summary:SetText(string.format("Challenges under way: %d of %d", active, Ch.MAX_ACTIVE))
        self.sub:SetText(string.format(
            "Progress counts from the moment you accept. %d challenge%s completed so far.",
            Ch:CountCompleted(), Ch:CountCompleted() == 1 and "" or "s"))

        local items = {}
        for _, def in ipairs(Ch:GetDefs()) do
            local state = Ch:GetState(def.id)
            local show = self.filter == "all" or (self.filter == "active" and state) or def.category == self.filter
            if show then
                local ok, reason = true, nil
                if not state then ok, reason = Ch:CanAccept(def) end
                items[#items + 1] = { def = def, state = state, canAccept = ok, reason = reason }
            end
        end
        table.sort(items, function(a, b)
            if (a.state ~= nil) ~= (b.state ~= nil) then return a.state ~= nil end
            if a.state and b.state then
                local fa = (a.state.progress or 0) / a.def.target
                local fb = (b.state.progress or 0) / b.def.target
                if fa ~= fb then return fa > fb end
            end
            if a.canAccept ~= b.canAccept then return a.canAccept end
            return a.def.order < b.def.order
        end)
        self.empty:SetShown(#items == 0)
        self.list:SetItems(items)
    end
    return page
end

CoA.UI:RegisterPage("challenges", {
    label = "Challenges", icon = "Interface\\Icons\\Ability_Warrior_BattleShout", order = 4,
    create = Create,
    refresh = function(page) page:Render() end,
})
