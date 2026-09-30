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
    -- stacked: professions, then reputation). In the stacked ones the
    -- level sits on TOP, in the MIDDLE or at the BOTTOM; bars are
    -- columnWidth wide. levelPlace FREE places it freely everywhere.
    arrangement = "ROW",
    -- What shows at all: the profession bars, the reputation bars.
    showProfessions = true,
    showReputation = true,
    -- Hide while in combat / in a group: the strip (professions,
    -- reputation, level) and the XP bar each on its own.
    hideInCombat = false,
    hideInGroup = false,
    xpHideInCombat = false,
    xpHideInGroup = false,
    levelPlace = "TOP",
    columnWidth = 240,

    -- Bars
    barHeight = 22,
    textHeight = 11,
    textGap = 4,            -- between the text line and its bar
    spacing = 15,
    segmentWidth = 21,
    barBgColor = { 0.192, 0.192, 0.192 },   -- the empty part of a bar
    barBgAlpha = 30,                -- percent
    labelFontSize = 12,     -- 0 = the font object's own size
    showIcons = true,
    showRank = true,        -- Apprentice, Journeyman, ... in the profession bars
    iconSize = 11,
    iconGap = 2,

    -- Level number
    levelShow = true,
    levelY = -25,           -- the row's own place for it (kept for old profiles)
    -- Moves the level (and the XP bar hanging from it) in every arrangement.
    -- With levelPlace FREE (in every arrangement) these are its coordinates,
    -- as the strip's own: X from the middle of the screen, Y from its top
    -- edge (0: at the top, negative: down), for the badge's top edge; it
    -- takes no room in the rows then.
    levelOffsetX = 0,
    levelOffsetY = 0,
    levelGap = 87,          -- the least room kept free for the level box
    levelFont = "Friz Quadrata",
    levelFontSize = 28,
    levelFontFlag = "OUTLINE",
    levelStyle = "CREST",   -- see Bars.LEVEL_STYLES
    levelColor = "GOLD",      -- GOLD, WHITE or CLASS
    levelBoxPadX = 14,
    levelBoxPadY = 10,
    levelBoxMinW = 62,

    -- Backdrop behind everything
    backdropShow = false,
    backdropColor = { 0, 0, 0 },
    backdropAlpha = 100,            -- percent
    backdropPadding = 8,
    backdropBorder = "GOLD",        -- NONE, FLAT or GOLD
    backdropBorderSize = 1,         -- in screen pixels
    backdropBorderColor = { 0, 0, 0, 1 },

    -- Own experience bar (XpBar.lua): off by default. A row of its own in
    -- the reputation bars' style, on TOP, in the MIDDLE (between
    -- professions and reputation) or at the BOTTOM; with its title line
    -- ("Level 20" and the numbers) or without.
    xpEnabled = false,
    xpRow = "BOTTOM",       -- TOP, MIDDLE, BOTTOM or FREE
    -- FREE: X from the middle of the screen, Y from its top edge (0: at the
    -- top, negative: down) for the top of its title line; no room in the
    -- rows. Width: 0 is as wide as the strip.
    xpFreeX = 0,
    xpFreeY = -200,
    xpWidth = 0,
    xpTitle = true,
    xpColor = { 0.58, 0.0, 0.55 },          -- Blizzard's classic purple
    xpRestedColor = { 0.0, 0.39, 0.88 },    -- and its rested blue
    xpTextMode = "CURRENT_MAX_PERCENT",     -- see XpBar.TEXT_MODES
    -- The title line: the level's font and size, the numbers' size ("" and
    -- 0: as on the other bars), and extra space to the bars beside the row.
    xpLevelMode = "TEXT",   -- TEXT ("Level 20") or BADGE (a badge of its own)
    -- The badge on the XP bar: its centre at a point of the bar plus X/Y,
    -- and a look of its own.
    xpBadgePoint = "LEFT",
    xpBadgeFollow = false,  -- rides on the end of the fill instead
    xpBadgeX = 0,
    xpBadgeY = 0,
    xpBadgeStyle = "CREST",
    xpBadgeFont = "Friz Quadrata",
    xpBadgeFontSize = 20,
    xpBadgeFontFlag = "OUTLINE",
    xpBadgeColor = "GOLD",
    xpLevelFont = "",
    xpLevelFontSize = 0,
    xpValueFontSize = 0,
    -- Where the numbers sit: ABOVE, IN or BELOW the bar, _LEFT, _CENTER or
    -- _RIGHT, plus X/Y.
    xpValuePlace = "ABOVE_RIGHT",
    xpValueX = 0,
    xpValueY = 0,
    xpGap = 0,

    -- Minimap button
    minimapShow = true,
    minimapAngle = 338,
}

-- Slider ranges, used by the options window and to clamp typed values.
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
    levelY = { -80, 80 },
    levelGap = { 0, 300 },
    levelFontSize = { 10, 80 },
    levelBoxPadX = { 0, 40 },
    levelBoxPadY = { 0, 30 },
    levelBoxMinW = { 20, 160 },
    width = { 200, 4000 },
    scale = { 50, 200 },
    xpLevelFontSize = { 0, 60 },
    xpValueFontSize = { 0, 40 },
    xpGap = { -20, 80 },
    xpValueX = { -500, 500 },
    xpValueY = { -100, 100 },
    xpFreeX = { -2000, 2000 },
    xpFreeY = { -3000, 200 },
    xpWidth = { 0, 4000 },
    xpBadgeX = { -600, 600 },
    xpBadgeY = { -200, 200 },
    xpBadgeFontSize = { 8, 80 },
    levelOffsetX = { -2000, 2000 },
    levelOffsetY = { -3000, 1200 },
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
-- Presets: ready-made looks, offered as read-only profiles (Profiles.lua):
-- the values here, everything else at its default.
Settings.PRESETS = {
    -- The look before the arrangements came: one row, level in the middle,
    -- no XP bar. That is the defaults.
    { id = "CLASSIC", values = {} },
    -- One column on the left, the XP bar free and wide above it with its
    -- badge, the row's level switched off. Positions in the new reckoning:
    -- the strip from the left edge, free places from the top edge.
    { id = "COLUMN_XP", values = {
        arrangement = "COLUMN", columnWidth = 191, width = 889,
        xFrom = "LEFT", x = 10, y = -10,
        levelShow = false, levelPlace = "FREE", levelOffsetY = -21, levelY = -33, levelGap = 93,
        levelStyle = "WINGS", levelFontSize = 27,
        levelBoxPadX = 4, levelBoxPadY = 8, levelBoxMinW = 44,
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
