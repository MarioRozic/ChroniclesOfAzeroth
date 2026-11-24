--[[
  Chronicles of Azeroth - UI/Theme.lua

  Visual language (v0.3.0, "native" redesign): the addon now dresses like
  Blizzard's own windows - the standard portrait frame, bottom tabs, red
  panel buttons, Friz Quadrata in Blizzard gold and white, tooltip-style
  insets and a parchment page for the journal.

  Blizzard templates and art are used where the Mainline client has them
  (ButtonFrameTemplate, PanelTabButtonTemplate, UIPanelButtonTemplate,
  SearchBoxTemplate, BackdropTemplate). Every template is created through
  Theme.TryCreate(), which falls back to a plain frame drawn with colour
  textures if a template is missing, so a Forever patch can never leave the
  addon without a window.
]]

local _, CoA = ...
local Theme = {}
CoA.Theme = Theme

-- Blizzard's UI font. (Morpheus is kept for the journal's chapter titles.)
Theme.FONT_HEADING = "Fonts\\FRIZQT__.TTF"
Theme.FONT_BODY = "Fonts\\FRIZQT__.TTF"
Theme.FONT_BOOK = "Fonts\\MORPHEUS.TTF"

-- r, g, b[, a] - values match Blizzard's FontObject colours.
Theme.C = {
    leather      = { 0.05, 0.05, 0.05, 0.92 },   -- fallback window body
    leatherLight = { 0.12, 0.12, 0.12, 1 },
    parchment    = { 0.10, 0.10, 0.10, 0.55 },
    parchmentTop = { 0.16, 0.16, 0.16, 0.55 },
    inset        = { 0.0, 0.0, 0.0, 0.45 },
    gold         = { 1.0, 0.82, 0.0, 1 },          -- NORMAL_FONT_COLOR
    goldDim      = { 0.55, 0.55, 0.55, 1 },         -- borders
    goldFaint    = { 0.40, 0.40, 0.40, 0.6 },
    ink          = { 1.0, 1.0, 1.0, 1 },            -- HIGHLIGHT_FONT_COLOR
    inkMuted     = { 0.80, 0.80, 0.80, 1 },
    inkFaint     = { 0.50, 0.50, 0.50, 1 },         -- GRAY_FONT_COLOR
    highlight    = { 1.0, 1.0, 1.0, 0.08 },
    selected     = { 1.0, 0.82, 0.0, 0.15 },
    blood        = { 1.0, 0.13, 0.13, 1 },
    verdant      = { 0.1, 1.0, 0.1, 1 },
    -- Journal page
    paper        = { 0.94, 0.88, 0.74, 1 },
    paperInk     = { 0.24, 0.16, 0.07, 1 },
    paperHead    = { 0.38, 0.22, 0.05, 1 },
    paperFaint   = { 0.45, 0.36, 0.24, 1 },
}

-- Category accent colours for feed entries.
Theme.CATEGORY_COLORS = {
    travel   = { 0.40, 0.75, 1.00 },
    progress = { 1.00, 0.82, 0.00 },
    quest    = { 1.00, 0.60, 0.20 },
    combat   = { 0.95, 0.30, 0.25 },
    system   = { 0.65, 0.65, 0.65 },
}

function Theme.Hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

---------------------------------------------------------------------------
-- Templates with fallback
---------------------------------------------------------------------------
-- Creates a frame from a Blizzard template; returns frame, usedTemplate.
function Theme.TryCreate(frameType, name, parent, template)
    if template then
        local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
        if ok and frame then return frame, true end
        CoA:Debug("template unavailable:", template)
    end
    return CreateFrame(frameType, name, parent), false
end

