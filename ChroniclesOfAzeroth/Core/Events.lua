--[[
  Chronicles of Azeroth - Core/Events.lua

  One hidden frame receives every game event the addon cares about and fans
  it out to the modules that registered for it. Modules never create their
  own event frames, which keeps event registration in one auditable place.

  Usage from a module:
      CoA:RegisterEvent("PLAYER_LEVEL_UP", self, "OnLevelUp")
      CoA:RegisterEvent("PLAYER_DEAD", self, function(module, event, ...) end)
]]

local _, CoA = ...

local eventFrame = CreateFrame("Frame")
local handlers = {}   -- [event] = { [module] = handler }

local function Dispatch(_, event, ...)
    local set = handlers[event]
    if not set then return end
    for module, handler in pairs(set) do
        local fn = handler
        if type(handler) == "string" then fn = module[handler] end
        if fn then
            local ok, err = pcall(fn, module, event, ...)
            if not ok then
                CoA:Print("|cffff5555error handling", event .. ":|r", err)
            end
        end
    end
end
eventFrame:SetScript("OnEvent", Dispatch)

-- Returns true when the event was registered. Unknown events are reported
-- instead of raising an error, so a client that lacks an event (or renamed
-- it) degrades gracefully. CoA.unsupportedEvents is shown by "/coa status".
CoA.unsupportedEvents = {}

function CoA:RegisterEvent(event, module, handler)
    handlers[event] = handlers[event] or {}
    handlers[event][module] = handler or event
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
        handlers[event][module] = nil
        self.unsupportedEvents[event] = true
        self:Debug("event not available on this client:", event)
        return false
    end
    return true
end

function CoA:UnregisterEvent(event, module)
    local set = handlers[event]
    if not set then return end
    set[module] = nil
    if next(set) == nil then
        handlers[event] = nil
        pcall(eventFrame.UnregisterEvent, eventFrame, event)
    end
end

CoA.eventFrame = eventFrame
