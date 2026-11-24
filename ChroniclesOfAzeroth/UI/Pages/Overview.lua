--[[
  Chronicles of Azeroth - UI/Pages/Overview.lua

  The RPG character profile: portrait, identity, title, the length of the
  journey, statistics, current whereabouts and the latest chronicle entries.

  Statistics that are not tracked yet (enemies defeated, achievements,
  challenges) are shown as "not yet recorded" with the phase that adds them,
  never as made-up numbers.
]]

local _, CoA = ...
local Theme, Widgets, Util = CoA.Theme, CoA.Widgets, CoA.Util
local C = Theme.C

local TILE_H, TILE_GAP = 58, 10

local function CreateTile(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(TILE_H)
    Theme.Panel(t, "inset")
    t.iconFrame = Theme.Icon(t, 36)
    t.iconFrame:SetPoint("LEFT", 10, 0)
    t.value = Theme.Heading(t, 18)
    t.value:SetPoint("TOPLEFT", t.iconFrame, "TOPRIGHT", 10, 1)
    t.value:SetPoint("RIGHT", -8, 0)
    if t.value.SetWordWrap then t.value:SetWordWrap(false) end
    t.label = Theme.Text(t, 11, C.inkMuted)
    t.label:SetPoint("TOPLEFT", t.value, "BOTTOMLEFT", 0, -3)
    t.label:SetPoint("RIGHT", -8, 0)
    if t.label.SetWordWrap then t.label:SetWordWrap(false) end

    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        Theme.SetBorderColor(self.borderEdges, C.goldDim)
        if self.tooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.label:GetText() or "", C.gold[1], C.gold[2], C.gold[3])
            GameTooltip:AddLine(self.tooltip, 0.9, 0.85, 0.7, true)
            GameTooltip:Show()
        end
    end)
    t:SetScript("OnLeave", function(self)
        Theme.SetBorderColor(self.borderEdges, C.goldFaint)
        if GameTooltip then GameTooltip:Hide() end
    end)
    return t
end

local function SetTile(t, icon, value, label, tooltip, pending)
    t.iconFrame.icon:SetTexture(icon)
    t.iconFrame.icon:SetDesaturated(pending and true or false)
    -- Long "not yet recorded" notes use a smaller size so they fit the tile.
    t.value:SetFont(Theme.FONT_HEADING, pending and 14 or 18, "")
    t.value:SetText(value)
    local vc = pending and C.inkFaint or C.gold
    t.value:SetTextColor(vc[1], vc[2], vc[3])
    t.label:SetText(label)
    t.tooltip = tooltip
end

local function SectionTitle(parent, text)
    local fs = Theme.Heading(parent, 17)
    fs:SetText(text)
    local line = Theme.HGradientTexture(parent, "ARTWORK", C.goldFaint, { 0, 0, 0, 0 })
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -4)
    line:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    return fs
end

