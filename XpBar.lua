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
-- The looks (Styles.lua).
Xp.STYLES = ns.Styles.LIST
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

-- The chosen style (Styles.lua).
function Xp.Def() return ns.Styles.Get(S("xpStyle")) end

-- The bar's height: its own, or (0) the style's from the bars' height.
function Xp.Height()
    local own = S("xpHeight")
    if own and own > 0 then return own end
    return Xp.Def().height(S("barHeight"))
end

-- Its width: its own, or (0) the strip's; a round style as wide as high.
function Xp.Width(stripWidth)
    local own = S("xpWidth")
    if own and own > 0 then return own end
    if Xp.Def().square then return Xp.Height() end
    return stripWidth
end

function Xp.Dividers() return Xp.Def().dividers or "OWN" end

-- Some styles always show the level as text (the ring's middle), never as
-- the badge.
function Xp.LevelMode() return Xp.Def().levelText and "TEXT" or S("xpLevelMode") end

-- The badge style "matching the bar" (Bars.lua, MATCH).
function Xp.MatchBadge() return Xp.Def().badge or "CREST" end

-- Where the level sits: its own place, or (AUTO) the style's.
function Xp.LevelPlace()
    local own = S("xpLevelPlace")
    if own and own ~= "AUTO" then return own end
    return Xp.Def().level.place or "ABOVE_LEFT"
end

-- Forever's plate under the level: the quest log's title bar (Tracker.lua):
-- dark, rounded top corners, a gold shine rising to the top, a faint gold
-- line along the bottom.
local PLATE_H, PLATE_PAD, PLATE_RADIUS = 32, 14, 10
local PLATE_MASK = "Interface\\AddOns\\ForeverProgressBars\\Media\\Rounded10.tga"

local function plate(bar)
    if bar.plate then return bar.plate end
    local p = CreateFrame("Frame", nil, bar)
    p:SetHeight(PLATE_H)
    p:SetFrameLevel((bar.sb:GetFrameLevel() or 1) + 3)
    p.bg = p:CreateTexture(nil, "BACKGROUND")
    p.bg:SetAllPoints(p)
    p.bg:SetColorTexture(0, 0, 0, 1)   -- opaque: what lies behind would show through the title
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

local function plateShown()
    return S("xpStyle") == "FOREVER" and S("xpTitle") and S("xpHeaderPlate") and Xp.LevelMode() ~= "BADGE"
end

-- Look of the bar for the chosen style; Bars.lua calls it after it painted
-- the empty part and the rim, and Apply after a change of style.
function Xp.ApplyStyle()
    local bar = slot()
    if not bar then return end
    local def = Xp.Def()
    local colours = def.ownColours and { fill = S("xpColor"), rested = S("xpRestedColor") } or nil
    ns.Styles.Apply(bar, S("xpStyle"), Xp.Height(), colours)
    Xp.PlaceLevel()
end

-- The title line's fonts. The bars' label size where ours is 0; the level
-- may have a font of its own. Each text is as tall as its font.
local function labelSize(fs)
    local own = S("labelFontSize")
    if own and own > 0 then return own end
    local _, size = fs:GetFont()
    return size or 12
end

-- The level's size: its own, the style's, or the bars' label size.
local function levelSize(bar)
    if S("xpLevelFontSize") > 0 then return S("xpLevelFontSize") end
    local style = Xp.Def().level.size
    if style then return style(S("barHeight"), Xp.Height()) end
    local own = S("labelFontSize")
    if own and own > 0 then return own end
    return (bar.nameBase and bar.nameBase[2]) or 12
end

function Xp.TitleSize()
    local bar = slot()
    if not bar then return 0 end
    local val = S("xpValueFontSize") > 0 and S("xpValueFontSize") or labelSize(bar.valueText)
    -- Only texts above the bar take room in the title line.
    if S("xpValuePlace"):sub(1, 5) ~= "ABOVE" then val = 0 end
    if Xp.LevelMode() == "BADGE" or Xp.LevelPlace():sub(1, 5) ~= "ABOVE" then return val end
    local lvl = plateShown() and PLATE_H or levelSize(bar)
    return math.max(lvl, val)
end

-- A text's colour: its own when switched on, else the style's, else the bars'.
local function textColour(ownKey, colourKey, style, fallback)
    if S(ownKey) then return S(colourKey) end
    return style or fallback
end

function Xp.StyleTitle()
    local bar = slot()
    if not bar then return end
    local name, value, def = bar.nameText, bar.valueText, Xp.Def()
    -- The fonts before any of ours, so leaving a style restores them.
    bar.nameBase = bar.nameBase or { name:GetFont() }
    bar.valueBase = bar.valueBase or { value:GetFont() }
    local path, _, flags = unpack(bar.nameBase)
    if S("xpLevelFont") ~= "" then path = ns.Media.FontPath(S("xpLevelFont"))
    elseif def.level.font then path = ns.Media.FontPath(def.level.font) end
    local size = levelSize(bar)
    if path then pcall(name.SetFont, name, path, size, flags) end
    local c = textColour("xpLevelColorOwn", "xpLevelColor", def.level.color, ns.Bars.NAME_COLOR)
    name:SetTextColor(c[1], c[2], c[3])
    name:SetHeight(size)
    local vpath, _, vflags = unpack(bar.valueBase)
    if S("xpValueFont") ~= "" then vpath = ns.Media.FontPath(S("xpValueFont"))
    elseif def.value.font then vpath = ns.Media.FontPath(def.value.font) end
    local vsize = S("xpValueFontSize") > 0 and S("xpValueFontSize") or labelSize(value)
    if vpath then pcall(value.SetFont, value, vpath, vsize, vflags) end
    local vc = textColour("xpValueColorOwn", "xpValueColor", def.value.color, ns.Bars.VALUE_COLOR)
    value:SetTextColor(vc[1], vc[2], vc[3])
    value:SetHeight(vsize)
    Xp.PlaceValue()
    Xp.PlaceLevel()
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
    if value.SetJustifyH then
        value:SetJustifyH(side == "LEFT" and "LEFT" or side == "CENTER" and "CENTER" or "RIGHT")
    end
end

function Xp.PlaceValue()
    local bar = slot()
    if not bar then return end
    Xp.TextLayer()
    Xp.PlaceText(bar.valueText, S("xpValuePlace"), S("xpValueX"), S("xpValueY"))
    if ns.XpInfo then ns.XpInfo.Apply() end
end

-- The level at its place, above the fill. In Forever it sits on its plate,
-- the plate where the level would be (above the bar: right on its edge).
function Xp.PlaceLevel()
    local bar = slot()
    if not bar then return end
    local name, layer = bar.nameText, Xp.TextLayer()
    local place, x, y = Xp.LevelPlace(), S("xpLevelX"), S("xpLevelY")
    if not plateShown() then
        if bar.plate then bar.plate:Hide() end
        if name:GetParent() ~= layer then name:SetParent(layer) end
        name:SetWidth(0)
        Xp.PlaceText(name, place, x, y)
        return
    end
    local p = plate(bar)
    if place:sub(1, 5) == "ABOVE" then y = y - S("textGap") end
    Xp.PlaceText(p, place, x, y)
    p:SetWidth(math.floor(name:GetStringWidth() + 2 * PLATE_PAD + 0.5))
    name:SetParent(p)
    name:SetJustifyH("CENTER")
    name:ClearAllPoints()
    name:SetPoint("LEFT", p, "LEFT", PLATE_PAD, 0)
    name:SetPoint("RIGHT", p, "RIGHT", -PLATE_PAD, 0)
    p:Show()
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
        local format = Xp.Def().level.format or L.XP_LEVEL
        bar.nameText:SetText(asText and format:format(UnitLevel("player") or 0) or "")
        bar.valueText:SetText(title and Xp.Text(S("xpTextMode"), cur, max) or "")
        ns.Styles.Update(bar, cur, max, rested)
    end
    Xp.PlaceLevel()
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
