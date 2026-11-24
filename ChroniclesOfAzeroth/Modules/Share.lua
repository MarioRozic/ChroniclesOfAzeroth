--[[
  Chronicles of Azeroth - Modules/Share.lua  (v0.5.0)

  Bragging rights, three ways:

  1. Announcements - when a milestone is earned, a line goes to guild and/or
     party chat, only if the player turned that channel on. No spam:
       * nothing for milestones unlocked quietly (the login catch-up)
       * unlocks close together are gathered into one line
       * at most one line per channel per minute, and 5 per channel per hour
       * never sent in combat or during a boss encounter; held until after
     Say is never used automatically: the client only allows it from a click.

  2. Brag - a button on the Character and Milestones pages posts a summary
     line to the channel the player picks (Say, Party, Guild).

  3. Inspect - two players who both use the addon can read each other's
     chronicle through hidden addon messages (prefix "CoAChron"), shown on the
     Fellows page like Blizzard's achievement comparison.
       request : "Q"
       answer  : "P<i>/<n>:<chunk>"  (the profile, cut into <= 240-byte chunks)
       refusal : "N"                 (the other player turned inspecting off)
     Messages are whispered, paced (one every 0.3 s, back off on throttle),
     never sent in combat or encounters, and each player answers the same
     requester at most once every 20 seconds.
]]

local _, CoA = ...
local Compat, Util = CoA.Compat, CoA.Util
local Share = CoA:NewModule("Share")
CoA.Share = Share

local PREFIX = "CoAChron"
local PROTOCOL = 1
local CHUNK = 240
local TAG = "[Chronicles of Azeroth]"

Share.fellows = {}        -- full name -> { profile = {...}, received = time(), status = "..." }

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
function Share:OnEnable()
    self.prefixOK = Compat.RegisterAddonPrefix(PREFIX)
    CoA:RegisterEvent("CHAT_MSG_ADDON", self, "OnAddonMessage")
    CoA:RegisterEvent("PLAYER_REGEN_ENABLED", self, "Flush")
    CoA:RegisterEvent("ENCOUNTER_END", self, "Flush")
    CoA:RegisterEvent("ADDON_ACTION_BLOCKED", self, "OnActionBlocked")
    CoA:RegisterEvent("ADDON_ACTION_FORBIDDEN", self, "OnActionBlocked")
    CoA:On("ACHIEVEMENT_UNLOCKED", self, function(_, def, quiet)
        if not quiet then self:QueueAnnouncement(def) end
    end)
    self:AddUnitMenuEntry()
end

local function Settings() return CoA.db.settings.share end

local function Busy()
    return Compat.InCombat() or Compat.EncounterInProgress()
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
local function Clip(s, max)
    max = max or 250
    if #s <= max then return s end
    return s:sub(1, max - 3) .. "..."
end

function Share:MilestoneLine(def)
    local name = CoA.char.meta.name
    local s = string.format('%s %s earned the milestone "%s" (%s)', TAG, name, def.name, def.desc)
    if def.title then s = s .. " and the title \"" .. def.title .. "\"" end
    return Clip(s .. ".")
end

function Share:ProfileLine()
    local char = CoA.char
    local m, s = char.meta, char.stats
    local earned, total = CoA.Achievements:CountUnlocked()
    local zones = 0
    for _, z in pairs(char.exploration.zones) do if not z.isInstance then zones = zones + 1 end end
    local days = CoA.Character:GetAdventureDays()
    local function P(n, w) return Util.FormatNumber(n) .. " " .. w .. (n == 1 and "" or "s") end
    return Clip(string.format("%s %s, %s: level %d, %d/%d milestones, %s, %s defeated, %s, %s on the road.",
        TAG, m.name, CoA.Character:GetTitle(), char.progress.level or 1, earned, total,
        P(s.questsCompleted, "quest"), P(s.kills, "enemy"):gsub("enemys", "enemies"), P(zones, "region"), P(days, "day")))
end

---------------------------------------------------------------------------
-- 1. Announcements
---------------------------------------------------------------------------
local pending = {}        -- defs waiting to be announced
local lastSent = {}       -- channel -> time of last announcement
local sentLog = {}        -- channel -> times of recent announcements
local GATHER, PER_CHANNEL, PER_HOUR = 4, 60, 5

