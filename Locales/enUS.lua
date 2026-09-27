local _, ns = ...

-- English is the base language and always loads first. Every other language
-- (Locales/<code>.lua) fills a table of its own; Locale.lua picks one. ns.L
-- holds no strings itself: it looks a key up in the chosen language, then in
-- English, and a key missing from both comes back as it is, so a missing
-- string shows in the game instead of raising an error.
local L = {}
ns.Locales = { enUS = L }

local active = L
ns.L = setmetatable({}, {
    __index = function(_, key)
        local v = active[key]
        if v == nil then v = L[key] end
        if v == nil then return key end
        return v
    end,
    __newindex = function() error("ns.L is read-only; add strings to Locales/*.lua") end,
})

-- Locale.lua only: shows the given language's table through ns.L.
function ns.SetActiveLocale(code)
    active = ns.Locales[code] or L
end

L.ADDON_NAME = "Forever Progress Bars"

-- Chat
L.MSG_LOCKED = "Bars locked: click-through, not draggable."
L.MSG_UNLOCKED = "Bars unlocked: drag them to move."
L.MSG_USAGE = "/fpb (options), /fpb lock, /fpb unlock, /fpb status"
L.MSG_NO_SKILL_API = "This client has no skill list: the profession bars stay empty."
L.MSG_LAST_PROFILE = "The last profile cannot be deleted."

-- Tooltips
L.TIP_RANK = "Rank"
L.TIP_TO_CAP = "To the next cap"
L.TIP_BONUS = "Bonus"
L.TIP_CLICK_OPEN = "Click to open or close the profession"
L.TIP_REP_LEFT = "Left-click: choose a faction"
L.TIP_REP_RIGHT = "Right-click: reputation tab"
L.REP_EMPTY = "(empty)"

-- Minimap button
L.MINIMAP_LEFT_CLICK = "Left-click: options"
L.MINIMAP_RIGHT_CLICK = "Right-click: lock or unlock the bars"
L.MINIMAP_DRAG = "Drag: move this button"
L.OPEN_OPTIONS = "Open the options"

-- Options window
L.OPT_HINT = "Drag for rough values, type for exact ones (confirm with Enter)."
L.OPT_LANGUAGE = "Language"
L.LANGUAGE_AUTO = "Game language"
L.PAGE_GENERAL = "General"
L.PAGE_BARS = "Bars"
L.PAGE_PROFESSIONS = "Professions"
L.PAGE_REPUTATION = "Reputation"
L.PAGE_LEVEL = "Level"
L.PAGE_PROFILES = "Profiles"

L.OPT_POSITION = "Position"
L.OPT_X = "Horizontal (from the centre)"
L.OPT_Y = "Vertical (from the top)"
L.OPT_WIDTH = "Width"
L.OPT_LOCK = "Lock (click-through, not draggable)"
L.OPT_MINIMAP = "Minimap button"
L.OPT_MINIMAP_SHOW = "Show the minimap button"

L.OPT_BARS = "Bars"
L.OPT_BAR_HEIGHT = "Bar height"
L.OPT_TEXT_HEIGHT = "Text height"
L.OPT_SPACING = "Space between bars"
L.OPT_SEGMENT_WIDTH = "Segment width"
L.OPT_LABEL_FONT_SIZE = "Label font size (0 = default)"
L.OPT_ICONS = "Profession icons"
L.OPT_SHOW_ICONS = "Show icons"
L.OPT_ICON_SIZE = "Icon size"
L.OPT_ICON_GAP = "Space between icon and name"

L.OPT_PROFESSIONS = "Professions and skills"
L.OPT_PROFESSIONS_HINT = "Two primary professions and two secondary skills are shown. Untick a skill to hide it."
L.OPT_NO_SKILLS = "No skills found yet."

L.OPT_REPUTATION = "Reputation bars"
L.OPT_REP_HINT = "You can also left-click a reputation bar to pick its faction."
L.OPT_REP_SLOT = "Bar %d"
L.OPT_REP_RELOAD = "Reload the faction list"

L.OPT_LEVEL = "Level number"
L.OPT_FONT = "Font"
L.OPT_FONT_SIZE = "Font size"
L.OPT_OUTLINE = "Outline"
L.OUTLINE_NONE = "None"
L.OUTLINE_NORMAL = "Outline"
L.OUTLINE_THICK = "Thick outline"
L.OPT_LEVEL_Y = "Move vertically"
L.OPT_LEVEL_GAP = "Least room for the level"
L.OPT_LEVEL_COLOR = "Number colour"
L.COLOR_GOLD = "Gold"
L.COLOR_WHITE = "White"
L.COLOR_CLASS = "Class colour"
L.OPT_LEVEL_BOX = "Box"
L.OPT_LEVEL_STYLE = "Style"
L.LEVEL_STYLE_NONE = "None (number only)"
L.LEVEL_STYLE_CLASSIC = "Classic"
L.LEVEL_STYLE_GOLD = "Gold"
L.LEVEL_STYLE_CLASS = "Class colour"
L.LEVEL_STYLE_PLAIN = "Plain (dark, no edge)"
L.LEVEL_STYLE_CREST = "Crest"
L.LEVEL_STYLE_HEX = "Hexagon"
L.LEVEL_STYLE_DIAMOND = "Diamond"
L.LEVEL_STYLE_ROSETTE = "Rosette"
L.LEVEL_STYLE_LAUREL = "Laurel wreath"
L.LEVEL_STYLE_WINGS = "Wings"
L.LEVEL_STYLE_RING_GOLD = "Gold ring"
L.LEVEL_STYLE_RING_ORNATE = "Ornate gold ring"
L.OPT_LEVEL_BOX_PAD_X = "Padding left and right"
L.OPT_LEVEL_BOX_PAD_Y = "Padding above and below"
L.OPT_LEVEL_BOX_MIN_W = "Least width"

L.PAGE_BACKDROP = "Background"
L.OPT_BACKDROP = "Background"
L.OPT_BACKDROP_SHOW = "Show a background behind the bars"
L.OPT_BACKDROP_COLOR = "Colour"
L.OPT_BACKDROP_ALPHA = "Opacity"
L.OPT_BACKDROP_PADDING = "Padding"
L.OPT_BACKDROP_BORDER = "Border"
L.OPT_BORDER_STYLE = "Style"
L.BORDER_NONE = "None"
L.BORDER_FLAT = "Flat"
L.BORDER_GOLD = "Gold"
L.OPT_BORDER_SIZE = "Thickness"
L.OPT_BORDER_COLOR = "Colour (Flat only)"

L.OPT_PROFILES = "Profiles"
L.OPT_PROFILE_ACTIVE = "Active profile"
L.OPT_PROFILE_SAVE_AS = "Save as..."
L.OPT_PROFILE_DELETE = "Delete"
L.POPUP_PROFILE_NAME = "Name of the new profile:"
L.POPUP_PROFILE_DELETE = "Really delete the profile \"%s\"?"
L.OPT_RESET = "Reset"
L.OPT_RESET_HINT = "Sets every value of the active profile back to the default."
L.OPT_RESET_BUTTON = "Reset the profile"
