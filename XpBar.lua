--[[---------------------------------------------------------------------------
XpBar.lua -- an experience bar in the style of the reputation bars. Off by
default.

The bar itself is built and placed by Bars.lua like the other bars (same
height, empty part, rim, segments): a row of its own over the whole width,
above the professions, between professions and reputation, or at the
bottom. With its title line on, "Level 20" sits above it on the left and the
numbers ("730 / 23200 (3%)") on the right, as on the reputation bars; off,
only the bar.

It does what Blizzard's bar does: the rested part ahead of the fill in the
rested colour, a tooltip in the bars' own layout, hidden at the maximum level
and while experience is switched off.

While it is on, Blizzard's bars are hidden: StatusTrackingBarManager, the
parent of both bar containers (Blizzard never shows or hides it itself;
the containers are Edit Mode systems and stay untouched). A watched
reputation's bar lives there too and goes with it. Switched off, they come
back.

A plain frame, nothing secure: it may change in combat.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Settings, L = ns.Settings, ns.L
local S = Settings.Get

local Xp = {}
ns.XpBar = Xp

Xp.TEXT_MODES = { "CURRENT_MAX", "CURRENT_MAX_PERCENT", "PERCENT", "NONE" }
-- OWN: our texture in the chosen colours. FOREVER: the same, in the look of
-- the other Forever addons (dark background, gold rim, as the quest log).
-- BLIZZARD: Blizzard's own XP bar art (Blizzard_StatusTrackingBar,
-- Mainline): background, fill, the rested bonus as a prediction, the frame,
-- 20 dividers (Bars.lua).
Xp.STYLES = { "OWN", "FOREVER", "BLIZZARD" }
Xp.ROWS = { "TOP", "MIDDLE", "BOTTOM", "FREE" }
Xp.VALUE_PLACES = { "ABOVE_LEFT", "ABOVE_CENTER", "ABOVE_RIGHT", "IN_LEFT", "IN_CENTER", "IN_RIGHT",
    "BELOW_LEFT", "BELOW_CENTER", "BELOW_RIGHT" }

-- The numbers: plain values in, text out, so the tests need no game.
function Xp.Text(mode, cur, max)
    if mode == "NONE" or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return "" end
    local pct = math.floor(cur / max * 100)
    if mode == "PERCENT" then return pct .. "%" end
    -- Our own format: Blizzard's XP_STATUS_BAR_TEXT carries an "XP: " in
    -- front, which the title line does not want.
    local base = ("%d / %d"):format(cur, max)
    if mode == "CURRENT_MAX_PERCENT" then return ("%s (%d%%)"):format(base, pct) end
    return base
end

-- Whether there is experience to show: not at the maximum level, not
-- switched off.
function Xp.Active()
    if IsXPUserDisabled and IsXPUserDisabled() then return false end
    local level = UnitLevel and UnitLevel("player") or 0
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
    return level < maxLevel and (UnitXPMax("player") or 0) > 0
end

-- Blizzard's experience and reputation bars, hidden while ours is on.
local hookedBlizzard = false
local function blizzardBars(show)
    local manager = _G.StatusTrackingBarManager
    if not manager then return end
    if not hookedBlizzard then
        hookedBlizzard = true
        -- HookScript, never hooksecurefunc on a frame method (Forever).
        manager:HookScript("OnShow", function(self)
            if S("xpEnabled") then self:Hide() end
        end)
    end
    if show then manager:Show() else manager:Hide() end
end
Xp.BlizzardBars = blizzardBars

-- Tooltip in the bars' own layout (Bars.lua ShowTooltip): anchored to the
-- right, the name as a white title, then label left and value right.
local function showTooltip(self)
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if not max or max <= 0 then return end
    local big = BreakUpLargeNumbers or tostring
    local grey, white = { 0.8, 0.8, 0.8 }, { 1, 1, 1 }
    local function row(label, value, c)
        c = c or white
        GameTooltip:AddDoubleLine(label, value, grey[1], grey[2], grey[3], c[1], c[2], c[3])
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.XP_LEVEL:format(UnitLevel("player") or 0), 1, 1, 1)
    row(L.TIP_XP, ("%s / %s"):format(big(cur), big(max)))
    row(L.TIP_XP_PROGRESS, ("%d%%"):format(math.floor(cur / max * 100)))
    row(L.TIP_XP_TO_LEVEL, big(max - cur))
    local rested = GetXPExhaustion and GetXPExhaustion()
    if rested and rested > 0 then
        row(L.TIP_XP_RESTED, ("%s (%d%%)"):format(big(rested), math.floor(rested / max * 100)), { 0.4, 0.6, 1 })
    end
    -- Blizzard's rest state, where the client names it (Forever does not).
    local _, stateName, multiplier = GetRestState and GetRestState()
    if type(stateName) == "string" and type(multiplier) == "number" then
        row(stateName, ("%d%%"):format(multiplier * 100))
    end
    GameTooltip:Show()