function Share:AnnounceChannels()
    local set, list = Settings(), {}
    if set.announceGuild and Compat.CanUseChannel("GUILD") then list[#list + 1] = "GUILD" end
    if set.announceParty then
        local group = Compat.GroupChannel()
        if group then list[#list + 1] = group end
    end
    return list
end

function Share:QueueAnnouncement(def)
    local set = Settings()
    if not (set.announceGuild or set.announceParty) then return end
    pending[#pending + 1] = def
    if self.gathering then return end
    self.gathering = true
    -- Wait a moment so several unlocks from one deed become one line.
    C_Timer.After(GATHER, function()
        self.gathering = false
        self:Flush()
    end)
end

local function RecentCount(channel, now)
    local log = sentLog[channel] or {}
    sentLog[channel] = log
    for i = #log, 1, -1 do
        if now - log[i] >= 3600 then table.remove(log, i) end
    end
    return #log
end

function Share:Flush()
    if self.gathering or #pending == 0 then
        self:PumpQueue()
        return
    end
    if Busy() then return end   -- PLAYER_REGEN_ENABLED / ENCOUNTER_END call again
    if self.chatBlocked then pending = {}; self:PumpQueue(); return end
    local now = time()
    local text
    if #pending == 1 then
        text = self:MilestoneLine(pending[1])
    else
        local names = {}
        for i, def in ipairs(pending) do
            if i <= 4 then names[#names + 1] = '"' .. def.name .. '"' end
        end
        local more = #pending > 4 and (" and " .. (#pending - 4) .. " more") or ""
        text = Clip(string.format("%s %s earned %d milestones: %s%s.", TAG, CoA.char.meta.name, #pending,
            table.concat(names, ", "), more))
    end
    pending = {}
    for _, channel in ipairs(self:AnnounceChannels()) do
        if (now - (lastSent[channel] or 0)) >= PER_CHANNEL and RecentCount(channel, now) < PER_HOUR then
            if Compat.SendChat(text, channel) then
                lastSent[channel] = now
                table.insert(sentLog[channel], now)
            end
        end
    end
    self:PumpQueue()
end

---------------------------------------------------------------------------
-- 2. Brag
---------------------------------------------------------------------------
Share.BRAG_CHANNELS = {
    { key = "SAY", label = "Say" },
    { key = "PARTY", label = "Party" },
    { key = "GUILD", label = "Guild" },
}

-- Say is never sent by the addon: the line is put in the chat box and the
-- player presses Enter (v0.5.1; sending Say from the addon raised "Interface
-- action failed because of an AddOn"). Party and Guild are sent directly,
-- unless the client has blocked one of our chat sends this session.
function Share:Brag(text, channel)
    if channel == "PARTY" then channel = Compat.GroupChannel() or "PARTY" end
    if not Compat.CanUseChannel(channel) then
        CoA:Print(channel == "GUILD" and "you are not in a guild." or "you are not in a group.")
        return false
    end
    Settings().bragChannel = channel == "INSTANCE_CHAT" and "PARTY" or channel
    if channel == "SAY" or self.chatBlocked then
        if Compat.OpenChatWith(text, channel) then return true end
        CoA:Print("could not open the chat box.")
        return false
    end
    return Compat.SendChat(text, channel)
end

-- The client refused a protected call from this addon. If it was a chat send,
-- stop sending chat ourselves for the rest of the session: Brag falls back
-- to the chat box and announcements pause.
function Share:OnActionBlocked(_, addon, func)
    if addon ~= CoA.name then return end
    func = tostring(func or "")
    if func:find("Chat") or func == "" then
        if not self.chatBlocked then
            CoA:Print("the game blocked a chat message from this addon (" .. (func ~= "" and func or "unknown") ..
                "). Brag will put the line in your chat box instead, and announcements are paused until you reload.")
        end
        self.chatBlocked = true
    end
end

---------------------------------------------------------------------------
-- 3. Inspect: serialisation
---------------------------------------------------------------------------
local function Esc(v) return (tostring(v or ""):gsub("[;=|]", "")) end

function Share:BuildProfile()
    local char = CoA.char
    local m, s = char.meta, char.stats
    local earned, total = CoA.Achievements:CountUnlocked()
    local zones = 0
    for _, z in pairs(char.exploration.zones) do if not z.isInstance then zones = zones + 1 end end
    local ids = {}
    for id in pairs(char.achievements.unlocked) do ids[#ids + 1] = id end
    table.sort(ids)
    local fields = {
        { "v", PROTOCOL }, { "ver", CoA.version },
        { "n", m.name }, { "t", CoA.Character:GetTitle() }, { "l", char.progress.level or 1 },
        { "c", m.classFile }, { "cn", m.className }, { "r", m.raceName },
        { "d", CoA.Character:GetAdventureDays() },
        { "q", s.questsCompleted }, { "k", s.kills }, { "e", s.eliteKills },
        { "rk", s.rareKills }, { "rs", s.raresSeen }, { "b", s.bossesDefeated },
        { "dn", s.dungeonsCompleted }, { "z", zones }, { "a", s.areasDiscovered },
        { "de", s.deaths }, { "ms", earned }, { "mt", total },
        { "ca", CoA.Challenges:CountActive() }, { "cc", CoA.Challenges:CountCompleted() },
        { "u", table.concat(ids, ",") },
    }
    local out = {}
    for _, f in ipairs(fields) do out[#out + 1] = f[1] .. "=" .. Esc(f[2]) end
    return table.concat(out, ";")
end

function Share.ParseProfile(text)
    local p = {}
    for key, value in string.gmatch(text or "", "([^;=]+)=([^;]*)") do p[key] = value end
    for _, k in ipairs({ "v", "l", "d", "q", "k", "e", "rk", "rs", "b", "dn", "z", "a", "de", "ms", "mt", "ca", "cc" }) do
        p[k] = tonumber(p[k]) or 0
    end
    p.unlocked = {}
    for id in string.gmatch(p.u or "", "[^,]+") do p.unlocked[id] = true end
    return p
end

---------------------------------------------------------------------------
-- 3. Inspect: paced sending
---------------------------------------------------------------------------
local queue = {}          -- { msg, target }
local pumping = false
local PACE, BACKOFF = 0.3, 1.5

function Share:Send(msg, target)
    queue[#queue + 1] = { msg = msg, target = target }
    self:PumpQueue()
end

function Share:PumpQueue()
    if pumping or #queue == 0 then return end
    if Busy() then return end   -- resumed by PLAYER_REGEN_ENABLED / ENCOUNTER_END
    local item = queue[1]
    local result = Compat.SendAddon(PREFIX, item.msg, "WHISPER", item.target)
    local delay = PACE
    if result == nil then
        queue = {}   -- no addon messages on this client
        return
    elseif result == 3 or result == 8 or result == 11 then
        delay = BACKOFF   -- throttled or locked down: try the same message again
    else
        table.remove(queue, 1)   -- sent, or failed for good (offline, invalid)
    end
    pumping = true
    C_Timer.After(delay, function()
        pumping = false
        self:PumpQueue()
    end)
end

---------------------------------------------------------------------------
-- 3. Inspect: requests and answers
---------------------------------------------------------------------------
local answered = {}       -- requester -> time of last answer
local incoming = {}       -- sender -> { parts = {}, n = total }

function Share:CanInspectNow()
    if not self.prefixOK then return false, "This client does not allow addon messages." end
    if Busy() then return false, "Not during combat." end
    return true
end

function Share:RequestProfile(fullName)
    if not fullName or fullName == "" then return false, "Target a player first." end
    local ok, why = self:CanInspectNow()
    if not ok then return false, why end
    local f = self.fellows[fullName] or {}
    if f.asked and time() - f.asked < 10 then return false, "Already asked a moment ago." end
    f.asked = time()
    f.status = "waiting"
    self.fellows[fullName] = f
    self:Send("Q", fullName)
    C_Timer.After(8, function()
        if f.status == "waiting" then
            f.status = "noreply"
            CoA:Fire("FELLOWS_CHANGED", fullName)
        end
    end)
    CoA:Fire("FELLOWS_CHANGED", fullName)
    return true
end

function Share:InspectTarget()
    local unit = "target"
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return false, "Target a player first." end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return false, "That is you." end
    return self:RequestProfile(Compat.UnitFullName(unit))
end

function Share:OnAddonMessage(_, prefix, text, channel, sender)
    prefix, text, sender = Compat.Safe(prefix), Compat.Safe(text), Compat.Safe(sender)
    if prefix ~= PREFIX or type(text) ~= "string" or not sender then return end
    if channel ~= "WHISPER" then return end
    if sender == Compat.UnitFullName("player") or sender == CoA.char.meta.name then return end

    if text == "Q" then
        if not Settings().allowInspect then
            self:Send("N", sender)
            return
        end
        local now = time()
        if answered[sender] and now - answered[sender] < 20 then return end
        answered[sender] = now
        local payload = self:BuildProfile()
        local n = math.ceil(#payload / CHUNK)
        for i = 1, n do
            self:Send("P" .. i .. "/" .. n .. ":" .. payload:sub((i - 1) * CHUNK + 1, i * CHUNK), sender)
        end
        return
    end

    local f = self.fellows[sender]
    if not f then return end   -- answers we never asked for are ignored
    if text == "N" then
        f.status = "refused"
        CoA:Fire("FELLOWS_CHANGED", sender)
        return
    end
    local i, n, chunk = text:match("^P(%d+)/(%d+):(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not (i and n and n <= 20 and i >= 1 and i <= n) then return end
    local buf = incoming[sender]
    if not buf or buf.n ~= n then
        buf = { parts = {}, n = n }
        incoming[sender] = buf
    end
    buf.parts[i] = chunk
    for k = 1, n do
        if not buf.parts[k] then return end
    end
    incoming[sender] = nil
    f.profile = Share.ParseProfile(table.concat(buf.parts))
    f.received = time()
    f.status = "ok"
    CoA:Fire("FELLOWS_CHANGED", sender)
end

---------------------------------------------------------------------------
-- "View Chronicle" in the player right-click menu (11.0+ Menu API only).
---------------------------------------------------------------------------
function Share:AddUnitMenuEntry()
    if not (Menu and Menu.ModifyMenu) then return end
    local function add(owner, root, contextData)
        if not (root and root.CreateButton) then return end
        root:CreateDivider()
        root:CreateButton("View Chronicle", function()
            local unit = contextData and contextData.unit
            local name = contextData and contextData.name
            local full = (unit and Compat.UnitFullName(unit)) or
                (name and (contextData.server and contextData.server ~= "" and (name .. "-" .. contextData.server) or name))
            local ok, why = Share:RequestProfile(full)
            if not ok and why then CoA:Print(why) end
            CoA.UI:Show("fellows")
            if CoA.UI.SelectFellow then CoA.UI:SelectFellow(full) end
        end)
    end
    for _, tag in ipairs({ "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND" }) do
        pcall(Menu.ModifyMenu, tag, add)
    end
end
