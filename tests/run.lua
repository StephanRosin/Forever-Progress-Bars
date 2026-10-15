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
check("an empty profile gets the defaults", S("xpBadgeStyle"), Settings.DEFAULTS.xpBadgeStyle)
check("the backdrop as by default", Bars.backdrop:IsShown(), Settings.DEFAULTS.backdropShow)
check("the bar height by default", Bars.Slot(1):GetHeight(), Settings.DEFAULTS.barHeight)
check("locked as by default", Bars.container:IsMovable(), not Settings.DEFAULTS.locked)

-- The rest runs on a fixed layout, so it does not change with the defaults.
local TEST_VALUES = {
    y = -29, locked = false, width = 1180, barHeight = 25, textHeight = 14, textGap = 1, spacing = 13,
    segmentWidth = 22, labelFontSize = 14, iconSize = 18, iconGap = 1,
    barBgColor = { 0, 0, 0 }, barBgAlpha = 60,
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
-- The level shows on the XP bar's badge (the strip has none of its own).
M.state.xp, M.state.xpMax = 730, 23200
Settings.Set("xpEnabled", true)
Settings.Set("xpLevelMode", "BADGE")
Settings.Set("xpBadgeStyle", "CLASSIC")
Settings.Set("xpBadgeFontSize", 38)
Settings.Set("xpBadgePadX", 10)
local badge = Bars.XpBadge()
check("level shown", badge.text:GetText(), "43")
M.Fire("PLAYER_LEVEL_UP", 44)
check("level up", badge.text:GetText(), "44")
check("default colour: gold", badge.text._textColor[1], ns.CFG.LEVEL_COLORS.GOLD[1])
Settings.Set("xpBadgeColor", "CLASS")
check("class colour", badge.text._textColor[3], 0.93)
Settings.Set("xpBadgeColor", nil)
check("default style: classic ring", badge.ring[1]:IsShown(), true)
check("classic: no inner line", badge.line[1]:IsShown(), false)
Settings.Set("xpBadgeStyle", "GOLD")
local G = ns.CFG.GOLD
local tg, sg, bg = badge.ring[1]._gradient, badge.ring[3]._gradient, badge.ring[2]._gradient
check("gold: top MID up to LIGHT", tg and tg[2].g == G.MID[2] and tg[3].b == G.LIGHT[3], true)
check("gold: sides meet the top", sg and sg[3].g == tg[2].g, true)
check("gold: sides meet the bottom", bg and sg[2].g == bg[3].g, true)
check("gold: inner line", badge.line[1]:IsShown(), true)
Settings.Set("xpBadgeStyle", "NONE")
check("none: no box", badge.bg:IsShown(), false)
check("none: no ring", badge.ring[1]:IsShown(), false)
Settings.Set("xpBadgeStyle", "CLASSIC")
check("box height from the font", badge:GetHeight(), 38 + 2 * 10)

section("Level badges")
local styles = table.concat(Bars.AvailableLevelStyles(), ",")
check("drawn badges always offered", styles:find("CREST", 1, true) ~= nil and styles:find("WINGS", 1, true) ~= nil, true)
check("Blizzard ring the client has", styles:find("RING_GOLD", 1, true) ~= nil, true)
check("Blizzard ring the client lacks", styles:find("RING_ORNATE", 1, true), nil)
local lb = badge
Settings.Set("xpBadgeStyle", "LAUREL")
check("laurel texture", lb.art._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeLaurel.tga")
check("art shown", lb.art:IsShown(), true)
check("no square behind it", lb.bg:IsShown(), false)
check("no ring", lb.ring[1]:IsShown(), false)
-- Two digits at 7 px each are narrower than the 38 px font: the middle
-- holds 38 + 2 * 10 and takes 54 % of the texture.
check("badge sized so the digits fit its middle", near(lb:GetHeight(), 58 / 0.54), true)
check("square badge", near(lb:GetWidth(), lb:GetHeight()), true)
check("art as big as the box", near(lb.art:GetWidth(), lb:GetWidth()), true)
Settings.Set("xpBadgeStyle", "WINGS")
check("wings: the cropped width", near(lb:GetWidth(), lb:GetHeight() * 468 / 256), true)
check("wings: empty margin cut off", lb.art._texCoord and near(lb.art._texCoord[1], 22 / 512), true)
Settings.Set("xpBadgeStyle", "CREST")
check("crest: digits lifted", select(5, badge.text:GetPoint("CENTER")) > 0, true)
Settings.Set("xpBadgeStyle", "RANK")
check("rank medal offered", styles:find("RANK", 1, true) ~= nil, true)
check("rank: tiers by ten levels", Bars.RankTier(1) .. Bars.RankTier(9) .. Bars.RankTier(10) .. Bars.RankTier(59)
      .. Bars.RankTier(60) .. Bars.RankTier(70), "112677")
check("rank: the level's texture", lb.art._texture,
      "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeRank" .. Bars.RankTier(M.state.level) .. ".tga")
check("rank: digits lifted onto the medal", near(select(5, badge.text:GetPoint("CENTER")), lb:GetHeight() * 56 / 512), true)
check("rank: margins cut off", near(lb:GetWidth(), lb:GetHeight() * 432 / 512), true)
local oldLevel = M.state.level
M.Fire("PLAYER_LEVEL_UP", 60)
check("level up: the new step at once", lb.art._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeRank7.tga")
M.state.level = oldLevel
-- A 1 at the front pulls left, at the end pushes right, 11 stays put, 25
-- needs nothing; 5 % of the font size.
local probe = badge.text
local shown = probe:GetText()
local fontSize = select(2, probe:GetFont())
for _, case in ipairs({ { "18", -0.05 * fontSize }, { "21", 0.05 * fontSize }, { "11", 0 }, { "25", 0 } }) do
    probe:SetText(case[1])
    check("optical nudge " .. case[1], near(Bars.OpticalNudge(probe), case[2]), true)
end
probe:SetText(shown)
Settings.Set("xpBadgeStyle", "RING_GOLD")
check("ring: Blizzard atlas", lb.art._atlas, "communities-ring-gold")
check("open ring: dark disc behind", lb.disc:IsShown(), true)
check("ring: a circle", lb:GetWidth(), lb:GetHeight())
Settings.Set("xpBadgeStyle", "LAUREL")
check("drawn badge: no disc", lb.disc:IsShown(), false)
check("drawn badge: whole texture", lb.art._texCoord and lb.art._texCoord[2], 1)
check("digits centred again", select(5, badge.text:GetPoint("CENTER")), 0)
Settings.Set("xpBadgeStyle", "RING_ORNATE")
check("missing art falls back to Classic", Bars.LevelStyle(Bars.XP_BADGE), "CLASSIC")
ns.DB().xpBadgeStyle = "HEX"
check("a style no longer offered: Classic", Bars.LevelStyle(Bars.XP_BADGE), "CLASSIC")
Settings.Set("xpBadgeStyle", "RING_ORNATE")
check("classic ring shown instead", lb.ring[1]:IsShown(), true)
check("no art then", lb.art:IsShown(), false)
Settings.Set("xpBadgeStyle", "CLASSIC")
for _, k in ipairs({ "xpEnabled", "xpLevelMode", "xpBadgeStyle", "xpBadgeFontSize", "xpBadgePadX" }) do
    Settings.Set(k, nil)
end

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
    check("columns: bars start at the top", y1, -RowHeightForTest())

    Settings.Set("arrangement", "COLUMN")
    local cx = at(Bars.RepSlot(1))
    local _, cy = at(Bars.RepSlot(1))
    local _, p4 = at(slot(4))
    check("one column: reputation under the professions", cx == 0 and cy < p4, true)
    check("one column: one bar wide", c:GetWidth(), colW)

    -- One under the other: their own gap.
    local _, y2 = at(slot(2))
    check("one column: rows rowGap apart", y2, y1 - RowHeightForTest() - S("rowGap"))
    Settings.Set("rowGap", 10)
    local _, y2b = at(slot(2))
    check("one column: the gap counts", y2b, y1 - RowHeightForTest() - 10)
    Settings.Set("rowGap", nil)
    Settings.Set("arrangement", nil)
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
    local gap = S("rowGap")
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
    -- The XP row is as tall as its own bar and title, not the bars' row.
    local xpH = Bars.XpHeight()
    check("middle: right below the professions", xp._points.BOTTOMLEFT[4], -(gap + xpH))
    check("middle: the reputation row moves down", Bars.RepSlot(1)._points.BOTTOMLEFT[4], repY - (xpH + gap))
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
    check("and below it", Bars.RepSlot(1)._points.BOTTOMLEFT[4], repY - (xpH + gap) - 20)
    Settings.Set("xpGap", nil)
    -- Without a title line: only the bar, the numbers gone.
    Settings.Set("xpTitle", false)
    check("no title: no level text", xp.nameText:GetText(), "")
    check("no title: only the bar's height", Bars.XpHeight(), ns.XpBar.Height())
    check("its height is not the bars' height", ns.XpBar.Height(), Settings.DEFAULTS.barHeight)
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
    check("free: Y for the title line's top", fy, -150 - (Bars.XpHeight() - ns.XpBar.Height()))
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
    Settings.Set("xpLevelMode", "BADGE")
    local box = Bars.XpBadge()
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

section("Free places from before")
-- Free places from before (1.1.0/1.1.1: from the screen's middle) move to
-- the new reckoning once, to the same spot.
do
    local account = ns.AccountDB()
    account.freeFromTop = nil
    local db = ns.DB()
    db.xpRow, db.xpFreeY = "FREE", 100
    local barHalf = S("barHeight") / 2
    local title = Bars.XpHeight() - S("barHeight")
    Bars.MigrateFreeToTop()
    check("migrated: the same spot from the top", S("xpFreeY"), math.floor(100 + barHalf + title - 540 + 0.5))
    check("migrated once", account.freeFromTop, true)
    local once = S("xpFreeY")
    Bars.MigrateFreeToTop()
    check("not twice", S("xpFreeY"), once)
    db.xpRow, db.xpFreeY = nil, nil
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
check("the reputation row moves down", Bars.RepSlot(2)._points.BOTTOMLEFT[4], -(14 + 6 + 25 + S("rowGap")))
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

section("Space between the bars")
local w, sp = c:GetWidth(), S("spacing")
local barWidth = slot(1):GetWidth()
check("four bars and three gaps fill the row", near(4 * barWidth + 3 * sp, w), true)
check("side by side: spacing apart", near(slot(3)._points.BOTTOMLEFT[3] - slot(2)._points.BOTTOMLEFT[3], barWidth + sp), true)
Settings.Set("rowGap", 9)
check("the reputation row: rowGap below", Bars.RepSlot(1)._points.BOTTOMLEFT[4], -(RowHeightForTest() + 9))
Settings.Set("rowGap", nil)

section("Backdrop")
local bd = Bars.backdrop
check("off by default", bd:IsShown(), false)
Settings.Set("backdropShow", true)
check("shown", bd:IsShown(), true)
check("opacity 50 %", bd.bg._texColor[4], 0.5)
local row = 14 + 1 + 25
local topLeft, bottomRight = bd._points.TOPLEFT, bd._points.BOTTOMRIGHT
check("top: the text line, plus padding", topLeft[4], 0 + 6)
check("left: padding", topLeft[3], -6)
check("bottom: the reputation row, plus padding", bottomRight[4], -(2 * row + 4) - 6)
check("right: padding", bottomRight[3], 6)
for i = 1, 4 do Settings.SetRep(i, 0) end
check("no reputation: the professions set the bottom", bd._points.BOTTOMRIGHT[4], -row - 6)
ns.DB().reps = nil
Settings.Changed("reps")
check("no border unless asked", bd.ring[1]:IsShown(), false)
Settings.Set("backdropBorderShow", true)
Settings.Set("backdropBorder", "GOLD")
Settings.Set("backdropBorderSize", 3)
check("gold border", bd.ring[1]._gradient ~= nil, true)
Settings.Set("backdropShow", false)
check("border without background: shown", bd:IsShown() and bd.ring[1]:IsShown(), true)
check("border without background: no fill", bd.bg:IsShown(), false)
Settings.Set("backdropShow", true)
check("background back", bd.bg:IsShown(), true)
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

section("XP lines")
do
    local I = ns.XpInfo
    for _, id in ipairs(I.IDS) do check(id .. " off by default", S("xpInfo" .. id), false) end
    check("under a minute", I.Duration(59), "< 1m")
    check("minutes", I.Duration(11 * 60 + 5), "11m")
    check("hours keep the minutes", I.Duration(3600), "1h 0m")
    check("days", I.Duration(2 * 86400 + 14 * 3600 + 11 * 60), "2d 14h 11m")
    check("gain", I.Gain(100, 1000, 250), 150)
    check("gain across a level-up", I.Gain(900, 1000, 50), 150)
    check("no rate without XP", I.PerHour(0, 600), nil)
    check("rate", I.PerHour(500, 1800), 1000)

    -- A fresh login with /played muted in the chat.
    M.state.level, M.state.xp, M.state.xpMax = 20, 1000, 10000
    M.state.serverTime = 1800000000
    local chat = M.newWidget("ChatFrame1")
    chat._events.TIME_PLAYED_MSG = true
    function chat:IsEventRegistered(e) return self._events[e] == true end
    _G.ChatFrame1 = chat
    local asked = 0
    _G.RequestTimePlayed = function() asked = asked + 1 end
    _G.C_QuestLog = { GetAllCompletedQuestIDs = function() return { 1, 2, 3 } end }
    Settings.Set("xpEnabled", true)
    Settings.Set("xpInfoLevelTime", true)
    check("/played asked once", asked, 1)
    check("chat frame muted meanwhile", chat._events.TIME_PLAYED_MSG, nil)
    M.Fire("PLAYER_ENTERING_WORLD", true, false)
    check("not asked again", asked, 1)
    M.Fire("TIME_PLAYED_MSG", 99999, 3 * 3600)
    M.RunTimers()
    check("chat frame listens again", chat._events.TIME_PLAYED_MSG, true)
    local lvl = I.TextOf("LevelTime")
    check("level time shown", lvl:IsShown(), true)
    check("level time", lvl:GetText(), "Time this level: 3h 0m")
    check("at its place", lvl._points.BOTTOMLEFT ~= nil, true)
    M.state.serverTime = 1800000000 + 600
    I.Update()
    check("level time runs on", lvl:GetText(), "Time this level: 3h 10m")

    -- Session, rate, time to level.
    for _, id in ipairs({ "SessionTime", "PerHour", "ToLevel", "Quests" }) do Settings.Set("xpInfo" .. id, true) end
    check("session", I.TextOf("SessionTime"):GetText(), "Time this session: 10m")
    check("no rate yet", I.TextOf("PerHour"):GetText(), "-- XP/hour")
    check("no estimate yet", I.TextOf("ToLevel"):GetText(), "Next level in ~--")
    M.state.xp = 2000
    M.Fire("PLAYER_XP_UPDATE", "player")
    check("rate: 1000 XP in 10 minutes", I.TextOf("PerHour"):GetText(), "6000 XP/hour")
    check("8000 left at 6000 an hour", I.TextOf("ToLevel"):GetText(), "Next level in ~1h 20m")
    check("quests on the character", I.TextOf("Quests"):GetText(), "Quests completed: 3")
    _G.C_QuestLog.GetAllCompletedQuestIDs = function() return { 1, 2, 3, 4 } end
    M.Fire("QUEST_TURNED_IN", 4, 100, 0)
    M.RunTimers()
    check("a quest handed in counts", I.TextOf("Quests"):GetText(), "Quests completed: 4")

    -- Places and offsets, the same for every line.
    Settings.Set("xpInfoQuestsPlace", "IN_LEFT")
    Settings.Set("xpInfoQuestsX", 12)
    local p = I.TextOf("Quests")._points.LEFT
    check("in the bar, left, moved", p and p[3], 4 + 12)

    -- Level-up: the level time starts again, the session goes on.
    M.Fire("PLAYER_LEVEL_UP", 21)
    I.Update()
    check("new level from zero", lvl:GetText(), "Time this level: < 1m")
    -- /reload keeps the session, a fresh login starts a new one.
    M.Fire("PLAYER_ENTERING_WORLD", false, true)
    check("reload keeps the session", I.TextOf("SessionTime"):GetText(), "Time this session: 10m")
    M.Fire("PLAYER_ENTERING_WORLD", true, false)
    check("login starts a new one", I.TextOf("SessionTime"):GetText(), "Time this session: < 1m")

    -- Rested: in the bar on the right, only while there is rested XP.
    M.state.rested = 2500
    Settings.Set("xpInfoRested", true)
    local rest = I.TextOf("Rested")
    check("rested shown", rest:IsShown(), true)
    check("rested text", rest:GetText(), "Rested: 2500 XP (25%)")
    check("in the bar, right", rest._points.RIGHT ~= nil, true)
    M.state.rested = nil
    M.Fire("UPDATE_EXHAUSTION")
    check("no rested XP: hidden", rest:IsShown(), false)
    M.state.rested = 100
    M.Fire("UPDATE_EXHAUSTION")
    check("back when rested again", rest:IsShown(), true)
    M.state.rested = nil

    -- Off again: hidden.
    Settings.Set("xpInfoQuests", false)
    check("switched off", I.TextOf("Quests"):IsShown(), false)

    -- The options page: one block per line, all alike.
    local rows = nil
    for _, page in ipairs(ns.Window.PAGES) do if page.id == "xpinfo" then rows = page.rows() end end
    check("own page", rows ~= nil, true)
    check("header, hint and six blocks of five", rows and #rows, 2 + 6 * 5)
    for _, id in ipairs(I.IDS) do
        Settings.Set("xpInfo" .. id, false)
    end
    Settings.Set("xpEnabled", false)
    _G.ChatFrame1, _G.RequestTimePlayed, _G.C_QuestLog = nil, nil, nil
    M.state.level = 43
end

section("XP bar style")
do
    local X = ns.XpBar
    M.state.xp, M.state.xpMax, M.state.rested = 730, 23200, 0
    M.state.level = 20
    M.atlases["UI-HUD-ExperienceBar-Frame"] = true
    _G.StatusTrackingBarManager = M.newWidget("StatusTrackingBarManager")
    Settings.Set("xpEnabled", true)
    local xp = Bars.XpSlot()
    local function parts(id) return xp.styleParts and xp.styleParts[id] end
    local function rows()
        local byLabel = {}
        for _, page in ipairs(ns.Window.PAGES) do
            if page.id:sub(1, 2) == "xp" then for _, r in ipairs(page.rows()) do byLabel[r.label] = r end end
        end
        return byLabel
    end
    check("forever by default", S("xpStyle"), "FOREVER")
    check("own: our texture", xp.sb._barTex, "Interface\\TargetingFrame\\UI-StatusBar")
    check("own: rim shown", xp.borders[1]:IsShown(), true)
    check("six styles (Own went into Forever, the ring left)", #X.STYLES, 6)
    for _, id in ipairs(X.STYLES) do
        check("style " .. id .. " named", ns.L["XP_STYLE_" .. id] ~= nil, true)
    end

    Settings.Set("xpStyle", "BLIZZARD")
    check("blizzard: Blizzard's fill", xp.sb._barTex, "UI-HUD-ExperienceBar-Fill-Experience")
    check("blizzard: fill not tinted", table.concat(xp.sb._color, ","), "1,1,1,1")
    check("blizzard: Blizzard's background", xp.bg._atlas, "UI-HUD-ExperienceBar-Background")
    check("blizzard: prediction for the rested part", xp.rested._barTex, "UI-HUD-ExperienceBar-Fill-Prediction")
    check("blizzard: rim hidden", xp.borders[1]:IsShown(), false)
    check("blizzard: frame shown", parts("BLIZZARD").over:IsShown(), true)
    local shown, art = 0, true
    for _, d in ipairs(xp.dividers) do
        if d:IsShown() then
            shown = shown + 1
            if d._atlas ~= "ui-hud-experiencebar-divider" then art = false end
        end
    end
    check("blizzard: 20 segments", shown, 19)
    check("blizzard: Blizzard's dividers", art, true)

    M.state.rested = 3000
    M.Fire("UPDATE_EXHAUSTION")
    check("blizzard rested: the fill stays purple", xp.sb._barTex, "UI-HUD-ExperienceBar-Fill-Experience")
    check("blizzard rested: the rested part shows", xp.rested:IsShown(), true)
    M.state.rested = 0
    M.Fire("UPDATE_EXHAUSTION")

    -- The badge riding on the fill works in every style with a fill.
    Settings.Set("xpLevelMode", "BADGE")
    Settings.Set("xpBadgeFollow", true)
    local box = Bars.XpBadge()
    check("blizzard: badge rides on the fill", select(2, box:GetPoint("CENTER")), xp.sb:GetStatusBarTexture())
    Settings.Set("xpStyle", "FOREVER")
    check("own: badge rides on the fill", select(2, box:GetPoint("CENTER")), xp.sb:GetStatusBarTexture())
    check("own again: our texture", xp.sb._barTex, "Interface\\TargetingFrame\\UI-StatusBar")
    check("own again: our colour", xp.sb._color[1], S("xpColor" .. S("xpStyle"))[1])
    check("own again: Blizzard's frame gone", parts("BLIZZARD").over:IsShown(), false)
    check("own again: rim shown", xp.borders[1]:IsShown(), true)
    local thin = true
    for _, d in ipairs(xp.dividers) do if d:IsShown() and d._w ~= 1 then thin = false end end
    check("own again: our dividers", thin, true)

    -- The colour pickers only where a style takes our colours.
    check("colour row: usable for own", rows().OPT_XP_COLOR.enabled(), true)
    Settings.Set("xpStyle", "BLIZZARD")
    check("colour row: dimmed for blizzard", rows().OPT_XP_COLOR.enabled(), false)

    -- Forever in the other Forever addons' look: the rim, ground, marker,
    -- plate and header as set.
    Settings.Set("xpStyle", "FOREVER")
    local LOOK = { xpBorder = "GOLD", xpBorderSize = 2, xpBgColor = { 0.047, 0.047, 0.055 }, xpBgAlpha = 82,
        xpMarker = true, xpHeaderPlate = true, xpLevelPlace = "ABOVE_CENTER", xpLevelFontSize = 18,
        xpLevelColorOwn = true, xpLevelColor = { 1, 0.82, 0.29 } }
    for k, v in pairs(LOOK) do Settings.Set(k, v) end
    check("colour row: usable for forever", rows().OPT_XP_COLOR.enabled(), true)
    check("forever: our texture", xp.sb._barTex, "Interface\\TargetingFrame\\UI-StatusBar")
    check("forever: our colour", xp.sb._color[1], S("xpColor" .. S("xpStyle"))[1])
    check("forever: gold rim", xp.borders[1]:IsShown() and xp.borders[1]._gradient ~= nil, true)
    check("forever: dark background", xp.bg._texColor[4], 0.82)
    check("forever: no Blizzard frame", parts("BLIZZARD").over:IsShown(), false)
    check("forever: fill inside a two-pixel rim", xp.sb._points.TOPLEFT[3], 2 * ns.Bars.OnePixel(xp))
    check("forever: the badge may be chosen", Bars.BadgeOnXp(), true)
    check("forever: no plate under the badge", xp.plate == nil or not xp.plate:IsShown(), true)
    check("forever: level choice usable", rows().OPT_XP_LEVEL_MODE.enabled == nil, true)
    Settings.Set("xpLevelMode", "TEXT")
    check("forever: level as text", xp.nameText:GetText(), "Level 20")
    check("forever: no badge with text", Bars.BadgeOnXp(), false)
    check("forever: level in the header gold", xp.nameText._textColor[1], 1)
    check("forever: level in the header size", select(2, xp.nameText:GetFont()), 18)
    check("forever: header plate shown", xp.plate and xp.plate:IsShown(), true)
    check("forever: level on the plate", xp.nameText._parent, xp.plate)
    check("forever: plate fits the text", xp.plate:GetWidth(), xp.nameText:GetStringWidth() + 28)
    check("forever: plate centred above", xp.plate._points.BOTTOM ~= nil, true)
    Settings.Set("xpLevelPlace", "BELOW_RIGHT")
    check("forever: plate goes where the level goes", xp.plate._points.TOPRIGHT ~= nil, true)
    Settings.Set("xpLevelPlace", "ABOVE_CENTER")
    Settings.Set("xpHeaderPlate", false)
    check("forever: plate can go", xp.plate:IsShown(), false)
    check("forever: level stays without the plate", xp.nameText:GetText(), "Level 20")
    Settings.Set("xpHeaderPlate", true)
    check("forever: plate back", xp.plate.bg:IsShown(), true)
    local r = rows()
    check("forever with text: badge rows dimmed", r.OPT_XP_BADGE_FOLLOW.enabled(), false)
    check("forever with text: badge look dimmed", r.OPT_LEVEL_STYLE.enabled(), false)
    Settings.Set("xpLevelMode", "BADGE")
    check("forever with the badge: level font dimmed", r.OPT_XP_LEVEL_FONT.enabled(), false)
    local marker = parts("FOREVER").marker
    check("forever: a marker at the end of the fill", marker:IsShown(), true)
    check("forever: the marker hangs on the fill", marker._points.CENTER[1], xp.sb:GetStatusBarTexture())
    check("forever: our gold marker", marker._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\BadgeMarker.tga")
    for k in pairs(LOOK) do Settings.Set(k, nil) end
    check("own after forever: black rim", xp.borders[1]._vertex[1], 0)
    check("own after forever: fill inside one pixel", xp.sb._points.TOPLEFT[3], ns.Bars.OnePixel(xp))
    check("own after forever: plate hidden", xp.plate:IsShown(), false)
    check("own after forever: no marker", parts("FOREVER").marker:IsShown(), false)
    Settings.Set("xpBorder", "NONE")
    check("no rim: hidden", xp.borders[1]:IsShown(), false)
    check("no rim: the fill to the edge", xp.sb._points.TOPLEFT[3], 0)
    Settings.Set("xpBorder", "FLAT")
    Settings.Set("xpBorderColor", { 1, 0, 0, 1 })
    check("flat rim in its colour", xp.borders[1]._vertex[1], 1)
    for _, k in ipairs({ "xpBorder", "xpBorderColor" }) do Settings.Set(k, nil) end
    check("own with badge: badge rows usable", rows().OPT_XP_BADGE_FOLLOW.enabled(), true)
    check("own after forever: level back on the text layer", xp.nameText._parent, X.TextLayer())

    -- Every text's options work in every style.
    Settings.Set("xpLevelMode", "TEXT")
    for _, id in ipairs(X.STYLES) do
        Settings.Set("xpStyle", id)
        Settings.Set("xpLevelColorOwn", true)
        Settings.Set("xpLevelColor", { 0.2, 0.3, 0.4 })
        check(id .. ": own level colour", xp.nameText._textColor[1], 0.2)
        Settings.Set("xpLevelFontSize", 23)
        check(id .. ": own level size", select(2, xp.nameText:GetFont()), 23)
        Settings.Set("xpLevelPlace", "BELOW_CENTER")
        Settings.Set("xpLevelX", 7)
        local where = (id == "FOREVER" and S("xpHeaderPlate")) and xp.plate or xp.nameText
        check(id .. ": level at its own place", where._points.TOP and where._points.TOP[3], 7)
        Settings.Set("xpValueColorOwn", true)
        Settings.Set("xpValueColor", { 0.6, 0.5, 0.4 })
        check(id .. ": own number colour", xp.valueText._textColor[1], 0.6)
        Settings.Set("xpValueFont", "Morpheus")
        check(id .. ": own number font", select(1, xp.valueText:GetFont()), ns.Media.FontPath("Morpheus"))
        Settings.Set("xpHeight", 30)
        check(id .. ": own height", xp:GetHeight(), 30)
        for _, k in ipairs({ "xpLevelColorOwn", "xpLevelColor", "xpLevelFontSize", "xpLevelPlace", "xpLevelX",
            "xpValueColorOwn", "xpValueColor", "xpValueFont", "xpHeight" }) do Settings.Set(k, nil) end
    end

    -- The new looks.
    local base = S("barHeight")
    Settings.Set("xpStyle", "RUNE")
    check("rune: taller than the bars", xp:GetHeight(), math.floor(base * 2.6 + 0.5))
    check("rune: its fill", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillRune.tga")
    check("rune: the slab", parts("RUNE").slab._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\RuneSlab.tga")
    check("rune: no dividers", (function() for _, d in ipairs(xp.dividers) do if d:IsShown() then return false end end return true end)(), true)
    check("rune: four runes", #parts("RUNE").runes, 4)
    check("rune: none lit at 3 %", parts("RUNE").runeGlow[1]:IsShown(), false)
    M.state.xp = 12000
    M.Fire("PLAYER_XP_UPDATE")
    check("rune: first two lit at 51 %", parts("RUNE").runeGlow[2]:IsShown(), true)
    check("rune: third dark at 51 %", parts("RUNE").runeGlow[3]:IsShown(), false)
    check("rune: badge matches", Bars.LevelStyle(Bars.XP_BADGE), "RUNESTONE")
    check("rune: colour rows dimmed", rows().OPT_XP_COLOR.enabled(), false)

    check("rune: material colours by default", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillRune.tga")
    check("rune: may take own colours", rows().OPT_XP_STYLE_COLOURS.enabled == nil, true)
    check("rune: own colours off by default", rows().OPT_XP_STYLE_COLOURS.get(), false)
    Settings.Set("xpStyleColoursRUNE", true)
    check("rune with own colours: a neutral fill", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillShade.tga")
    check("rune with own colours: the chosen colour", xp.sb._color[1], S("xpColor" .. S("xpStyle"))[1])
    check("rune with own colours: the rested colour", xp.rested._color[3], S("xpRestedColor" .. S("xpStyle"))[3])
    check("rune with own colours: pickers usable", rows().OPT_XP_COLOR.enabled(), true)
    Settings.Set("xpStyle", "EMBER")
    check("forge: its own switch, still off", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillEmber.tga")
    Settings.Set("xpStyleColoursEMBER", true)
    check("forge with own colours: its own colour", xp.sb._color[1], Settings.DEFAULTS.xpColorEMBER[1])
    Settings.Set("xpColorRUNE", { 0.1, 0.2, 0.3 })
    check("forge: the rune stone's colour is not its own", xp.sb._color[1], Settings.DEFAULTS.xpColorEMBER[1])
    Settings.Set("xpStyle", "RUNE")
    check("rune: its own colour", xp.sb._color[1], 0.1)
    check("the colour row shows the chosen style's", rows().OPT_XP_COLOR.get()[1], 0.1)
    Settings.Set("xpStyle", "FOREVER")
    check("forever: untouched", xp.sb._color[1], Settings.DEFAULTS.xpColorFOREVER[1])
    check("forever: own colours on by default", rows().OPT_XP_STYLE_COLOURS.get(), true)
    Settings.Set("xpColorFOREVER", { 0.3, 0.3, 0.3 })
    check("forever: the chosen colour", xp.sb._color[1], 0.3)
    Settings.Set("xpStyleColoursFOREVER", false)
    check("forever switched off: pickers dimmed", rows().OPT_XP_COLOR.enabled(), false)
    Settings.Set("xpStyleColoursFOREVER", nil)
    Settings.Set("xpColorFOREVER", nil)
    Settings.Set("xpStyle", "FOREVER")
    Settings.Set("xpStyleColoursFOREVER", false)
    check("forever switched off: the style's colour", xp.sb._color[1], Settings.DEFAULTS.xpColorFOREVER[1])
    Settings.Set("xpStyleColoursFOREVER", nil)
    Settings.Set("xpStyle", "BLIZZARD")
    check("blizzard: off by default", rows().OPT_XP_STYLE_COLOURS.get(), false)
    Settings.Set("xpStyleColoursBLIZZARD", true)
    check("blizzard with own colours: a neutral fill", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillShade.tga")
    check("blizzard with own colours: rested in its colour", xp.rested._color[3], Settings.DEFAULTS.xpRestedColorBLIZZARD[3])
    Settings.Set("xpStyleColoursBLIZZARD", nil)
    check("blizzard off again: Blizzard's fill", xp.sb._barTex, "UI-HUD-ExperienceBar-Fill-Experience")
    Settings.Set("xpStyle", "THIN")
    Settings.Set("xpStyleColoursTHIN", true)
    Settings.Set("xpColorTHIN", { 0.9, 0.1, 0.1 })
    check("hairline with own colours: the line", xp.sb._color[1], 0.9)
    for _, k in ipairs({ "xpStyleColoursTHIN", "xpColorTHIN" }) do Settings.Set(k, nil) end
    Settings.Set("xpStyle", "FOREVER")
    for _, k in ipairs({ "xpStyleColoursRUNE", "xpStyleColoursEMBER", "xpColorRUNE" }) do Settings.Set(k, nil) end
    Settings.Set("xpStyle", "EMBER")
    check("forge: molten again", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillEmber.tga")
    Settings.Set("xpStyle", "GEMS")
    local g = parts("GEMS")
    check("gems: twenty", #g.base, 20)
    check("gems: the fill unseen", xp.sb._color[4], 0)
    check("gems: ten full at 51 %", g.gem[10]:IsShown() and g.gem[10]._texCoord[2], 1)
    check("gems: the eleventh cut", g.gem[11]:IsShown() and g.gem[11]._texCoord[2] < 1, true)
    check("gems: the twelfth empty", g.gem[12]:IsShown(), false)
    M.state.rested = 3000
    M.Fire("UPDATE_EXHAUSTION")
    check("gems: rested ahead in sapphire", g.base[12]._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\GemRested.tga")
    check("gems: far ahead empty", g.base[20]._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\GemEmpty.tga")
    check("gems: badge matches", Bars.LevelStyle(Bars.XP_BADGE), "GEM")

    Settings.Set("xpStyle", "RUNE")
    check("rune after the gems: the fill seen again", xp.sb._color[4], 1)
    Settings.Set("xpStyle", "RING")
    check("a style no longer offered: Forever", X.StyleId(), "FOREVER")
    Settings.Set("xpStyle", "THIN")
    check("thin: three pixels", xp:GetHeight(), 3)
    check("thin: rested dotted after the fill", parts("THIN").dots._points.TOPLEFT[1], xp.sb:GetStatusBarTexture())
    check("thin: level below", xp.nameText._points.TOPLEFT ~= nil, true)

    Settings.Set("xpStyle", "EMBER")
    local e = parts("EMBER")
    check("ember: molten fill", xp.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillEmber.tga")
    check("ember: hot tip on the fill", e.tip._points.RIGHT[1], xp.sb:GetStatusBarTexture())
    check("ember: six rivets", #e.rivets, 6)
    check("ember: badge matches", Bars.LevelStyle(Bars.XP_BADGE), "SHIELD")
    Settings.Set("xpBadgeStyle", "LAUREL")
    check("ember: a chosen badge stays", Bars.LevelStyle(Bars.XP_BADGE), "LAUREL")
    Settings.Set("xpBadgeStyle", nil)
    check("badge menu offers matching", Bars.AvailableLevelStyles(Bars.XP_BADGE)[1], "MATCH")

    Settings.Set("xpStyle", "FOREVER")
    check("own after all: parts of the others hidden", parts("EMBER").over:IsShown() or parts("GEMS").over:IsShown(), false)
    check("own after all: bars' height", xp:GetHeight(), base)

    M.state.xp, M.state.rested = 730, 0
    for _, k in ipairs({ "xpStyle", "xpLevelMode", "xpBadgeFollow" }) do Settings.Set(k, nil) end
    Settings.Set("xpEnabled", false)
    M.state.level = 43
end

section("Bar style (professions, reputation)")
do
    local bar
    for i = 1, 10 do
        local b = Bars.Slot(i)
        if b and b:IsShown() and b.styleTint then bar = b break end
    end
    check("a shown profession bar", bar ~= nil, true)
    if bar then
        local c = bar.styleTint
        check("forever by default", S("barStyle"), "FOREVER")
        check("own: our texture", bar.sb._barTex, "Interface\\TargetingFrame\\UI-StatusBar")
        check("own: its own colour", bar.sb._color[1], c[1])
        local base = S("barHeight")
        Settings.Set("barStyle", "RUNE")
        check("rune: taller", bar:GetHeight(), math.floor(base * 2.6 + 0.5))
        check("rune: a neutral fill", bar.sb._barTex, "Interface\\AddOns\\ForeverProgressBars\\Media\\FillShade.tga")
        check("rune: in the bar's colour", bar.sb._color[1], c[1])
        check("rune: no dividers", (function() for _, d in ipairs(bar.dividers) do if d:IsShown() then return false end end return true end)(), true)
        Settings.Set("barStyle", "GEMS")
        local g = bar.styleParts.GEMS
        check("gems: the fill unseen", bar.sb._color[4], 0)
        check("gems: colourless glass", g.gem[1]._texture, "Interface\\AddOns\\ForeverProgressBars\\Media\\GemShade.tga")
        check("gems: in the bar's colour", g.gem[1]._vertex[1], c[1])
        check("rank in the middle", bar.standing._points.CENTER ~= nil, true)
        Settings.Set("barStyle", "GEMS")
        check("gems: texts above the gems", bar.standing:GetParent():GetFrameLevel() > bar.styleParts.GEMS.over:GetFrameLevel(), true)
        Settings.Set("standingY", 6)
        check("rank moved up", bar.standing._points.CENTER[4], 6)
        Settings.Set("standingY", nil)
        Settings.Set("barStyle", "BLIZZARD")
        local n = 0
        for _, d in ipairs(bar.dividers) do if d:IsShown() then n = n + 1 end end
        Settings.Set("segmentWidth", S("segmentWidth") * 2)
        local m = 0
        for _, d in ipairs(bar.dividers) do if d:IsShown() then m = m + 1 end end
        check("blizzard: segment width counts on these bars", m < n, true)
        Settings.Set("segmentWidth", nil)
        Settings.Set("barStyle", "FOREVER")
        check("forever: the fill seen again", bar.sb._color[4], 1)
        Settings.Set("barBorder", "GOLD")
        check("forever: gold rim as set", bar.borders[1]._gradient ~= nil, true)
        Settings.Set("barMarker", true)
        check("forever: the marker as set", bar.styleParts.FOREVER.markerOn, true)
        for _, k in ipairs({ "barBorder", "barMarker" }) do Settings.Set(k, nil) end
        check("forever: still its colour", bar.sb._color[1], c[1])
        Settings.Set("barStyle", "EMBER")
        check("xp badge follows its own style, not the bars'", Bars.LevelStyle(Bars.XP_BADGE) ~= "SHIELD" or S("xpStyle") == "EMBER", true)
        Settings.Set("barStyle", nil)
        check("own again: bars' height", bar:GetHeight(), base)
        check("own again: our texture", bar.sb._barTex, "Interface\\TargetingFrame\\UI-StatusBar")
    end
    local rep
    for i = 1, 10 do
        local b = Bars.RepSlot(i)
        if b and b:IsShown() and b.styleTint then rep = b break end
    end
    if rep then
        local c = rep.styleTint
        Settings.Set("barStyle", "THIN")
        check("reputation: hairline in the standing's colour", rep.sb._color[1], c[1])
        check("reputation: three pixels", rep:GetHeight(), 3)
        Settings.Set("barStyle", nil)
    end
end

section("XP bar: settings of its own")
do
    Settings.Set("xpEnabled", true)
    local xp = Bars.XpSlot()
    local h0 = Bars.XpHeight()
    local nameH = xp.nameText:GetHeight()
    Settings.Set("textGap", 12)
    Settings.Set("textHeight", 20)
    Settings.Set("labelFontSize", 20)
    Settings.Set("barBgAlpha", 90)
    check("the bars' text line leaves it alone", Bars.XpHeight(), h0)
    check("the bars' text height leaves it alone", xp.nameText:GetHeight(), nameH)
    check("the bars' label size leaves its numbers alone", select(2, xp.valueText:GetFont()), Settings.DEFAULTS.labelFontSize)
    check("the bars' background leaves it alone", xp.bg._texColor[4], Settings.DEFAULTS.xpBgAlpha / 100)
    for _, k in ipairs({ "textGap", "textHeight", "labelFontSize", "barBgAlpha" }) do Settings.Set(k, nil) end
    Settings.Set("xpTextGap", 12)
    check("its own gap counts", Bars.XpHeight(), h0 + 12 - Settings.DEFAULTS.xpTextGap)
    Settings.Set("xpBgAlpha", 80)
    check("its own background counts", xp.bg._texColor[4], 0.8)
    for _, k in ipairs({ "xpTextGap", "xpBgAlpha", "xpEnabled" }) do Settings.Set(k, nil) end

    -- Once per account, every profile takes over what the bars had.
    local account = ns.AccountDB()
    account.xpOwnSettings = nil
    account.profiles.Old = { textGap = 7, barHeight = 26, labelFontSize = 14, barBgColor = { 0.1, 0.2, 0.3 },
        backdropShow = true }
    account.profiles.Forever = { barHeight = 26, xpStyle = "RUNE", xpTextGap = 2, textGap = 9 }
    Settings.MigrateXpOwn()
    local old, other = account.profiles.Old, account.profiles.Forever
    check("migrated: gap", old.xpTextGap, 7)
    check("migrated: height", old.xpHeight, 26)
    check("migrated: number size", old.xpValueFontSize, 14)
    check("migrated: background colour copied", old.xpBgColor[2] == 0.2 and old.xpBgColor ~= old.barBgColor, true)
    check("migrated: own values kept", other.xpTextGap, 2)
    check("migrated: the border stays with the background", old.backdropBorderShow, true)
    check("migrated: no background, no border", other.backdropBorderShow, nil)
    check("migrated: a taller style keeps its height", other.xpHeight, nil)
    other.textGap = 1
    Settings.MigrateXpOwn()
    check("only once", other.xpTextGap, 2)
    account.profiles.Old, account.profiles.Forever = nil, nil
end

section("The strip's own level badge is gone")
do
    check("no level page", (function() for _, p in ipairs(ns.Window.PAGES) do if p.id == "level" then return false end end return true end)(), true)
    check("no level settings", Settings.DEFAULTS.levelShow == nil and Settings.DEFAULTS.levelStyle == nil, true)
    local account = ns.AccountDB()
    account.levelGone = nil
    account.profiles.Old = { levelShow = true, levelStyle = "WINGS", levelBoxPadX = 4, levelBoxMinW = 44 }
    Settings.MigrateLevelGone()
    local old = account.profiles.Old
    check("migrated: the badge padding moves to the XP badge", old.xpBadgePadX, 4)
    check("migrated: its least width too", old.xpBadgeMinW, 44)
    check("migrated: the level settings leave", old.levelShow == nil and old.levelStyle == nil and old.levelBoxPadX == nil, true)
    account.profiles.Old = nil
end

section("XP badge page only with the badge")
do
    local W = ns.Window
    local badgePage
    for _, p in ipairs(W.PAGES) do if p.id == "xpbadge" then badgePage = p end end
    Settings.Set("xpLevelMode", "TEXT")
    check("text: no badge page", badgePage.shown(), false)
    Settings.Set("xpLevelMode", "BADGE")
    check("badge: the badge page", badgePage.shown(), true)
    local first
    for _, p in ipairs(W.PAGES) do if p.id == "xptext" then first = p.rows()[2] end end
    check("the level choice comes first on the texts page", first.label, "OPT_XP_LEVEL_MODE")
    Settings.Set("xpEnabled", true)
    W.Open("xpbadge")
    Settings.Set("xpLevelMode", "TEXT")
    check("its page gives way", W.Current(), "xptext")
    W.Toggle()
    Settings.Set("xpLevelMode", nil)
    Settings.Set("xpEnabled", nil)
end

section("XP colours per style: from before")
do
    local account = ns.AccountDB()
    account.xpColoursPerStyle = nil
    account.profiles.Old = { xpColor = { 0.1, 0.2, 0.3 }, xpRestedColor = { 0.4, 0.5, 0.6 }, xpStyleColours = true }
    Settings.MigrateXpColours()
    local old = account.profiles.Old
    check("migrated: own keeps the colour", old.xpColorOWN[1], 0.1)
    check("migrated: forever too", old.xpRestedColorFOREVER[3], 0.6)
    check("migrated: the rune stone keeps its own", old.xpColorRUNE, nil)
    check("migrated: the switch for both", old.xpStyleColoursRUNE and old.xpStyleColoursEMBER, true)
    check("migrated: the shared keys leave", old.xpColor == nil and old.xpStyleColours == nil, true)
    account.profiles.Old = nil
end

section("Progress bars and XP bar on and off")
do
    local W = ns.Window
    local function shown(id)
        W.Open("general")
        local b = _G["ForeverProgressBarsNav" .. id]
        return b ~= nil and b:IsShown()
    end
    check("both on by default: the bars' pages", shown("bars"), true)
    Settings.Set("barsEnabled", false)
    check("bars off: hidden", Bars.StripCondition(), "hide")
    check("bars off: their pages gone", shown("bars") or shown("professions") or shown("backdrop"), false)
    W.Open("bars")
    check("bars off: their page not offered", W.Current(), "general")
    Settings.Set("barsEnabled", nil)
    check("bars on again: shown", Bars.StripCondition() ~= "hide", true)
    check("bars on again: their pages", shown("bars"), true)
    Settings.Set("xpEnabled", false)
    check("xp off: its pages gone", shown("xp") or shown("xptext") or shown("xpinfo"), false)
    Settings.Set("xpEnabled", true)
    check("xp on: its pages", shown("xp"), true)
    W.Open("xptext")
    Settings.Set("xpEnabled", false)
    check("xp off while on its page: back to General", W.Current(), "general")
    Settings.Set("xpEnabled", nil)
    local first = W.PAGES[1].rows()
    check("General starts with both switches", first[2].label .. "," .. first[3].label, "OPT_BARS_ENABLED,OPT_XP_ENABLED")
    W.Toggle()
end

section("Own merged into Forever: from before")
do
    local account = ns.AccountDB()
    account.ownMerged = nil
    account.profiles.Gold = { xpStyle = "FOREVER", barStyle = "FOREVER", xpColorOWN = { 0.5, 0.5, 0.5 } }
    account.profiles.Plain = { xpStyle = "OWN", barStyle = "OWN", xpColorOWN = { 0.2, 0.3, 0.4 } }
    Settings.MigrateOwnMerged()
    local gold, plain = account.profiles.Gold, account.profiles.Plain
    check("forever profile: gold rim written", gold.xpBorder .. gold.xpBorderSize, "GOLD2")
    check("forever profile: the marker and plate", gold.xpMarker and gold.xpHeaderPlate, true)
    check("forever profile: the gold header", gold.xpLevelPlace .. gold.xpLevelFontSize, "ABOVE_CENTER18")
    check("forever profile: the bars' look too", gold.barBorder .. tostring(gold.barMarker), "GOLDtrue")
    check("forever profile: Own's colours dropped", gold.xpColorOWN, nil)
    check("own profile: now Forever (the default)", plain.xpStyle == nil and plain.barStyle == nil, true)
    check("own profile: its colours now Forever's", plain.xpColorFOREVER[1], 0.2)
    check("own profile: nothing else written", plain.xpBorder == nil and plain.xpMarker == nil, true)
    account.profiles.Gold, account.profiles.Plain = nil, nil
end

section("Only SavedVariables, nothing private")
for _, f in ipairs(tocFiles()) do
    local src = io.open(ROOT .. "/" .. f):read("*a")
    check("no CVar storage in " .. f, src:find("CVar", 1, true), nil)
    check("no ChatPanel fonts in " .. f, src:find("ChatPanel", 1, true), nil)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