end

local function hideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function slot() return ns.Bars.XpSlot and ns.Bars.XpSlot() end

local OWN_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"   -- Bars.lua CFG.BAR_TEXTURE
local ATLAS = {
    background = "UI-HUD-ExperienceBar-Background",
    fill = "UI-HUD-ExperienceBar-Fill-Experience",
    prediction = "UI-HUD-ExperienceBar-Fill-Prediction",
    frame = "UI-HUD-ExperienceBar-Frame",
}
-- Blizzard's bar inside that frame (Camelot StatusTrackingBarConstants:
-- container 1192 x 17, bar 3 smaller); the frame art reaches past it by
-- the rest of its atlas size.
local BLIZZARD_BAR_W, BLIZZARD_BAR_H = 1189, 14

-- The Forever look's background: the quest log's (its FOREVER preset).
local FOREVER_BG = { 0.047, 0.047, 0.055, 0.82 }

local function blizzard() return S("xpStyle") == "BLIZZARD" end

-- Forever shows the level as a header above the bar (the quest log's title:
-- Friz Quadrata, gold, shadow), never as the badge.
local HEADER_FONT, HEADER_SIZE, HEADER_COLOR = "Friz Quadrata", 18, { 1, 0.82, 0.29 }
function Xp.LevelMode() return S("xpStyle") == "FOREVER" and "TEXT" or S("xpLevelMode") end

-- The plate the header sits on, centred on the bar's top edge: the quest
-- log's title bar (Tracker.lua): dark, rounded top corners, a gold shine
-- rising to the top, a faint gold line along the bottom.
local PLATE_H, PLATE_PAD, PLATE_RADIUS = 32, 14, 10
local PLATE_MASK = "Interface\\AddOns\\ForeverProgressBars\\Media\\Rounded10.tga"

local function plate(bar)
    if bar.plate then return bar.plate end
    local p = CreateFrame("Frame", nil, bar)
    p:SetHeight(PLATE_H)
    p:SetPoint("BOTTOM", bar, "TOP", 0, 0)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints(p)
    p.shine = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    p.shine:SetAllPoints(p)
    p.shine:SetColorTexture(1, 1, 1, 1)
    ns.Bars.Gradient(p.shine, { 1, 0.79, 0.19, 0 }, { 1, 0.79, 0.19, 0.10 })
    p.line = p:CreateTexture(nil, "ARTWORK")
    p.line:SetHeight(1)
    p.line:SetPoint("BOTTOMLEFT")
    p.line:SetPoint("BOTTOMRIGHT")
    p.line:SetColorTexture(0.78, 0.59, 0.13, 0.45)
    -- Rounded on top only: the mask reaches a radius below the plate.
    if p.CreateMaskTexture then
        local mask = p:CreateMaskTexture()
        mask:SetTexture(PLATE_MASK, "CLAMP", "CLAMP")
        mask:SetTextureSliceMargins(PLATE_RADIUS, PLATE_RADIUS, PLATE_RADIUS, PLATE_RADIUS)
        mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        mask:SetPoint("TOPLEFT")
        mask:SetPoint("BOTTOMRIGHT", 0, -PLATE_RADIUS)
        p.bg:AddMaskTexture(mask)
        p.shine:AddMaskTexture(mask)
    end
    bar.plate = p
    return p
