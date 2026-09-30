local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The options window: pages on the left, the chosen page on the right, the
-- language at the bottom left. Opened from the minimap button or /fpb; the
-- page under Interface Options -> AddOns only has a button to open it.
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT, NAV_WIDTH = 760, 560, 170
local COLORS = {
    bg = { 0.07, 0.07, 0.08, 0.96 },
    nav = { 0.10, 0.10, 0.12, 1 },
    title = { 0.12, 0.12, 0.14, 1 },
    border = { 0, 0, 0, 1 },
    accent = { 1.00, 0.82, 0.00, 1 },
    text = { 0.90, 0.90, 0.90, 1 },
    selected = { 1, 1, 1, 0.08 },
}

local function Fill(frame, color, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(color[1], color[2], color[3], color[4])
    return t
end

local function Border(frame)
    local c = COLORS.border
    local edges = {}
    for i = 1, 4 do
        edges[i] = frame:CreateTexture(nil, "BORDER")
        edges[i]:SetColorTexture(c[1], c[2], c[3], c[4])
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
end

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
-- The pages. `rows` is a spec for ns.BuildRows; `build` builds a page by
-- itself (the skill list changes at runtime).
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

local function generalRows()
    local w, h = screenSize()
    return {
        { type = "header", label = "OPT_POSITION" },
        choice("xFrom", "OPT_X_FROM", { "CENTER", "LEFT" }, "FROM_"),
        choice("yFrom", "OPT_Y_FROM", { "TOP", "CENTER" }, "FROM_"),
        -- Ranges wide enough for either reference.
        { label = "OPT_X", min = -w, max = w, step = 1, unit = "px",
          get = function() return S("x") end, set = function(v) Settings.Set("x", v) end },
        { label = "OPT_Y", min = -h, max = h, step = 1, unit = "px",
          get = function() return S("y") end, set = function(v) Settings.Set("y", v) end },
        { label = "OPT_WIDTH", min = 200, max = w, step = 1, unit = "px",
          get = function() return math.min(Settings.Width(w), w) end, set = function(v) Settings.Set("width", v) end },
        check("locked", "OPT_LOCK"),
        { label = "OPT_SCALE", min = 50, max = 200, step = 5, unit = "%",
          get = function() return S("scale") end, set = function(v) Settings.Set("scale", v) end },
        { type = "header", label = "OPT_ARRANGEMENT" },
        choice("arrangement", "OPT_ARRANGE", { "ROW", "COLUMNS", "COLUMN" }, "ARRANGE_"),
        num("columnWidth", "OPT_COLUMN_WIDTH"),
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

local function barRows()
    return {
        { type = "header", label = "OPT_BARS" },
        num("barHeight", "OPT_BAR_HEIGHT"),
        num("textHeight", "OPT_TEXT_HEIGHT"),
        num("textGap", "OPT_TEXT_GAP"),
        num("spacing", "OPT_SPACING"),
        num("segmentWidth", "OPT_SEGMENT_WIDTH"),
        num("labelFontSize", "OPT_LABEL_FONT_SIZE"),
        colorRow("barBgColor", "OPT_BAR_BG_COLOR", true),
        { label = "OPT_BAR_BG_ALPHA", min = 0, max = 100, step = 1, unit = "%",
          get = function() return S("barBgAlpha") end,
          set = function(v) Settings.Set("barBgAlpha", v) end },
        { type = "header", label = "OPT_ICONS" },
        check("showIcons", "OPT_SHOW_ICONS"),
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

-- Choosing "Free" or back relabels the two sliders at once.
Settings.OnChange(function(key)
    if (key == "levelPlace" or key == nil) and ns.RelabelOptions then ns.RelabelOptions() end
end)

-- Stufe: where the row's badge sits, then how it looks.
local function levelRows()
    local rows = {
        { type = "header", label = "OPT_LEVEL" },
        check("levelShow", "OPT_LEVEL_SHOW"),
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
        check("xpEnabled", "OPT_XP_ENABLED"),
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

-- The preset picked in the list (loaded only with the button).
local presetChoice = { id = "CLASSIC" }

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
                for _, name in ipairs(ns.ProfileList()) do list[#list + 1] = { label = name, value = name } end
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
        { type = "header", label = "OPT_PRESETS" },
        { type = "text", label = "OPT_PRESET_HINT", height = 40 },
        {
            type = "select", label = "OPT_PRESET",
            choices = function()
                local list = {}
                for _, p in ipairs(Settings.PRESETS) do list[#list + 1] = { label = L["PRESET_" .. p.id], value = p.id } end
                return list
            end,
            get = function() return presetChoice.id end,
            set = function(v) presetChoice.id = v end,
        },
        { type = "buttons", buttons = {
            { label = "OPT_PRESET_LOAD", width = 200, onClick = function()
                if Settings.ApplyPreset(presetChoice.id) then
                    ns.Print(L.MSG_PRESET_LOADED)
                    Window.Refresh()
                end
            end },
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

-- The professions page: one checkbox per known skill, rebuilt on every
-- show, since skills are learned and unlearned.
local function buildSkillPage(content)
    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", 18, -8)
    local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 20, -34)
    hint:SetWidth(480)
    hint:SetJustifyH("LEFT")
    local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 26, -64)
    local checks = {}

    local function relabel()
        header:SetText(L.OPT_PROFESSIONS)
        hint:SetText(L.OPT_PROFESSIONS_HINT)
        empty:SetText(L.OPT_NO_SKILLS)
    end
    ns.Locale.OnChange(relabel)
    relabel()

    return function()
        local skills = ns.Bars.KnownSkills()
        for i, line in ipairs(skills) do
            local c = checks[i]
            if not c then
                c = CreateFrame("CheckButton", "ForeverProgressBarsSkillCheck" .. i, content,
                                "InterfaceOptionsCheckButtonTemplate")
                c:SetPoint("TOPLEFT", 22, -58 - (i - 1) * 30)
                c.label = _G[c:GetName() .. "Text"] or c.Text
                c:SetScript("OnClick", function(self)
                    Settings.SetHidden(self.skillName, not self:GetChecked())
                end)
                checks[i] = c
            end
            c.skillName = line.name
            if c.label and c.label.SetText then
                c.label:SetText(("%s  |cff888888%d/%d|r"):format(line.name, line.rank, line.maxRank))
            end
            c:SetChecked(not Settings.IsHidden(line.name, line.key))
            c:Show()
        end
        for i = #skills + 1, #checks do checks[i]:Hide() end
        empty:SetShown(#skills == 0)
        content:SetHeight(80 + #skills * 30)
    end
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
-- Building the window
-- --------------------------------------------------------------------------
local frame, scroll, current
local pages = {}

local function showPage(id)
    current = id
    for _, page in ipairs(Window.PAGES) do
        local p = pages[page.id]
        if p then
            p.content:SetShown(page.id == id)
            p.button.selected:SetShown(page.id == id)
        end
    end
    local p = pages[id]
    scroll:SetScrollChild(p.content)
    if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
    p.refresh()
end

-- The language dropdown at the bottom left.
local function languageRow(nav)
    local label = nav:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    label:SetPoint("BOTTOMLEFT", 12, 44)
    local choices = function()
        local list = { { value = "AUTO", label = L.LANGUAGE_AUTO } }
        for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = c end
        return list
    end
    local function labelFor(v)
        for _, c in ipairs(choices()) do if c.value == v then return c.label end end
        return tostring(v)
    end
    local refresh
    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and UIDropDownMenu_SetText then
        local dd = CreateFrame("Frame", "ForeverProgressBarsLanguage", nav, "UIDropDownMenuTemplate")
        dd:SetPoint("BOTTOMLEFT", -6, 8)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, 130) end
        UIDropDownMenu_Initialize(dd, function(_, level)
            for _, c in ipairs(choices()) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = c.label
                info.checked = (c.value == ns.Locale.Setting())
                info.func = function() ns.Locale.Set(c.value) end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        refresh = function() UIDropDownMenu_SetText(dd, labelFor(ns.Locale.Setting())) end
    else
        local button = CreateFrame("Button", "ForeverProgressBarsLanguage", nav, "UIPanelButtonTemplate")
        button:SetSize(146, 22)
        button:SetPoint("BOTTOMLEFT", 12, 14)
        button:SetScript("OnClick", function()
            local list, now = choices(), ns.Locale.Setting()
            for i, c in ipairs(list) do
                if c.value == now then
                    ns.Locale.Set(list[(i % #list) + 1].value)
                    return
                end
            end
            ns.Locale.Set(list[1].value)
        end)
        refresh = function() button:SetText(labelFor(ns.Locale.Setting())) end
    end
    local function relabel()
        label:SetText(L.OPT_LANGUAGE)
        refresh()
    end
    ns.Locale.OnChange(relabel)
    relabel()
end

local function navButton(nav, page, i)
    local b = CreateFrame("Button", "ForeverProgressBarsNav" .. page.id, nav)
    b:SetSize(NAV_WIDTH - 2, 28)
    b:SetPoint("TOPLEFT", 1, -8 - (i - 1) * 30)
    b.selected = Fill(b, COLORS.selected, "BACKGROUND")
    b.selected:Hide()
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local hl = b:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 1, 1, 0.05) end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("LEFT", 14, 0)
    b:SetScript("OnClick", function() showPage(page.id) end)
    local function relabel() b.text:SetText(L[page.label]) end
    ns.Locale.OnChange(relabel)
    relabel()
    return b
end

local function createWindow()
    frame = CreateFrame("Frame", "ForeverProgressBarsOptions", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Fill(frame, COLORS.bg)
    Border(frame)
    -- Esc closes it.
    if UISpecialFrames then tinsert(UISpecialFrames, "ForeverProgressBarsOptions") end

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(30)
    Fill(titleBar, COLORS.title)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(L.ADDON_NAME)
    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 2, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    local nav = CreateFrame("Frame", nil, frame)
    nav:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", 1, 1)
    nav:SetWidth(NAV_WIDTH)
    Fill(nav, COLORS.nav)

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", nav, "TOPRIGHT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", -1, 1)

    scroll = CreateFrame("ScrollFrame", "ForeverProgressBarsOptionsScroll", body, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local now = self.GetVerticalScroll and self:GetVerticalScroll() or 0
        local range = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
        local target = math.max(0, math.min(range or 0, now - delta * 40))
        if self.SetVerticalScroll then self:SetVerticalScroll(target) end
    end)

    for i, page in ipairs(Window.PAGES) do
        local content = CreateFrame("Frame", "ForeverProgressBarsPage" .. page.id, scroll)
        content:SetSize(WIDTH - NAV_WIDTH - 40, 10)
        content:Hide()
        local refresh
        if page.build then
            refresh = page.build(content)
        else
            local height
            refresh, height = ns.BuildRows(content, "ForeverProgressBarsPage" .. page.id, page.rows())
            content:SetHeight(height)
        end
        pages[page.id] = { content = content, refresh = refresh, button = navButton(nav, page, i) }
    end
    languageRow(nav)

    frame:SetScript("OnShow", function() Window.Refresh() end)
    showPage("general")
end

-- Fetches every value on the visible page again.
function Window.Refresh()
    if not frame or not current then return end
    pages[current].refresh()
end
ns.RefreshOptions = Window.Refresh

function Window.Toggle()
    if not frame then createWindow() end
    frame:SetShown(not frame:IsShown())
end

function Window.Open(pageID)
    if not frame then createWindow() end
    frame:Show()
    if pageID and pages[pageID] then showPage(pageID) end
end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

Window.ShowPage = function(id) return showPage(id) end

-- A change from elsewhere (dragging, a slash command) shows on the page.
Settings.OnChange(function()
    if frame and frame:IsShown() then Window.Refresh() end
end)
ns.Locale.OnChange(function() ns.RelabelOptions() end)
