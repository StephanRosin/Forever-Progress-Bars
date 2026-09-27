-- Tests for Forever Progress Bars. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverProgressBars"

local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-50s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local S, Settings, Bars = ns.Settings.Get, ns.Settings, ns.Bars

M.Fire("ADDON_LOADED", ADDON)
M.Fire("PLAYER_LOGIN")
M.RunTimers()
M.RunTimers()

section("Defaults")
check("an empty profile gets the defaults", S("levelStyle"), Settings.DEFAULTS.levelStyle)
check("the backdrop is on by default", Bars.backdrop:IsShown(), Settings.DEFAULTS.backdropShow)
check("the bar height by default", Bars.Slot(1):GetHeight(), Settings.DEFAULTS.barHeight)
check("locked by default", Bars.container:IsMovable(), not Settings.DEFAULTS.locked)

-- The rest runs on a fixed layout, so it does not change with the defaults.
local TEST_VALUES = {
    y = -29, locked = false, barHeight = 25, textHeight = 14, textGap = 1, spacing = 13,
    segmentWidth = 22, labelFontSize = 14, iconSize = 18, iconGap = 1,
    barBgColor = { 0, 0, 0 }, barBgAlpha = 60,
    levelStyle = "CLASSIC", levelFontSize = 38, levelBoxPadX = 10,
    backdropShow = false, backdropAlpha = 50, backdropPadding = 6, backdropBorder = "NONE",
}
local function useTestValues()
    for k, v in pairs(TEST_VALUES) do ns.DB()[k] = v end
    Settings.Changed(nil)
end
useTestValues()

section("Profession bars")
local function slot(i) return Bars.Slot(i) end
local function name(i) return slot(i).data and slot(i).data.name end
check("slot 1: first primary", name(1), "Alchemy")
check("slot 2: second primary", name(2), "Mining")
check("slot 3: First Aid first", name(3), "First Aid")
check("slot 4: Cooking", name(4), "Cooking")
check("value text", slot(1).valueText:GetText(), "300/375")
check("fill value", slot(1).sb:GetValue(), 300)
check("fill colour: Alchemy green", slot(1).sb._color[1], ns.CFG.COLORS.ALCHEMY[1])
check("icon from the spell", slot(1).icon._texture, "ICON2259")
check("weapon skills never shown", (function()
    for i = 1, 4 do if name(i) == "Swords" then return true end end
    return false
end)(), false)
check("Fishing hidden by default", Settings.IsHidden("Fishing", "FISHING"), true)

Settings.SetHidden("First Aid", true)
check("hiding First Aid: Cooking moves up", name(3), "Cooking")
check("slot 4 now Fishing? no, hidden", name(4), nil)
check("empty slot hidden", slot(4):IsShown(), false)
Settings.SetHidden("Fishing", false)
check("showing Fishing fills slot 4", name(4), "Fishing")
Settings.SetHidden("First Aid", false)
Settings.SetHidden("Fishing", true)
check("back to First Aid", name(3), "First Aid")

-- A collapsed header is expanded for the scan and collapsed again.
M.state.skills[4][3] = false
Bars.Refresh()
check("collapsed header read anyway", name(3), "First Aid")
check("and collapsed again", M.state.skills[4][3], false)
M.state.skills[4][3] = true

section("Forever lists every profession twice")
table.insert(M.state.skills, 3, { "Alchemy", false, false, 300, 0, 0, 375, true })
Bars.Refresh()
check("the repeat takes no second bar", name(2), "Mining")
table.remove(M.state.skills, 3)
Bars.Refresh()