end

-- Forever: the level text moves onto the plate, as wide as the text; other
-- styles: the plate hides and the text goes back to the bar.
function Xp.LayoutHeader()
    local bar = slot()
    if not bar then return end
    local name, on = bar.nameText, S("xpStyle") == "FOREVER" and S("xpTitle")
    if not on then
        if bar.plate then bar.plate:Hide() end
        if name:GetParent() ~= bar then
            name:SetParent(bar)
            name:SetJustifyH("LEFT")
        end
        return
    end
    local p = plate(bar)
    p.bg:SetColorTexture(0, 0, 0, 1)   -- opaque: what lies behind would show through the title
    name:SetParent(p)
    name:SetJustifyH("CENTER")
    p:SetWidth(math.floor(name:GetStringWidth() + 2 * PLATE_PAD + 0.5))
    -- Pinned on both sides: Bars.lua gives the label a width of its own.
    name:ClearAllPoints()
    name:SetPoint("LEFT", p, "LEFT", PLATE_PAD, 0)
    name:SetPoint("RIGHT", p, "RIGHT", -PLATE_PAD, 0)
    p:Show()
end

-- The frame around the bar: one texture over the fill, below the numbers,
-- the ends kept by slice margins while the middle stretches to any width.
local function frameArt(bar)
    if bar.frameArt then return bar.frameArt end
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(bar.sb)
    holder:SetFrameLevel((bar.sb:GetFrameLevel() or 1) + 2)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(ATLAS.frame)
    if not info or not tex.SetAtlas then return nil end
    tex:SetAtlas(ATLAS.frame, false)
    local ox = math.max(0, ((info.width or 0) - BLIZZARD_BAR_W) / 2)
    local oy = math.max(0, ((info.height or 0) - BLIZZARD_BAR_H) / 2)
    tex:SetPoint("TOPLEFT", holder, "TOPLEFT", -ox, oy)
    tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", ox, -oy)
    if tex.SetTextureSliceMargins then
        local cap = info.height or 0
        pcall(tex.SetTextureSliceMargins, tex, cap, 0, cap, 0)
        local mode = Enum and Enum.UITextureSliceMode
        if mode and tex.SetTextureSliceMode then pcall(tex.SetTextureSliceMode, tex, mode.Stretched) end
    end
    bar.frameArt = holder
    return holder
end

