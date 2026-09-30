local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The options window, built like Forever Unit Frames' (Style.lua and
-- Widgets.lua are the same): a title bar, the pages on the left with the
-- language at the bottom, the chosen page on the right, a footer. Opened
-- from the minimap button or /fpb; the page under Interface Options ->
-- AddOns only has a button to open it.
local Window = {}
ns.Window = Window

local Style, Widgets = ns.Style, ns.Widgets

local function num(key, label)
    local range = Settings.RANGES[key]
    return {
        label = label, min = range[1], max = range[2], step = 1, unit = "px",
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function check(key, label)
    return {
        type = "check", label = label,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function screenSize()
    local w = (UIParent.GetWidth and UIParent:GetWidth()) or 0
    local h = (UIParent.GetHeight and UIParent:GetHeight()) or 0
    if w <= 0 then w = 1920 end
    if h <= 0 then h = 1080 end
    return math.floor(w), math.floor(h)
end

-- --------------------------------------------------------------------------
-- The pages. `rows` is a spec turned into widgets below; `build` builds a
-- page by itself (the skill list changes at runtime).
-- --------------------------------------------------------------------------
-- A dropdown over fixed values, labelled prefix .. value.
local function choice(key, label, values, prefix)
    return {
        type = "select", label = label,
        choices = function()
            local list = {}
            for _, v in ipairs(values) do list[#list + 1] = { label = L[prefix .. v], value = v } end
            return list
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

-- Allgemein: what shows, how it is arranged, where it sits.
local function generalRows()
    local w, h = screenSize()
    return {
        { type = "header", label = "OPT_SHOW" },
        check("showProfessions", "OPT_SHOW_PROFESSIONS"),
        check("showReputation", "OPT_SHOW_REPUTATION"),
        check("levelShow", "OPT_LEVEL_SHOW"),
        check("xpEnabled", "OPT_XP_ENABLED"),
        { type = "header", label = "OPT_HIDE" },
        check("hideInCombat", "OPT_HIDE_COMBAT"),
        check("hideInGroup", "OPT_HIDE_GROUP"),
        check("xpHideInCombat", "OPT_XP_HIDE_COMBAT"),
        check("xpHideInGroup", "OPT_XP_HIDE_GROUP"),
        { type = "header", label = "OPT_ARRANGEMENT" },
        choice("arrangement", "OPT_ARRANGE", { "ROW", "COLUMNS", "COLUMN" }, "ARRANGE_"),
        { label = "OPT_SCALE", min = 50, max = 200, step = 5, unit = "%",
          get = function() return S("scale") end, set = function(v) Settings.Set("scale", v) end },
        { type = "header", label = "OPT_POSITION" },
        choice("xFrom", "OPT_X_FROM", { "CENTER", "LEFT" }, "FROM_"),
        choice("yFrom", "OPT_Y_FROM", { "TOP", "CENTER" }, "FROM_"),
        -- Ranges wide enough for either reference.
        { label = "OPT_X", min = -w, max = w, step = 1, unit = "px",
          get = function() return S("x") end, set = function(v) Settings.Set("x", v) end },
        { label = "OPT_Y", min = -h, max = h, step = 1, unit = "px",
          get = function() return S("y") end, set = function(v) Settings.Set("y", v) end },
        check("locked", "OPT_LOCK"),
        { type = "header", label = "OPT_MINIMAP" },
        check("minimapShow", "OPT_MINIMAP_SHOW"),
    }
end

local function colorRow(key, label, noOpacity)
    return {
        type = "color", label = label, noOpacity = noOpacity,
        get = function()
            local c = S(key)
            return { c[1], c[2], c[3], c[4] or 1 }
        end,
        set = function(c)
            Settings.Set(key, noOpacity and { c[1], c[2], c[3] } or { c[1], c[2], c[3], c[4] })
        end,
    }
end

-- Leisten: their size (both widths), text line, look, icons.
local function barRows()
    local w = screenSize()
    return {
        { type = "header", label = "OPT_BAR_SIZE" },
        { label = "OPT_ROW_WIDTH", min = 200, max = w, step = 1, unit = "px",
          get = function() return math.min(Settings.Width(w), w) end, set = function(v) Settings.Set("width", v) end },
        num("columnWidth", "OPT_COLUMN_WIDTH"),
        num("barHeight", "OPT_BAR_HEIGHT"),
        num("spacing", "OPT_SPACING"),
        num("segmentWidth", "OPT_SEGMENT_WIDTH"),
        { type = "header", label = "OPT_BAR_TEXT" },
        num("textHeight", "OPT_TEXT_HEIGHT"),
        num("textGap", "OPT_TEXT_GAP"),
        num("labelFontSize", "OPT_LABEL_FONT_SIZE"),
        { type = "header", label = "OPT_BAR_LOOK" },
        colorRow("barBgColor", "OPT_BAR_BG_COLOR", true),
        { label = "OPT_BAR_BG_ALPHA", min = 0, max = 100, step = 1, unit = "%",
          get = function() return S("barBgAlpha") end,
          set = function(v) Settings.Set("barBgAlpha", v) end },
        { type = "header", label = "OPT_ICONS" },
        check("showIcons", "OPT_SHOW_ICONS"),
        check("showRank", "OPT_SHOW_RANK"),
        num("iconSize", "OPT_ICON_SIZE"),
        num("iconGap", "OPT_ICON_GAP"),
    }
end

local function repRows()
    local rows = {
        { type = "header", label = "OPT_REPUTATION" },
        { type = "text", label = "OPT_REP_HINT" },
    }
    for slot = 1, 4 do
        rows[#rows + 1] = {
            type = "select",
            label = function() return L.OPT_REP_SLOT:format(slot) end,
            -- A function: factions discovered later appear on the next open.
            choices = function()
                local list = { { label = L.REP_EMPTY, value = 0 } }
                for _, f in ipairs(ns.Factions()) do list[#list + 1] = { label = f.name, value = f.id } end
                return list
            end,
            get = function() return Settings.Reps()[slot] or 0 end,
            set = function(v) Settings.SetRep(slot, v) end,
        }
    end
    rows[#rows + 1] = { type = "buttons", buttons = {
        { label = "OPT_REP_RELOAD", width = 200, onClick = function()
            ns.RefreshReputation()
            Window.Refresh()
        end },
    } }
    return rows
end

-- The look of a level badge: font, size, outline, colour, style. keys: the
-- settings it reads (ns.Bars.ROW_BADGE or ns.Bars.XP_BADGE).
local function badgeLookRows(keys)
    return {
        {
            type = "select", label = "OPT_LEVEL_STYLE",
            choices = function()
                local list = {}
                for _, style in ipairs(ns.Bars.AvailableLevelStyles()) do
                    list[#list + 1] = { label = L["LEVEL_STYLE_" .. style], value = style }
                end
                return list
            end,
            get = function() return ns.Bars.LevelStyle(keys) end,
            set = function(v) Settings.Set(keys.style, v) end,
        },
        {
            type = "select", label = "OPT_FONT",
            choices = function()
                local list = {}
                for _, name in ipairs(ns.Media.FontNames()) do list[#list + 1] = { label = name, value = name } end
                return list
            end,
            get = function() return S(keys.font) end,
            set = function(v) Settings.Set(keys.font, v) end,
        },
        num(keys.size, "OPT_FONT_SIZE"),
        {
            type = "select", label = "OPT_OUTLINE",
            choices = function()
                return {
                    { label = L.OUTLINE_NONE, value = "" },
                    { label = L.OUTLINE_NORMAL, value = "OUTLINE" },
                    { label = L.OUTLINE_THICK, value = "THICKOUTLINE" },
                }
            end,
            get = function() return S(keys.flag) end,
            set = function(v) Settings.Set(keys.flag, v) end,
        },
        {
            type = "select", label = "OPT_LEVEL_COLOR",
            choices = function()
                return {
                    { label = L.COLOR_GOLD, value = "GOLD" },
                    { label = L.COLOR_WHITE, value = "WHITE" },
                    { label = L.COLOR_CLASS, value = "CLASS" },
                }
            end,
            get = function() return S(keys.color) end,
            set = function(v) Settings.Set(keys.color, v) end,
        },
    }
end

-- A row whose label reads differently while the level is placed freely.
local function freeLabelled(row, freeLabel)
    local normal = row.label
    row.label = function()
        return S("levelPlace") == "FREE" and L[freeLabel] or L[normal]
    end
    return row
end

-- Choosing "Free" or back relabels the two sliders at once (labels that
-- are functions are read again on every refresh).

-- Stufe: where the row's badge sits, then how it looks.
local function levelRows()
    local rows = {
        { type = "header", label = "OPT_LEVEL" },
        choice("levelPlace", "OPT_LEVEL_PLACE", { "TOP", "MIDDLE", "BOTTOM", "FREE" }, "LEVEL_PLACE_"),
        -- With "Free" the two become its coordinates.
        freeLabelled(num("levelOffsetX", "OPT_LEVEL_X"), "OPT_LEVEL_FREE_X"),
        freeLabelled(num("levelOffsetY", "OPT_LEVEL_Y"), "OPT_LEVEL_FREE_Y"),
        num("levelGap", "OPT_LEVEL_GAP"),
        { type = "header", label = "OPT_LEVEL_BOX" },
    }
    for _, row in ipairs(badgeLookRows(ns.Bars.ROW_BADGE)) do rows[#rows + 1] = row end
    rows[#rows + 1] = num("levelBoxPadX", "OPT_LEVEL_BOX_PAD_X")
    rows[#rows + 1] = num("levelBoxPadY", "OPT_LEVEL_BOX_PAD_Y")
    rows[#rows + 1] = num("levelBoxMinW", "OPT_LEVEL_BOX_MIN_W")
    return rows
end

-- XP bar: the bar and its place; the title line (the level as text or as
-- a badge, the numbers); the badge, used only with "as badge".
local function xpRows()
    local X = ns.XpBar
    local rows = {
        { type = "header", label = "OPT_XP" },
        { type = "text", label = "OPT_XP_HINT", height = 40 },
        choice("xpRow", "OPT_XP_ROW", X.ROWS, "XP_ROW_"),
        num("xpGap", "OPT_XP_GAP"),
        num("xpFreeX", "OPT_XP_FREE_X"),
        num("xpFreeY", "OPT_XP_FREE_Y"),
        num("xpWidth", "OPT_XP_WIDTH"),
        colorRow("xpColor", "OPT_XP_COLOR", true),
        colorRow("xpRestedColor", "OPT_XP_RESTED_COLOR", true),

        { type = "header", label = "OPT_XP_TITLE_HEADER" },
        check("xpTitle", "OPT_XP_TITLE"),
        choice("xpLevelMode", "OPT_XP_LEVEL_MODE", { "TEXT", "BADGE" }, "XP_LEVEL_"),
        {
            type = "select", label = "OPT_XP_LEVEL_FONT",
            choices = function()
                local list = { { label = L.XP_FONT_SAME, value = "" } }
                for _, name in ipairs(ns.Media.FontNames()) do list[#list + 1] = { label = name, value = name } end
                return list
            end,
            get = function() return S("xpLevelFont") end,
            set = function(v) Settings.Set("xpLevelFont", v) end,
        },
        num("xpLevelFontSize", "OPT_XP_LEVEL_SIZE"),
        choice("xpTextMode", "OPT_XP_TEXT_MODE", X.TEXT_MODES, "XP_MODE_"),
        num("xpValueFontSize", "OPT_XP_VALUE_SIZE"),
        choice("xpValuePlace", "OPT_XP_VALUE_PLACE", X.VALUE_PLACES, "XP_VALUE_"),
        num("xpValueX", "OPT_XP_VALUE_X"),
        num("xpValueY", "OPT_XP_VALUE_Y"),

        { type = "header", label = "OPT_XP_BADGE" },
        { type = "text", label = "OPT_XP_BADGE_HINT" },
        check("xpBadgeFollow", "OPT_XP_BADGE_FOLLOW"),
        choice("xpBadgePoint", "OPT_XP_BADGE_POINT",
            { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }, "POINT_"),
        num("xpBadgeX", "OPT_XP_BADGE_X"),
        num("xpBadgeY", "OPT_XP_BADGE_Y"),
    }
    for _, row in ipairs(badgeLookRows(ns.Bars.XP_BADGE)) do rows[#rows + 1] = row end
    return rows
end

local function backdropRows()
    return {
        { type = "header", label = "OPT_BACKDROP" },
        check("backdropShow", "OPT_BACKDROP_SHOW"),
        colorRow("backdropColor", "OPT_BACKDROP_COLOR", true),
        { label = "OPT_BACKDROP_ALPHA", min = 0, max = 100, step = 1, unit = "%",
          get = function() return S("backdropAlpha") end,
          set = function(v) Settings.Set("backdropAlpha", v) end },
        num("backdropPadding", "OPT_BACKDROP_PADDING"),
        { type = "header", label = "OPT_BACKDROP_BORDER" },
        {
            type = "select", label = "OPT_BORDER_STYLE",
            choices = function()
                return {
                    { label = L.BORDER_NONE, value = "NONE" },
                    { label = L.BORDER_FLAT, value = "FLAT" },
                    { label = L.BORDER_GOLD, value = "GOLD" },
                }
            end,
            get = function() return S("backdropBorder") end,
            set = function(v) Settings.Set("backdropBorder", v) end,
        },
        num("backdropBorderSize", "OPT_BORDER_SIZE"),
        colorRow("backdropBorderColor", "OPT_BORDER_COLOR"),
    }
end

-- The export/import field; Window.shareField for the tests.
local shareField = {}
Window.shareField = shareField

local function profileRows()
    return {
        { type = "header", label = "OPT_PROFILES" },
        {
            type = "select", label = "OPT_PROFILE_ACTIVE",
            choices = function()
                local list = {}
                for _, name in ipairs(ns.ProfileList()) do
                    -- Presets show their name and "(preset)".
                    local id = ns.PresetId(name)
                    local label = id and (L["PRESET_" .. id] .. " " .. L.PRESET_SUFFIX) or name
                    list[#list + 1] = { label = label, value = name }
                end
                return list
            end,
            get = function() return ns.ActiveProfile() end,
            set = function(v)
                ns.SwitchProfile(v)
                Window.Refresh()
            end,
        },
        { type = "buttons", buttons = {
            { label = "OPT_PROFILE_SAVE_AS", width = 150, onClick = function() ns.AskProfileName() end },
            { label = "OPT_PROFILE_DELETE", width = 110, onClick = function() ns.AskDeleteProfile() end },
        } },
        { type = "header", label = "OPT_SHARE" },
        { type = "text", label = "OPT_SHARE_HINT", height = 40 },
        { type = "edit", ref = shareField },
        { type = "buttons", buttons = {
            { label = "OPT_EXPORT", width = 130, onClick = function()
                local box = shareField.box
                box:SetText(ns.Share.Export())
                box:SetFocus()
                box:HighlightText()
            end },
            { label = "OPT_IMPORT", width = 130, onClick = function()
                local ok = ns.Share.Import(shareField.box:GetText())
                ns.Print(ok and L.MSG_IMPORTED or L.MSG_IMPORT_FAILED)
                if ok then Window.Refresh() end
            end },
        } },
        { type = "header", label = "OPT_RESET" },
        { type = "text", label = "OPT_RESET_HINT" },
        { type = "buttons", buttons = {
            { label = "OPT_RESET_BUTTON", width = 200, onClick = function()
                Settings.ResetProfile()
                Window.Refresh()
            end },
        } },
    }
end

-- --------------------------------------------------------------------------
-- Spec rows into widgets
-- --------------------------------------------------------------------------
local WIDTH, HEIGHT = 780, 560
local TITLE_H, NAV_W, FOOTER_H = 32, 160, 40
local NAV_ROW_H, NAV_TOP, NAV_BAR_W = 28, 8, 3
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, HINT_ROW_H = 70, 26
local BUTTON_H, BUTTON_W, BUTTON_GAP = 24, 140, 8

-- A label: a locale key or a function (read again on refresh).
local function labelText(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- Stacks rows top to bottom; a header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + (height or row:GetHeight())
    end
    return stack
end

-- A muted line of explanation.
local function hintRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    row.text = Style.Text(row, 11, "muted")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    row.text:SetPoint("RIGHT", row, "RIGHT", -INSET, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetText(labelText(opt.label))
    function row:Refresh() end
    function row:SetEnabled() end
    return row, opt.height or HINT_ROW_H
end

-- Several buttons side by side.
local function buttonsRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local x = INSET
    row.buttons = {}
    for _, b in ipairs(opt.buttons) do
        local button = Widgets.Button(row, { text = labelText(b.label), width = b.width or BUTTON_W,
            onClick = b.onClick })
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + (b.width or BUTTON_W) + BUTTON_GAP
        row.buttons[#row.buttons + 1] = button
    end
    function row:Refresh() end
    function row:SetEnabled(on) for _, button in ipairs(row.buttons) do button:SetEnabled(on) end end
    return row, BUTTON_H + 12
end

-- A text area to copy from or paste into (export / import).
local function editRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local area = Widgets.TextArea(row, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H })
    area:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    -- The buttons use it like an edit box.
    function area:SetFocus() area.edit:SetFocus() end
    function area:HighlightText() area.edit:HighlightText() end
    if opt.ref then opt.ref.box = area end
    function row:Refresh() end
    function row:SetEnabled() end
    return row, TEXT_AREA_H + 12
end

-- The widget for one spec row, and its height (nil: the widget's own).
local function widgetFor(page, opt)
    local kind = opt.type or "slider"
    if kind == "header" then
        local row = Widgets.Header(page, labelText(opt.label))
        row.isSection = true
        return row
    elseif kind == "text" then
        return hintRow(page, opt)
    elseif kind == "buttons" then
        return buttonsRow(page, opt)
    elseif kind == "edit" then
        return editRow(page, opt)
    end
    local o = { label = labelText(opt.label), get = opt.get, set = opt.set }
    local row
    if kind == "check" then
        row = Widgets.Checkbox(page, o)
    elseif kind == "select" then
        o.items = function()
            local items = {}
            for _, c in ipairs(opt.choices()) do
                items[#items + 1] = { value = c.value, text = c.label, font = c.font }
            end
            return items
        end
        row = Widgets.Dropdown(page, o)
    elseif kind == "color" then
        o.noOpacity = opt.noOpacity
        row = Widgets.Color(page, o)
    else
        o.min, o.max, o.step = opt.min, opt.max, opt.step or 1
        row = Widgets.Slider(page, o)
    end
    -- A label that follows the settings (e.g. "X" for a free level).
    if type(opt.label) == "function" then
        local refresh = row.Refresh
        function row:Refresh()
            row:SetLabel(opt.label())
            refresh(self)
        end
    end
    return row
end

local function buildRows(page, spec)
    local stack = newStack(page)
    for _, opt in ipairs(spec) do
        local row, height = widgetFor(page, opt)
        stack.add(row, height)
    end
    page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
end

-- The professions page: one checkbox per known skill, rebuilt on every
-- show, since skills are learned and unlearned.
local function buildSkillPage(page)
    local stack = newStack(page)
    local header = Widgets.Header(page, L.OPT_PROFESSIONS)
    header.isSection = true
    stack.add(header)
    local hint = hintRow(page, { label = "OPT_PROFESSIONS_HINT", height = 40 })
    stack.add(hint, 40)
    local top = stack.y
    local empty = Style.Text(page, 12, "muted")
    empty:SetPoint("TOPLEFT", page, "TOPLEFT", INSET, -top - 6)
    empty:SetText(L.OPT_NO_SKILLS)
    local checks = {}
    page.fixedRows = stack.rows
    page.rebuild = function()
        local skills = ns.Bars.KnownSkills()
        for i, line in ipairs(skills) do
            local c = checks[i]
            if not c then
                c = Widgets.Checkbox(page, {
                    label = "",
                    get = function() return not Settings.IsHidden(c.skillName, c.skillKey) end,
                    set = function(v) Settings.SetHidden(c.skillName, not v) end,
                })
                c:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(top + (i - 1) * Widgets.ROW_H))
                c:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -(top + (i - 1) * Widgets.ROW_H))
                checks[i] = c
            end
            c.skillName, c.skillKey = line.name, line.key
            c:SetLabel(("%s  |cff888888%d/%d|r"):format(ns.Bars.ProfessionLabel(line), line.rank, line.maxRank))
            c:Show()
        end
        for i = #skills + 1, #checks do checks[i]:Hide() end
        empty:SetShown(#skills == 0)
        local rows = {}
        for _, r in ipairs(page.fixedRows) do rows[#rows + 1] = r end
        for i = 1, #skills do rows[#rows + 1] = checks[i] end
        page.rows = rows
        page.height = top + math.max(1, #skills) * Widgets.ROW_H + PAGE_BOTTOM
    end
    page.rebuild()
end

Window.PAGES = {
    { id = "general", label = "PAGE_GENERAL", rows = generalRows },
    { id = "bars", label = "PAGE_BARS", rows = barRows },
    { id = "professions", label = "PAGE_PROFESSIONS", build = buildSkillPage },
    { id = "reputation", label = "PAGE_REPUTATION", rows = repRows },
    { id = "level", label = "PAGE_LEVEL", rows = levelRows },
    { id = "xp", label = "PAGE_XP", rows = xpRows },
    { id = "backdrop", label = "PAGE_BACKDROP", rows = backdropRows },
    { id = "profiles", label = "PAGE_PROFILES", rows = profileRows },
}

-- --------------------------------------------------------------------------
-- The window
-- --------------------------------------------------------------------------
local frame, current
local pages = {}

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function pageFor(id)
    if pages[id] then return pages[id] end
    local spec
    for _, p in ipairs(Window.PAGES) do if p.id == id then spec = p end end
    if not spec then return nil end
    local page = CreateFrame("Frame", "ForeverProgressBarsPage" .. id, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if spec.build then spec.build(page) else buildRows(page, spec.rows()) end
    page:SetHeight(page.height)
    page:Hide()
    pages[id] = page
    return page
end

-- Scrolling: a thin accent thumb, as in Forever Unit Frames.
local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3,
        -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", "ForeverProgressBarsOptionsScroll", body)
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    local thumb = body:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(unpack(Style.COLORS.accent))
    thumb:SetWidth(2)
    thumb:Hide()
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Navigation ----------------------------------------------------------------------
local function paintNav()
    for id, b in pairs(frame.navButtons) do
        local selected = id == current
        Style.Paint(b.text, selected and "accent" or "text")
        b.selected = selected
        b.bar:SetShown(selected)
    end
end

local function navButton(nav, page, y)
    local b = CreateFrame("Button", "ForeverProgressBarsNav" .. page.id, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(L[page.label])
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnClick", function() Window.ShowPage(page.id) end)
    frame.navButtons[page.id] = b
end

-- The language, at the bottom of the navigation: a label above a dropdown
-- as wide as the column; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.OPT_LANGUAGE,
        items = function()
            local list = { { value = "AUTO", text = L.LANGUAGE_AUTO } }
            for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = { value = c.value, text = c.label } end
            return list
        end,
        get = function() return ns.Locale.Setting() end,
        set = function(v) ns.Locale.Set(v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    frame.languageRow = row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    frame.navButtons = {}
    for i, page in ipairs(Window.PAGES) do navButton(nav, page, NAV_TOP + (i - 1) * NAV_ROW_H) end
    languageRow(nav)
    return nav
end

-- Footer: lock or unlock the strip (drag it while unlocked).
local function refreshFooter()
    if frame and frame.lockButton then
        frame.lockButton.text:SetText(S("locked") and L.OPT_UNLOCK_STRIP or L.OPT_LOCK_STRIP)
    end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    local lock = Widgets.Button(footer, { text = L.OPT_UNLOCK_STRIP, width = 160,
        onClick = function() Settings.Set("locked", not S("locked")) end })
    lock:SetPoint("LEFT", footer, "LEFT", 12, 0)
    frame.lockButton = lock
    refreshFooter()
    return footer
end

-- Title bar with the version and a drawn close cross.
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.ADDON_NAME)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ((getMetadata and getMetadata(ADDON, "Version")) or ""))
    bar.close = closeButton(bar)
    return bar
end

local WINDOW_NAME = "ForeverProgressBarsOptions"

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    local footer = createFooter(frame)
    local nav = createNav(frame)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    createScroll(body)
    -- Hiding the window (ESC, the cross) takes an open dropdown list along.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:SetScript("OnShow", function() Window.Refresh() end)
    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == WINDOW_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, WINDOW_NAME) end
    end
end

local function ensureWindow()
    if not frame then createWindow() end
end

-- Public API ----------------------------------------------------------------------

function Window.ShowPage(id)
    ensureWindow()
    local page = pageFor(id)
    if not page then return end
    Widgets.CloseList()
    for _, p in pairs(pages) do if p ~= page then p:Hide() end end
    current = id
    if page.rebuild then
        page.rebuild()
        page:SetHeight(page.height)
    end
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    paintNav()
    updateScrollbar()
end

-- Fetches every value on the visible page again.
function Window.Refresh()
    if not frame or not current then return end
    local page = pages[current]
    if not page then return end
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    if frame.languageRow then frame.languageRow:Refresh() end
    refreshFooter()
end
ns.RefreshOptions = Window.Refresh

function Window.Open(pageID)
    ensureWindow()
    frame:Show()
    Window.ShowPage(pageID or current or "general")
end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- A change from elsewhere (dragging, a slash command, a profile) shows on
-- the page.
Settings.OnChange(function()
    if frame and frame:IsShown() then Window.Refresh() end
end)

-- Every label is set when its widget is built: a new language gets a new
-- window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name and page.
ns.Locale.OnChange(function()
    if not frame then return end
    local wasOpen, page = frame:IsShown(), current
    frame:Hide()
    frame, pages = nil, {}
    if wasOpen then Window.Open(page) end
end)