---------------------------------------------------------------------------
-- Texture helpers
---------------------------------------------------------------------------
function Theme.SolidTexture(parent, layer, color, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end

-- Vertical gradient (top -> bottom); solid fill if SetGradient is missing.
function Theme.GradientTexture(parent, layer, top, bottom, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetColorTexture(1, 1, 1, 1)
    local ok = false
    if CreateColor and t.SetGradient then
        ok = pcall(t.SetGradient, t, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
    end
    if not ok then t:SetColorTexture(bottom[1], bottom[2], bottom[3], bottom[4] or 1) end
    return t
end

function Theme.HGradientTexture(parent, layer, left, right, sublevel)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    t:SetColorTexture(1, 1, 1, 1)
    local ok = false
    if CreateColor and t.SetGradient then
        ok = pcall(t.SetGradient, t, "HORIZONTAL",
            CreateColor(left[1], left[2], left[3], left[4] or 1),
            CreateColor(right[1], right[2], right[3], right[4] or 1))
    end
    if not ok then t:SetColorTexture(left[1], left[2], left[3], (left[4] or 1) * 0.6) end
    return t
end

-- Atlas with a fallback colour (atlas names can differ between clients).
function Theme.AtlasOrColor(texture, atlas, color)
    if atlas and texture.SetAtlas then
        local ok, result = pcall(texture.SetAtlas, texture, atlas)
        if ok and result ~= false and texture.GetAtlas and texture:GetAtlas() == atlas then return true end
    end
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return false
end

-- 1px border lines just inside `frame`.
function Theme.Border(frame, color, inset, layer, thickness)
    inset = inset or 0
    thickness = thickness or 1
    layer = layer or "BORDER"
    local edges = {}
    local function edge()
        local t = frame:CreateTexture(nil, layer)
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        edges[#edges + 1] = t
        return t
    end
    local top = edge()
    top:SetPoint("TOPLEFT", inset, -inset); top:SetPoint("TOPRIGHT", -inset, -inset); top:SetHeight(thickness)
    local bottom = edge()
    bottom:SetPoint("BOTTOMLEFT", inset, inset); bottom:SetPoint("BOTTOMRIGHT", -inset, inset); bottom:SetHeight(thickness)
    local left = edge()
    left:SetPoint("TOPLEFT", inset, -inset); left:SetPoint("BOTTOMLEFT", inset, inset); left:SetWidth(thickness)
    local right = edge()
    right:SetPoint("TOPRIGHT", -inset, -inset); right:SetPoint("BOTTOMRIGHT", -inset, inset); right:SetWidth(thickness)
    return edges
end

function Theme.SetBorderColor(edges, color)
    if not edges then return end
    for _, t in ipairs(edges) do
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

function Theme.Diamond(parent, size, color, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    color = color or Theme.C.gold
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    t:SetSize(size, size)
    if t.SetRotation then t:SetRotation(math.pi / 4) end
    return t
end

-- Thin divider line (fades at both ends).
function Theme.Divider(parent, width, color)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 200, 3)
    color = color or Theme.C.goldDim
    local f = { color[1], color[2], color[3], 0 }
    local left = Theme.HGradientTexture(holder, "ARTWORK", f, color)
    left:SetHeight(1)
    left:SetPoint("LEFT", 0, 0); left:SetPoint("RIGHT", holder, "CENTER", 0, 0)
    local right = Theme.HGradientTexture(holder, "ARTWORK", color, f)
    right:SetHeight(1)
    right:SetPoint("LEFT", holder, "CENTER", 0, 0); right:SetPoint("RIGHT", 0, 0)
    return holder
end

---------------------------------------------------------------------------
-- Panels: Blizzard tooltip-style inset (BackdropTemplate), with a plain
-- fallback. style = "inset" (dark) | "card" (slightly lighter)
---------------------------------------------------------------------------
local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
Theme.BACKDROP = BACKDROP

local function ApplyBackdrop(frame, bg, border)
    if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
        pcall(Mixin, frame, BackdropTemplateMixin)
        if frame.OnBackdropSizeChanged then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end
    if not frame.SetBackdrop then return false end
    local ok = pcall(frame.SetBackdrop, frame, BACKDROP)
    if not ok then return false end
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    return true
end
Theme.ApplyBackdrop = ApplyBackdrop

function Theme.Panel(frame, style)
    local bg = style == "card" and { 0.12, 0.12, 0.12, 0.75 } or { 0, 0, 0, 0.5 }
    local border = { 0.6, 0.6, 0.6, 1 }
    if ApplyBackdrop(frame, bg, border) then
        frame.usesBackdrop = true
        return
    end
    local t = Theme.SolidTexture(frame, "BACKGROUND", bg)
    t:SetAllPoints()
    frame.borderEdges = Theme.Border(frame, Theme.C.goldDim)
end

-- Hover feedback for panels in either mode.
function Theme.SetPanelHighlight(frame, on)
    if frame.usesBackdrop then
        local v = on and 0.85 or 0.6
        frame:SetBackdropBorderColor(on and 1 or v, on and 0.82 or v, on and 0 or v, 1)
    else
        Theme.SetBorderColor(frame.borderEdges, on and Theme.C.gold or Theme.C.goldDim)
    end
end

---------------------------------------------------------------------------
-- Text (Friz Quadrata with Blizzard's drop shadow)
---------------------------------------------------------------------------
function Theme.Text(parent, size, color, font, layer, flags)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or Theme.FONT_BODY, size or 12, flags or "")
    color = color or Theme.C.ink
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end

function Theme.Heading(parent, size, color)
    return Theme.Text(parent, size or 16, color or Theme.C.gold, Theme.FONT_HEADING)
end

-- Icon with Blizzard's dark slot border.
function Theme.Icon(parent, size, texture)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    local bg = Theme.SolidTexture(holder, "BACKGROUND", { 0, 0, 0, 1 })
    bg:SetAllPoints()
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if texture then icon:SetTexture(texture) end
    holder.icon = icon
    holder.edges = Theme.Border(holder, { 0.35, 0.35, 0.35, 1 }, 0, "OVERLAY")
    return holder
end
