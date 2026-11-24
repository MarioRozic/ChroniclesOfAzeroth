--[[
  Chronicles of Azeroth - UI/Pages/Challenges.lua

  The Challenges chapter as a book, like the Quest Log: the left page lists
  the challenges under way and every other challenge by category; the right
  page shows the chosen one, with Accept or Abandon in the footer.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local function CategoryLabel(key)
    for _, c in ipairs(CoA.ChallengeData.CATEGORIES) do
        if c.key == key then return c.label end
    end
    return key
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Challenges")
    page.summary = Theme.Ink(L, 12, C.bookMuted)
    page.summary:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)
    local rule = Theme.InkRule(L)
    rule:SetPoint("TOPLEFT", 2, -48); rule:SetPoint("RIGHT", L, "RIGHT", -4, 0)

    page.list = Widgets.SelectList(L, 24, function() page:Render() end)
    page.list:SetPoint("TOPLEFT", 0, -52)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.doc = Widgets.Document(R)
    page.doc.area:SetAllPoints()
    page.doc.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end

    function page:Toggle()
        local sel = self.selected
        if not sel then return end
        local Ch = CoA.Challenges
        if Ch:IsActive(sel.def.id) then
            Ch:Abandon(sel.def.id)
            CoA.Compat.PlaySound("IG_QUEST_LOG_ABANDON_QUEST", 846)
        else
            local ok, reason = Ch:Accept(sel.def.id)
            if ok then
                CoA.Compat.PlaySound("IG_QUEST_LIST_OPEN", 875)
            elseif reason then
                CoA:Print(reason)
            end
        end
    end

    function page:Render()
        local Ch = CoA.Challenges
        local active = Ch:CountActive()
        self.summary:SetText(string.format("%d of %d under way  \194\183  %d completed",
            active, Ch.MAX_ACTIVE, Ch:CountCompleted()))

        local items, under = {}, {}
        local byCat = {}
        for _, def in ipairs(Ch:GetDefs()) do
            local state = Ch:GetState(def.id)
            local ok, reason = true, nil
            if not state then ok, reason = Ch:CanAccept(def) end
            local it = { key = def.id, def = def, state = state, canAccept = ok, reason = reason,
                         icon = def.icon, text = def.name }
            if state then
                it.right = (state.progress or 0) .. "/" .. def.target
                under[#under + 1] = it
            else
                local done = Ch:GetCompleted(def.id)
                it.right = done and (Theme.Hex(C.bookGreen) .. "Done|r") or nil
                it.dim = not ok and Ch:CountActive() < Ch.MAX_ACTIVE
                byCat[def.category] = byCat[def.category] or {}
                table.insert(byCat[def.category], it)
            end
        end
        if #under > 0 then
            items[#items + 1] = { header = "Under way" }
            for _, it in ipairs(under) do items[#items + 1] = it end
        end
        for _, cat in ipairs(CoA.ChallengeData.CATEGORIES) do
            if byCat[cat.key] then
                items[#items + 1] = { header = cat.label }
                for _, it in ipairs(byCat[cat.key]) do items[#items + 1] = it end
            end
        end
        local sel = self.list:SetSelectableItems(items)
        self.selected = sel

        local d = self.doc
        d:Begin()
        local footer = {}
        if sel then
            local def, state = sel.def, sel.state
            d:Title(def.name)
            d:Sub(CategoryLabel(def.category) .. (state and "  \194\183  Under way" or ""))
            d:Rule()
            d:Para(def.desc)

            d:Heading("Progress")
            if state then
                d:Bar(state.progress or 0, def.target)
            else
                d:Para(string.format("Not taken. Goal: %d.", def.target), C.bookMuted)
            end
            if def.failOn == "death" then d:Para("Dying while this challenge is under way fails it.", C.bookRed) end

            d:Heading("Details")
            local lines = {}
            if state then
                lines[#lines + 1] = "Taken " .. Util.FormatLongDate(state.accepted) ..
                    (state.zone and (" in " .. state.zone) or "") .. "."
            end
            if def.id == "localhero" and state and state.zone then
                lines[#lines + 1] = "Only quests completed in " .. state.zone .. " count."
            end
            local done = Ch:GetCompleted(def.id)
            if done then
                lines[#lines + 1] = string.format("Completed %d time%s, last on %s.", done.count,
                    done.count == 1 and "" or "s", Util.FormatLongDate(done.last))
            end
            local failed = Ch:GetFailed(def.id)
            if failed > 0 then lines[#lines + 1] = string.format("Failed %d time%s.", failed, failed == 1 and "" or "s") end
            if def.category == "combat" or def.category == "social" then
                lines[#lines + 1] = "Kills inside dungeons do not count."
            end
            if not state and sel.reason then lines[#lines + 1] = sel.reason end
            lines[#lines + 1] = "Progress counts from the moment you accept, and the challenge can be taken again."
            for _, l in ipairs(lines) do d:Para(l) end

            if state then
                footer[1] = { text = "Abandon Challenge", onClick = function() page:Toggle() end }
            else
                footer[1] = { text = "Accept", onClick = function() page:Toggle() end,
                              disabled = not sel.canAccept, tooltip = sel.reason }
            end
        end
        d:End(self.lastKey ~= (sel and sel.key))
        self.lastKey = sel and sel.key
        CoA.UI:SetFooter(footer)
    end
    return page
end

CoA.UI:RegisterPage("challenges", {
    label = "Challenges", order = 4,
    create = Create,
    refresh = function(page) page:Render() end,
})
