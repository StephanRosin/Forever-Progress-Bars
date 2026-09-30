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
    if S("xpLevelMode") == "BADGE" then return val end
    local lvl = S("xpLevelFontSize") > 0 and S("xpLevelFontSize") or labelSize(bar.nameText)
    return math.max(lvl, val)
end

function Xp.StyleTitle()
    local bar = slot()
    if not bar then return end
    local name, value = bar.nameText, bar.valueText
    local path, _, flags = name:GetFont()
    if S("xpLevelFont") ~= "" then path = ns.Media.FontPath(S("xpLevelFont")) end
    local size = S("xpLevelFontSize") > 0 and S("xpLevelFontSize") or labelSize(name)
    if path then pcall(name.SetFont, name, path, size, flags) end
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
function Xp.PlaceValue()
    local bar = slot()
    if not bar then return end
    local value = bar.valueText
    if not bar.valueLayer then
        bar.valueLayer = CreateFrame("Frame", nil, bar)
        bar.valueLayer:SetAllPoints(bar)
        bar.valueLayer:SetFrameLevel((bar.sb:GetFrameLevel() or 1) + 3)
        value:SetParent(bar.valueLayer)
    end
    local where, side = S("xpValuePlace"):match("^(%u+)_(%u+)$")
    local s = SIDES[side] or SIDES.RIGHT
    local gap = S("textGap")
    local x, y = S("xpValueX"), S("xpValueY")
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
        local asText = title and S("xpLevelMode") ~= "BADGE"
        bar.nameText:SetText(asText and L.XP_LEVEL:format(UnitLevel("player") or 0) or "")
        bar.valueText:SetText(title and Xp.Text(S("xpTextMode"), cur, max) or "")
    end
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
    bar.sb:SetStatusBarColor(unpack(S("xpColor")))
    local c = S("xpRestedColor")
    bar.rested:SetStatusBarColor(c[1], c[2], c[3], 0.6)
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
