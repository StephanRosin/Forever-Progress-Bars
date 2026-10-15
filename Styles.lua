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
  square         as wide as it is high when no width of its own is set
  inset(h, px)   where the fill sits inside the bar: left, top, right, bottom
  dividers       OWN (the bars' segments), BLIZZARD (Blizzard's 20) or NONE
  ownColours     whether the fill and rested colour settings apply
  levelText      the level always shows as text (never the badge)
  level, value   the texts' defaults: place, size(base, h), font, colour,
                 format (the level's text, else "Level %d")
  badge          the badge style "matching the bar" (Bars.lua, MATCH)
  hiddenFill     the bar's fill stays unseen (the style draws its own)
  tintable       may take chosen colours instead of its material's (XP bar)
  build(bar, x)  makes its own textures once: x.under on the bar (below the
                 fill), x.over on a frame above the fill
  apply(bar, x, h)                   the static look
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

Styles.LIST = { "OWN", "FOREVER", "BLIZZARD", "RUNE", "GEMS", "RING", "THIN", "EMBER" }

local GOLD_TEXT = { 1, 0.82, 0.29 }

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

-- The styles -------------------------------------------------------------------

local DEF = {}
Styles.DEF = DEF

-- Our texture in the chosen colours, a thin black rim.
DEF.OWN = {
    height = function(base) return base end,
    dividers = "OWN", ownColours = true, badge = "CREST",
    level = { place = "ABOVE_LEFT" },
    value = {},
}

-- The look of the other Forever addons: dark, a gold rim two screen pixels
-- wide (the minimap's), the level as text on a plate (XpBar.lua) or as the
-- badge, and a gold marker
-- where the fill ends (tools/badges/marker.svg; Blizzard's own tick is
-- 10 x 14 only and blurs when grown). The bar fills 100 of the marker's
-- 160 height; it is half as wide.
DEF.FOREVER = {
    height = function(base) return base end,
    inset = function(h, px) local r = 2 * px return r, r, r, r end,
    dividers = "OWN", ownColours = true, badge = "CREST",
    level = { place = "ABOVE_CENTER", size = function() return 18 end, font = "Friz Quadrata", color = GOLD_TEXT },
    value = {},
    build = function(bar, x)
        x.marker = over(x, "OVERLAY", MEDIA .. "BadgeMarker.tga")
    end,
    apply = function(bar, x, h)
        local B = ns.Bars
        bar.bg:SetColorTexture(0.047, 0.047, 0.055, 0.82)   -- the quest log's FOREVER preset
        B.PlaceRing(bar.borders, bar, 2 * B.OnePixel(bar), 0)
        B.PaintGold(bar.borders)
        local m = math.floor(h * 160 / 100 + 0.5)
        x.marker:SetSize(m / 2, m)
    end,
    update = function(bar, x, cur, max)
        x.marker:ClearAllPoints()
        x.marker:SetPoint("CENTER", ends(bar), "RIGHT", 0, 0)
        x.marker:SetShown(midway(cur, max))
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

DEF.BLIZZARD = {
    height = function(base) return base end,
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
        t:SetPoint("TOPLEFT", bar.sb, "TOPLEFT", -ox, oy)
        t:SetPoint("BOTTOMRIGHT", bar.sb, "BOTTOMRIGHT", ox, -oy)
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
            bar.rested:SetStatusBarTexture(ATLAS.prediction)
            bar.rested:SetStatusBarColor(1, 1, 1, 1)
        end
    end,
}

-- Runenstein: a carved slab, the fill glowing arcane in a groove, runes cut
-- below it at 25, 50, 75 and 100 % that light up once reached.
local RUNE_LIT, RUNE_DARK = { 0.80, 0.72, 1 }, { 0.36, 0.37, 0.41 }
DEF.RUNE = {
    height = function(base) return math.floor(base * 2.6 + 0.5) end,
    inset = function(h) return 34, math.floor(h * 0.2 + 0.5), 34, math.floor(h * 0.42 + 0.5) end,
    dividers = "NONE", badge = "RUNESTONE", tintable = true,
    level = { place = "ABOVE_LEFT", color = { 0.85, 0.80, 1 } },
    value = {},   -- white: grey on the bright violet fill reads badly
    build = function(bar, x)
        x.slab = under(bar, x, "BACKGROUND", 1, MEDIA .. "RuneSlab.tga")
        x.slab:SetAllPoints(bar)
        sliced(x.slab, 32, 32)
        x.groove = under(bar, x, "BORDER", 0)
        x.groove:SetColorTexture(0.067, 0.071, 0.086, 1)
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
    apply = function(bar, x, h)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
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
            base:SetTexture(MEDIA .. ((i - 1 < restTo and f < 1) and "GemRested.tga" or "GemEmpty.tga"))
            base:SetSize(size, size)
            base:ClearAllPoints()
            base:SetPoint("CENTER", bar.sb, "LEFT", cx, 0)
            gem:SetShown(f > 0)
            gem:SetTexture(MEDIA .. file)
            gem:SetVertexColor(r, g, b, 1)
            if f > 0 then
                gem:SetTexCoord(0, f, 0, 1)
                gem:SetSize(size * f, size)
                gem:ClearAllPoints()
                gem:SetPoint("LEFT", base, "LEFT", 0, 0)
            end
        end
    end,
}

-- Siegelring: a round gauge around the level instead of a bar, for near
-- the player frame: a gold bezel with 20 notches, the experience as an arc
-- (short rotated pieces), the rested bonus after it, a gold diamond at the
-- end. The arc runs at 0.36 of the size, 0.07 thick (RingBezel.svg).
local ARC_PIECES = 90
DEF.RING = {
    height = function(base) return base * 5 end,
    square = true, hiddenFill = true,
    dividers = "NONE", levelText = true,
    -- Only the number in the middle: "Level 18" is too wide for it.
    level = { place = "IN_CENTER", format = "%d", size = function(_, h) return math.floor(h * 0.3 + 0.5) end,
              font = "Friz Quadrata", color = { 0.95, 0.86, 0.61 } },
    value = { color = { 0.87, 0.84, 0.78 } },
    build = function(bar, x)
        x.disc = over(x, "BACKGROUND", MEDIA .. "RingDisc.tga")
        x.arc = {}
        for i = 1, ARC_PIECES do
            -- Soft-edged pieces: the game smooths them when turned (ArcPiece.svg).
            x.arc[i] = over(x, "ARTWORK", MEDIA .. "ArcPiece.tga")
        end
        x.bezel = over(x, "OVERLAY", MEDIA .. "RingBezel.tga")
        x.diamond = x.over:CreateTexture(nil, "OVERLAY", nil, 1)
        x.diamond:SetTexture(MEDIA .. "Diamond.tga")
    end,
    apply = function(bar)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
        fill(bar.sb, WHITE)
        paintFill(bar, 1, 1, 1, 0)
        if bar.rested then bar.rested:SetStatusBarColor(1, 1, 1, 0) end
    end,
    update = function(bar, x, cur, max, rested)
        local w = width(bar)
        local h = (bar.sb.GetHeight and bar.sb:GetHeight()) or 0
        local tinted = bar.styleTinted and bar.styleTint
        local d = math.min(w, h)
        -- Centred, or at the left end with the texts beside it.
        local ox = bar.styleRingLeft and (d - w) / 2 or 0
        x.disc:SetSize(d * 0.66, d * 0.66)
        x.disc:ClearAllPoints()
        x.disc:SetPoint("CENTER", bar.sb, "CENTER", ox, 0)
        x.bezel:SetSize(d, d)
        x.bezel:ClearAllPoints()
        x.bezel:SetPoint("CENTER", bar.sb, "CENTER", ox, 0)
        local r, thick = d * 0.36, d * 0.07
        local len = 2 * math.pi * r / ARC_PIECES * 1.3
        local pct = max > 0 and cur / max or 0
        local restTo = max > 0 and math.min(1, (cur + (rested or 0)) / max) or 0
        for i = 1, ARC_PIECES do
            local at = (i - 0.5) / ARC_PIECES
            local a = at * 2 * math.pi
            local t = x.arc[i]
            t:SetSize(len * 64 / 58, thick * 16 / 10)   -- the piece is 58 x 10 of its 64 x 16
            t:ClearAllPoints()
            t:SetPoint("CENTER", bar.sb, "CENTER", ox + r * math.sin(a), r * math.cos(a))
            if t.SetRotation then t:SetRotation(-a) end
            if at <= pct and tinted then
                t:SetVertexColor(tinted[1], tinted[2], tinted[3], 1)
            elseif at <= pct then
                -- Lighter at the start, deeper towards the end.
                local k = at
                t:SetVertexColor(0.78 - 0.30 * k, 0.48 - 0.26 * k, 1 - 0.18 * k, 1)
            elseif at <= restTo then
                -- Opaque: see-through pieces overlap into stripes.
                t:SetVertexColor(0.22, 0.36, 0.64, 1)
            else
                t:SetVertexColor(0.08, 0.09, 0.11, 1)
            end
        end
        local a = pct * 2 * math.pi
        x.diamond:SetSize(d * 0.1, d * 0.1)
        x.diamond:ClearAllPoints()
        x.diamond:SetPoint("CENTER", bar.sb, "CENTER", ox + r * math.sin(a), r * math.cos(a))
        x.diamond:SetShown(midway(cur, max))
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
    dividers = "NONE", badge = "SHIELD", tintable = true,
    level = { place = "ABOVE_LEFT", color = { 1, 0.70, 0.36 } },
    value = { color = { 0.91, 0.79, 0.63 } },
    build = function(bar, x)
        x.frame = under(bar, x, "BACKGROUND", 1, MEDIA .. "EmberFrame.tga")
        x.frame:SetAllPoints(bar)
        sliced(x.frame, 24, 24)
        x.channel = under(bar, x, "BORDER", 0)
        x.channel:SetColorTexture(0.05, 0.043, 0.04, 1)
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
    apply = function(bar, x, h)
        for _, b in ipairs(bar.borders) do b:Hide() end
        bar.bg:SetColorTexture(0, 0, 0, 0)
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

-- Applying ----------------------------------------------------------------------

function Styles.Get(id) return DEF[id] or DEF.OWN end

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
-- ringLeft (the ring at the bar's left end, its texts beside it);
-- restedTint (the rested part's colour for a tinted bar); bg,
-- bgAlpha (the empty part, else the bars' own).
function Styles.Apply(bar, id, h, opts)
    opts = opts or {}
    local def = Styles.Get(id)
    bar.styleId = id
    bar.styleTinted = opts.tinted
    bar.styleRingLeft = opts.ringLeft
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
    if def.inset then l, t, r, b = def.inset(h, B.OnePixel(bar)) end
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
        if def.apply then def.apply(bar, x, h) end
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
