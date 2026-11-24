--[[
  Chronicles of Azeroth - Modules/Challenges.lua  (Phase 3)

  Personal challenges the player accepts from the Challenges chapter.
  Progress counts only deeds that happen after a challenge is accepted.

  Deeds are announced by the tracking modules with CoA:Fire("DEED", kind, ctx):
    kill      Combat:Credit       ctx = creature info + newType
    rare_seen Combat:SeeRare      ctx = { name }
    boss      Combat:OnEncounterEnd ctx = { name }
    dungeon   Combat:CompleteRun  ctx = { name, deaths }
    quest     Tracker             ctx = { zone }
    death     Tracker             ctx = {}
    level     Character           ctx = { level }
    zone_new  Tracker             ctx = { zone }
    area      Tracker             ctx = {}
    subzone   Tracker             ctx = { name }
    emote     this module         ctx = { token, targetGUID, targetIsPlayer }

  Saved per character:
    challenges.active[id]    = { accepted, progress, zone, seen = {} }
    challenges.completed[id] = { count, first, last }
    challenges.failed[id]    = count
]]

local _, CoA = ...
local Compat, Util = CoA.Compat, CoA.Util
local D = CoA.ChallengeData
local Challenges = CoA:NewModule("Challenges")
CoA.Challenges = Challenges

Challenges.MAX_ACTIVE = D.MAX_ACTIVE

local function Store()
    local c = CoA.char.challenges
    c.active = c.active or {}
    c.completed = c.completed or {}
    c.failed = c.failed or {}
    return c
end

function Challenges:OnEnable()
    CoA:On("DEED", self, function(_, kind, ctx) self:OnDeed(kind, ctx or {}) end)
    self:HookEmotes()
    -- Forget active challenges whose definition no longer exists.
    local store = Store()
    for id in pairs(store.active) do
        if not D.byId[id] then store.active[id] = nil end
    end
end

---------------------------------------------------------------------------
-- Emotes: hooksecurefunc is the taint-free way to observe DoEmote.
---------------------------------------------------------------------------
local lastEmote = 0
local function OnEmote(token)
    if type(token) ~= "string" then return end
    local now = GetTime and GetTime() or 0
    if now - lastEmote < 0.3 then return end -- one call can route through both hooks
    lastEmote = now
    local guid = Compat.UnitGUID and Compat.UnitGUID("target")
    local isPlayer = UnitIsPlayer and Compat.Safe(UnitIsPlayer("target")) and true or false
    if guid == Compat.PlayerGUID() then isPlayer = false end
    CoA:Fire("DEED", "emote", { token = string.upper(token), targetGUID = guid, targetIsPlayer = isPlayer })
end

function Challenges:HookEmotes()
    if self.hooked or not hooksecurefunc then return end
    self.hooked = true
    if type(DoEmote) == "function" then
        pcall(hooksecurefunc, "DoEmote", OnEmote)
    end
    if C_ChatInfo and type(C_ChatInfo.PerformEmote) == "function" then
        pcall(hooksecurefunc, C_ChatInfo, "PerformEmote", OnEmote)
    end
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------
function Challenges:GetDefs() return D.LIST end
function Challenges:GetDef(id) return D.byId[id] end
function Challenges:GetCategories() return D.CATEGORIES end

function Challenges:IsActive(id) return Store().active[id] ~= nil end

function Challenges:CountActive()
    return Util.CountKeys(Store().active)
end

function Challenges:CountCompleted()
    local n = 0
    for _, rec in pairs(Store().completed) do n = n + (rec.count or 0) end
    return n
end

function Challenges:GetState(id) return Store().active[id] end
function Challenges:GetCompleted(id) return Store().completed[id] end
function Challenges:GetFailed(id) return Store().failed[id] or 0 end

-- Returns ok, reason.
function Challenges:CanAccept(def)
    if not def then return false, "Unknown challenge." end
    if self:IsActive(def.id) then return false, "Already under way." end
    local level = CoA.char.progress.level or 1
    if def.minLevel and level < def.minLevel then
        return false, "Requires level " .. def.minLevel .. "."
    end
    if def.on == "level" and level >= (Compat.GetMaxPlayerLevel() or 60) then
        return false, "You have reached the highest level."
    end
    if self:CountActive() >= D.MAX_ACTIVE then
        return false, "You can pursue " .. D.MAX_ACTIVE .. " challenges at once."
    end
    return true