section("Clicking a profession")
check("spellbook route shown", slot(1).open:IsShown(), true)
check("skill line", slot(1).open.skillLine, 171)
M.casts = {}
slot(1).open:GetScript("OnClick")(slot(1).open)
check("casts the spellbook entry (offset + 1)", M.casts[1], 11)
-- A skill without a spellbook entry falls back to /cast by name.
M.state.professions[3][6] = "x"
Bars.Refresh()
check("fallback: no spellbook button", slot(3).open:IsShown(), false)
check("fallback: macro", slot(3).click:GetAttribute("macrotext"), "/cast First Aid")
M.state.professions[3][6] = 14
-- In combat the wiring waits.
M.state.combat = true
M.state.professions[1][6] = 30
Bars.Refresh()
check("in combat: not rewired", slot(1).open.spellOffset, 10)
M.state.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
check("after combat: rewired", slot(1).open.spellOffset, 30)
M.state.professions[1][6] = 10
Bars.Refresh()
-- An open window on this profession closes; on another one the tab is pressed.
_G.ProfessionsFrame = M.newWidget("ProfessionsFrame")
local pressed
local tab = M.newWidget()
tab.skillLine = 186
function tab:OnClick() pressed = self.skillLine end
ProfessionsFrame.rightProfessionTabs = { tab }
local closed = false
C_TradeSkillUI = { CloseTradeSkill = function() closed = true end }
_G.Professions = { IsSelectedProfession = function(line) return line == 171 end }
check("same profession open: closes", Bars.OpenProfession(171, 10), "closed")
check("closed", closed, true)
check("other profession: its tab", Bars.OpenProfession(186, 12), "tab")
check("tab pressed", pressed, 186)
ProfessionsFrame._shown = false
check("closed window: cast", Bars.OpenProfession(186, 12), "opened")
pressed = nil
ProfessionsFrame._shown = true
M.Fire("TRADE_SKILL_SHOW")
check("once shown, the wanted tab is pressed", pressed, 186)
M.state.time = M.state.time + 5
pressed = nil
M.Fire("TRADE_SKILL_LIST_UPDATE")
check("after the deadline nothing more", pressed, nil)
_G.ProfessionsFrame, _G.Professions, C_TradeSkillUI = nil, nil, nil

section("Reputation")
local function rep(i) return Bars.RepSlot(i).data and Bars.RepSlot(i).data.name end
check("Alliance default 1", rep(1), "Darnassus")
check("Alliance default 2", rep(2), "Gnomeregan")
check("Alliance default 3", rep(3), "Ironforge")
check("Alliance default 4", rep(4), "Stormwind")
check("standing text", Bars.RepSlot(3).standing:GetText(), "Honored")
check("value relative to the standing", Bars.RepSlot(3).valueText:GetText(), "3000/12000")
check("the faction list header was collapsed again", M.state.factions[1][10], true)
M.state.faction = "Horde"
check("Horde gets the Horde cities", Settings.Reps()[1], 76)
M.state.faction = "Alliance"
Settings.SetRep(1, 609)
check("choosing a faction", rep(1), "Cenarion Circle")
check("the others stay", rep(2), "Gnomeregan")
Settings.SetRep(1, 0)
check("empty slot hidden", Bars.RepSlot(1):IsShown(), false)
Settings.SetRep(1, 69)
M.state.sex = 3
ns.RefreshReputation()
check("standing by gender", Bars.RepSlot(4).standing:GetText(), "Friendly (f)")
M.state.sex = 2
ns.RefreshReputation()
Bars.RepSlot(1).click:GetScript("OnClick")(nil, "RightButton", false)
check("right-click opens the reputation tab", M.state.characterTab, "ReputationFrame")

section("Level number")
check("level shown", Bars.levelText:GetText(), "43")
M.Fire("PLAYER_LEVEL_UP", 44)
check("level up", Bars.levelText:GetText(), "44")
check("default colour: gold", Bars.levelText._textColor[1], ns.CFG.LEVEL_COLORS.GOLD[1])
Settings.Set("levelColor", "CLASS")
check("class colour", Bars.levelText._textColor[3], 0.93)
Settings.Set("levelColor", nil)
check("default style: classic ring", Bars.levelBox.ring[1]:IsShown(), true)
check("classic: no inner line", Bars.levelBox.line[1]:IsShown(), false)
Settings.Set("levelStyle", "GOLD")
local G = ns.CFG.GOLD
local tg, sg, bg = Bars.levelBox.ring[1]._gradient, Bars.levelBox.ring[3]._gradient, Bars.levelBox.ring[2]._gradient
check("gold: top MID up to LIGHT", tg and tg[2].g == G.MID[2] and tg[3].b == G.LIGHT[3], true)
check("gold: sides meet the top", sg and sg[3].g == tg[2].g, true)
check("gold: sides meet the bottom", bg and sg[2].g == bg[3].g, true)
check("gold: inner line", Bars.levelBox.line[1]:IsShown(), true)
Settings.Set("levelStyle", "NONE")
check("none: no box", Bars.levelBox.bg:IsShown(), false)
check("none: no ring", Bars.levelBox.ring[1]:IsShown(), false)
Settings.Set("levelStyle", TEST_VALUES.levelStyle)
check("box height from the font", Bars.levelBox:GetHeight(), 38 + 2 * 10)

