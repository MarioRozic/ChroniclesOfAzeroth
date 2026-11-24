--[[
  Chronicles of Azeroth - UI/Theme.lua

  The visual language: a dark leather-and-parchment palette, thin gold
  double borders, and the Morpheus font that ships with every WoW client for
  medieval headings.

  To stay robust on the Forever client, the frame art is drawn with solid
  colour textures (Texture:SetColorTexture) rather than relying on specific
  art files, so nothing can turn up as a missing green box. Only long-lived
  stock files are referenced (fonts, Interface\Icons\*, the chat size grip).
]]

local _, CoA = ...
local Theme = {}
CoA.Theme = Theme

Theme.FONT_HEADING = "Fonts\\MORPHEUS.TTF"
Theme.FONT_BODY = "Fonts\\FRIZQT__.TTF"

-- r, g, b[, a]
Theme.C = {
    leather      = { 0.075, 0.058, 0.042, 0.97 },
    leatherLight = { 0.115, 0.088, 0.062, 1 },
    parchment    = { 0.165, 0.128, 0.088, 1 },
    parchmentTop = { 0.205, 0.160, 0.108, 1 },
    inset        = { 0.055, 0.043, 0.031, 0.85 },
    gold         = { 0.831, 0.686, 0.216, 1 },
    goldDim      = { 0.560, 0.450, 0.200, 1 },
    goldFaint    = { 0.560, 0.450, 0.200, 0.35 },
    ink          = { 0.910, 0.850, 0.710, 1 },  -- main text on dark parchment
    inkMuted     = { 0.660, 0.600, 0.480, 1 },
    inkFaint     = { 0.480, 0.430, 0.340, 1 },
    highlight    = { 0.831, 0.686, 0.216, 0.14 },
    selected     = { 0.831, 0.686, 0.216, 0.24 },
    blood        = { 0.70, 0.22, 0.18, 1 },
    verdant      = { 0.45, 0.70, 0.35, 1 },
}

-- Category accent colours for feed entries.
Theme.CATEGORY_COLORS = {
    travel   = { 0.55, 0.72, 0.85 },
    progress = { 0.83, 0.69, 0.22 },
    quest    = { 0.82, 0.62, 0.32 },
    combat   = { 0.78, 0.32, 0.26 },
    system   = { 0.66, 0.60, 0.48 },
}

function Theme.Hex(c)
    return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

---------------------------------------------------------------------------
-- Texture helpers
---------------------------------------------------------------------------
function Theme.SolidTexture(parent, layer, color, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return t
end

-- Vertical gradient (top colour -> bottom colour). Falls back to a solid
-- fill on clients without the CreateColor-based SetGradient signature.
function Theme.GradientTexture(parent, layer, top, bottom, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetColorTexture(1, 1, 1, 1)
    local ok = false
    if CreateColor and t.SetGradient then
        ok = pcall(t.SetGradient, t, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
            CreateColor(top[1], top[2], top[3], top[4] or 1))
    end
    if not ok then
        t:SetColorTexture(bottom[1], bottom[2], bottom[3], bottom[4] or 1)
    end
    return t
end

-- Horizontal gradient (left -> right); used for highlight bars.
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

-- Draws a 1px border of `color` just inside `frame`, inset by `inset`.
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
    for _, t in ipairs(edges) do
        t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

-- A small gold diamond ornament (a rotated square).
function Theme.Diamond(parent, size, color, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    color = color or Theme.C.gold
    t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    t:SetSize(size, size)
    if t.SetRotation then t:SetRotation(math.pi / 4) end
    return t
end

-- Gold divider: fading line - diamond - fading line.
function Theme.Divider(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 200, 9)
    local g, f = Theme.C.gold, { Theme.C.gold[1], Theme.C.gold[2], Theme.C.gold[3], 0 }
    local left = Theme.HGradientTexture(holder, "ARTWORK", f, g)
    left:SetHeight(1)
    left:SetPoint("LEFT", 0, 0); left:SetPoint("RIGHT", holder, "CENTER", -7, 0)
    local right = Theme.HGradientTexture(holder, "ARTWORK", g, f)
    right:SetHeight(1)
    right:SetPoint("LEFT", holder, "CENTER", 7, 0); right:SetPoint("RIGHT", 0, 0)
    local d = Theme.Diamond(holder, 6)
    d:SetPoint("CENTER")
    return holder
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------

-- Dark parchment panel with a faint gold border. style = "inset" | "card"
function Theme.Panel(frame, style)
    if style == "inset" then
        local bg = Theme.SolidTexture(frame, "BACKGROUND", Theme.C.inset)
        bg:SetAllPoints()
        frame.borderEdges = Theme.Border(frame, Theme.C.goldFaint)
    else
        local bg = Theme.GradientTexture(frame, "BACKGROUND", Theme.C.parchmentTop, Theme.C.parchment)
        bg:SetAllPoints()
        frame.borderEdges = Theme.Border(frame, Theme.C.goldFaint)
    end
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function Theme.Text(parent, size, color, font, layer, flags)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or Theme.FONT_BODY, size or 12, flags or "")
    color = color or Theme.C.ink
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end

function Theme.Heading(parent, size, color)
    local fs = Theme.Text(parent, size or 20, color or Theme.C.gold, Theme.FONT_HEADING)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- Square icon with a thin gold frame, trimmed of the default icon edge.
function Theme.Icon(parent, size, texture)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    local bg = Theme.SolidTexture(holder, "BACKGROUND", { 0, 0, 0, 0.8 })
    bg:SetAllPoints()
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if texture then icon:SetTexture(texture) end
    holder.icon = icon
    holder.edges = Theme.Border(holder, Theme.C.goldDim, 0, "OVERLAY")
    return holder
end
