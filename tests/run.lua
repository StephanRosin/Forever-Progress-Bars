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
check("the backdrop as by default", Bars.backdrop:IsShown(), Settings.DEFAULTS.backdropShow)
check("the bar height by default", Bars.Slot(1):GetHeight(), Settings.DEFAULTS.barHeight)
check("locked as by default", Bars.container:IsMovable(), not Settings.DEFAULTS.locked)

-- The rest runs on a fixed layout, so it does not change with the defaults.
local TEST_VALUES = {
    y = -29, locked = false, width = 1180, barHeight = 25, textHeight = 14, textGap = 1, spacing = 13,
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
-- An open window on this profession closes; on another one it switches
-- with OpenTradeSkill. Blizzard's tabs are never pressed (in or out of
-- combat): that leaves the window tainted and WoW blames the addon.
_G.ProfessionsFrame = M.newWidget("ProfessionsFrame")
local pressed
local tab = M.newWidget()
tab.skillLine = 186
function tab:OnClick() pressed = self.skillLine end
ProfessionsFrame.rightProfessionTabs = { tab }
local closed, opened = false, {}
local current = 171
C_TradeSkillUI = { CloseTradeSkill = function() closed = true end,
                   OpenTradeSkill = function(id) opened[#opened + 1] = id; return true end,
                   GetBaseProfessionInfo = function() return { professionID = current } end }
_G.Professions = { IsSelectedProfession = function(line) return line == current end }
check("same profession open: closes", Bars.OpenProfession(171, 10), "closed")
check("closed", closed, true)
check("other profession: switched", Bars.OpenProfession(186, 12), "switched")
check("other profession: OpenTradeSkill with the skill line", opened[1], 186)
check("other profession: no tab pressed", pressed, nil)
ProfessionsFrame._shown = false
check("closed window: cast", Bars.OpenProfession(186, 12), "opened")
ProfessionsFrame._shown = true
M.Fire("TRADE_SKILL_SHOW")
check("once shown, the wanted profession wins", opened[#opened], 186)
check("once shown: no tab pressed", pressed, nil)
-- In combat the same way.
M.state.combat = true
opened = {}
check("in combat, window open: switched", Bars.OpenProfession(186, 12), "switched")
check("in combat: OpenTradeSkill", opened[1], 186)
ProfessionsFrame._shown = false
M.casts = {}
check("in combat, window closed: cast", Bars.OpenProfession(186, 12), "opened")
check("in combat: cast done", #M.casts, 1)
ProfessionsFrame._shown = true
check("in combat: the wanted profession wins", Bars.PressWantedTab(), "switched")
check("in combat: switched to it", opened[#opened], 186)
check("in combat: no tab pressed", pressed, nil)
current = 186
local before = #opened
Bars.PressWantedTab()
check("already shown: not switched again", #opened, before)
M.state.combat = false
M.state.time = M.state.time + 5
before = #opened
M.Fire("TRADE_SKILL_LIST_UPDATE")
check("after the deadline nothing more", #opened, before)
_G.ProfessionsFrame, _G.Professions, C_TradeSkillUI = nil, nil, nil

section("In combat: protected bars stay untouched")
do
    -- Each bar carries a secure click button, so bars and container are
    -- protected: in combat nothing may move, size, show or hide them.
    local blocked = {}
    local function guard(f, label)
        for _, m in ipairs({ "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight", "SetSize",
                             "Show", "Hide", "SetShown", "EnableMouse", "SetMovable" }) do
            local orig = f[m]
            f[m] = function(self, ...)
                if M.state.combat then blocked[#blocked + 1] = label .. ":" .. m end
                return orig(self, ...)
            end
        end
    end
    for i = 1, 4 do guard(Bars.Slot(i), "slot" .. i); guard(Bars.RepSlot(i), "rep" .. i) end
    local container = M.byName["ForeverProgressBarsFrame"]
    guard(container, "container")

    local wasX, wasLocked = S("x"), S("locked")
    Settings.Set("locked", true)
    M.state.combat = true
    M.state.skills[2][4] = 301          -- a skill-up in combat: only the value
    Bars.Refresh()
    ns.RefreshReputation()
    check("skill-up: nothing protected", table.concat(blocked, ","), "")
    check("skill-up: value updated at once", slot(1).valueText:GetText(), "301/375")
    Settings.SetHidden("Cooking", true) -- slot 4 empties: has to wait
    Settings.Set("x", 40)               -- moving: has to wait
    Settings.Set("locked", false)       -- unlocking: has to wait
    check("changes in combat: nothing protected", table.concat(blocked, ","), "")
    check("slot 4 still shown until combat ends", slot(4):IsShown(), true)

    M.state.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    check("after combat: slot 4 hidden", slot(4):IsShown(), false)
    check("after combat: moved", select(4, container:GetPoint("TOP")), 40)
    check("after combat: unlocked", container:IsMovable(), true)

    Settings.SetHidden("Cooking", false)
    Settings.Set("x", wasX)
    Settings.Set("locked", wasLocked)
    M.state.skills[2][4] = 300
    Bars.Refresh()
end

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
Settings.Set("levelStyle", "RANK")
check("rank medal offered", styles:find("RANK", 1, true) ~= nil, true)
check("rank: tiers by ten levels", Bars.RankTier(1) .. Bars.RankTier(9) .. Bars.RankTier(10) .. Bars.RankTier(59)
      .. Bars.RankTier(60) .. Bars.RankTier(70), "112677")
check("rank: the level's texture", lb.art._texture,
      "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeRank" .. Bars.RankTier(M.state.level) .. ".tga")
check("rank: digits lifted onto the medal", near(select(5, Bars.levelText:GetPoint("CENTER")), lb:GetHeight() * 56 / 512), true)
check("rank: margins cut off", near(lb:GetWidth(), lb:GetHeight() * 432 / 512), true)
local oldLevel = M.state.level
M.Fire("PLAYER_LEVEL_UP", 60)
check("level up: the new step at once", lb.art._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeRank7.tga")
M.state.level = oldLevel
-- A 1 at the front pulls left, at the end pushes right, 11 stays put, 25
-- needs nothing; 5 % of the font size.
local probe = Bars.levelText
local shown = probe:GetText()
local fontSize = select(2, probe:GetFont())
for _, case in ipairs({ { "18", -0.05 * fontSize }, { "21", 0.05 * fontSize }, { "11", 0 }, { "25", 0 } }) do
    probe:SetText(case[1])
    check("optical nudge " .. case[1], near(Bars.OpticalNudge(probe), case[2]), true)
end
probe:SetText(shown)
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
-- Automatic width: 60 % of the screen, at most 1180. The mock screen is
-- 1920 wide: 1152.
ns.DB().width = nil
Settings.Changed("width")
check("automatic width on this screen", c:GetWidth(), 1152)
check("automatic width: capped on a wide screen", Settings.AutoWidth(2383), 1180)
check("automatic width: a small screen", Settings.AutoWidth(1024), 614)
Settings.Set("width", 1180)
check("a width of your own", c:GetWidth(), 1180)
Settings.Set("width", 5000)
check("never wider than the screen", c:GetWidth(), 1920)
Settings.Set("width", TEST_VALUES.width)
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

local function RowHeightForTest() return S("textHeight") + S("textGap") + S("barHeight") end

section("Professions and reputation can be switched off")
do
    local rowH = RowHeightForTest()
    Settings.Set("showProfessions", false)
    check("professions hidden", slot(1):IsShown(), false)
    check("reputation takes their place", Bars.RepSlot(1)._points.BOTTOMLEFT[4], 0)
    Settings.Set("showProfessions", nil)
    check("professions back", slot(1):IsShown(), true)
    check("reputation below again", Bars.RepSlot(1)._points.BOTTOMLEFT[4] < 0, true)
    Settings.Set("showReputation", false)
    check("reputation hidden", Bars.RepSlot(1):IsShown(), false)
    Settings.Set("arrangement", "COLUMNS")
    check("columns: one column left", Bars.container:GetWidth(), S("columnWidth"))
    Settings.Set("arrangement", "COLUMN")
    Settings.Set("showReputation", nil)
    local firstY = slot(1)._points.BOTTOMLEFT[4]
    Settings.Set("showProfessions", false)
    check("column: reputation where the first profession was", Bars.RepSlot(1)._points.BOTTOMLEFT[4], firstY)
    Settings.Set("showProfessions", nil)
    Settings.Set("arrangement", nil)
end

section("Ranks, names and standings follow the language")
do
    check("rank in the profession bar", slot(1).standing:GetText(), "Master")
    check("rank from the cap", Bars.RankText(150), "Journeyman")
    Settings.Set("showRank", false)
    check("rank can be switched off", slot(1).standing:GetText(), "")
    Settings.Set("showRank", nil)
    ns.Locale.Set("deDE")
    check("German profession name", slot(1).nameText:GetText(), "Alchimie")
    check("German rank", slot(1).standing:GetText(), "Meister")
    local repText = Bars.RepSlot(1).standing:GetText()
    local isGerman = false
    for i = 1, 8 do if repText == ns.Locales.deDE["STANDING_" .. i] then isGerman = true end end
    check("German standing (the client speaks English)", isGerman, true)
    ns.Locale.Set("AUTO")
    check("back in English", slot(1).nameText:GetText(), "Alchemy")
end

section("Hide in combat or in a group")
do
    local drivers = {}
    _G.RegisterStateDriver = function(f, what, cond) drivers[f] = cond end
    _G.UnregisterStateDriver = function(f) drivers[f] = nil end
    local c = Bars.container
    check("nothing hidden by default", Bars.StripCondition(), nil)
    Settings.Set("hideInCombat", true)
    check("strip: Blizzard's secure driver", drivers[c], "[combat] hide; show")
    Settings.Set("hideInGroup", true)
    check("strip: combat and group", drivers[c], "[combat] hide; [group] hide; show")
    Settings.Set("hideInCombat", nil)
    Settings.Set("hideInGroup", nil)
    check("strip: driver gone", drivers[c], nil)
    -- A change in combat waits (setting up the driver is protected).
    M.state.combat = true
    Settings.Set("hideInCombat", true)
    check("in combat: not yet", drivers[c], nil)
    M.state.combat = false
    M.Fire("PLAYER_REGEN_ENABLED")
    check("after combat: set", drivers[c], "[combat] hide; show")
    Settings.Set("hideInCombat", nil)
    -- The XP bar on its own rules.
    local holder = Bars.XpHolder()
    Settings.Set("xpHideInCombat", true)
    M.Fire("PLAYER_REGEN_DISABLED")
    check("XP bar hidden in combat", holder:IsShown(), false)
    M.Fire("PLAYER_REGEN_ENABLED")
    check("XP bar back after combat", holder:IsShown(), true)
    _G.IsInGroup = function() return true end
    Settings.Set("xpHideInGroup", true)
    check("XP bar hidden in a group", holder:IsShown(), false)
    _G.IsInGroup = nil
    M.Fire("GROUP_ROSTER_UPDATE")
    check("XP bar back without a group", holder:IsShown(), true)
    Settings.Set("xpHideInCombat", nil)
    Settings.Set("xpHideInGroup", nil)
    _G.RegisterStateDriver, _G.UnregisterStateDriver = nil, nil
end

section("Position references")
do
    local c = Bars.container
    check("default: top centre", Bars.PositionPoint(), "TOP")
    -- The mock container reports where it is.
    local oldLeft, oldTop, oldCenter = c.GetLeft, c.GetTop, c.GetCenter
    function c:GetLeft() return 300 end
    function c:GetTop() return 1000 end
    function c:GetCenter() return 876, 980 end
    Settings.Set("xFrom", "LEFT")
    check("from the left: point", Bars.PositionPoint(), "TOPLEFT")
    check("from the left: x is the left edge", S("x"), 300)
    check("anchored at the screen's top left", c._points.TOPLEFT[2], "TOPLEFT")
    Settings.Set("yFrom", "CENTER")
    check("from the centre: point", Bars.PositionPoint(), "LEFT")
    check("from the centre: y is the strip's centre", S("y"), 980 - 540)
    Settings.Set("xFrom", "CENTER")
    check("both centre", Bars.PositionPoint(), "CENTER")
    check("x from the screen's middle again", S("x"), 876 - 960)
    Settings.Set("yFrom", nil)
    Settings.Set("xFrom", nil)
    c.GetLeft, c.GetTop, c.GetCenter = oldLeft, oldTop, oldCenter
    Settings.Set("x", nil); Settings.Set("y", TEST_VALUES.y)
    check("back to the top centre", Bars.PositionPoint(), "TOP")
end

section("Arrangement and scale")
do
    local c = Bars.container
    local levelBox = Bars.LevelBox and Bars.LevelBox() or nil
    local function at(bar) local p = bar._points.BOTTOMLEFT; return p[3], p[4], p[2] end
    local colW = S("columnWidth")
    check("default: in a row", S("arrangement"), "ROW")

    Settings.Set("arrangement", "COLUMNS")
    local x1, y1, rel = at(slot(1))
    check("columns: hangs from the top", rel, "TOPLEFT")
    check("columns: professions on the left", x1, 0)
    check("columns: bars are the column width", slot(1):GetWidth(), colW)
    local rx, ry = at(Bars.RepSlot(1))
    check("columns: reputation on the right", rx, colW + S("spacing"))
    check("columns: side by side", ry, y1)
    local _, y4 = at(slot(4))
    check("columns: stacked downwards", y4 < y1, true)
    check("columns: two columns wide", c:GetWidth(), 2 * colW + S("spacing"))
    check("level above: the bars start below it", y1 < -RowHeightForTest(), true)

    Settings.Set("levelPlace", "MIDDLE")
    rx = at(Bars.RepSlot(1))
    check("level in the middle: the columns make room", rx > colW + S("spacing"), true)
    local _, ym = at(slot(1))
    check("level in the middle: bars start at the top", ym, -RowHeightForTest())

    Settings.Set("levelPlace", "BOTTOM")
    local _, yb = at(slot(1))
    check("level below: bars start at the top", yb, -RowHeightForTest())
    check("level below: the container reaches past the bars", c:GetHeight() > -select(2, at(slot(4))), true)

    Settings.Set("arrangement", "COLUMN")
    Settings.Set("levelPlace", "TOP")
    local cx = at(Bars.RepSlot(1))
    local _, cy = at(Bars.RepSlot(1))
    local _, p4 = at(slot(4))
    check("one column: reputation under the professions", cx == 0 and cy < p4, true)
    check("one column: one bar wide", c:GetWidth(), colW)

    Settings.Set("arrangement", nil)
    Settings.Set("levelPlace", nil)
    check("back in a row: automatic width again", c:GetWidth(), TEST_VALUES.width)

    -- Scale: everything together, the position stays in screen pixels.
    Settings.Set("scale", 150)
    check("scaled", c:GetScale(), 1.5)
    check("position kept in screen pixels", c._points.TOP[4] * 1.5, S("y"))
    Settings.Set("scale", nil)
    check("unscaled again", c:GetScale(), 1)
end

section("Presets are read-only profiles")
do
    local own = ns.ActiveProfile()
    local list = ns.ProfileList()
    check("presets in the profile list", list[#list], ns.PresetName("COLUMN_XP"))
    check("own profiles first", list[1], own)
    for _, p in ipairs(Settings.PRESETS) do
        for k in pairs(p.values) do check(p.id .. ": " .. k .. " is a setting", Settings.DEFAULTS[k] ~= nil, true) end
        check(p.id .. " has a name", ns.L["PRESET_" .. p.id] ~= "PRESET_" .. p.id, true)
    end
    Settings.Set("locked", false)
    Settings.SetHidden("Cooking", true)
    ns.SwitchProfile(ns.PresetName("COLUMN_XP"))
    check("column preset: arrangement", S("arrangement"), "COLUMN")
    check("column preset: XP bar on", S("xpEnabled"), true)
    check("column preset: XP bar free and wide", S("xpRow") .. " " .. S("xpWidth"), "FREE 1161")
    check("column preset: from the left edge", S("xFrom") .. " " .. S("x"), "LEFT 10")
    check("column preset: badge rides on the fill", S("xpBadgeFollow"), true)
    check("own lock came along", S("locked"), false)
    check("own hidden skills came along", Settings.IsHidden("Cooking", "COOKING"), true)
    -- A change lasts until the next rebuild (a reload).
    M.chat = {}
    Settings.Set("barHeight", 33)
    check("changed for now", S("barHeight"), 33)
    check("told it is a preset", (M.chat[1] or ""):find(ns.L.MSG_PRESET_READONLY, 1, true) ~= nil, true)
    ns.RebuildPresets()
    check("back after a reload", S("barHeight"), Settings.DEFAULTS.barHeight)
    check("own lock kept over the rebuild", S("locked"), false)
    check("presets cannot be deleted", ns.DeleteProfile(ns.PresetName("COLUMN_XP")), false)
    ns.SwitchProfile(ns.PresetName("CLASSIC"))
    check("classic: a row", S("arrangement"), "ROW")
    check("classic: no XP bar", S("xpEnabled"), false)
    ns.SwitchProfile(own)
    check("back on the own profile", ns.ActiveProfile(), own)
    Settings.Set("locked", nil)
    Settings.SetHidden("Cooking", false)
end

section("Export and import")
do
    local Share = ns.Share
    local function copy(t)
        if type(t) ~= "table" then return t end
        local c = {}
        for k, v in pairs(t) do c[k] = copy(v) end
        return c
    end
    local saved = copy(ns.DB())
    Settings.Set("barHeight", 30)
    Settings.Set("arrangement", "COLUMNS")
    Settings.Set("barBgColor", { 0.5, 0.25, 0.125 })
    Settings.SetHidden("Cooking", true)
    local text = Share.Export()
    check("export starts with the marker", text:sub(1, 5), "FPB1:")
    -- Round trip: reset, import, the same settings again.
    Settings.ResetProfile()
    check("reset: default height", S("barHeight"), ns.Settings.DEFAULTS.barHeight)
    check("import accepted", Share.Import(text), true)
    check("imported: bar height", S("barHeight"), 30)
    check("imported: arrangement", S("arrangement"), "COLUMNS")
    check("imported: colour", S("barBgColor")[2], 0.25)
    check("imported: hidden skill", Settings.IsHidden("Cooking", "COOKING"), true)
    check("imported: layout applied", slot(1)._points.BOTTOMLEFT[2], "TOPLEFT")
    -- Rubbish, and strings that try to be code, change nothing.
    for _, bad in ipairs({ "", "hello", "FPB1:", "FPB1:t", "FPB1:tn1;", "FPB1:s99:x",
                           "FPB1:ts9:barHeightn1e999;}", "return os.exit()" }) do
        check("refused: " .. bad, (Share.Import(bad)), nil)
    end
    check("refused strings keep the profile", S("barHeight"), 30)
    -- Unknown keys and wrong types are skipped, the rest imports.
    local clean = Share.Decode("FPB1:ts9:barHeightn25;s7:unknownn1;s6:lockeds3:yes}")
    check("wrong type skipped", clean.locked, nil)
    check("unknown key skipped", clean.unknown, nil)
    check("known key kept", clean.barHeight, 25)
    -- Numbers are clamped to their range.
    Share.Import("FPB1:ts9:barHeightn999;}")
    check("clamped", S("barHeight"), ns.Settings.RANGES.barHeight[2])
    -- The options page: export fills the field, import reads it.
    local W = ns.Window
    if W and W.shareField and W.shareField.box then
        W.shareField.box:SetText(text)
    end
    local db = ns.DB()
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(saved) do db[k] = v end
    Settings.Changed(nil)
end

section("Own XP bar")
do
    local X = ns.XpBar
    check("off by default", S("xpEnabled"), false)
    check("text: current / max", X.Text("CURRENT_MAX", 2256, 24000), "2256 / 24000")
    check("text: with percent", X.Text("CURRENT_MAX_PERCENT", 2256, 24000), "2256 / 24000 (9%)")
    check("text: percent", X.Text("PERCENT", 2256, 24000), "9%")
    check("text: none", X.Text("NONE", 2256, 24000), "")
    -- Blizzard's template carries "XP: " in front: not used.
    _G.XP_STATUS_BAR_TEXT = "XP: %s/%s"
    check("text: no XP prefix", X.Text("CURRENT_MAX_PERCENT", 730, 23200), "730 / 23200 (3%)")
    _G.XP_STATUS_BAR_TEXT = nil
    M.state.xp, M.state.xpMax, M.state.rested = 730, 23200, 3000
    local lvl = M.state.level
    M.state.level = 20
    _G.StatusTrackingBarManager = M.newWidget("StatusTrackingBarManager")
    local xp = Bars.XpSlot()
    local c = Bars.container
    local rowH = RowHeightForTest()
    local gap = ns.CFG.REP_ROW_GAP
    check("hidden while off", xp:IsShown(), false)
    Settings.Set("xpEnabled", true)
    check("Blizzard's bars hidden", StatusTrackingBarManager:IsShown(), false)
    StatusTrackingBarManager:Show()
    StatusTrackingBarManager:GetScript("OnShow")(StatusTrackingBarManager)
    check("and kept hidden", StatusTrackingBarManager:IsShown(), false)
    check("shown", xp:IsShown(), true)
    check("on a plain holder of its own", xp._parent, Bars.XpHolder())
    check("as wide as the strip", xp:GetWidth(), c:GetWidth())
    check("title: the level", xp.nameText:GetText(), ns.L.XP_LEVEL:format(20))
    check("title: the numbers", xp.valueText:GetText(), "730 / 23200 (3%)")
    check("fill value", xp.sb:GetValue(), 730)
    check("rested part ahead of it", xp.rested:GetValue(), 730 + 3000)
    check("no click buttons: not protected", xp.click, nil)
    -- Row places (in a row): at the bottom, below the reputation row.
    local repY = Bars.RepSlot(1)._points.BOTTOMLEFT[4]
    check("bottom: below the reputation", xp._points.BOTTOMLEFT[4] < repY, true)
    Settings.Set("xpRow", "TOP")
    check("top: above the professions", xp._points.BOTTOMLEFT[4], rowH + gap)
    Settings.Set("xpRow", "MIDDLE")
    check("middle: right below the professions", xp._points.BOTTOMLEFT[4], -(gap + rowH))
    check("middle: the reputation row moves down", Bars.RepSlot(1)._points.BOTTOMLEFT[4], repY - (rowH + gap))
    -- Title fonts: a big level, the numbers as they were.
    local valueSize = select(2, xp.valueText:GetFont())
    local h0 = Bars.XpHeight()
    Settings.Set("xpLevelFontSize", 30)
    check("big level number", select(2, xp.nameText:GetFont()), 30)
    check("numbers unchanged", select(2, xp.valueText:GetFont()), valueSize)
    check("the row grows with it", Bars.XpHeight() > h0, true)
    Settings.Set("xpValueFontSize", 9)
    check("numbers smaller", select(2, xp.valueText:GetFont()), 9)
    Settings.Set("xpLevelFont", "Morpheus")
    check("level font of its own", xp.nameText:GetFont(), ns.Media.FontPath("Morpheus"))
    for _, k in ipairs({ "xpLevelFontSize", "xpValueFontSize", "xpLevelFont" }) do Settings.Set(k, nil) end
    -- The numbers' place: above (default), in or below the bar.
    local val = xp.valueText
    check("numbers: above, right by default", val._points.BOTTOMRIGHT and val._points.BOTTOMRIGHT[2], "TOPRIGHT")
    Settings.Set("xpValuePlace", "IN_CENTER")
    check("numbers: in the bar, middle", val._points.CENTER and val._points.CENTER[1], xp.sb)
    check("numbers: above the fill", val:GetParent():GetFrameLevel() > xp.sb:GetFrameLevel(), true)
    Settings.Set("xpValuePlace", "BELOW_LEFT")
    Settings.Set("xpValueX", 5)
    check("numbers: below, left", val._points.TOPLEFT and val._points.TOPLEFT[2], "BOTTOMLEFT")
    check("numbers: offset", val._points.TOPLEFT[3], 5)
    for _, k in ipairs({ "xpValuePlace", "xpValueX" }) do Settings.Set(k, nil) end
    -- Extra space to the other bars.
    local yMid = xp._points.BOTTOMLEFT[4]
    Settings.Set("xpGap", 10)
    check("more space above it", xp._points.BOTTOMLEFT[4], yMid - 10)
    check("and below it", Bars.RepSlot(1)._points.BOTTOMLEFT[4], repY - (rowH + gap) - 20)
    Settings.Set("xpGap", nil)
    -- Without a title line: only the bar, the numbers gone.
    Settings.Set("xpTitle", false)
    check("no title: no level text", xp.nameText:GetText(), "")
    check("no title: only the bar's height", Bars.XpHeight(), S("barHeight"))
    Settings.Set("xpTitle", nil)
    -- Stacked: one column, between professions and reputation.
    Settings.Set("arrangement", "COLUMN")
    local p4 = slot(4)._points.BOTTOMLEFT[4]
    local r1 = Bars.RepSlot(1)._points.BOTTOMLEFT[4]
    local xy = xp._points.BOTTOMLEFT[4]
    check("column: between the blocks", xy < p4 and xy > r1, true)
    check("column: as wide as the column", xp:GetWidth(), S("columnWidth"))
    Settings.Set("arrangement", "COLUMNS")
    check("two columns: middle means top", xp._points.BOTTOMLEFT[4], -Bars.XpHeight())
    check("two columns: over both", xp:GetWidth(), c:GetWidth())
    Settings.Set("arrangement", nil)
    -- Free: X from the screen's middle, Y from its top edge (for the top
    -- of the title line), no row in the strip, own width.
    local repRowY = Bars.RepSlot(1)._points.BOTTOMLEFT[4]
    Settings.Set("xpRow", "FREE")
    Settings.Set("xpFreeX", 30)
    Settings.Set("xpFreeY", -150)
    local _, rel, rp, fx, fy = xp:GetPoint("TOP")
    check("free: from the screen's top", rel == UIParent and rp == "TOP", true)
    check("free: X", fx, 30)
    check("free: Y for the title line's top", fy, -150 - (Bars.XpHeight() - S("barHeight")))
    check("free: the reputation row back in its place", Bars.RepSlot(1)._points.BOTTOMLEFT[4], -(rowH + gap))
    check("free: as wide as the strip", xp:GetWidth(), c:GetWidth())
    Settings.Set("xpWidth", 300)
    check("free: a width of its own", xp:GetWidth(), 300)
    for _, k in ipairs({ "xpFreeX", "xpFreeY", "xpWidth" }) do Settings.Set(k, nil) end
    Settings.Set("xpRow", nil)
    -- Tooltip in the bars' layout: title, then label / value lines.
    local lines = {}
    local oldAdd, oldDouble = GameTooltip.AddLine, GameTooltip.AddDoubleLine
    GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
    GameTooltip.AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. "=" .. r end
    xp:GetScript("OnEnter")(xp)
    check("tooltip: level as the title", lines[1], ns.L.XP_LEVEL:format(20))
    check("tooltip: experience", lines[2], ns.L.TIP_XP .. "=730 / 23200")
    check("tooltip: rested", lines[5], ns.L.TIP_XP_RESTED .. "=3000 (12%)")
    GameTooltip.AddLine, GameTooltip.AddDoubleLine = oldAdd, oldDouble
    xp:GetScript("OnLeave")(xp)
    -- A badge of its own instead of the text, on the bar.
    local rowBox = Bars.LevelBox()
    Settings.Set("xpLevelMode", "BADGE")
    local box = Bars.XpBadge()
    check("badge: a second badge", box ~= rowBox, true)
    check("badge: shown", box:IsShown(), true)
    check("badge: the level", box.text:GetText(), tostring(M.state.level))
    check("badge: no level text", xp.nameText:GetText(), "")
    check("badge: on the bar's left end", select(2, box:GetPoint("CENTER")), xp.sb)
    check("badge: in front of the bar", box:GetFrameLevel() > xp:GetFrameLevel(), true)
    Settings.Set("xpBadgePoint", "TOPRIGHT")
    Settings.Set("xpBadgeX", -6)
    Settings.Set("xpBadgeY", 3)
    local _, _, rp, bx, by = box:GetPoint("CENTER")
    check("badge: at any point of the bar", rp, "TOPRIGHT")
    check("badge: moved by its own X/Y", bx .. "," .. by, "-6,3")
    Settings.Set("xpBadgeFollow", true)
    local _, onTo, edge = box:GetPoint("CENTER")
    check("follow: on the fill's end", onTo, xp.sb:GetStatusBarTexture())
    check("follow: its top edge for a top point", edge, "TOPRIGHT")
    Settings.Set("xpBadgeFollow", nil)
    Settings.Set("xpBadgeFontSize", 40)
    check("badge: its own size", select(2, box.text:GetFont()), 40)
    check("row badge unchanged", select(2, rowBox.text:GetFont()), S("levelFontSize"))
    check("row badge still shown", rowBox:IsShown(), true)
    for _, k in ipairs({ "xpLevelMode", "xpBadgePoint", "xpBadgeX", "xpBadgeY", "xpBadgeFontSize" }) do
        Settings.Set(k, nil)
    end
    check("badge gone with the text mode", box:IsShown(), false)
    -- As a badge, the level's text size does not make the line taller.
    local plain = Bars.XpHeight()
    Settings.Set("xpLevelMode", "BADGE")
    Settings.Set("xpLevelFontSize", 40)
    check("badge: the text size does not move the bar", Bars.XpHeight(), plain)
    Settings.Set("xpLevelMode", nil)
    check("text: the text size does", Bars.XpHeight() > plain, true)
    Settings.Set("xpLevelFontSize", nil)
    check("text again", xp.nameText:GetText(), ns.L.XP_LEVEL:format(20))
    -- Hidden at the maximum level and with XP switched off.
    M.state.level = 60
    M.Fire("PLAYER_LEVEL_UP")
    check("max level: hidden", xp:IsShown(), false)
    M.state.level = 20
    M.state.xpOff = true
    M.Fire("DISABLE_XP_GAIN")
    check("XP switched off: hidden", xp:IsShown(), false)
    M.state.xpOff = nil
    Settings.Set("xpEnabled", nil)
    check("switched off: hidden", xp:IsShown(), false)
    check("switched off: Blizzard's bars back", StatusTrackingBarManager:IsShown(), true)
    _G.StatusTrackingBarManager = nil
    M.state.level = lvl
end

section("Level number can be hidden")
check("level box shown by default", Bars.LevelBox():IsShown(), true)
local slot3x = slot(3)._points.BOTTOMLEFT[3]
Settings.Set("levelShow", false)
check("level box hidden", Bars.LevelBox():IsShown(), false)
check("the row closes up", slot(3)._points.BOTTOMLEFT[3] < slot3x, true)
Settings.Set("levelShow", nil)
check("shown again", Bars.LevelBox():IsShown(), true)
-- Free: X from the screen's middle, Y from its top edge, no room kept.
Settings.Set("levelPlace", "FREE")
Settings.Set("levelOffsetX", 50)
Settings.Set("levelOffsetY", -20)
local _, rel, rp, fx, fy = Bars.LevelBox():GetPoint("TOP")
check("free: from the screen's top", rel == UIParent and rp == "TOP", true)
check("free: at X/Y", fx .. "," .. fy, "50,-20")
check("free: the row closes up", slot(3)._points.BOTTOMLEFT[3] < slot3x, true)
Settings.Set("arrangement", "COLUMN")
_, rel, rp, fx, fy = Bars.LevelBox():GetPoint("TOP")
check("free in a column too", fx .. "," .. fy, "50,-20")
Settings.Set("scale", 200)
_, rel, rp, fx, fy = Bars.LevelBox():GetPoint("TOP")
check("free: screen pixels at any scale", fx * 2 .. "," .. fy * 2, "50,-20")
Settings.Set("scale", nil)
for _, k in ipairs({ "arrangement", "levelPlace", "levelOffsetX", "levelOffsetY" }) do Settings.Set(k, nil) end
check("back in the row", slot(3)._points.BOTTOMLEFT[3], slot3x)

-- Free places from before (1.1.0/1.1.1: from the screen's middle) move to
-- the new reckoning once, to the same spot.
do
    local account = ns.AccountDB()
    account.freeFromTop = nil
    local db = ns.DB()
    db.levelPlace, db.levelOffsetY = "FREE", 100
    local boxHalf = Bars.LevelBox():GetHeight() / 2
    Bars.MigrateFreeToTop()
    check("migrated: the same spot from the top", S("levelOffsetY"), math.floor(100 + boxHalf - 540 + 0.5))
    check("migrated once", account.freeFromTop, true)
    local once = S("levelOffsetY")
    Bars.MigrateFreeToTop()
    check("not twice", S("levelOffsetY"), once)
    db.levelPlace, db.levelOffsetY = nil, nil
    Settings.Changed(nil)
end

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
-- The widgets are rows with a label and their control (Widgets.lua).
local function rowFor(label, field)
    for _, f in ipairs(M.frames) do
        if f[field] and f.label and f.label._text and f.label._text:find(label, 1, true)
           and f:IsShown() ~= false then
            return f
        end
    end
end
ns.Window.ShowPage("bars")
local height = rowFor("Bar height", "slider")
check("bar height slider", height ~= nil, true)
height.slider:GetScript("OnValueChanged")(height.slider, 20, true)
check("the slider sets the value", S("barHeight"), 20)
height.edit:SetText("30")
height.edit:GetScript("OnEnterPressed")(height.edit)
check("the number box sets it", S("barHeight"), 30)
height.edit:SetText("99")
height.edit:GetScript("OnEnterPressed")(height.edit)
check("out of range: refused", S("barHeight"), 30)
Settings.Set("barHeight", nil)
ns.Window.ShowPage("professions")
local skillRow = rowFor("Alchemy", "box")
check("a checkbox per skill", skillRow ~= nil, true)
check("ticked when shown", skillRow.box:GetChecked(), true)
skillRow.box:GetScript("OnClick")(skillRow.box)
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
-- Blizzard's addon compartment: the same clicks through the TOC's globals.
ForeverProgressBars_OnAddonCompartmentClick("ForeverProgressBars", "LeftButton")
check("compartment click opens the options", ns.Window.IsShown(), true)
ForeverProgressBars_OnAddonCompartmentClick("ForeverProgressBars", "LeftButton")
check("compartment click again: closed", ns.Window.IsShown(), false)
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