local function Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    local area = Widgets.ScrollArea(page)
    area:SetAllPoints()
    page.area = area
    local content = area.content

    -- Hero card -------------------------------------------------------------
    local hero = CreateFrame("Frame", nil, content)
    hero:SetPoint("TOPLEFT", 0, 0)
    hero:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    hero:SetHeight(128)
    Theme.Panel(hero, "card")
    page.hero = hero

    local portraitHolder = CreateFrame("Frame", nil, hero)
    portraitHolder:SetSize(96, 96)
    portraitHolder:SetPoint("LEFT", 16, 0)
    local pbg = Theme.SolidTexture(portraitHolder, "BACKGROUND", { 0, 0, 0, 1 })
    pbg:SetAllPoints()
    local portrait = portraitHolder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 3, -3)
    portrait:SetPoint("BOTTOMRIGHT", -3, 3)
    page.portrait = portrait
    Theme.Border(portraitHolder, C.gold, 0, "OVERLAY")
    Theme.Border(portraitHolder, C.goldFaint, 3, "OVERLAY")
    local levelBadge = CreateFrame("Frame", nil, portraitHolder)
    levelBadge:SetSize(30, 20)
    levelBadge:SetPoint("BOTTOM", portraitHolder, "BOTTOM", 0, -8)
    levelBadge:SetFrameLevel(portraitHolder:GetFrameLevel() + 2)
    local lbBg = Theme.SolidTexture(levelBadge, "BACKGROUND", C.leather)
    lbBg:SetAllPoints()
    Theme.Border(levelBadge, C.gold)
    page.levelBadge = Theme.Heading(levelBadge, 13)
    page.levelBadge:SetPoint("CENTER", 0, 0)
    page.levelBadge:SetJustifyH("CENTER")
    page.levelBadge:SetJustifyV("MIDDLE")

    page.name = Theme.Heading(hero, 28)
    page.name:SetPoint("TOPLEFT", portraitHolder, "TOPRIGHT", 20, -2)
    page.title = Theme.Text(hero, 15, C.inkMuted, Theme.FONT_HEADING)
    page.title:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -2)
    page.identity = Theme.Text(hero, 13, C.ink)
    page.identity:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -10)
    page.realm = Theme.Text(hero, 11, C.inkFaint)
    page.realm:SetPoint("TOPLEFT", page.identity, "BOTTOMLEFT", 0, -5)

    page.dayNumber = Theme.Heading(hero, 34)
    page.dayNumber:SetPoint("TOPRIGHT", -20, -24)
    page.dayNumber:SetJustifyH("RIGHT")
    page.dayLabel = Theme.Text(hero, 11, C.inkMuted)
    page.dayLabel:SetPoint("TOPRIGHT", page.dayNumber, "BOTTOMRIGHT", 0, -2)
    page.dayLabel:SetJustifyH("RIGHT")
    page.dayLabel:SetText("days on the road")
    page.since = Theme.Text(hero, 11, C.inkFaint)
    page.since:SetPoint("TOPRIGHT", page.dayLabel, "BOTTOMRIGHT", 0, -3)
    page.since:SetJustifyH("RIGHT")

    -- Statistics -------------------------------------------------------------
    local statsTitle = SectionTitle(content, "Deeds & Tallies")
    statsTitle:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 2, -20)
    page.statsTitle = statsTitle
    page.tiles = {}
    for i = 1, 12 do page.tiles[i] = CreateTile(content) end

    -- Whereabouts & recent entries -------------------------------------------
    page.whereTitle = SectionTitle(content, "Whereabouts")
    page.where = Theme.Text(content, 13, C.ink)
    page.where:SetPoint("TOPLEFT", page.whereTitle, "BOTTOMLEFT", 0, -12)

    page.recentTitle = SectionTitle(content, "Latest in the Chronicle")
    page.recentRows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(26)
        row.icon = Theme.Icon(row, 20)
        row.icon:SetPoint("LEFT", 0, 0)
        row.text = Theme.Text(row, 12, C.ink)
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -70, 0)
        row.text:SetJustifyV("MIDDLE")
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row.time = Theme.Text(row, 11, C.inkFaint)
        row.time:SetPoint("RIGHT", 0, 0)
        row.time:SetJustifyH("RIGHT")
        row.time:SetJustifyV("MIDDLE")
        page.recentRows[i] = row
    end
    page.recentEmpty = Theme.Text(content, 12, C.inkFaint)
    page.recentEmpty:SetWidth(560)
    page.recentEmpty:SetText("Nothing has been written yet. Go forth, and the chronicle will follow.")

    area.OnWidthChanged = function() page:Layout() end

    function page:Layout()
        local width = content:GetWidth()
        if not width or width < 50 then return end
        local cols = width > 760 and 4 or (width > 520 and 3 or 2)
        local tileW = (width - (cols - 1) * TILE_GAP) / cols
        local y = 128 + 20 + 30   -- below hero and section title
        for i, tile in ipairs(self.tiles) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            tile:ClearAllPoints()
            tile:SetWidth(tileW)
            tile:SetPoint("TOPLEFT", content, "TOPLEFT", col * (tileW + TILE_GAP), -(y + row * (TILE_H + TILE_GAP)))
        end
        local rows = math.ceil(#self.tiles / cols)
        y = y + rows * (TILE_H + TILE_GAP) + 14

        self.whereTitle:ClearAllPoints()
        self.whereTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
        self.where:SetWidth(math.max(100, width - 8))
        y = y + 30 + math.max(18, self.where:GetStringHeight() or 18) + 22

        self.recentTitle:ClearAllPoints()
        self.recentTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -y)
        y = y + 32
        self.recentEmpty:ClearAllPoints()
        self.recentEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
        for i, row in ipairs(self.recentRows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -(y + (i - 1) * 28))
            row:SetPoint("RIGHT", content, "RIGHT", -4, 0)
        end
        y = y + #self.recentRows * 28 + 10
        area:SetContentHeight(y)
    end

    return page
end

