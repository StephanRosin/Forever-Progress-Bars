--[[---------------------------------------------------------------------------
Styles.lua -- the looks a bar can take: the XP bar (XpBar.lua, its own
setting) and the profession and reputation bars (Bars.lua, barStyle). They
work on any bar Bars.lua builds (bg, borders, sb, an optional rested bar).
The profession and reputation bars are tinted: their colour carries meaning
(a profession's, a standing's), so a style with a material of its own draws
it neutral and takes their colour (Styles.Colour).

Each style says:
  height(base)   its default height from the bars' height (the XP bar's
                 own height setting wins when it is not 0)
  inset(h, px)   where the fill sits inside the bar: left, top, right, bottom
  dividers       OWN (the bars' segments), BLIZZARD (Blizzard's 20) or NONE
  ownColours     whether the fill and rested colour settings apply
  level, value   the texts' defaults: place, size(base, h), font, colour,
                 format (the level's text, else "Level %d")
  badge          the badge style "matching the bar" (Bars.lua, MATCH)
  hiddenFill     the bar's fill stays unseen (the style draws its own)
  emptyPart      it shows the empty part's colour and opacity settings
  build(bar, x)  makes its own textures once: x.under on the bar (below the
                 fill), x.over on a frame above the fill
  apply(bar, x, h, opts)             the static look
  update(bar, x, cur, max, rested)   what follows the values; also runs
                                     when the bar changes size

The art is drawn for the addon: tools/art/*.svg, rendered by
tools/make_badges to Media/<Name>.tga.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local S = ns.Settings.Get

local Styles = {}
ns.Styles = Styles

local MEDIA = "Interface\\AddOns\\ForeverProgressBars\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local OWN_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"   -- Bars.lua CFG.BAR_TEXTURE
-- A neutral fill for a tinted bar (professions, reputation): their colour
-- carries meaning, so a style with a material of its own takes their colour.
local SHADE = MEDIA .. "FillShade.tga"

Styles.LIST = { "FOREVER", "BLIZZARD", "RUNE", "GEMS", "THIN", "EMBER", "PHIAL", "ICE", "TAVERN", "GNOME" }

-- Helpers -------------------------------------------------------------------

local function under(bar, x, layer, sub, file)
    local t = bar:CreateTexture(nil, layer, nil, sub)
    if file then t:SetTexture(file) end
    x.under[#x.under + 1] = t
    return t
end

local function over(x, layer, file, add)
    local t = x.over:CreateTexture(nil, layer or "OVERLAY")
    if file then t:SetTexture(file) end
    if add then t:SetBlendMode("ADD") end
    return t
end

-- A texture whose ends keep their shape: slice margins in texture pixels,
-- drawn that many UI units wide (Forever Quest Log, Corners.lua).
local function sliced(t, left, right)
    if t.SetTextureSliceMargins then
        pcall(t.SetTextureSliceMargins, t, left, 0, right, 0)
        local mode = Enum and Enum.UITextureSliceMode
        if mode and t.SetTextureSliceMode then pcall(t.SetTextureSliceMode, t, mode.Stretched) end
    end
end

-- The fill's texture, set only on a change: the badge riding on the fill
-- hangs from that texture.
local function fill(sb, file)
    if sb.fpbFill ~= file then
        sb.fpbFill = file
        sb:SetStatusBarTexture(file)
    end
end

-- A tinted bar's own colour (Styles.Colour), else the style's.
local function tint(bar, r, g, b)
    local t = bar.styleTinted and bar.styleTint
    if t then return t[1], t[2], t[3] end
    return r, g, b
end

local function paintFill(bar, r, g, b, a)
    local tr, tg, tb = tint(bar, r, g, b)
    bar.sb:SetStatusBarColor(tr, tg, tb, a or 1)
end

local function ends(bar)
    return bar.sb.GetStatusBarTexture and bar.sb:GetStatusBarTexture()
end

local function width(bar)
    return (bar.sb.GetWidth and bar.sb:GetWidth()) or 0
end

-- Whether the fill has an end inside the bar to decorate.
local function midway(cur, max) return (cur or 0) > 0 and (cur or 0) < (max or 0) end

-- A style with a material of its own: no rim, no ground, its fill (neutral on
-- a tinted bar).
local function material(bar, file)
    for _, b in ipairs(bar.borders) do b:Hide() end
    bar.bg:SetColorTexture(0, 0, 0, 0)
    fill(bar.sb, bar.styleTinted and SHADE or file)
    paintFill(bar, 1, 1, 1)
end

-- The rested part flat in the style's colour, unless a colour was chosen.
local function paintRested(bar, r, g, b, a)
    if not bar.rested then return end
    bar.rested:SetStatusBarTexture(WHITE)
    local rc = bar.styleRestedTint
    if rc then bar.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.5)
    else bar.rested:SetStatusBarColor(r, g, b, a) end
end

-- The empty part's settings on a style with a groove of its own, which has a
-- hole behind it (plate): the chosen colour mixed over the groove's by its
-- opacity. Below GROOVE_SOLID the groove itself fades out, so 0 is truly see-through
-- and the default of 30 keeps the plain dark groove. opts.bg: the XP bar's;
-- else the bars'. Returns how solid the groove is.
local GROOVE_SOLID = 30
local function paintGroove(t, opts, r, g, b)
    local c = (opts and opts.bg) or S("barBgColor")
    local percent = (opts and opts.bgAlpha) or S("barBgAlpha")
    local a, solid = percent / 100, math.min(1, percent / GROOVE_SOLID)
    t:SetColorTexture(c[1] * a + r * (1 - a), c[2] * a + g * (1 - a), c[3] * a + b * (1 - a), solid)
    return solid
end

-- A plate with a hole for the fill, so the game shows through an empty bar: its
-- 256 wide texture in four parts around the fill. The ends keep their pixels;
-- the strips above and below stretch the texture's plain middle.
local PLATE_W = 256
local STRIP_FROM, STRIP_TO = 0.45, 0.55
local function plate(bar, x, file)
    local parts = {}
    for _, side in ipairs({ "left", "right", "top", "bottom" }) do
        parts[side] = under(bar, x, "BACKGROUND", 1, file)
    end
    return parts
end

-- left, top, right, bottom: the fill's inset in the bar. ox, oy: the plate's own.
local function placePlate(p, bar, h, left, top, right, bottom, ox, oy)
    ox, oy = ox or 0, oy or 0
    local plateH = math.max(1, h - oy * 2)
    for _, t in pairs(p) do t:ClearAllPoints() end
    p.left:SetPoint("TOPLEFT", bar, "TOPLEFT", ox, -oy)
    p.left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", ox, oy)
    p.left:SetWidth(left - ox)
    p.left:SetTexCoord(0, (left - ox) / PLATE_W, 0, 1)
    p.right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -ox, -oy)
    p.right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -ox, oy)
    p.right:SetWidth(right - ox)
    p.right:SetTexCoord(1 - (right - ox) / PLATE_W, 1, 0, 1)
    p.top:SetPoint("TOPLEFT", bar, "TOPLEFT", left, -oy)
    p.top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -right, -oy)
    p.top:SetHeight(math.max(1, top - oy))
    p.top:SetTexCoord(STRIP_FROM, STRIP_TO, 0, (top - oy) / plateH)
    p.bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", left, oy)
    p.bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -right, oy)
    p.bottom:SetHeight(math.max(1, bottom - oy))
    p.bottom:SetTexCoord(STRIP_FROM, STRIP_TO, 1 - (bottom - oy) / plateH, 1)
end

-- A texture tiled along the fill, staying put as the fill grows (Dots in THIN).
local function tiled(x, layer, file)
    local t = over(x, layer)
    t:SetTexture(file, "REPEAT", "CLAMP")
    if t.SetHorizTile then t:SetHorizTile(true) end
    return t
end

local function alongFill(t, bar, cur)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", bar.sb, "TOPLEFT")
    t:SetPoint("BOTTOMRIGHT", ends(bar), "BOTTOMRIGHT")
    t:SetShown((cur or 0) > 0)
end

-- The fill's shaped end, right of it: squeezed near the end of the bar so it
-- stays inside; neutral on a tinted bar.
local function placeTip(bar, tip, tipWidth, cur, max)
    local room = max > 0 and width(bar) * (1 - cur / max) or 0
    tip:SetVertexColor(tint(bar, 1, 1, 1))
    tip:SetSize(math.max(1, math.min(tipWidth, room)), (bar.sb.GetHeight and bar.sb:GetHeight()) or 0)
    tip:ClearAllPoints()
    tip:SetPoint("LEFT", ends(bar), "RIGHT", 0, 0)
    tip:SetShown(midway(cur, max))
end

-- The styles -------------------------------------------------------------------

local DEF = {}
Styles.DEF = DEF

-- Forever, the plain look: our texture in the chosen colours, the empty part
-- in the background colour, a rim as set (none, flat in a colour, or gold
-- shaded like the minimap's), and if asked a gold marker where the fill ends
-- (tools/badges/marker.svg; Blizzard's own tick is 10 x 14 only and blurs
-- when grown; the bar fills 100 of the marker's 160 height, it is half as
-- wide). opts.border = { style, size (screen pixels), color }, opts.marker.
local function rim(opts)
    return opts and opts.border or { style = "FLAT", size = 1, color = ns.Bars.BORDER_COLOR }
end

DEF.FOREVER = {
    height = function(base) return base end,
    inset = function(h, px, opts)
        local b = rim(opts)
        if b.style == "NONE" then return 0, 0, 0, 0 end
        local r = b.size * px
        return r, r, r, r
    end,
    dividers = "OWN", ownColours = true, emptyPart = true, badge = "CREST",
    level = { place = "ABOVE_LEFT" },
    value = {},
    build = function(bar, x)
        x.marker = over(x, "OVERLAY", MEDIA .. "BadgeMarker.tga")
    end,
    apply = function(bar, x, h, opts)
        local B, b = ns.Bars, rim(opts)
        if b.style == "NONE" then
            for _, t in ipairs(bar.borders) do t:Hide() end
        else
            B.PlaceRing(bar.borders, bar, b.size * B.OnePixel(bar), 0)
            if b.style == "GOLD" then B.PaintGold(bar.borders) else B.PaintRing(bar.borders, b.color) end
        end
        local m = math.floor(h * 160 / 100 + 0.5)
        x.marker:SetSize(m / 2, m)
        x.markerOn = opts and opts.marker == true
    end,
    update = function(bar, x, cur, max)
        x.marker:ClearAllPoints()
        x.marker:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.marker:SetShown(x.markerOn and midway(cur, max))
    end,
}

-- Blizzard's own XP bar art (Blizzard_StatusTrackingBar, Mainline):
-- background, fill, the rested bonus as a prediction, the frame, 20 dividers.
-- The fill stays purple while rested (unlike Blizzard's), so only the rested
-- part is blue.
local ATLAS = {
    background = "UI-HUD-ExperienceBar-Background",
    fill = "UI-HUD-ExperienceBar-Fill-Experience",
    prediction = "UI-HUD-ExperienceBar-Fill-Prediction",
    frame = "UI-HUD-ExperienceBar-Frame",
}
-- Blizzard's bar inside that frame (Camelot StatusTrackingBarConstants:
-- container 1192 x 17, bar 3 smaller); the frame reaches past it by the
-- rest of its atlas size.
local BLIZZARD_BAR_W, BLIZZARD_BAR_H = 1189, 14
-- The frame's opening is smaller than the bar and has bevelled ends, so a
-- fill as big as the bar pokes out past the frame. These keep the fill's
-- corners under the frame's line (measured on screen at bar height 25: the
-- opening is 14.5 high; the bevels keep their width, the height stretches).
local BLIZZARD_INSET_SIDE, BLIZZARD_INSET_EDGE_SHARE = 7.5, 0.21

DEF.BLIZZARD = {
    height = function(base) return base end,
    inset = function(h)
        local edge = math.floor(h * BLIZZARD_INSET_EDGE_SHARE + 0.5)
        return BLIZZARD_INSET_SIDE, edge, BLIZZARD_INSET_SIDE, edge
    end,
    dividers = "BLIZZARD", badge = "CREST",
    level = { place = "ABOVE_LEFT" },
    value = {},
    build = function(bar, x)
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS.frame)
        local t = over(x, "OVERLAY")
        if not info or not t.SetAtlas then return end
        t:SetAtlas(ATLAS.frame, false)
        local ox = math.max(0, ((info.width or 0) - BLIZZARD_BAR_W) / 2)
        local oy = math.max(0, ((info.height or 0) - BLIZZARD_BAR_H) / 2)
        -- Hung on the bar, not the fill: the fill sits inside the frame.
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", 1 - ox, oy - 1)
        t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", ox - 1, 1 - oy)
        local cap = info.height or 0
        sliced(t, cap, cap)
        x.frame = t
    end,
    apply = function(bar)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetAtlas(ATLAS.background)
        fill(bar.sb, bar.styleTinted and SHADE or ATLAS.fill)
        paintFill(bar, 1, 1, 1)
        if bar.rested then
            local rc = bar.styleRestedTint
            if rc then
                bar.rested:SetStatusBarTexture(WHITE)
                bar.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.6)
            else
                bar.rested:SetStatusBarTexture(ATLAS.prediction)
                bar.rested:SetStatusBarColor(1, 1, 1, 1)
            end
        end
    end,
}

-- Runenstein: a carved slab, the fill glowing arcane in a groove, runes cut
-- below it at 25, 50, 75 and 100 % that light up once reached.
local RUNE_LIT, RUNE_DARK = { 0.80, 0.72, 1 }, { 0.36, 0.37, 0.41 }
DEF.RUNE = {
    height = function(base) return math.floor(base * 2.6 + 0.5) end,
    inset = function(h) return 34, math.floor(h * 0.2 + 0.5), 34, math.floor(h * 0.42 + 0.5) end,
    dividers = "NONE", emptyPart = true, badge = "RUNESTONE",
    level = { place = "ABOVE_LEFT", color = { 0.85, 0.80, 1 } },
    value = {},   -- white: grey on the bright violet fill reads badly
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "RuneSlab.tga")
        x.groove = under(bar, x, "BORDER", 0)
        x.groove:SetAllPoints(bar.sb)
        x.shade = under(bar, x, "BORDER", 1)
        x.shade:SetColorTexture(1, 1, 1, 1)
        ns.Bars.Gradient(x.shade, { 0, 0, 0, 0 }, { 0, 0, 0, 0.9 })
        x.shade:SetPoint("TOPLEFT", bar.sb, "TOPLEFT")
        x.shade:SetPoint("TOPRIGHT", bar.sb, "TOPRIGHT")
        x.glow = over(x, "ARTWORK", MEDIA .. "Glow.tga", true)
        x.glow:SetVertexColor(0.63, 0.47, 1, 0.9)
        x.spark = over(x, "OVERLAY")
        x.spark:SetColorTexture(0.95, 0.92, 1, 1)
        x.runes, x.runeGlow = {}, {}
        for i = 1, 4 do
            x.runeGlow[i] = over(x, "ARTWORK", MEDIA .. "Glow.tga", true)
            x.runeGlow[i]:SetVertexColor(0.63, 0.47, 1, 0.7)
            x.runes[i] = over(x, "OVERLAY", MEDIA .. "RuneGlyph" .. i .. ".tga")
        end
    end,
    apply = function(bar, x, h, opts)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
        x.shade:SetAlpha(paintGroove(x.groove, opts, 0.067, 0.071, 0.086))
        placePlate(x.plate, bar, h, DEF.RUNE.inset(h))
        fill(bar.sb, bar.styleTinted and SHADE or MEDIA .. "FillRune.tga")
        paintFill(bar, 1, 1, 1)
        if bar.rested then
            bar.rested:SetStatusBarTexture(WHITE)
            local rc = bar.styleRestedTint
            if rc then bar.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.5)
            else bar.rested:SetStatusBarColor(0.58, 0.40, 1, 0.30) end
        end
        local _, top, _, bottom = DEF.RUNE.inset(h)
        x.shade:SetHeight(math.max(2, math.floor((h - top - bottom) * 0.25)))
        x.runeSize = math.floor(bottom * 0.75 + 0.5)
        x.bottom = bottom
    end,
    update = function(bar, x, cur, max)
        local groove = (bar.sb.GetHeight and bar.sb:GetHeight()) or 0
        local on = midway(cur, max)
        x.spark:ClearAllPoints()
        x.spark:SetPoint("TOP", ends(bar), "TOPRIGHT", 0, 0)
        x.spark:SetPoint("BOTTOM", ends(bar), "BOTTOMRIGHT", 0, 0)
        x.spark:SetWidth(2)
        x.spark:SetShown(on)
        x.glow:SetVertexColor(tint(bar, 0.63, 0.47, 1))
        x.glow:SetSize(groove * 2.4, groove * 2.4)
        x.glow:ClearAllPoints()
        x.glow:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.glow:SetShown(on)
        local w, pct = width(bar), max > 0 and cur / max or 0
        for i = 1, 4 do
            local at = i / 4
            local lit = pct >= at
            local r, g = x.runes[i], x.runeGlow[i]
            local size = x.runeSize or 12
            r:SetSize(size, size)
            r:ClearAllPoints()
            r:SetPoint("CENTER", bar.sb, "BOTTOMLEFT", w * at - (i == 4 and size / 2 or 0), -(x.bottom or 0) / 2)
            local c = lit and RUNE_LIT or RUNE_DARK
            r:SetVertexColor(c[1], c[2], c[3], 1)
            g:SetSize(size * 2, size * 2)
            g:ClearAllPoints()
            g:SetPoint("CENTER", r, "CENTER")
            g:SetShown(lit)
        end
    end,
}

-- Edelsteine: twenty gems in gold settings on a chain instead of a bar; the
-- gem being filled is cut where the experience ends, the rested bonus waits
-- in sapphires.
local GEMS = 20
DEF.GEMS = {
    height = function(base) return math.floor(base * 1.5 + 0.5) end,
    dividers = "NONE", badge = "GEM", hiddenFill = true,
    level = { place = "ABOVE_LEFT", color = { 1, 0.95, 0.84 } },
    value = { color = { 0.85, 0.80, 0.90 } },
    build = function(bar, x)
        x.chain = under(bar, x, "BORDER", 0)
        x.chain:SetColorTexture(0.72, 0.57, 0.25, 1)
        x.chain:SetHeight(2)
        x.chain:SetPoint("LEFT", bar.sb, "LEFT")
        x.chain:SetPoint("RIGHT", bar.sb, "RIGHT")
        x.base, x.gem = {}, {}
        for i = 1, GEMS do
            x.base[i] = over(x, "ARTWORK")
            x.gem[i] = over(x, "OVERLAY", MEDIA .. "GemFill.tga")
        end
    end,
    apply = function(bar)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
        -- The bar stays (texts and the badge hang from it), unseen.
        fill(bar.sb, WHITE)
        paintFill(bar, 1, 1, 1, 0)
        if bar.rested then bar.rested:SetStatusBarColor(1, 1, 1, 0) end
    end,
    update = function(bar, x, cur, max, rested)
        local w = width(bar)
        local h = (bar.GetHeight and bar:GetHeight()) or 0
        -- A tinted bar's gems are colourless glass in its colour.
        local file = bar.styleTinted and "GemShade.tga" or "GemFill.tga"
        local r, g, b = tint(bar, 1, 1, 1)
        local size = math.min(h, w / GEMS * 1.1)
        local pct = max > 0 and cur / max * GEMS or 0
        local restTo = max > 0 and (cur + (rested or 0)) / max * GEMS or 0
        for i = 1, GEMS do
            local f = math.max(0, math.min(1, pct - (i - 1)))
            local base, gem = x.base[i], x.gem[i]
            local cx = (i - 0.5) / GEMS * w
            local waiting = i - 1 < restTo and f < 1
            local rc = (waiting and bar.styleRestedTint) or nil
            -- A chosen rested colour: glass in that colour in an empty setting.
            base:SetTexture(MEDIA .. ((waiting and not rc) and "GemRested.tga" or "GemEmpty.tga"))
            base:SetSize(size, size)
            base:ClearAllPoints()
            base:SetPoint("CENTER", bar.sb, "LEFT", cx, 0)
            gem:SetShown(f > 0 or rc ~= nil)
            gem:SetTexture(MEDIA .. file)
            gem:SetVertexColor(r, g, b, 1)
            if f == 0 and rc then
                gem:SetTexture(MEDIA .. "GemShade.tga")
                gem:SetVertexColor(rc[1], rc[2], rc[3], 0.7)
                gem:SetTexCoord(0, 1, 0, 1)
                gem:SetSize(size, size)
                gem:ClearAllPoints()
                gem:SetPoint("CENTER", base, "CENTER")
            end
            if f > 0 then
                gem:SetTexCoord(0, f, 0, 1)
                gem:SetSize(size * f, size)
                gem:ClearAllPoints()
                gem:SetPoint("LEFT", base, "LEFT", 0, 0)
            end
        end
    end,
}

-- Hauchdünn: three pixels along the screen's edge, no frame; the rested
-- bonus dotted, a short tick where the experience ends, small text below.
DEF.THIN = {
    height = function() return 3 end,
    dividers = "NONE", badge = "CREST",
    level = { place = "BELOW_LEFT", size = function() return 12 end, color = { 0.81, 0.78, 0.87 } },
    value = { color = { 0.64, 0.61, 0.70 } },
    build = function(bar, x)
        x.dots = over(x, "ARTWORK")
        x.dots:SetTexture(MEDIA .. "Dots.tga", "REPEAT", "CLAMP")
        if x.dots.SetHorizTile then x.dots:SetHorizTile(true) end
        x.dots:SetVertexColor(0.56, 0.69, 0.93, 1)
        x.tick = over(x, "OVERLAY")
        x.tick:SetColorTexture(0.95, 0.93, 0.98, 1)
    end,
    apply = function(bar, x, h)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(1, 1, 1, 0.07)
        fill(bar.sb, WHITE)
        paintFill(bar, 0.71, 0.58, 0.88)
        if bar.rested then bar.rested:SetStatusBarColor(1, 1, 1, 0) end
        x.tick:SetSize(1, h * 3)
    end,
    update = function(bar, x, cur, max, rested)
        local w = width(bar)
        local room = math.max(0, math.min(rested or 0, max - cur))
        local rw = max > 0 and w * room / max or 0
        x.dots:ClearAllPoints()
        x.dots:SetPoint("TOPLEFT", ends(bar), "TOPRIGHT", 0, 0)
        x.dots:SetPoint("BOTTOMLEFT", ends(bar), "BOTTOMRIGHT", 0, 0)
        x.dots:SetWidth(math.max(1, rw))
        x.dots:SetShown(rw >= 1)
        local rc = bar.styleRestedTint or { 0.56, 0.69, 0.93 }
        x.dots:SetVertexColor(rc[1], rc[2], rc[3], 1)
        x.tick:ClearAllPoints()
        x.tick:SetPoint("TOP", ends(bar), "TOPRIGHT", 0, 0)
        x.tick:SetShown(midway(cur, max))
    end,
}

-- Schmiedeglut: a forged iron frame with rivets, the experience as molten
-- metal glowing hottest at its end, a few sparks; the rested bonus as
-- cooling embers.
DEF.EMBER = {
    height = function(base) return math.floor(base * 1.6 + 0.5) end,
    inset = function(h)
        local side, edge = math.floor(h * 0.42 + 0.5), math.floor(h * 0.27 + 0.5)
        return side, edge, side, edge
    end,
    dividers = "NONE", emptyPart = true, badge = "SHIELD",
    level = { place = "ABOVE_LEFT", color = { 1, 0.70, 0.36 } },
    value = { color = { 0.91, 0.79, 0.63 } },
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "EmberFrame.tga")
        x.channel = under(bar, x, "BORDER", 0)
        x.channel:SetAllPoints(bar.sb)
        x.rivets = {}
        for i = 1, 6 do
            x.rivets[i] = under(bar, x, "BORDER", 2, MEDIA .. "Rivet.tga")
        end
        x.tip = over(x, "ARTWORK", MEDIA .. "EmberTip.tga")
        x.glow = over(x, "OVERLAY", MEDIA .. "Glow.tga", true)
        x.glow:SetVertexColor(1, 0.55, 0.15, 0.85)
        x.sparks = {}
        for i = 1, 3 do
            x.sparks[i] = over(x, "OVERLAY", MEDIA .. "Glow.tga", true)
            x.sparks[i]:SetVertexColor(1, 0.82, 0.45, 1)
        end
    end,
    apply = function(bar, x, h, opts)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
        paintGroove(x.channel, opts, 0.05, 0.043, 0.04)
        placePlate(x.plate, bar, h, DEF.EMBER.inset(h))
        fill(bar.sb, bar.styleTinted and SHADE or MEDIA .. "FillEmber.tga")
        paintFill(bar, 1, 1, 1)
        if bar.rested then
            bar.rested:SetStatusBarTexture(WHITE)
            local rc = bar.styleRestedTint
            if rc then bar.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.5)
            else bar.rested:SetStatusBarColor(0.50, 0.13, 0.05, 0.55) end
        end
        x.h = h
    end,
    update = function(bar, x, cur, max)
        local h, w = x.h or 30, width(bar)
        local rivet = math.max(4, math.floor(h * 0.17 + 0.5))
        local side, edge = DEF.EMBER.inset(h)
        for i = 1, 6 do
            local at = ((i - 1) % 3 + 1) / 4
            local t = x.rivets[i]
            t:SetSize(rivet, rivet)
            t:ClearAllPoints()
            local y = i <= 3 and edge / 2 or -edge / 2
            t:SetPoint("CENTER", bar.sb, i <= 3 and "TOPLEFT" or "BOTTOMLEFT", w * at, y)
        end
        local on = (cur or 0) > 0
        local channel = (bar.sb.GetHeight and bar.sb:GetHeight()) or 0
        local filled = max > 0 and w * cur / max or 0
        x.tip:SetVertexColor(tint(bar, 1, 1, 1))
        x.glow:SetVertexColor(tint(bar, 1, 0.55, 0.15))
        x.tip:SetSize(math.max(1, math.min(h * 2.2, filled)), channel)
        x.tip:ClearAllPoints()
        x.tip:SetPoint("RIGHT", ends(bar), "RIGHT", 0, 0)
        x.tip:SetShown(on)
        x.glow:SetSize(h * 1.3, h * 1.8)
        x.glow:ClearAllPoints()
        x.glow:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.glow:SetShown(on and cur < max)
        local spots = { { 6, 0.55, 3 }, { -4, 0.85, 2 }, { 14, 0.25, 2 } }
        for i, s in ipairs(spots) do
            local t = x.sparks[i]
            t:SetSize(s[3] * 2, s[3] * 2)
            t:ClearAllPoints()
            t:SetPoint("CENTER", ends(bar), "TOPRIGHT", s[1], h * s[2] * 0.5)
            t:SetShown(on and cur < max)
        end
    end,
}

-- Alchemie-Phiole: a glass tube between brass caps, the experience a bubbling
-- potion with a round end; the rested bonus a thinner blue one behind it.
local PHIAL_CAP_SHARE = 0.55
local PHIAL_TUBE_GAP = 2
local function phialCap(h) return math.floor(h * PHIAL_CAP_SHARE + 0.5) end
DEF.PHIAL = {
    height = function(base) return math.floor(base * 1.4 + 0.5) end,
    inset = function(h)
        local side, edge = phialCap(h) - 1, math.max(4, math.floor(h * 0.2 + 0.5))
        return side, edge, side, edge
    end,
    dividers = "NONE", emptyPart = true, badge = "GEM",
    level = { place = "ABOVE_LEFT", color = { 0.89, 0.74, 0.42 } },
    value = { color = { 0.91, 0.87, 0.78 } },
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "PhialGlass.tga")
        x.empty = under(bar, x, "BORDER", 0)
        x.empty:SetAllPoints(bar.sb)
        x.bubbles = tiled(x, "ARTWORK", MEDIA .. "PhialBubbles.tga")
        x.tip = over(x, "ARTWORK")
        x.glow = over(x, "ARTWORK", MEDIA .. "Glow.tga", true)
        x.gloss = over(x, "OVERLAY")
        x.gloss:SetColorTexture(1, 1, 1, 0.18)
        x.capL = over(x, "OVERLAY", MEDIA .. "PhialCap.tga")
        x.capR = over(x, "OVERLAY", MEDIA .. "PhialCap.tga")
        x.capR:SetTexCoord(1, 0, 0, 1)
    end,
    apply = function(bar, x, h, opts)
        material(bar, MEDIA .. "FillPhial.tga")
        paintGroove(x.empty, opts, 0.09, 0.085, 0.12)
        paintRested(bar, 0.25, 0.45, 0.85, 0.55)
        x.tip:SetTexture(MEDIA .. (bar.styleTinted and "PhialTipShade.tga" or "PhialTip.tga"))
        local cap = phialCap(h)
        local side, top, sideR, bottom = DEF.PHIAL.inset(h)
        -- The tube starts under the caps and is a little lower than they are.
        placePlate(x.plate, bar, h, side, top, sideR, bottom, math.floor(cap / 2), PHIAL_TUBE_GAP)
        x.capL:SetSize(cap, h)
        x.capL:ClearAllPoints()
        x.capL:SetPoint("LEFT", bar, "LEFT", 0, 0)
        x.capR:SetSize(cap, h)
        x.capR:ClearAllPoints()
        x.capR:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        x.gloss:ClearAllPoints()
        x.gloss:SetPoint("TOPLEFT", bar.sb, "TOPLEFT", 0, -1)
        x.gloss:SetPoint("TOPRIGHT", bar.sb, "TOPRIGHT", 0, -1)
        x.gloss:SetHeight(math.max(2, math.floor(h * 0.14 + 0.5)))
    end,
    update = function(bar, x, cur, max)
        alongFill(x.bubbles, bar, cur)
        local tube = (bar.sb.GetHeight and bar.sb:GetHeight()) or 0
        placeTip(bar, x.tip, tube / 2, cur, max)
        x.glow:SetVertexColor(tint(bar, 0.78, 0.48, 0.96))
        x.glow:SetSize(tube * 1.8, tube * 1.8)
        x.glow:ClearAllPoints()
        x.glow:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.glow:SetShown(midway(cur, max))
    end,
}

-- Eissplitter: a frame with pointed ends, faceted ice breaking off in a jagged
-- edge; the rested bonus as pale frost.
DEF.ICE = {
    height = function(base) return math.floor(base * 1.4 + 0.5) end,
    inset = function(h)
        -- The frame's points keep their 18 units, whatever the height.
        local edge = math.max(2, math.floor(h * 0.12 + 0.5))
        return 20, edge, 20, edge
    end,
    dividers = "NONE", emptyPart = true, badge = "CREST",
    level = { place = "ABOVE_LEFT", color = { 0.84, 0.95, 1 } },
    value = { color = { 0.78, 0.87, 0.93 } },
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "IceFrame.tga")
        x.empty = under(bar, x, "BORDER", 0)
        x.empty:SetAllPoints(bar.sb)
        x.facets = tiled(x, "ARTWORK", MEDIA .. "IceFacets.tga")
        x.tip = over(x, "ARTWORK")
        x.glow = over(x, "OVERLAY", MEDIA .. "Glow.tga", true)
    end,
    apply = function(bar, x, h, opts)
        material(bar, MEDIA .. "FillIce.tga")
        paintGroove(x.empty, opts, 0.06, 0.09, 0.13)
        placePlate(x.plate, bar, h, DEF.ICE.inset(h))
        paintRested(bar, 0.81, 0.88, 1, 0.4)
        x.tip:SetTexture(MEDIA .. (bar.styleTinted and "IceTipShade.tga" or "IceTip.tga"))
    end,
    update = function(bar, x, cur, max)
        alongFill(x.facets, bar, cur)
        local channel = (bar.sb.GetHeight and bar.sb:GetHeight()) or 0
        placeTip(bar, x.tip, channel * 0.7, cur, max)
        x.glow:SetVertexColor(tint(bar, 0.55, 0.85, 1))
        x.glow:SetSize(channel * 1.6, channel * 1.6)
        x.glow:ClearAllPoints()
        x.glow:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.glow:SetShown(midway(cur, max))
    end,
}

-- Taverne: a wooden board with nails, ale in a dark groove; the rested bonus
-- as the foam ahead of it.
local TAVERN_NAILS = 3
DEF.TAVERN = {
    height = function(base) return math.floor(base * 1.6 + 0.5) end,
    inset = function(h)
        local edge = math.floor(h * 0.22 + 0.5)
        return 28, edge, 28, edge
    end,
    dividers = "NONE", emptyPart = true, badge = "SHIELD",
    level = { place = "ABOVE_LEFT", color = { 1, 0.80, 0.42 } },
    value = { color = { 0.93, 0.85, 0.70 } },
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "TavernBoard.tga")
        x.groove = under(bar, x, "BORDER", 0)
        x.groove:SetAllPoints(bar.sb)
        x.nails, x.endNails = {}, {}
        for i = 1, TAVERN_NAILS do
            x.nails[i] = under(bar, x, "BORDER", 2, MEDIA .. "Rivet.tga")
        end
        for i = 1, 2 do
            x.endNails[i] = under(bar, x, "BORDER", 2, MEDIA .. "Rivet.tga")
            x.endNails[i]:SetPoint("CENTER", bar, i == 1 and "LEFT" or "RIGHT", i == 1 and 14 or -14, 0)
        end
    end,
    apply = function(bar, x, h, opts)
        material(bar, MEDIA .. "FillAle.tga")
        paintGroove(x.groove, opts, 0.06, 0.04, 0.02)
        placePlate(x.plate, bar, h, DEF.TAVERN.inset(h))
        paintRested(bar, 0.96, 0.93, 0.83, 0.75)
        x.h = h
    end,
    update = function(bar, x)
        local h, w = x.h or 30, width(bar)
        local _, edge = DEF.TAVERN.inset(h)
        local nail = math.max(3, math.floor(h * 0.14 + 0.5))
        for i = 1, TAVERN_NAILS do
            local t = x.nails[i]
            t:SetSize(nail, nail)
            t:ClearAllPoints()
            t:SetPoint("CENTER", bar.sb, "TOPLEFT", w * i / (TAVERN_NAILS + 1), edge / 2)
        end
        for _, t in ipairs(x.endNails) do t:SetSize(nail * 2, nail * 2) end
    end,
}

-- Gnomenwerk: a brass plate with a row of lamps; the lamp being reached fades
-- in, the rested bonus waits in amber. Lit lamps have a halo, so they are drawn
-- larger than their place (LampLit: the core spans 20 x 44 of 32 x 64).
local LAMPS = 40
local LAMP_CORE_W, LAMP_CORE_H = 20 / 32, 44 / 64
local LAMP_GAP_SHARE = 0.18
local LAMP_EDGE = 3
Styles.GNOME_RESTED = { 0.95, 0.72, 0.35 }
DEF.GNOME = {
    height = function(base) return math.floor(base * 1.4 + 0.5) end,
    inset = function(h)
        return 20, math.floor(h * 0.2 + 0.5), 20, math.floor(h * 0.2 + 0.5)
    end,
    dividers = "NONE", emptyPart = true, badge = "RANK", hiddenFill = true,
    level = { place = "ABOVE_LEFT", color = { 0.89, 0.74, 0.42 } },
    value = { color = { 0.85, 0.87, 0.82 } },
    build = function(bar, x)
        x.plate = plate(bar, x, MEDIA .. "GnomePlate.tga")
        x.display = under(bar, x, "BORDER", 0)
        x.display:SetAllPoints(bar.sb)
        x.rivets = {}
        for i, spot in ipairs({ { "TOPLEFT", 9, -7 }, { "BOTTOMLEFT", 9, 7 }, { "TOPRIGHT", -9, -7 }, { "BOTTOMRIGHT", -9, 7 } }) do
            x.rivets[i] = under(bar, x, "BORDER", 2, MEDIA .. "Rivet.tga")
            x.rivets[i]:SetVertexColor(1, 0.84, 0.5, 1)
            x.rivets[i]:SetSize(6, 6)
            x.rivets[i]:SetPoint("CENTER", bar, spot[1], spot[2], spot[3])
        end
        x.off, x.lit = {}, {}
        for i = 1, LAMPS do
            x.off[i] = over(x, "ARTWORK", MEDIA .. "LampOff.tga")
            x.lit[i] = over(x, "OVERLAY", MEDIA .. "LampLit.tga")
        end
    end,
    apply = function(bar, x, h, opts)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
        paintGroove(x.display, opts, 0.04, 0.06, 0.055)
        placePlate(x.plate, bar, h, DEF.GNOME.inset(h))
        -- The bar stays (texts and the badge hang from it), unseen.
        fill(bar.sb, WHITE)
        paintFill(bar, 1, 1, 1, 0)
        if bar.rested then bar.rested:SetStatusBarColor(1, 1, 1, 0) end
    end,
    update = function(bar, x, cur, max, rested)
        local w = width(bar)
        local slot = w / LAMPS
        local gap = math.max(1, math.floor(slot * LAMP_GAP_SHARE + 0.5))
        local cellW = math.max(1, slot - gap)
        local cellH = math.max(1, ((bar.sb.GetHeight and bar.sb:GetHeight()) or 0) - LAMP_EDGE * 2)
        local pct = max > 0 and cur / max * LAMPS or 0
        local restTo = max > 0 and (cur + (rested or 0)) / max * LAMPS or 0
        local r, g, b = tint(bar, 0.45, 0.98, 0.85)
        local rc = bar.styleRestedTint or Styles.GNOME_RESTED
        for i = 1, LAMPS do
            local off, lit = x.off[i], x.lit[i]
            off:SetSize(cellW, cellH)
            off:ClearAllPoints()
            off:SetPoint("LEFT", bar.sb, "LEFT", (i - 1) * slot + gap / 2, 0)
            lit:SetSize(cellW / LAMP_CORE_W, cellH / LAMP_CORE_H)
            lit:ClearAllPoints()
            lit:SetPoint("CENTER", off, "CENTER")
            local f = math.max(0, math.min(1, pct - (i - 1)))
            if f > 0 then
                lit:SetVertexColor(r, g, b, f)
            else
                lit:SetVertexColor(rc[1], rc[2], rc[3], 0.8)
            end
            lit:SetShown(f > 0 or i - 1 < restTo)
        end
    end,
}

-- Applying ----------------------------------------------------------------------

function Styles.Get(id) return DEF[id] or DEF.FOREVER end

local function parts(bar, id)
    bar.styleParts = bar.styleParts or {}
    local x = bar.styleParts[id]
    if x then return x end
    x = { under = {} }
    x.over = CreateFrame("Frame", nil, bar)
    x.over:SetAllPoints(bar)
    x.over:SetFrameLevel((bar.sb:GetFrameLevel() or 1) + 2)
    -- Whatever hangs on the bar's size follows it.
    x.over:SetScript("OnSizeChanged", function() Styles.Refresh(bar) end)
    bar.styleParts[id] = x
    local def = DEF[id]
    if def and def.build then def.build(bar, x) end
    return x
end

local function showParts(x, shown)
    x.over:SetShown(shown)
    for _, t in ipairs(x.under) do t:SetShown(shown) end
end

-- The look: first the plain bar (our texture, the black rim, the empty
-- part in the bars' colours), then the style on top.
-- opts: fill, rested (our colours, for the styles that take them); tinted
-- (a bar whose colour comes from Styles.Colour: professions, reputation);
-- restedTint (the rested part's colour for a tinted bar); bg,
-- bgAlpha (the empty part, else the bars' own); border, marker (Forever).
function Styles.Apply(bar, id, h, opts)
    opts = opts or {}
    if not DEF[id] then id = "FOREVER" end   -- a style no longer offered (Own)
    local def = Styles.Get(id)
    bar.styleId = id
    bar.styleTinted = opts.tinted
    bar.styleRestedTint = opts.restedTint
    for other, x in pairs(bar.styleParts or {}) do
        if other ~= id then showParts(x, false) end
    end
    local B = ns.Bars
    for _, b in ipairs(bar.borders) do b:Show() end
    B.PlaceRing(bar.borders, bar, 1, 0)
    B.PaintRing(bar.borders, B.BORDER_COLOR)
    bar.bg:SetVertexColor(1, 1, 1, 1)
    local c = opts.bg or S("barBgColor")
    bar.bg:SetColorTexture(c[1], c[2], c[3], (opts.bgAlpha or S("barBgAlpha")) / 100)
    local l, t, r, b = 1, 1, 1, 1
    if def.inset then l, t, r, b = def.inset(h, B.OnePixel(bar), opts) end
    bar.sb:ClearAllPoints()
    bar.sb:SetPoint("TOPLEFT", bar, "TOPLEFT", l, -t)
    bar.sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -r, b)
    fill(bar.sb, OWN_TEXTURE)
    local fc, rc = opts.fill, opts.rested
    -- An alpha left at 0 by a style without a fill would stay.
    paintFill(bar, 1, 1, 1)
    if fc then bar.sb:SetStatusBarColor(fc[1], fc[2], fc[3], 1) end
    if bar.rested then
        bar.rested:SetStatusBarTexture(OWN_TEXTURE)
        if rc then bar.rested:SetStatusBarColor(rc[1], rc[2], rc[3], 0.6) end
    end
    local x = (def.build or def.apply or def.update) and parts(bar, id)
    if x then
        showParts(x, true)
        if def.apply then def.apply(bar, x, h, opts) end
    end
    -- A tinted bar keeps its colour through a change of look.
    if bar.styleTinted and bar.styleTint then Styles.Colour(bar, unpack(bar.styleTint)) end
    Styles.Refresh(bar)
end

-- A tinted bar's colour: the fill takes it (unseen where the style draws
-- its own), the style's parts follow.
function Styles.Colour(bar, r, g, b)
    bar.styleTint = { r, g, b }
    local def = bar.styleId and DEF[bar.styleId]
    bar.sb:SetStatusBarColor(r, g, b, def and def.hiddenFill and 0 or 1)
    Styles.Refresh(bar)
end

-- The values the style follows; Refresh lays them out again.
function Styles.Update(bar, cur, max, rested)
    bar.styleValues = { cur or 0, max or 0, rested or 0 }
    Styles.Refresh(bar)
end

function Styles.Refresh(bar)
    local id = bar.styleId
    local def = id and DEF[id]
    local x = bar.styleParts and bar.styleParts[id]
    local v = bar.styleValues
    if def and def.update and x and v then def.update(bar, x, v[1], v[2], v[3]) end
end