section("Level badges")
local styles = table.concat(Bars.AvailableLevelStyles(), ",")
check("drawn badges always offered", styles:find("CREST", 1, true) ~= nil and styles:find("WINGS", 1, true) ~= nil, true)
check("Blizzard ring the client has", styles:find("RING_GOLD", 1, true) ~= nil, true)
check("Blizzard ring the client lacks", styles:find("RING_ORNATE", 1, true), nil)
local lb = Bars.levelBox
Settings.Set("levelStyle", "LAUREL")
check("laurel texture", lb.art._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeLaurel.tga")
check("art shown", lb.art:IsShown(), true)
check("no square behind it", lb.bg:IsShown(), false)
check("no ring", lb.ring[1]:IsShown(), false)
-- Two digits at 7 px each are narrower than the 38 px font: the middle
-- holds 38 + 2 * 10 and takes 54 % of the texture.
check("badge sized so the digits fit its middle", near(lb:GetHeight(), 58 / 0.54), true)
check("square badge", near(lb:GetWidth(), lb:GetHeight()), true)
check("art as big as the box", near(lb.art:GetWidth(), lb:GetWidth()), true)
Settings.Set("levelStyle", "WINGS")
check("wings: the cropped width", near(lb:GetWidth(), lb:GetHeight() * 468 / 256), true)
check("wings: empty margin cut off", lb.art._texCoord and near(lb.art._texCoord[1], 22 / 512), true)
local wingGap = slot(3)._points.BOTTOMLEFT[3] - (slot(2)._points.BOTTOMLEFT[3] + slot(2):GetWidth())
check("the bars make room for the wings", wingGap >= lb:GetWidth(), true)
-- The gap between bar 2 and bar 3 is the badge, its margin of 2 on each
-- side and the usual space between two bars.
check("but only just", near(wingGap, lb:GetWidth() + 2 * 2 + S("spacing")), true)
Settings.Set("levelStyle", "CREST")
check("crest: digits lifted", select(5, Bars.levelText:GetPoint("CENTER")) > 0, true)
Settings.Set("backdropShow", true)
Settings.Set("levelY", 20)
local badgeTop = -(14 + 1 + 25) / 2 + 20 + lb:GetHeight() / 2
check("moved up, the badge reaches above the text line", badgeTop > 0, true)
check("the backdrop covers the badge", near(Bars.backdrop._points.TOPLEFT[4], badgeTop + 6), true)
Settings.Set("levelY", nil)
Settings.Set("backdropShow", TEST_VALUES.backdropShow)
Settings.Set("levelStyle", "RING_GOLD")
check("ring: Blizzard atlas", lb.art._atlas, "communities-ring-gold")
check("open ring: dark disc behind", lb.disc:IsShown(), true)
check("ring: a circle", lb:GetWidth(), lb:GetHeight())
Settings.Set("levelStyle", "LAUREL")
check("drawn badge: no disc", lb.disc:IsShown(), false)
check("drawn badge: whole texture", lb.art._texCoord and lb.art._texCoord[2], 1)
check("digits centred again", select(5, Bars.levelText:GetPoint("CENTER")), 0)
Settings.Set("levelStyle", "RING_ORNATE")
check("missing art falls back to Classic", Bars.LevelStyle(), "CLASSIC")
ns.DB().levelStyle = "HEX"
check("a style no longer offered: Classic", Bars.LevelStyle(), "CLASSIC")
Settings.Set("levelStyle", "RING_ORNATE")
check("classic ring shown instead", lb.ring[1]:IsShown(), true)
check("no art then", lb.art:IsShown(), false)
Settings.Set("levelStyle", TEST_VALUES.levelStyle)

section("Position and size")
local c = Bars.container
check("anchored to the screen top", c._points.TOP[2], "TOP")
check("default y", c._points.TOP[4], -29)
check("default width", c:GetWidth(), 1180)
Settings.Set("width", 5000)
check("never wider than the screen", c:GetWidth(), 1920)
Settings.Set("width", nil)
check("height: text, gap and bar", c:GetHeight(), 14 + 1 + 25)
function c:GetCenter() return 1000, 500 end
function c:GetTop() return 1000 end
c:GetScript("OnDragStop")(c)
check("dragging stores x", S("x"), 40)
check("dragging stores y", S("y"), -80)
Settings.Set("x", nil); Settings.Set("y", TEST_VALUES.y)
check("unlocked by default: movable", c:IsMovable(), true)
ns.ToggleLock()
check("locked: not movable", c:IsMovable(), false)
check("locked: click-through", c._mouse, false)
ns.ToggleLock()

section("Space between text and bar")
local function nameY() return slot(1).nameText._points.BOTTOMLEFT[4] end
check("default: 1 px", nameY(), 1)
Settings.Set("textGap", 6)
check("the name moves up", nameY(), 6)
check("the value too", slot(1).valueText._points.BOTTOMRIGHT[4], 6)
check("the icon too", slot(1).icon._points.BOTTOMLEFT[4], 6)
check("the row grows", c:GetHeight(), 14 + 6 + 25)
check("the click area covers the text", slot(1).open._points.TOPLEFT[4], 14 + 6)
check("the reputation row moves down", Bars.RepSlot(2)._points.BOTTOMLEFT[4], -(14 + 6 + 25 + 4))
check("reputation names too", Bars.RepSlot(2).nameText._points.BOTTOMLEFT[4], 6)
Settings.Set("textGap", -3)
check("negative: into the bar", nameY(), -3)
Settings.Set("textGap", TEST_VALUES.textGap)

section("Empty part of the bars")
check("default: black at 60 %", table.concat(slot(1).bg._texColor, ","), "0,0,0,0.6")
Settings.Set("barBgColor", { 0.2, 0.3, 0.4 })
Settings.Set("barBgAlpha", 25)
check("colour and opacity", table.concat(slot(2).bg._texColor, ","), "0.2,0.3,0.4,0.25")
check("reputation bars too", Bars.RepSlot(1).bg._texColor[4], 0.25)
Settings.Set("barBgColor", TEST_VALUES.barBgColor)
Settings.Set("barBgAlpha", TEST_VALUES.barBgAlpha)

section("The level sits in the middle")
-- 2*barWidth + 1.5*spacing + levelGap/2 == width/2
local w, sp = c:GetWidth(), S("spacing")
local barWidth = slot(1):GetWidth()
local gap = slot(3)._points.BOTTOMLEFT[3] - (slot(2)._points.BOTTOMLEFT[3] + barWidth) - sp
check("centred", near(2 * barWidth + 1.5 * sp + gap / 2, w / 2), true)

section("Backdrop")
local bd = Bars.backdrop
check("off by default", bd:IsShown(), false)
Settings.Set("backdropShow", true)
check("shown", bd:IsShown(), true)
check("opacity 50 %", bd.bg._texColor[4], 0.5)
local row = 14 + 1 + 25
local topLeft, bottomRight = bd._points.TOPLEFT, bd._points.BOTTOMRIGHT
-- The level box (58 high, centred 25 below the row's middle) reaches lowest
-- of all? The reputation row ends at -(2*39+4) = -82; the box at
-- -19.5-25-29 = -73.5. The top: the box reaches -19.5-25+29 = -15.5, below 0.
check("top: the text line, plus padding", topLeft[4], 0 + 6)
check("left: padding", topLeft[3], -6)
check("bottom: the reputation row, plus padding", bottomRight[4], -(2 * row + 4) - 6)
check("right: padding", bottomRight[3], 6)
for i = 1, 4 do Settings.SetRep(i, 0) end
check("no reputation: the level box sets the bottom", bd._points.BOTTOMRIGHT[4], -row / 2 - 25 - 29 - 6)
Settings.Set("levelY", 40)
check("level box above the row: the top follows", bd._points.TOPLEFT[4], -row / 2 + 40 + 29 + 6)
Settings.Set("levelY", nil)
ns.DB().reps = nil
Settings.Changed("reps")
Settings.Set("backdropBorder", "GOLD")
Settings.Set("backdropBorderSize", 3)
check("gold border", bd.ring[1]._gradient ~= nil, true)
check("gold inner line", bd.line[1]:IsShown(), true)
Settings.Set("backdropBorder", "FLAT")
Settings.Set("backdropBorderColor", { 1, 0, 0, 1 })
check("flat border colour", bd.ring[2]._vertex[1], 1)
check("no inner line when flat", bd.line[1]:IsShown(), false)
Settings.Set("backdropAlpha", 20)
check("opacity", bd.bg._texColor[4], 0.2)
Settings.ResetProfile()
check("reset: back to the default backdrop", bd:IsShown(), Settings.DEFAULTS.backdropShow)
check("reset: an empty profile", next(ns.DB()), nil)
useTestValues()

section("Profiles")
Settings.Set("barHeight", 30)
check("setting stored", ns.DB().barHeight, 30)
check("applied", slot(1):GetHeight(), 30)
ns.SwitchProfile("Second")
check("save as keeps the values", S("barHeight"), 30)
Settings.Set("barHeight", 12)
ns.SwitchProfile("Default")
check("switching applies at once", slot(1):GetHeight(), 30)
ns.SwitchProfile("Second")
check("and back", slot(1):GetHeight(), 12)
ns.DeleteProfile("Second")
check("deleting falls back to Default", ns.ActiveProfile(), "Default")
Settings.Set("barHeight", nil)
check("a default is not stored", ns.DB().barHeight, nil)
Settings.Set("barHeight", 999)
check("values are clamped", S("barHeight"), 40)
Settings.Set("barHeight", nil)

section("Options window")
ns.Window.Open()
check("window shown", ns.Window.IsShown(), true)
local function shown(want)
    for _, fs in ipairs(M.fontStrings) do if fs._text == want then return true end end
    for _, f in ipairs(M.frames) do if f._text == want then return true end end
    return false
end
check("pages listed", shown("Reputation"), true)
local function sliderFor(label)
    for _, f in ipairs(M.frames) do
        local t = f._name and _G[f._name .. "Text"]
        if f._kind == "Slider" and t and t._text == label then return f end
    end
end
ns.Window.ShowPage("bars")
local height = sliderFor("Bar height")
check("bar height slider", height ~= nil, true)
height:GetScript("OnValueChanged")(height, 20)
check("the slider sets the value", S("barHeight"), 20)
local box = M.byName[height._name .. "Box"]
box:SetText("99")
box:GetScript("OnEnterPressed")(box)
check("the text field clamps", S("barHeight"), 40)
Settings.Set("barHeight", nil)
ns.Window.ShowPage("professions")
local skillCheck = M.byName["ForeverProgressBarsSkillCheck1"]
check("a checkbox per skill", skillCheck ~= nil, true)
check("ticked when shown", skillCheck:GetChecked(), true)
skillCheck:SetChecked(false)
skillCheck:GetScript("OnClick")(skillCheck)
check("unticking hides it", Settings.IsHidden("Alchemy", "ALCHEMY"), true)
Settings.SetHidden("Alchemy", false)
ns.Window.Toggle()
check("toggled closed", ns.Window.IsShown(), false)
check("interface options page", M.registered[1], "Forever Progress Bars")

section("Minimap button")
local mb = M.byName["ForeverProgressBarsMinimapButton"]
check("button exists", mb ~= nil, true)
mb:GetScript("OnClick")(mb, "LeftButton")
check("left-click opens the options", ns.Window.IsShown(), true)
mb:GetScript("OnClick")(mb, "LeftButton")
mb:GetScript("OnClick")(mb, "RightButton")
check("right-click locks", S("locked"), true)
mb:GetScript("OnClick")(mb, "RightButton")
Settings.Set("minimapShow", false)
check("can be hidden", mb:IsShown(), false)
Settings.Set("minimapShow", nil)

section("Slash command and status")
M.chat = {}
SlashCmdList["FOREVERPROGRESSBARS"]("status")
check("status prints", #M.chat > 3, true)
check("status names the client", M.chat[1]:find("1.60.1", 1, true) ~= nil, true)
SlashCmdList["FOREVERPROGRESSBARS"]("lock")
check("/fpb lock", S("locked"), true)
SlashCmdList["FOREVERPROGRESSBARS"]("unlock")
check("/fpb unlock", S("locked"), false)

section("Languages")
local base = ns.Locales.enUS
for code, strings in pairs(ns.Locales) do
    for key in pairs(base) do check(code .. " has " .. key, strings[key] ~= nil, true) end
    for key in pairs(strings) do check(code .. ": " .. key .. " is known", base[key] ~= nil, true) end
    for key, value in pairs(base) do
        local want = select(2, value:gsub("%%[ds]", ""))
        local got = strings[key] and select(2, strings[key]:gsub("%%[ds]", "")) or want
        check(code .. ": placeholders of " .. key, got, want)
    end
end
check("German umlauts", ns.Locales.deDE.OPT_BAR_HEIGHT, "Leistenhöhe")
-- The old addon wrote "Groesse", "Loeschen", "Hoehe": none of that is left.
for key, value in pairs(ns.Locales.deDE) do
    for _, bad in ipairs({ "oess", "oesch", "oehe", "aende", "ueber", "fuer", "Rueck", "schliess" }) do
        check("no umlaut workaround in " .. key .. " (" .. bad .. ")", value:find(bad), nil)
    end
end
ns.Window.Open()
ns.Window.ShowPage("bars")
ns.Locale.Set("deDE")
check("options relabel at once", shown("Leistenhöhe"), true)
check("pages relabel", shown("Leisten"), true)
check("language stored account wide", ForeverProgressBarsProfiles.language, "deDE")
ns.Locale.Set("AUTO")
check("back to English", shown("Bar height"), true)
ns.Window.Toggle()

section("Only SavedVariables, nothing private")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("CVar", 1, true), nil)
    check("no ChatPanel fonts in " .. f, src:find("ChatPanel", 1, true), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