local function Refresh(page)
    local char = CoA.char
    if not char then return end
    local m, p, s = char.meta, char.progress, char.stats
    local Character = CoA.Character

    -- Ask for /played the first time the profile is viewed this session.
    Character:RequestTimePlayed()

    if SetPortraitTexture then SetPortraitTexture(page.portrait, "player") end
    page.levelBadge:SetText(p.level)

    local r, g, b = CoA.Compat.GetClassColor(m.classFile)
    page.name:SetText(m.name)
    page.name:SetTextColor(r, g, b)
    page.title:SetText(Character:GetTitle())
    page.identity:SetText(string.format("Level %d %s %s  %s %s", p.level, m.raceName, m.className,
        Theme.Hex(C.inkFaint) .. "\194\183|r", m.factionLocalized))
    page.realm:SetText("of " .. m.realm)

    page.dayNumber:SetText(Character:GetAdventureDays())
    page.since:SetText("Chronicle begun " .. Util.FormatLongDate(m.chronicleStarted))

    -- Tiles -----------------------------------------------------------------
    local played, live = Character:GetTimePlayed()
    local playedText = played and Util.FormatDuration(played) or "Unknown"
    local playedTip = played
        and ((live and "Total /played time for this character." or "Last known /played value, recorded ") ..
             (live and "" or Util.FormatLongDate(p.timePlayedStamp) .. "."))
        or "Open this page again in a moment, or type /played, so the server can report it."

    local zones = 0
    for _, z in pairs(char.exploration.zones) do
        if not z.isInstance then zones = zones + 1 end
    end
    local feedCount = #char.feed.entries

    local T = page.tiles
    SetTile(T[1], "Interface\\Icons\\INV_Misc_PocketWatch_01", playedText, "Time played", playedTip, not played)
    SetTile(T[2], "Interface\\Icons\\INV_Misc_Map_01", Util.FormatNumber(zones), "Regions explored",
        "Distinct zones visited while the chronicle was open.")
    SetTile(T[3], "Interface\\Icons\\INV_Misc_Note_02", Util.FormatNumber(s.questsCompleted), "Quests completed",
        "Quests turned in since the chronicle began.")
    SetTile(T[4], "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar", Util.FormatNumber(s.instancesEntered), "Dungeons entered",
        "Times you entered an instance. Completions are tracked from Phase 2.")
    SetTile(T[5], "Interface\\Icons\\Spell_Holy_SurgeOfLight", Util.FormatNumber(s.levelsGained), "Levels gained",
        string.format("Levels gained while the chronicle was open. You joined at level %d.", m.startLevel))
    SetTile(T[6], "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", Util.FormatNumber(s.deaths), "Deaths",
        "Times you fell in battle.")
    SetTile(T[7], "Interface\\Icons\\Spell_Fire_Fire", Util.FormatNumber(s.sessions), "Nights at camp",
        "Play sessions (logins) recorded.")
    SetTile(T[8], "Interface\\Icons\\INV_Misc_Book_09", Util.FormatNumber(feedCount), "Chronicle entries",
        "Events written into your chronicle.")
    SetTile(T[9], "Interface\\Icons\\Ability_DualWield", "Not yet recorded", "Enemies defeated",
        "Arrives in Phase 2. The Forever client closes the combat log to addons, so kills need a verified source first.", true)
    SetTile(T[10], "Interface\\Icons\\INV_Misc_Head_Dragon_01", "Not yet recorded", "Bosses & rares",
        "Arrives in Phase 2, once boss and rare detection is verified on the Forever client.", true)
    SetTile(T[11], "Interface\\Icons\\Spell_Holy_ChampionsBond", "Arrives in Phase 2", "Milestones unlocked",
        "Custom milestones (achievements) are added in Phase 2.", true)
    SetTile(T[12], "Interface\\Icons\\Ability_Warrior_BattleShout", "Arrives in Phase 3", "Active challenges",
        "Personal challenges are added in Phase 3.", true)

    -- Whereabouts -----------------------------------------------------------
    local loc = char.location
    local where
    if loc.zone ~= "" then
        where = Theme.Hex(C.gold) .. loc.zone .. "|r"
        if loc.subzone ~= "" and loc.subzone ~= loc.zone then
            where = where .. Theme.Hex(C.inkMuted) .. ", " .. loc.subzone .. "|r"
        end
        local rec = char.exploration.zones[loc.zone]
        if rec then
            where = where .. "\n" .. Theme.Hex(C.inkMuted) ..
                string.format("First recorded %s  \194\183  %d visit%s  \194\183  %d quest%s here",
                    Util.FormatLongDate(rec.firstVisit), rec.visits, rec.visits == 1 and "" or "s",
                    rec.quests or 0, (rec.quests or 0) == 1 and "" or "s") .. "|r"
        end
    else
        where = Theme.Hex(C.inkFaint) .. "Your whereabouts are unknown." .. "|r"
    end
    page.where:SetText(where)

    -- Recent entries ---------------------------------------------------------
    local entries = char.feed.entries
    local n = #entries
    page.recentEmpty:SetShown(n == 0)
    for i, row in ipairs(page.recentRows) do
        local e = entries[n - i + 1]
        if e then
            row.icon.icon:SetTexture(CoA.Feed:GetIcon(e))
            row.text:SetText(CoA.Feed:FormatText(e))
            row.time:SetText(Util.FormatDay(e.t))
            row:Show()
        else
            row:Hide()
        end
    end

    page:Layout()
end

CoA.UI:RegisterPage("overview", {
    label = "Character", icon = "Interface\\Icons\\INV_Misc_Head_Human_01", order = 1,
    create = Create, refresh = Refresh,
})
