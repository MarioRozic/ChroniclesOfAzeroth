--[[
  Chronicles of Azeroth - UI/Pages/Fellows.lua  (v0.5.0)

  The Fellows chapter: other players' chronicles, read through hidden addon
  messages (see Modules/Share.lua), compared with yours side by side like
  Blizzard's achievement comparison; plus the sharing settings.

    left page   Sharing settings, You, and every fellow you have inspected
    right page  the comparison (or the settings)
    footer      Inspect Target
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local STATUS = {
    waiting = "Asking...",
    noreply = "No answer",
    refused = "Private",
}

-- Your own numbers in the same shape as a received profile.
local function MyProfile()
    return CoA.Share.ParseProfile(CoA.Share:BuildProfile())
end

local function Inspect()
    local ok, why = CoA.Share:InspectTarget()
    if ok then
        CoA.UI:SelectFellow(CoA.Compat.UnitFullName("target"))
    elseif why then
        CoA:Print(why)
    end
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local L, R = CoA.UI:PageAreas(page)

    page.heading = Theme.BookTitle(L, 20)
    page.heading:SetPoint("TOPLEFT", 2, 0)
    page.heading:SetText("Fellows")
    page.summary = Theme.Ink(L, 12, C.bookMuted)
    page.summary:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -4)
    page.summary:SetPoint("RIGHT", L, "RIGHT", -4, 0)
    page.summary:SetText("Target a player who also keeps a chronicle, then press Inspect Target.")
    page.list = Widgets.SelectList(L, 24, function() page:Render() end)
    page.list:SetPoint("TOPLEFT", 0, -62)
    page.list:SetPoint("BOTTOMRIGHT", 0, 0)

    page.doc = Widgets.Document(R)
    page.doc.area:SetAllPoints()
    page.doc.area.OnWidthChanged = function() if page:IsShown() then page:Render() end end

    -- Settings (shown instead of the document when "Sharing" is selected).
    local set = CreateFrame("Frame", nil, R)
    set:SetAllPoints()
    set:Hide()
    page.settings = set
    local t = Theme.BookTitle(set, 20)
    t:SetPoint("TOPLEFT", 2, -2)
    t:SetText("Sharing")
    local rule = Theme.InkRule(set)
    rule:SetPoint("TOPLEFT", 2, -30); rule:SetPoint("RIGHT", set, "RIGHT", -6, 0)
    local h1 = Theme.BookHeading(set, 14)
    h1:SetPoint("TOPLEFT", 2, -44)
    h1:SetText("Announce new milestones")
    local function S() return CoA.db.settings.share end
    page.checkGuild = Widgets.Check(set, "In guild chat", function(v) S().announceGuild = v end)
    page.checkGuild:SetPoint("TOPLEFT", 2, -66)
    page.checkParty = Widgets.Check(set, "In party chat", function(v) S().announceParty = v end)
    page.checkParty:SetPoint("TOPLEFT", 2, -92)
    local note = Theme.Ink(set, 12, C.bookMuted)
    note:SetPoint("TOPLEFT", 4, -122); note:SetPoint("RIGHT", set, "RIGHT", -10, 0)
    note:SetText("Milestones earned close together share one line. At most one line a minute per channel and five an hour, never during combat or a boss fight. Say is only used when you press Brag.")
    local h2 = Theme.BookHeading(set, 14)
    h2:SetPoint("TOPLEFT", 2, -196)
    h2:SetText("Privacy")
    page.checkInspect = Widgets.Check(set, "Let other players inspect my chronicle", function(v) S().allowInspect = v end)
    page.checkInspect:SetPoint("TOPLEFT", 2, -218)
    local note2 = Theme.Ink(set, 12, C.bookMuted)
    note2:SetPoint("TOPLEFT", 4, -248); note2:SetPoint("RIGHT", set, "RIGHT", -10, 0)
    note2:SetText("They see your name, title, level, totals and earned milestones. Never your journal or where you are.")

    function page:Render()
        local Share = CoA.Share
        local items = {
            { header = "Settings" },
            { key = "settings", text = "Sharing", icon = "Interface\\Icons\\INV_Letter_15" },
            { header = "Chronicles" },
            { key = "self", text = CoA.char.meta.name .. "  " .. Theme.Hex(C.bookMuted) .. "(you)|r",
              icon = "Interface\\Icons\\INV_Misc_Book_09" },
        }
        local names = {}
        for name in pairs(Share.fellows) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local f = Share.fellows[name]
            items[#items + 1] = {
                key = name, text = CoA.Compat.ShortName(name), fellow = f,
                icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
                right = f.status ~= "ok" and STATUS[f.status] or nil,
                dim = f.status ~= "ok",
            }
        end
        if not self.list.selectedKey then self.list.selectedKey = names[1] or "self" end
        local sel = self.list:SetSelectableItems(items)

        local isSettings = sel and sel.key == "settings"
        self.settings:SetShown(isSettings)
        self.doc.area:SetShown(not isSettings)
        if isSettings then
            local s = CoA.db.settings.share
            self.checkGuild:SetChecked(s.announceGuild)
            self.checkParty:SetChecked(s.announceParty)
            self.checkInspect:SetChecked(s.allowInspect)
        else
            self:RenderComparison(sel)
        end

        local canInspect, why = Share:CanInspectNow()
        CoA.UI:SetFooter({
            { text = "Inspect Target", onClick = Inspect, disabled = not canInspect,
              tooltip = why or "Ask your target for their chronicle. They need Chronicles of Azeroth too." },
        })
    end

    function page:RenderComparison(sel)
        local d = self.doc
        d:Begin()
        local mine = MyProfile()
        local f = sel and sel.fellow
        local theirs = f and f.status == "ok" and f.profile
        if f and not theirs then
            d:Title(CoA.Compat.ShortName(sel.key))
            d:Rule()
            if f.status == "waiting" then
                d:Para("Asking for their chronicle...")
            elseif f.status == "refused" then
                d:Para("This player keeps their chronicle private.")
            else
                d:Para("No answer. They may not use Chronicles of Azeroth, may be on another faction or offline, or may be in combat. Try again in a moment.", C.bookMuted)
            end
            d:End(true)
            return
        end
        local p = theirs or mine
        d:Title(theirs and CoA.Compat.ShortName(sel.key) or CoA.char.meta.name)
        d:Sub(string.format("%s  \194\183  level %d %s %s", p.t or "", p.l, p.r or "", p.cn or ""))
        if theirs then
            d:Para(string.format("Received %s. Chronicles of Azeroth %s.", Util.FormatClock(f.received), p.ver or "?"), C.bookFaint)
        end
        d:Rule()
        local otherName = theirs and CoA.Compat.ShortName(sel.key) or nil
        local function row(label, key)
            if theirs then
                return { label, Util.FormatNumber(mine[key]), Util.FormatNumber(theirs[key]), mine[key], theirs[key] }
            end
            return { label, Util.FormatNumber(mine[key]), "" }
        end
        d:Compare({ "", "You", otherName or "" }, {
            row("Days on the road", "d"),
            row("Milestones earned", "ms"),
            row("Quests completed", "q"),
            row("Enemies defeated", "k"),
            row("Elites defeated", "e"),
            row("Rares slain", "rk"),
            row("Bosses defeated", "b"),
            row("Dungeons completed", "dn"),
            row("Regions explored", "z"),
            row("Hidden places", "a"),
            row("Challenges completed", "cc"),
            row("Deaths", "de"),
        })

        d:Heading("Milestones")
        local rows = {}
        for _, def in ipairs(CoA.AchievementData.LIST) do
            local a, b = mine.unlocked[def.id], theirs and theirs.unlocked[def.id]
            if a or b then
                rows[#rows + 1] = { def.name, a and "Earned" or "-", theirs and (b and "Earned" or "-") or "", a and 1 or 0, theirs and (b and 1 or 0) or nil }
            end
        end
        if #rows == 0 then
            d:Para("No milestones earned yet.", C.bookMuted)
        else
            d:Compare({ "", "You", otherName or "" }, rows)
        end
        d:End(self.lastKey ~= (sel and sel.key))
        self.lastKey = sel and sel.key
    end
    return page
end

function CoA.UI:SelectFellow(fullName)
    local f = self.frame
    local page = f and f.pageFrames.fellows
    if page and fullName then
        page.list.selectedKey = fullName
        page:Render()
    end
end

CoA.UI:RegisterPage("fellows", {
    label = "Fellows", order = 7,
    create = function(parent)
        local page = Create(parent)
        CoA:On("FELLOWS_CHANGED", page, function() if page:IsShown() then page:Render() end end)
        return page
    end,
    refresh = function(page) page:Render() end,
})
