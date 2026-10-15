local ADDON, ns = ...

-- Every user setting, its default and its range. The active profile
-- (Profiles.lua) stores only what differs from the default; Get falls back to
-- DEFAULTS. Set writes the profile and tells the listeners (the bars, the
-- minimap button, the options window).
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
    -- Position: the top edge's centre, relative to the top centre of the
    -- screen, and the strip's width. Dragging writes the same values.
    x = 0,
    y = -25,
    -- What x and y count from: x from the screen's CENTER (the strip's
    -- centre) or LEFT edge (the strip's left edge); y from the screen's TOP
    -- edge (the strip's top) or CENTER (the strip's centre).
    xFrom = "CENTER",
    yFrom = "TOP",
    width = 0,              -- 0: automatic, see Settings.AutoWidth
    locked = true,
    scale = 100,            -- percent, everything together

    -- Arrangement: ROW (professions in a row, reputation below), COLUMNS
    -- (professions left, reputation right, each stacked) or COLUMN (all
    -- stacked: professions, then reputation); stacked, bars are columnWidth
    -- wide.
    arrangement = "ROW",
    -- What shows at all: the progress bars as a whole (off: hidden, their
    -- menu too), the profession bars, the reputation bars.
    barsEnabled = true,
    showProfessions = true,
    showReputation = true,
    -- Hide while in combat / in a group: the strip (professions,
    -- reputation) and the XP bar each on its own.
    hideInCombat = false,
    hideInGroup = false,
    xpHideInCombat = false,
    xpHideInGroup = false,
    columnWidth = 240,

    -- Bars
    barHeight = 22,
    barStyle = "FOREVER",   -- the profession and reputation bars' look, see Styles.LIST
    -- Forever: the bars' rim (NONE, FLAT or GOLD, in screen pixels) and a
    -- gold marker where the fill ends.
    barBorder = "FLAT",
    barBorderSize = 1,
    barBorderColor = { 0, 0, 0, 0.9 },
    barMarker = false,
    standingY = 0,          -- the rank or standing in the bar, moved up or down
    textHeight = 11,
    textGap = 4,            -- between the text line and its bar
    spacing = 15,           -- between bars side by side (a row, two columns)
    rowGap = 4,             -- between bars one under the other
    segmentWidth = 21,
    barBgColor = { 0.192, 0.192, 0.192 },   -- the empty part of a bar
    barBgAlpha = 30,                -- percent
    labelFontSize = 12,     -- 0 = the font object's own size
    showIcons = true,
    showRank = true,        -- Apprentice, Journeyman, ... in the profession bars
    iconSize = 11,
    iconGap = 2,

    -- Backdrop behind everything
    backdropShow = false,
    backdropColor = { 0, 0, 0 },
    backdropAlpha = 100,            -- percent
    backdropPadding = 8,
    backdropBorderShow = false,     -- the border, with or without the background
    backdropBorder = "GOLD",        -- NONE, FLAT or GOLD
    backdropBorderSize = 1,         -- in screen pixels
    backdropBorderColor = { 0, 0, 0, 1 },

    -- Own experience bar (XpBar.lua): off by default. A row of its own in
    -- the reputation bars' style, on TOP, in the MIDDLE (between
    -- professions and reputation) or at the BOTTOM; with its title line
    -- ("Level 20" and the numbers) or without.
    xpEnabled = false,
    xpStyle = "FOREVER",    -- the look, see Styles.LIST
    xpBorder = "FLAT",      -- Forever: the rim, as the bars'
    xpBorderSize = 1,
    xpBorderColor = { 0, 0, 0, 0.9 },
    xpMarker = false,
    xpHeight = 0,           -- 0: the style's height (from the default bar height)
    -- The XP bar's own counterparts of the bars' settings: none of those
    -- touch it (Settings.MigrateXpOwn copies them over once).
    xpTextHeight = 11,      -- the title line's least height
    xpTextGap = 4,          -- between the texts and the bar
    xpSegmentWidth = 21,
    xpBgColor = { 0.192, 0.192, 0.192 },    -- the empty part (style Own)
    xpBgAlpha = 30,                         -- percent
    xpRow = "BOTTOM",       -- TOP, MIDDLE, BOTTOM or FREE
    -- FREE: X from the middle of the screen, Y from its top edge (0: at the
    -- top, negative: down) for the top of its title line; no room in the
    -- rows. Width: 0 is as wide as the strip.
    xpFreeX = 0,
    xpFreeY = -200,
    xpWidth = 0,
    xpTextMode = "CURRENT_MAX_PERCENT",     -- see XpBar.TEXT_MODES
    -- The title line: the level's font and size, the numbers' size ("" and
    -- 0: as on the other bars), and extra space to the bars beside the row.
    xpLevelMode = "TEXT",   -- TEXT ("Level 20"), BADGE (a badge of its own) or NONE
    -- The badge on the XP bar: its centre at a point of the bar plus X/Y,
    -- and a look of its own.
    xpBadgePoint = "LEFT",
    xpBadgeFollow = false,  -- rides on the end of the fill instead
    xpBadgeX = 0,
    xpBadgeY = 0,
    xpBadgeStyle = "MATCH", -- MATCH: the badge belonging to the bar's style
    xpBadgeFont = "Friz Quadrata",
    xpBadgeFontSize = 20,
    xpBadgeFontFlag = "OUTLINE",
    xpBadgePadX = 14,       -- room around the digits
    xpBadgePadY = 10,
    xpBadgeMinW = 62,
    xpBadgeColor = "GOLD",
    -- The level as text, in every style: font, size, colour ("", 0 and off:
    -- the style's), place (AUTO: the style's, else as the numbers) plus X/Y.
    xpLevelFont = "",
    xpLevelFontSize = 0,
    xpLevelColorOwn = false,
    xpLevelColor = { 1, 0.82, 0.29 },
    xpLevelPlace = "AUTO",
    xpLevelX = 0,
    xpLevelY = 0,
    xpHeaderPlate = false,  -- Forever style: the plate behind the level
    -- The numbers: font, size, colour ("", 0 and off: the style's).
    xpValueFont = "",
    xpValueFontSize = 0,
    xpValueColorOwn = false,
    xpValueColor = { 1, 1, 1 },
    -- The extra lines (XpInfo.lua): font, size, colour ("", 0, off: the numbers').
    xpInfoFont = "",
    xpInfoFontSize = 0,
    xpInfoColorOwn = false,
    xpInfoColor = { 1, 1, 1 },
    -- Where the numbers sit: ABOVE, IN or BELOW the bar, _LEFT, _CENTER or
    -- _RIGHT, plus X/Y.
    xpValuePlace = "ABOVE_RIGHT",
    xpValueX = 0,
    xpValueY = 0,
    xpGap = 0,
    -- Extra lines on the XP bar (XpInfo.lua), all off: shown, place (as the
    -- numbers), X/Y.
    xpInfoLevelTime = false, xpInfoLevelTimePlace = "ABOVE_LEFT", xpInfoLevelTimeX = 0, xpInfoLevelTimeY = 0,
    xpInfoSessionTime = false, xpInfoSessionTimePlace = "ABOVE_RIGHT", xpInfoSessionTimeX = 0, xpInfoSessionTimeY = 0,
    xpInfoPerHour = false, xpInfoPerHourPlace = "BELOW_CENTER", xpInfoPerHourX = 0, xpInfoPerHourY = 0,
    xpInfoToLevel = false, xpInfoToLevelPlace = "BELOW_LEFT", xpInfoToLevelX = 0, xpInfoToLevelY = 0,
    xpInfoQuests = false, xpInfoQuestsPlace = "BELOW_RIGHT", xpInfoQuestsX = 0, xpInfoQuestsY = 0,
    xpInfoRested = false, xpInfoRestedPlace = "IN_RIGHT", xpInfoRestedX = 0, xpInfoRestedY = 0,

    -- Minimap button
    minimapShow = true,
    minimapAngle = 338,
}

-- Slider ranges, used by the options window and to clamp typed values.
-- The XP bar's colours, one pair per style (XpBar ColourKey):
-- xpColor<STYLE>, xpRestedColor<STYLE>, taken while xpStyleColours<STYLE>
-- is on; off, the style's own colours (Own and Forever: these defaults).
-- On by default for Forever, which always took the colours.
Settings.XP_COLOURS = {
    FOREVER = { { 0.58, 0.0, 0.55 }, { 0.0, 0.39, 0.88 }, true },  -- Blizzard's classic purple and rested blue
    BLIZZARD = { { 0.58, 0.0, 0.55 }, { 0.0, 0.39, 0.88 } },
    RUNE = { { 0.58, 0.40, 1.0 }, { 0.35, 0.30, 0.75 } },
    GEMS = { { 0.69, 0.42, 0.94 }, { 0.24, 0.38, 0.66 } },
    THIN = { { 0.71, 0.58, 0.88 }, { 0.56, 0.69, 0.93 } },
    EMBER = { { 1.0, 0.45, 0.12 }, { 0.50, 0.13, 0.05 } },
}
for style, pair in pairs(Settings.XP_COLOURS) do
    Settings.DEFAULTS["xpColor" .. style] = pair[1]
    Settings.DEFAULTS["xpRestedColor" .. style] = pair[2]
    Settings.DEFAULTS["xpStyleColours" .. style] = pair[3] == true
end

Settings.RANGES = {
    barHeight = { 4, 40 },
    textHeight = { 8, 30 },
    textGap = { -10, 20 },
    spacing = { 0, 60 },
    segmentWidth = { 4, 60 },
    barBgAlpha = { 0, 100 },
    labelFontSize = { 0, 30 },
    iconSize = { 6, 40 },
    iconGap = { 0, 20 },
    xpBadgePadX = { 0, 40 },
    xpBadgePadY = { 0, 30 },
    xpBadgeMinW = { 20, 160 },
    rowGap = { 0, 40 },
    width = { 200, 4000 },
    scale = { 50, 200 },
    xpLevelFontSize = { 0, 60 },
    xpValueFontSize = { 0, 40 },
    xpInfoFontSize = { 0, 40 },
    xpGap = { -20, 80 },
    xpValueX = { -500, 500 },
    xpValueY = { -100, 100 },
    xpLevelX = { -500, 500 },
    xpLevelY = { -100, 100 },
    xpHeight = { 0, 400 },
    xpBorderSize = { 1, 8 },
    barBorderSize = { 1, 8 },
    standingY = { -40, 40 },
    xpTextHeight = { 8, 30 },
    xpTextGap = { -10, 20 },
    xpSegmentWidth = { 4, 60 },
    xpBgAlpha = { 0, 100 },
    xpInfoLevelTimeX = { -500, 500 }, xpInfoLevelTimeY = { -100, 100 },
    xpInfoSessionTimeX = { -500, 500 }, xpInfoSessionTimeY = { -100, 100 },
    xpInfoPerHourX = { -500, 500 }, xpInfoPerHourY = { -100, 100 },
    xpInfoToLevelX = { -500, 500 }, xpInfoToLevelY = { -100, 100 },
    xpInfoQuestsX = { -500, 500 }, xpInfoQuestsY = { -100, 100 },
    xpInfoRestedX = { -500, 500 }, xpInfoRestedY = { -100, 100 },
    xpFreeX = { -2000, 2000 },
    xpFreeY = { -3000, 200 },
    xpWidth = { 0, 4000 },
    xpBadgeX = { -600, 600 },
    xpBadgeY = { -200, 200 },
    xpBadgeFontSize = { 8, 80 },
    columnWidth = { 80, 800 },
    backdropAlpha = { 0, 100 },
    backdropPadding = { 0, 40 },
    backdropBorderSize = { 1, 8 },
}

-- The width when none is set: 60 % of the screen, at most 1180. Screens
-- and UI scales differ a lot: 1180 is about half of a wide screen at a
-- small UI scale, but nearly all of a 1920 x 1080 one at scale 1.
Settings.AUTO_WIDTH_SHARE = 0.6
Settings.AUTO_WIDTH_MAX = 1180

function Settings.AutoWidth(screenWidth)
    if not screenWidth or screenWidth <= 0 then return Settings.AUTO_WIDTH_MAX end
    return math.min(Settings.AUTO_WIDTH_MAX, math.floor(screenWidth * Settings.AUTO_WIDTH_SHARE))
end

-- The width in use: the setting, or the automatic one.
function Settings.Width(screenWidth)
    local w = Settings.Get("width")
    if not w or w <= 0 then return Settings.AutoWidth(screenWidth) end
    return w
end

-- Reputation bars by default: the player faction's four capital cities.
Settings.DEFAULT_REPS = {
    Alliance = { 69, 54, 47, 72 },   -- Darnassus, Gnomeregan, Ironforge, Stormwind
    Horde = { 76, 530, 81, 68 },     -- Orgrimmar, Darkspear Trolls, Thunder Bluff, Undercity
}

-- Skills hidden unless the player shows them, by profession key.
Settings.DEFAULT_HIDDEN = { FISHING = true, RIDING = true }

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed (profile switch, reset).
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

-- A preset is read-only: changes last until the next reload. Said once.
local presetHintShown = false
local function presetHint()
    if presetHintShown or not ns.IsPreset or not ns.IsPreset(ns.ActiveProfile()) then return end
    presetHintShown = true
    if ns.Print then ns.Print(ns.L.MSG_PRESET_READONLY) end
end

function Settings.Set(key, value)
    presetHint()
    local range = Settings.RANGES[key]
    if range and type(value) == "number" then
        value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
    end
    if value == Settings.DEFAULTS[key] then value = nil end
    ns.DB()[key] = value
    Settings.Changed(key)
end

-- The four reputation slots (faction IDs, 0 = empty).
function Settings.Reps()
    local reps = ns.DB().reps
    if type(reps) == "table" then return reps end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return Settings.DEFAULT_REPS[faction] or { 0, 0, 0, 0 }
end

function Settings.SetRep(slot, factionID)
    local reps = {}
    for i, v in ipairs(Settings.Reps()) do reps[i] = v end
    for i = 1, 4 do reps[i] = reps[i] or 0 end
    reps[slot] = factionID or 0
    ns.DB().reps = reps
    Settings.Changed("reps")
end

-- Is a skill hidden? The player's choice by skill name, else the default by
-- profession key.
function Settings.IsHidden(name, key)
    local hidden = ns.DB().hidden
    if type(hidden) == "table" and hidden[name] ~= nil then return hidden[name] end
    return Settings.DEFAULT_HIDDEN[key or ""] or false
end

function Settings.SetHidden(name, value)
    ns.DB().hidden = ns.DB().hidden or {}
    ns.DB().hidden[name] = value and true or false
    Settings.Changed("hidden")
end

-- Back to the defaults, keeping the language (it is not in the profile).
-- Up to 1.6 the XP bar took the bars' text line, segments, background,
-- label size and height, and the strip's border came with its background.
-- Now each has its own; once per account every profile gets them from what
-- it had, so nothing moves.
local XP_OWN = { textHeight = "xpTextHeight", textGap = "xpTextGap", segmentWidth = "xpSegmentWidth",
    barBgColor = "xpBgColor", barBgAlpha = "xpBgAlpha" }
-- A second pass (its own flag: the first may have run already): the XP
-- badge's padding was the strip's level badge's.
local BADGE_OWN = { levelBoxPadX = "xpBadgePadX", levelBoxPadY = "xpBadgePadY", levelBoxMinW = "xpBadgeMinW" }
-- The strip's own level badge is gone (the XP bar shows the level): its
-- settings leave the profiles.
local LEVEL_GONE = { "levelShow", "levelPlace", "levelY", "levelOffsetX", "levelOffsetY", "levelGap",
    "levelFont", "levelFontSize", "levelFontFlag", "levelStyle", "levelColor",
    "levelBoxPadX", "levelBoxPadY", "levelBoxMinW" }
-- Styles whose height is the bar height itself.
local PLAIN_STYLES = { OWN = true, FOREVER = true, BLIZZARD = true }

function Settings.MigrateXpOwn()
    local account = ns.AccountDB()
    if account.xpOwnSettings then return end
    account.xpOwnSettings = true
    for name, p in pairs(account.profiles or {}) do
        if type(p) == "table" and name:sub(1, 1) ~= "@" then
            -- The border had no switch of its own: it came with the background.
            if p.backdropShow == true and p.backdropBorderShow == nil then p.backdropBorderShow = true end
            for from, to in pairs(XP_OWN) do
                if p[from] ~= nil and p[to] == nil then
                    local v = p[from]
                    p[to] = type(v) == "table" and { unpack(v) } or v
                end
            end
            local plain = PLAIN_STYLES[p.xpStyle or "OWN"]
            if p.barHeight ~= nil and p.xpHeight == nil and plain then p.xpHeight = p.barHeight end
            local label = p.labelFontSize
            if type(label) == "number" and label > 0 then
                if p.xpValueFontSize == nil then p.xpValueFontSize = label end
                if p.xpLevelFontSize == nil and (p.xpStyle == nil or p.xpStyle == "OWN" or p.xpStyle == "BLIZZARD") then
                    p.xpLevelFontSize = label
                end
            end
        end
    end
end

-- Up to now one colour pair served every XP style: it stays with the two
-- that used it (Own, Forever), once per account.
function Settings.MigrateXpColours()
    local account = ns.AccountDB()
    if account.xpColoursPerStyle then return end
    account.xpColoursPerStyle = true
    for name, p in pairs(account.profiles or {}) do
        if type(p) == "table" and name:sub(1, 1) ~= "@" then
            for _, base in ipairs({ "xpColor", "xpRestedColor" }) do
                local v = p[base]
                if type(v) == "table" then
                    for _, style in ipairs({ "OWN", "FOREVER" }) do
                        if p[base .. style] == nil then p[base .. style] = { unpack(v) } end
                    end
                end
                p[base] = nil
            end
            if p.xpStyleColours ~= nil then
                for _, style in ipairs({ "RUNE", "EMBER" }) do
                    if p["xpStyleColours" .. style] == nil then p["xpStyleColours" .. style] = p.xpStyleColours end
                end
                p.xpStyleColours = nil
            end
        end
    end
end

-- "Own" was Forever with a thin black rim and no extras: it leaves, Forever
-- takes its place with the rim set (defaults: Own's look). A profile on the
-- old Forever gets its look written out: gold rim, dark ground, marker,
-- plate, the level as a gold header in the middle. Once per account.
local FOREVER_LOOK = {
    border = "GOLD", borderSize = 2, bg = { 0.047, 0.047, 0.055 }, bgAlpha = 82, marker = true,
}
local function setIfNil(p, k, v) if p[k] == nil then p[k] = v end end

function Settings.MigrateOwnMerged()
    local account = ns.AccountDB()
    if account.ownMerged then return end
    account.ownMerged = true
    for name, p in pairs(account.profiles or {}) do
        if type(p) == "table" and name:sub(1, 1) ~= "@" then
            -- The XP bar.
            if p.xpStyle == "FOREVER" then
                setIfNil(p, "xpBorder", FOREVER_LOOK.border)
                setIfNil(p, "xpBorderSize", FOREVER_LOOK.borderSize)
                setIfNil(p, "xpBgColor", { unpack(FOREVER_LOOK.bg) })
                setIfNil(p, "xpBgAlpha", FOREVER_LOOK.bgAlpha)
                setIfNil(p, "xpMarker", FOREVER_LOOK.marker)
                setIfNil(p, "xpHeaderPlate", true)
                if p.xpLevelPlace == nil or p.xpLevelPlace == "AUTO" then p.xpLevelPlace = "ABOVE_CENTER" end
                if (p.xpLevelFontSize or 0) == 0 then p.xpLevelFontSize = 18 end
                setIfNil(p, "xpLevelFont", "Friz Quadrata")
                if p.xpLevelFont == "" then p.xpLevelFont = "Friz Quadrata" end
                if not p.xpLevelColorOwn then
                    p.xpLevelColorOwn = true
                    setIfNil(p, "xpLevelColor", { 1, 0.82, 0.29 })
                end
            elseif p.xpStyle == "OWN" or p.xpStyle == nil then
                p.xpStyle = nil
                -- Its colours are now Forever's.
                for _, base in ipairs({ "xpColor", "xpRestedColor", "xpStyleColours" }) do
                    if p[base .. "OWN"] ~= nil then p[base .. "FOREVER"] = p[base .. "OWN"] end
                end
            end
            for _, base in ipairs({ "xpColor", "xpRestedColor", "xpStyleColours" }) do p[base .. "OWN"] = nil end
            -- The profession and reputation bars.
            if p.barStyle == "FOREVER" then
                setIfNil(p, "barBorder", FOREVER_LOOK.border)
                setIfNil(p, "barBorderSize", FOREVER_LOOK.borderSize)
                setIfNil(p, "barBgColor", { unpack(FOREVER_LOOK.bg) })
                setIfNil(p, "barBgAlpha", FOREVER_LOOK.bgAlpha)
                setIfNil(p, "barMarker", FOREVER_LOOK.marker)
            elseif p.barStyle == "OWN" then
                p.barStyle = nil
            end
        end
    end
end

-- The title line's switch left: the level and the numbers each show or
-- hide on their own. A profile with it off hides both. Once per account.
function Settings.MigrateTitleGone()
    local account = ns.AccountDB()
    if account.titleGone then return end
    account.titleGone = true
    for name, p in pairs(account.profiles or {}) do
        if type(p) == "table" and name:sub(1, 1) ~= "@" then
            if p.xpTitle == false then
                p.xpLevelMode = "NONE"
                p.xpTextMode = "NONE"
            end
            p.xpTitle = nil
        end
    end
end

function Settings.MigrateLevelGone()
    local account = ns.AccountDB()
    if account.levelGone then return end
    account.levelGone = true
    for name, p in pairs(account.profiles or {}) do
        if type(p) == "table" and name:sub(1, 1) ~= "@" then
            for from, to in pairs(BADGE_OWN) do
                if p[from] ~= nil and p[to] == nil then p[to] = p[from] end
            end
            for _, k in ipairs(LEVEL_GONE) do p[k] = nil end
        end
    end
end

-- Presets: ready-made looks, offered as read-only profiles (Profiles.lua):
-- the values here, everything else at its default.
Settings.PRESETS = {
    -- The look before the arrangements came: one row, no XP bar. That is
    -- the defaults.
    { id = "CLASSIC", values = {} },
    -- One column on the left, the XP bar free and wide above it with its
    -- badge. Positions in the new reckoning: the strip from the left edge,
    -- free places from the top edge.
    { id = "COLUMN_XP", values = {
        arrangement = "COLUMN", columnWidth = 191, width = 889,
        xFrom = "LEFT", x = 10, y = -10,
        xpBadgePadX = 4, xpBadgePadY = 8, xpBadgeMinW = 44,
        xpEnabled = true, xpRow = "FREE", xpFreeY = 2, xpWidth = 1161, xpGap = 14,
        xpValuePlace = "IN_CENTER",
        xpLevelMode = "BADGE", xpBadgeY = -1, xpBadgeFontSize = 22, xpBadgeFollow = true,
    } },
}


function Settings.ResetProfile()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end
