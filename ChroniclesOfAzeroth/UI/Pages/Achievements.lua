--[[
  Chronicles of Azeroth - UI/Pages/Achievements.lua

  The Milestones chapter as a book: the left page lists every milestone by
  category (earned ones marked), the right page shows the chosen one with
  its progress or the day it was earned. "Change title" sits in the footer.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local function CategoryLabel(key)
    for _, c in ipairs(CoA.AchievementData.CATEGORIES) do
        if c.key == key then return c.label end
    end
    return key
end

local function CycleTitle()
    -- Level title -> each earned title -> level title.
    local A = CoA.Achievements
    local titles = A:GetEarnedTitles()
    local current = CoA.char.profile.customTitle
    local nextTitle = titles[1]
    for i, t in ipairs(titles) do
        if t == current then nextTitle = titles[i + 1] end
    end
    A:WearTitle(nextTitle)
    CoA.UI:RefreshHeader()
    CoA.UI:RefreshCurrent()
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Milestones")
    page.summary = Theme.Ink(L, 12, C.bookMuted)
    page.summary:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)
    page.total = Widgets.ProgressBar(L, 200, 14)
    page.total:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -6)

    page.list = Widgets.SelectList(L, 24, function() page:Render() end)
    page.list:SetPoint("TOPLEFT", 0, -72)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.doc = Widgets.Document(R)
    page.doc.area:SetAllPoints()
    page.doc.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end
    page.titleButton = { GetScript = function() return CycleTitle end }  -- used by tests

    function page:Render()
        local A = CoA.Achievements
        local earned, total = A:CountUnlocked()
        self.summary:SetText(string.format("%d of %d earned", earned, total))
        self.total:SetProgress(earned, total, earned .. " / " .. total)

        -- Left page: by category; earned first within a category.
        local items = {}
        for _, cat in ipairs(CoA.AchievementData.CATEGORIES) do
            local group = {}
            for _, def in ipairs(CoA.AchievementData.LIST) do
                if def.category == cat.key then
                    local unlocked = A:IsUnlocked(def.id)
                    local available = A:IsAvailable(def)
                    local current = (not unlocked and available) and A:GetProgress(def) or 0
                    group[#group + 1] = {
                        key = def.id, def = def, unlocked = unlocked, available = available, current = current,
                        icon = def.icon, text = def.name, dim = not unlocked,
                        right = unlocked and (Theme.Hex(C.bookGreen) .. "Earned|r")
                            or (available and (math.min(current, def.target) .. "/" .. def.target) or "-"),
                    }
                end
            end
            table.sort(group, function(a, b)
                if (a.unlocked ~= nil) ~= (b.unlocked ~= nil) then return a.unlocked ~= nil end
                if a.available ~= b.available then return a.available end
                local fa, fb = a.current / a.def.target, b.current / b.def.target
                if fa ~= fb then return fa > fb end
                return a.def.name < b.def.name
            end)
            if #group > 0 then
                items[#items + 1] = { header = cat.label }
                for _, it in ipairs(group) do items[#items + 1] = it end
            end
        end
        local sel = self.list:SetSelectableItems(items)

        -- Right page: the chosen milestone.
        local d = self.doc
        d:Begin()
        if sel then
            local def = sel.def
            d:Title(def.name)
            d:Sub(CategoryLabel(def.category))
            d:Rule()
            d:Para(def.desc)
            if sel.unlocked then
                d:Heading("Earned")
                d:Para(Util.FormatLongDate(sel.unlocked.t), C.bookGreen)
                local where = sel.unlocked.level and ("At level " .. sel.unlocked.level) or ""
                if sel.unlocked.zone then where = where .. (where ~= "" and ", in " or "In ") .. sel.unlocked.zone end
                if where ~= "" then d:Para(where .. ".") end
            elseif not sel.available then
                d:Heading("Unavailable")
                d:Para("This chronicle began part-way through your journey, so this milestone cannot be judged fairly.", C.bookMuted)
            else
                d:Heading("Progress")
                d:Bar(sel.current, def.target)
            end
            if def.title then
                d:Heading("Reward")
                d:Para("Title: " .. def.title)
            end
        end
        d:Heading("Your title")
        d:Para(CoA.Character:GetTitle())
        local titles = A:GetEarnedTitles()
        if #titles == 0 then
            d:Para("Earn a milestone with a title reward to wear it.", C.bookMuted)
        end
        d:End(self.lastKey ~= (sel and sel.key))
        self.lastKey = sel and sel.key

        CoA.UI:SetFooter({
            { text = "Change Title", onClick = CycleTitle, disabled = #titles == 0,
              tooltip = #titles == 0 and "Earn a milestone with a title reward first." or "Wear the next title you have earned." },
        })
    end
    return page
end

CoA.UI:RegisterPage("achievements", {
    label = "Milestones", order = 3,
    create = Create,
    refresh = function(page) page:Render() end,
})
