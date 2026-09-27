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
    y = -28,
    width = 1180,
    locked = true,

    -- Bars
    barHeight = 22,
    textHeight = 11,
    textGap = 4,            -- between the text line and its bar
    spacing = 15,
    segmentWidth = 21,
    barBgColor = { 0.192, 0.192, 0.192 },   -- the empty part of a bar
    barBgAlpha = 97,                -- percent
    labelFontSize = 12,     -- 0 = the font object's own size
    showIcons = true,
    iconSize = 11,
    iconGap = 2,

    -- Level number
    levelY = -25,
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
    backdropShow = true,
    backdropColor = { 0, 0, 0 },
    backdropAlpha = 100,            -- percent
    backdropPadding = 8,
    backdropBorder = "GOLD",        -- NONE, FLAT or GOLD
    backdropBorderSize = 1,         -- in screen pixels
    backdropBorderColor = { 0, 0, 0, 1 },

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
    backdropAlpha = { 0, 100 },
    backdropPadding = { 0, 40 },
    backdropBorderSize = { 1, 8 },
}

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

function Settings.Set(key, value)
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
function Settings.ResetProfile()
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    Settings.Changed(nil)
end