-- The fill stays purple while rested (unlike Blizzard's), so only the rested
-- part is blue. Set only once: the badge riding on the fill hangs from its texture.
local function foreverFill(bar)
    if bar.fillAtlas ~= ATLAS.fill then
        bar.fillAtlas = ATLAS.fill
        bar.sb:SetStatusBarTexture(ATLAS.fill)
    end
    bar.sb:SetStatusBarColor(1, 1, 1)
end

-- Look of the bar for the chosen style; Bars.lua calls it after it painted
-- the empty part and the rim, and Apply after a change of style.
function Xp.ApplyStyle()
    local bar = slot()
    if not bar then return end
    local on = blizzard()
    for _, b in ipairs(bar.borders or {}) do b:SetShown(not on) end
    local art = on and frameArt(bar) or bar.frameArt
    if art then art:SetShown(on) end
    -- Forever: a gold rim two screen pixels wide, as the minimap's; else one unit.
    local B, gold = ns.Bars, S("xpStyle") == "FOREVER"
    local rim = gold and 2 * B.OnePixel(bar) or 1
    B.PlaceRing(bar.borders, bar, rim, 0)
    bar.sb:ClearAllPoints()
    bar.sb:SetPoint("TOPLEFT", bar, "TOPLEFT", rim, -rim)
    bar.sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -rim, rim)
    if on then
        bar.bg:SetAtlas(ATLAS.background)
        bar.bg:SetVertexColor(1, 1, 1, 1)
        foreverFill(bar)
        bar.rested:SetStatusBarTexture(ATLAS.prediction)
        bar.rested:SetStatusBarColor(1, 1, 1, 1)
    else
        bar.bg:SetVertexColor(1, 1, 1, 1)
        if gold then
            bar.bg:SetColorTexture(unpack(FOREVER_BG))
            B.PaintGold(bar.borders)
        else
            local c = S("barBgColor")
            bar.bg:SetColorTexture(c[1], c[2], c[3], S("barBgAlpha") / 100)
            B.PaintRing(bar.borders, B.BORDER_COLOR)
        end
        bar.fillAtlas = nil
        bar.sb:SetStatusBarTexture(OWN_TEXTURE)
        bar.sb:SetStatusBarColor(unpack(S("xpColor")))
        local r = S("xpRestedColor")
        bar.rested:SetStatusBarTexture(OWN_TEXTURE)
        bar.rested:SetStatusBarColor(r[1], r[2], r[3], 0.6)
    end
    Xp.LayoutHeader()
end

-- The title line's fonts. The bars' label size where ours is 0; the level
-- may have a font of its own. Each text is as tall as its font.
local function labelSize(fs)
    local own = S("labelFontSize")
    if own and own > 0 then return own end
    local _, size = fs:GetFont()
    return size or 12
end

function Xp.TitleSize()
    local bar = slot()
    if not bar then return 0 end
    local val = S("xpValueFontSize") > 0 and S("xpValueFontSize") or labelSize(bar.valueText)
    -- Numbers in or below the bar take no room in the title line.
    if S("xpValuePlace"):sub(1, 5) ~= "ABOVE" then val = 0 end
    -- As a badge the level is no text in the line: only the numbers count.
    if Xp.LevelMode() == "BADGE" then return val end
    if S("xpStyle") == "FOREVER" then return math.max(PLATE_H, val) end
    local lvl = S("xpLevelFontSize") > 0 and S("xpLevelFontSize") or labelSize(bar.nameText)
    return math.max(lvl, val)
end

function Xp.StyleTitle()
    local bar = slot()
    if not bar then return end
    local name, value = bar.nameText, bar.valueText
    local header = S("xpStyle") == "FOREVER"
    -- The font before any of ours, so leaving the header style restores it.
    bar.nameBase = bar.nameBase or { name:GetFont() }
    local path, base, flags = unpack(bar.nameBase)
    if S("xpLevelFont") ~= "" then path = ns.Media.FontPath(S("xpLevelFont"))
    elseif header then path = ns.Media.FontPath(HEADER_FONT) end
    local own = S("labelFontSize")
    local size = S("xpLevelFontSize") > 0 and S("xpLevelFontSize") or header and HEADER_SIZE
        or own and own > 0 and own or base or 12
    if path then pcall(name.SetFont, name, path, size, flags) end
    name:SetTextColor(unpack(header and HEADER_COLOR or ns.Bars.NAME_COLOR))
    name:SetHeight(size)
    local vpath, _, vflags = value:GetFont()
    local vsize = S("xpValueFontSize") > 0 and S("xpValueFontSize") or labelSize(value)
    if vpath then pcall(value.SetFont, value, vpath, vsize, vflags) end
    value:SetHeight(vsize)
    Xp.PlaceValue()
end

-- The numbers' place. In the bar they need a layer above the fill, so the
-- text moves onto one of its own once.
local SIDES = { LEFT = { "LEFT", 4 }, CENTER = { "", 0 }, RIGHT = { "RIGHT", -4 } }

