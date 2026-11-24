--[[
  Chronicles of Azeroth - Core/Init.lua

  Creates the addon namespace, a tiny module system and an internal message
  bus. Everything else in the addon hangs off the shared namespace table that
  WoW passes to every file listed in the .toc (the "..." vararg).

  Target client: WoW Forever 1.60.x (interface 16001, Mainline / Midnight code
  base, Lua 5.1). No external libraries are used.
]]

local ADDON_NAME, CoA = ...

CoA.name = ADDON_NAME
CoA.displayName = "Chronicles of Azeroth"
CoA.version = "0.3.0"

-- Exposed globally only so other addons (and /dump) can inspect it. Nothing in
-- this addon reads the global; all files use the private namespace.
_G.ChroniclesOfAzeroth = CoA

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
local PREFIX = "|cffd4af37Chronicles|r: "

function CoA:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

function CoA:Debug(...)
    if self.db and self.db.settings and self.db.settings.debug then
        self:Print("|cff888888[debug]|r", ...)
    end
end

---------------------------------------------------------------------------
-- Module system
--
-- A module is a plain table. Optional lifecycle methods:
--   module:OnInitialize()  - SavedVariables are ready (ADDON_LOADED)
--   module:OnEnable()      - the player is in the world (PLAYER_LOGIN)
-- Modules are initialised in the order they were created (i.e. .toc order).
---------------------------------------------------------------------------
CoA.modules = {}
CoA.moduleOrder = {}

function CoA:NewModule(name)
    assert(not self.modules[name], "Module already exists: " .. tostring(name))
    local module = { name = name, addon = self }
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = module
    return module
end

function CoA:GetModule(name)
    return self.modules[name]
end

function CoA:CallModules(method, ...)
    for _, module in ipairs(self.moduleOrder) do
        local fn = module[method]
        if type(fn) == "function" then
            local ok, err = pcall(fn, module, ...)
            if not ok then
                -- Never let one broken module take the whole addon down.
                self:Print("|cffff5555error in", module.name .. "." .. method .. ":|r", err)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Internal message bus (addon-internal "events", e.g. FEED_ENTRY_ADDED).
-- Lets the UI react to data changes without modules knowing about the UI.
---------------------------------------------------------------------------
local listeners = {}

function CoA:On(message, owner, fn)
    listeners[message] = listeners[message] or {}
    listeners[message][owner] = fn
end

function CoA:Off(message, owner)
    if listeners[message] then
        listeners[message][owner] = nil
    end
end

function CoA:Fire(message, ...)
    local set = listeners[message]
    if not set then return end
    for owner, fn in pairs(set) do
        local ok, err = pcall(fn, owner, ...)
        if not ok then
            self:Print("|cffff5555error in listener for", message .. ":|r", err)
        end
    end
end