end

---------------------------------------------------------------------------
-- Accept / abandon / complete / fail
---------------------------------------------------------------------------
function Challenges:Accept(id)
    local def = D.byId[id]
    local ok, reason = self:CanAccept(def)
    if not ok then return false, reason end
    local zone = CoA.char.location.zone
    Store().active[id] = { accepted = time(), progress = 0, seen = {},
                           zone = zone ~= "" and zone or nil }
    CoA.Feed:Add("challenge_accepted", { id = id, name = def.name })
    CoA:Fire("CHALLENGES_CHANGED", "accept", id)
    return true
end

function Challenges:Abandon(id)
    local store = Store()
    if not store.active[id] then return false end
    store.active[id] = nil
    CoA:Fire("CHALLENGES_CHANGED", "abandon", id)
    return true
end

function Challenges:Complete(def)
    local store = Store()
    local state = store.active[def.id]
    store.active[def.id] = nil
    local rec = store.completed[def.id] or { count = 0, first = time() }
    rec.count = rec.count + 1
    rec.last = time()
    if state and state.accepted then
        local took = time() - state.accepted
        if not rec.fastest or took < rec.fastest then rec.fastest = took end
    end
    store.completed[def.id] = rec
    CoA.Feed:Add("challenge_completed", { id = def.id, name = def.name, count = rec.count })
    if CoA.Toast then
        CoA.Toast:Show({ kind = "challenge", name = def.name, desc = def.desc, icon = def.icon })
    end
    CoA:Fire("CHALLENGES_CHANGED", "complete", def.id)
    CoA:Fire("STATS_CHANGED", "challenge")
end

function Challenges:Fail(def)
    local store = Store()
    store.active[def.id] = nil
    store.failed[def.id] = (store.failed[def.id] or 0) + 1
    CoA.Feed:Add("challenge_failed", { id = def.id, name = def.name })
    CoA:Fire("CHALLENGES_CHANGED", "fail", def.id)
end

---------------------------------------------------------------------------
-- Deeds
---------------------------------------------------------------------------
function Challenges:OnDeed(kind, ctx)
    if not CoA.char then return end
    local store = Store()
    local changed = false
    -- Collect first: completing or failing edits the active table.
    local ids = {}
    for id in pairs(store.active) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def, state = D.byId[id], store.active[id]
        if def and state then
            if def.failOn and def.failOn == kind then
                self:Fail(def)
            elseif def.on == kind and (not def.test or def.test(ctx, state)) then
                local counts = true
                if def.key then
                    local k = def.key(ctx)
                    if k == nil or k == "" then
                        counts = false
                    else
                        k = tostring(k)
                        state.seen = state.seen or {}
                        if state.seen[k] then counts = false else state.seen[k] = true end
                    end
                end
                if counts then
                    state.progress = (state.progress or 0) + 1
                    changed = true
                    if state.progress >= def.target then self:Complete(def) end
                end
            end
        end
    end
    if changed then CoA:Fire("CHALLENGES_CHANGED", "progress") end
end

---------------------------------------------------------------------------
-- Feed kinds
---------------------------------------------------------------------------
local function IconOf(d)
    local def = d.id and D.byId[d.id]
    return def and def.icon or "Interface\\Icons\\Ability_Warrior_BattleShout"
end

CoA.Feed:RegisterKind("challenge_accepted", {
    category = "progress", icon = IconOf,
    text = function(d) return "You took up the challenge \"" .. (d.name or "?") .. "\"." end,
    journal = function(d) return "I swore to see \"" .. (d.name or "a challenge") .. "\" through." end,
})

CoA.Feed:RegisterKind("challenge_completed", {
    category = "progress", icon = IconOf,
    text = function(d)
        local t = "You completed the challenge \"" .. (d.name or "?") .. "\"."
        if (d.count or 1) > 1 then t = t .. " (" .. d.count .. " times now)" end
        return t
    end,
    journal = function(d) return "I kept my word and completed \"" .. (d.name or "a challenge") .. "\"." end,
})

CoA.Feed:RegisterKind("challenge_failed", {
    category = "progress", icon = IconOf,
    text = function(d) return "You failed the challenge \"" .. (d.name or "?") .. "\"." end,
    journal = function(d) return "I fell short of \"" .. (d.name or "a challenge") .. "\", this time." end,
})