-- The layer above the fill that carries the numbers and the extra lines.
function Xp.TextLayer()
    local bar = slot()
    if not bar then return end
    if not bar.valueLayer then
        bar.valueLayer = CreateFrame("Frame", nil, bar)
        bar.valueLayer:SetAllPoints(bar)
        bar.valueLayer:SetFrameLevel((bar.sb:GetFrameLevel() or 1) + 3)
        bar.valueText:SetParent(bar.valueLayer)
    end
    return bar.valueLayer
end

-- A text at one of VALUE_PLACES, moved by x/y.
function Xp.PlaceText(value, place, x, y)
    local bar = slot()
    if not bar then return end
    local where, side = place:match("^(%u+)_(%u+)$")
    local s = SIDES[side] or SIDES.RIGHT
    local gap = S("textGap")
    value:ClearAllPoints()
    if where == "IN" then
        local p = s[1] == "" and "CENTER" or s[1]
        value:SetPoint(p, bar.sb, p, s[2] + x, y)
    elseif where == "BELOW" then
        value:SetPoint("TOP" .. s[1], bar, "BOTTOM" .. s[1], x, -gap + y)
    else
        value:SetPoint("BOTTOM" .. s[1], bar, "TOP" .. s[1], x, gap + y)
    end
    value:SetJustifyH(side == "LEFT" and "LEFT" or side == "CENTER" and "CENTER" or "RIGHT")
end

function Xp.PlaceValue()
    local bar = slot()
    if not bar then return end
    Xp.TextLayer()
    Xp.PlaceText(bar.valueText, S("xpValuePlace"), S("xpValueX"), S("xpValueY"))
    if ns.XpInfo then ns.XpInfo.Apply() end
end

-- Values and visibility. A change in visibility lays the strip out again
-- (the row comes or goes).
function Xp.Update()
    local bar = slot()
    if not bar then return end
    local shown = S("xpEnabled") and Xp.Active() or false
    if shown then
        local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
        local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
        bar.sb:SetMinMaxValues(0, max)
        bar.sb:SetValue(cur)
        bar.rested:SetMinMaxValues(0, max)
        bar.rested:SetValue(math.min(max, cur + rested))
        bar.rested:SetShown(rested > 0)
        local title = S("xpTitle")
        -- The level as text, or none when the badge sits on the bar.
        local asText = title and Xp.LevelMode() ~= "BADGE"
        bar.nameText:SetText(asText and L.XP_LEVEL:format(UnitLevel("player") or 0) or "")
        bar.valueText:SetText(title and Xp.Text(S("xpTextMode"), cur, max) or "")
    end
    Xp.LayoutHeader()
    if (bar:IsShown() and true or false) ~= shown then
        bar:SetShown(shown)
        if ns.Bars.Relayout then ns.Bars.Relayout() end
    end
end

-- Colours, scripts, Blizzard's bars; then the values and the layout.
function Xp.Apply()
    local bar = slot()
    if not bar then return end
    if not bar.xpScripts then
        bar.xpScripts = true
        bar:SetScript("OnEnter", showTooltip)
        bar:SetScript("OnLeave", hideTooltip)
    end
    Xp.ApplyStyle()
    blizzardBars(not S("xpEnabled"))
    Xp.StyleTitle()
    Xp.Update()
    if ns.Bars.Relayout then ns.Bars.Relayout() end
end

Settings.OnChange(function(key)
    if key == nil or (type(key) == "string" and key:sub(1, 2) == "xp") then Xp.Apply() end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING",
    "PLAYER_ENTERING_WORLD", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
    pcall(events.RegisterEvent, events, e)
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
    -- At login after the strip is built (Bars.lua builds at PLAYER_LOGIN).
    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.After then C_Timer.After(0, Xp.Apply) else Xp.Apply() end
        return
    end
    Xp.Update()
end)
