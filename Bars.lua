--[[---------------------------------------------------------------------------
Forever Progress Bars -- two primary professions, two secondary skills and
four reputations as bars, with the character level in a box in the middle.

Rules it is built by:
  * It never moves, hides or reparents a frame it does not own.
  * Every API that differs between clients is probed at runtime (Forever
    1.60 has C_SkillInfo / C_Reputation, TBC 2.5 the old globals) and degrades
    to "no bars" instead of a Lua error.
  * The click on a profession bar opens the profession the way Blizzard's own
    profession tabs do; see OpenProfession.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- One row: the text line, the gap under it and the bar.
local function RowHeight()
    return S("textHeight") + S("textGap") + S("barHeight")
end

-- Fixed values: not settings.
local CFG = {
    NUM_SLOTS = 4,          -- 2 primary professions + 2 secondary skills
    NUM_REP_SLOTS = 4,
    REP_ROW_GAP = 4,        -- between the profession row and the reputation row
    LEVEL_COLORS = { GOLD = { 1.00, 0.90, 0.45 }, WHITE = { 1, 1, 1 } },
    LEVEL_BOX_MARGIN = 10,  -- between the level box and the bars
    LEVEL_BOX_BG = { 0, 0, 0, 0.60 },
    LEVEL_BOX_BG_DARK = { 0.03, 0.03, 0.05, 0.85 },
    LEVEL_BOX_BORDER = { 0.65, 0.55, 0.28, 0.95 },
    -- The gold style: LIGHT and MID are Blizzard's own gold gradient, SHADE,
    -- DARK and LINE the same hue, darker (as the border of Forever Unit
    -- Frames and Forever Square Minimap).
    GOLD = {
        LIGHT = { 1, 1, 0.557, 1 }, MID = { 1, 0.792, 0.188, 1 },
        SHADE = { 0.78, 0.59, 0.13, 1 }, DARK = { 0.55, 0.38, 0.07, 1 },
        LINE = { 0.2, 0.12, 0.02, 1 },
    },
    BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar",
    BORDER_COLOR = { 0, 0, 0, 0.90 },
    SEGMENT_COLOR = { 0, 0, 0, 0.55 },
    FONT_TEMPLATE = "GameFontHighlightSmall",
    NAME_COLOR = { 0.90, 0.90, 0.90 },
    VALUE_COLOR = { 1.00, 1.00, 1.00 },
    ICON_CROP = 0.07,       -- trims the border baked into Blizzard's icons
    REFRESH_THROTTLE = 0.20,
    SKILLFRAME_RETRY = 1.00,

    COLORS = {
        ALCHEMY        = { 0.45, 0.85, 0.35 },  -- flask green
        BLACKSMITHING  = { 0.60, 0.60, 0.65 },  -- steel grey
        ENCHANTING     = { 0.75, 0.45, 0.95 },  -- arcane purple
        ENGINEERING    = { 0.95, 0.60, 0.20 },  -- copper orange
        HERBALISM      = { 0.25, 0.80, 0.45 },  -- leaf green
        JEWELCRAFTING  = { 0.95, 0.35, 0.55 },  -- ruby pink
        LEATHERWORKING = { 0.70, 0.50, 0.30 },  -- tanned leather
        MINING         = { 0.80, 0.70, 0.35 },  -- ore gold
        SKINNING       = { 0.80, 0.35, 0.30 },  -- raw hide red
        TAILORING      = { 0.45, 0.65, 0.95 },  -- bolt-of-cloth blue
        FIRST_AID      = { 0.95, 0.95, 0.95 },  -- bandage white
        COOKING        = { 0.95, 0.75, 0.45 },  -- warm bread
        FISHING        = { 0.35, 0.70, 0.90 },  -- water blue
        RIDING         = { 0.70, 0.65, 0.55 },  -- saddle brown
        UNKNOWN        = { 0.55, 0.55, 0.60 },
    },
}
ns.CFG = CFG

local Bars = {}
ns.Bars = Bars

-- =============================================================================
-- Professions
--
-- Skill line names are localised, so nothing is matched by English name. Each
-- profession's localised name comes from its apprentice spell at login.
-- `openSpellID` is the spell whose cast opens the window, if there is one:
-- Mining opens nothing (Smelting does), gathering skills and Riding have no
-- window, and Fishing must never be wired (casting it starts fishing).
-- `ab` is the expansion a profession came with; Jewelcrafting (TBC) does not
-- exist on a vanilla content client such as Forever.
-- =============================================================================
local PROFESSIONS = {
    { key = "ALCHEMY",        spellID = 2259,  kind = "primary", openSpellID = 2259 },
    { key = "BLACKSMITHING",  spellID = 2018,  kind = "primary", openSpellID = 2018 },
    { key = "ENCHANTING",     spellID = 7411,  kind = "primary", openSpellID = 7411 },
    { key = "ENGINEERING",    spellID = 4036,  kind = "primary", openSpellID = 4036 },
    -- Spell 2366 is "Herb Gathering", the skill line "Herbalism": the alias
    -- gives the bar its colour on English clients.
    { key = "HERBALISM",      spellID = 2366,  kind = "primary", aliases = { "Herbalism" } },
    { key = "JEWELCRAFTING",  spellID = 25229, kind = "primary", openSpellID = 25229, ab = 2 },
    { key = "LEATHERWORKING", spellID = 2108,  kind = "primary", openSpellID = 2108 },
    { key = "MINING",         spellID = 2575,  kind = "primary", openSpellID = 2656 },
    { key = "SKINNING",       spellID = 8613,  kind = "primary" },
    { key = "TAILORING",      spellID = 3908,  kind = "primary", openSpellID = 3908 },
    -- Secondary skills, in display order.
    { key = "FIRST_AID",      spellID = 3273,  kind = "secondary", priority = 1, openSpellID = 3273 },
    { key = "COOKING",        spellID = 2550,  kind = "secondary", priority = 2, openSpellID = 2550 },
    { key = "FISHING",        spellID = 7620,  kind = "secondary", priority = 3 },
    { key = "RIDING",         spellID = 33388, kind = "secondary", priority = 4 },
}
Bars.PROFESSIONS = PROFESSIONS

local byLocalised = {}
local resolved = false

local function Print(fmt, ...)
    local msg = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then frame:AddMessage("|cff66ccff" .. L.ADDON_NAME .. "|r: " .. msg) end
end
ns.Print = Print

local function ColorTexture(tex, r, g, b, a)
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a) else tex:SetTexture(r, g, b, a) end
end

-- A spell's localised name, across the shapes this API has taken.
local function SpellName(spellID)
    if type(spellID) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    if type(_G.GetSpellInfo) == "function" then
        local ok, a = pcall(_G.GetSpellInfo, spellID)
        if ok then
            if type(a) == "string" and a ~= "" then return a end
            if type(a) == "table" and type(a.name) == "string" then return a.name end
        end
    end
    return nil
end

local function SpellIcon(spellID)
    if type(spellID) ~= "number" then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and info.iconID then return info.iconID end
    end
    if type(_G.GetSpellTexture) == "function" then
        local ok, icon = pcall(_G.GetSpellTexture, spellID)
        if ok and icon then return icon end
    end
    if type(_G.GetSpellInfo) == "function" then
        local ok, _, _, icon = pcall(_G.GetSpellInfo, spellID)
        if ok and icon then return icon end
    end
    return nil
end

local function ResolveProfessionNames()
    if resolved then return end
    resolved = true
    for _, p in ipairs(PROFESSIONS) do
        p.icon = SpellIcon(p.spellID)
        local name = SpellName(p.spellID)
        if name then
            p.spellName = name
            byLocalised[name] = p
        end
        if p.openSpellID then p.openSpellName = SpellName(p.openSpellID) end
        for _, alias in ipairs(p.aliases or {}) do
            if not byLocalised[alias] then byLocalised[alias] = p end
        end
    end
end

local function ColorForKey(key)
    return unpack(CFG.COLORS[key] or CFG.COLORS.UNKNOWN)
end

-- =============================================================================
-- One shape for skills and reputation
--
-- TBC (2.5) has global functions with many return values, Forever (1.60) the
-- same data in C_SkillInfo / C_Reputation tables. Read off the running
-- client, not the retail documentation. One trap: the old isExpanded is the
-- new isCollapsed, inverted. The reputation thresholds are renamed too
-- (barMin/barMax/barValue -> currentReactionThreshold/nextReactionThreshold/
-- currentStanding, hasRep -> isHeaderWithRep).
-- =============================================================================
local Api = {}
ns.Api = Api

local function hasCSkill()
    return C_SkillInfo and type(C_SkillInfo.GetNumSkillLines) == "function"
       and type(C_SkillInfo.GetSkillLineInfo) == "function"
end

local function hasCRep()
    return C_Reputation and type(C_Reputation.GetNumFactions) == "function"
       and type(C_Reputation.GetFactionDataByIndex) == "function"
end

function Api.SkillAPIAvailable()
    if hasCSkill() then
        return type(C_SkillInfo.ExpandSkillHeader) == "function"
           and type(C_SkillInfo.CollapseSkillHeader) == "function"
    end
    return type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function"
       and type(ExpandSkillHeader) == "function" and type(CollapseSkillHeader) == "function"
end

function Api.NumSkillLines()
    if hasCSkill() then return C_SkillInfo.GetNumSkillLines() or 0 end
    return (type(GetNumSkillLines) == "function" and GetNumSkillLines()) or 0
end

-- { name, isHeader, isCollapsed, rank, tempPoints, modifier, maxRank,
--   isAbandonable, skillID }
function Api.SkillLineInfo(i)
    if hasCSkill() then
        local d = C_SkillInfo.GetSkillLineInfo(i)
        if not d then return nil end
        return {
            name = d.name, isHeader = d.isHeader, isCollapsed = d.isCollapsed,
            rank = d.rank, tempPoints = d.tempPoints, modifier = d.modifier,
            maxRank = d.maxRank, isAbandonable = d.isAbandonable, skillID = d.skillID,
        }
    end
    if type(GetSkillLineInfo) ~= "function" then return nil end
    local name, isHeader, isExpanded, rank, tempPoints, modifier, maxRank, isAbandonable = GetSkillLineInfo(i)
    if not name then return nil end
    return {
        name = name, isHeader = isHeader, isCollapsed = not isExpanded,
        rank = rank, tempPoints = tempPoints, modifier = modifier,
        maxRank = maxRank, isAbandonable = isAbandonable,
    }
end

function Api.ExpandSkillHeader(i)
    if hasCSkill() then return C_SkillInfo.ExpandSkillHeader(i) end
    if type(ExpandSkillHeader) == "function" then return ExpandSkillHeader(i) end
end

function Api.CollapseSkillHeader(i)
    if hasCSkill() then return C_SkillInfo.CollapseSkillHeader(i) end
    if type(CollapseSkillHeader) == "function" then return CollapseSkillHeader(i) end
end

function Api.FactionAPIAvailable()
    return hasCRep() or (type(GetNumFactions) == "function" and type(GetFactionInfo) == "function")
end

function Api.NumFactions()
    if hasCRep() then return C_Reputation.GetNumFactions() or 0 end
    return (type(GetNumFactions) == "function" and GetNumFactions()) or 0
end

-- { name, standing, min, max, value, isHeader, isCollapsed, hasRep, factionID }
function Api.FactionInfo(i)
    if hasCRep() then
        local d = C_Reputation.GetFactionDataByIndex(i)
        if not d then return nil end
        return {
            name = d.name, standing = d.reaction,
            min = d.currentReactionThreshold, max = d.nextReactionThreshold,
            value = d.currentStanding, isHeader = d.isHeader, isCollapsed = d.isCollapsed,
            hasRep = d.isHeaderWithRep, factionID = d.factionID,
        }
    end
    if type(GetFactionInfo) ~= "function" then return nil end
    local name, _, standing, barMin, barMax, barValue, _, _, isHeader,
          isCollapsed, hasRep, _, _, factionID = GetFactionInfo(i)
    if not name then return nil end
    return {
        name = name, standing = standing, min = barMin, max = barMax, value = barValue,
        isHeader = isHeader, isCollapsed = isCollapsed, hasRep = hasRep, factionID = factionID,
    }
end

function Api.ExpandFactionHeader(i)
    if hasCRep() and type(C_Reputation.ExpandFactionHeader) == "function" then
        return C_Reputation.ExpandFactionHeader(i)
    end
    if type(ExpandFactionHeader) == "function" then return ExpandFactionHeader(i) end
end

function Api.CollapseFactionHeader(i)
    if hasCRep() and type(C_Reputation.CollapseFactionHeader) == "function" then
        return C_Reputation.CollapseFactionHeader(i)
    end
    if type(CollapseFactionHeader) == "function" then return CollapseFactionHeader(i) end
end

-- =============================================================================
-- Skill scan
--
-- The skill list reports only lines under EXPANDED headers, so everything is
-- expanded, read and put back as it was. Collapsing shifts the indices of
-- the lines below, so the restore walks the headers backwards. Expanding and
-- collapsing fire SKILL_LINES_CHANGED; the `scanning` flag and a short
-- suppression window keep scan -> event -> scan from looping.
-- =============================================================================
local scanning = false
local suppressSkillEventsUntil = 0

local function SkillWindowOpen()
    local f = _G.SkillFrame
    if not f then return false end
    if f.IsVisible then return f:IsVisible() end
    return f:IsShown()
end

-- Every non-header line, grouped under its header.
local function CollectLines()
    local order, current = {}, nil
    for i = 1, Api.NumSkillLines() do
        local d = Api.SkillLineInfo(i)
        if d and d.name then
            if d.isHeader then
                current = { name = d.name, lines = {} }
                order[#order + 1] = current
            elseif current then
                local rank, maxRank = tonumber(d.rank) or 0, tonumber(d.maxRank) or 0
                -- Forever lists every profession TWICE in a row, with the same
                -- rank. Only an exact repeat under the same header is dropped,
                -- so two different skills can never merge.
                local repeated = false
                for _, seen in ipairs(current.lines) do
                    if seen.name == d.name and seen.rank == rank and seen.maxRank == maxRank then
                        repeated = true
                        break
                    end
                end
                if not repeated then
                    current.lines[#current.lines + 1] = {
                        name = d.name, rank = rank, maxRank = maxRank,
                        modifier = tonumber(d.modifier) or 0,
                        tempPoints = tonumber(d.tempPoints) or 0,
                        isAbandonable = d.isAbandonable and true or false,
                        skillID = d.skillID, prof = byLocalised[d.name],
                    }
                end
            end
        end
    end
    return order
end

-- primaries, secondaries; or nil, nil, reason ("skillframe", "noapi", "error").
local function ScanSkills()
    if not Api.SkillAPIAvailable() then return nil, nil, "noapi" end
    -- Expanding headers under the player's nose would scroll an open skill
    -- window around; the caller retries when it is closed.
    if SkillWindowOpen() then return nil, nil, "skillframe" end

    scanning = true
    local collapsed, groups, mutated = {}, nil, false
    local ok = pcall(function()
        local any = false
        for i = 1, Api.NumSkillLines() do
            local d = Api.SkillLineInfo(i)
            if d and d.isHeader and d.isCollapsed then
                collapsed[d.name] = true
                any = true
            end
        end
        -- Index 0 means "all" for both expand and collapse.
        if any then
            Api.ExpandSkillHeader(0)
            mutated = true
        end
        groups = CollectLines()
    end)
    if mutated then
        pcall(function()
            local headers = {}
            for i = 1, Api.NumSkillLines() do
                local d = Api.SkillLineInfo(i)
                if d and d.isHeader then headers[#headers + 1] = { index = i, name = d.name } end
            end
            for i = #headers, 1, -1 do
                if collapsed[headers[i].name] then Api.CollapseSkillHeader(headers[i].index) end
            end
        end)
        suppressSkillEventsUntil = GetTime() + 0.5
    end
    scanning = false
    if not ok then return nil, nil, "error" end

    -- Classification, locale independent, most reliable first:
    --   a) the header holding a recognised primary (secondary) skill is the
    --      professions (secondary skills) header: all its lines belong to it;
    --   b) else primary professions are the only skills you can unlearn;
    --   c) else by name.
    local primaryHeader, secondaryHeader
    for _, h in ipairs(groups or {}) do
        for _, line in ipairs(h.lines) do
            if line.prof then
                if line.prof.kind == "primary" and not primaryHeader then
                    primaryHeader = h
                elseif line.prof.kind == "secondary" and not secondaryHeader then
                    secondaryHeader = h
                end
            end
        end
    end
    if not primaryHeader then
        for _, h in ipairs(groups or {}) do
            for _, line in ipairs(h.lines) do
                if line.isAbandonable and h ~= secondaryHeader then
                    primaryHeader = h
                    break
                end
            end
            if primaryHeader then break end
        end
    end

    local primaries, secondaries = {}, {}
    local function accept(list, line, kind)
        -- Weapon and armour proficiencies have a maximum of 1.
        if (line.maxRank or 0) <= 1 then return end
        line.key = line.prof and line.prof.key or "UNKNOWN"
        line.kind = kind
        list[#list + 1] = line
    end
    for _, h in ipairs(groups or {}) do
        for _, line in ipairs(h.lines) do
            if h == primaryHeader then
                accept(primaries, line, "primary")
            elseif h == secondaryHeader then
                accept(secondaries, line, "secondary")
            elseif line.prof then
                accept(line.prof.kind == "primary" and primaries or secondaries, line, line.prof.kind)
            end
        end
    end
    table.sort(secondaries, function(a, b)
        local pa = a.prof and a.prof.priority or 99
        local pb = b.prof and b.prof.priority or 99
        if pa ~= pb then return pa < pb end
        return a.name < b.name
    end)
    return primaries, secondaries
end
Bars.ScanSkills = function() return ScanSkills() end

-- =============================================================================
-- Opening a profession, the way Blizzard's own tabs do
--
-- After ProfessionsLargeRightTabMixin:CastProfessionSpell
-- (Blizzard_ProfessionsTemplates.lua): cast the SPELLBOOK ENTRY
-- (spellOffset + 1), and only when that profession is not already selected;
-- otherwise every click sends a new request and the answers overtake each
-- other. skillLine and spellOffset come from GetProfessions() and
-- GetProfessionInfo(index), which include Cooking and First Aid.
-- =============================================================================
local function ProfessionInfo(name)
    if not name or type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return nil
    end
    local ok, i1, i2, i3, i4, i5, i6, i7 = pcall(GetProfessions)
    if not ok then return nil end
    -- Not ipairs: GetProfessions returns gaps (nil for a missing second
    -- primary), and ipairs would stop there.
    local indices = { i1, i2, i3, i4, i5, i6, i7 }
    for i = 1, 7 do
        local index = indices[i]
        if index then
            local okInfo, found, _, _, _, _, spellOffset, skillLine = pcall(GetProfessionInfo, index)
            if okInfo and found == name and type(spellOffset) == "number" then
                return skillLine, spellOffset
            end
        end
    end
    return nil
end
Bars.ProfessionInfo = ProfessionInfo

local function IsSelected(skillLine)
    if not skillLine then return false end
    local f = _G.Professions
    if not (f and type(f.IsSelectedProfession) == "function") then return false end
    local ok, yes = pcall(f.IsSelectedProfession, skillLine)
    return ok and yes and true or false
end

local function WindowShown()
    local f = _G.ProfessionsFrame
    return (f and f.IsShown and f:IsShown()) and true or false
end

-- Blizzard's own tab for this profession, if the window is open. The tabs
-- carry their skill line (frame.skillLine) and a plain OnClick method.
local function TabFor(skillLine)
    if not skillLine then return nil end
    local f = _G.ProfessionsFrame
    if not (f and type(f.rightProfessionTabs) == "table") then return nil end
    for _, tab in ipairs(f.rightProfessionTabs) do
        if tab and tab.skillLine == skillLine and type(tab.OnClick) == "function"
           and tab.IsShown and tab:IsShown() then
            return tab
        end
    end
    return nil
end
Bars.TabFor = TabFor

-- The profession to show once the window stands.
--
-- On showing, the window makes EVERY tab cast its profession spell
-- (EventRegistry "ProfessionsFrame.Show"), and the last answer wins: a click
-- on Cooking loaded Cooking and then jumped to another profession. So until
-- the deadline, every trade skill event presses our tab again; our press
-- comes after the last answer and wins. Blizzard's CastProfessionSpell does
-- nothing for the profession already selected, so pressing is harmless.
local wantedTab, wantedUntil
local TAB_DEADLINE = 2

local function OpenProfession(skillLine, spellOffset)
    if not spellOffset then return "no data" end
    -- Open and already selected: close it (Blizzard's tabs cannot do that).
    if WindowShown() and IsSelected(skillLine) then
        wantedTab, wantedUntil = nil, nil
        if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill) end
        return "closed"
    end
    -- Open on another profession: press Blizzard's own tab.
    local tab = WindowShown() and TabFor(skillLine) or nil
    if tab then
        wantedTab, wantedUntil = nil, nil
        pcall(tab.OnClick, tab)
        return "tab"
    end
    -- Closed: cast and remember the tab.
    local cast = C_SpellBook and C_SpellBook.CastSpellBookItem
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if type(cast) ~= "function" or bank == nil then return "no spellbook" end
    wantedTab = skillLine
    wantedUntil = ((GetTime and GetTime()) or 0) + TAB_DEADLINE
    pcall(cast, spellOffset + 1, bank)
    return "opened"
end
Bars.OpenProfession = OpenProfession

local function PressWantedTab()
    if not wantedTab then return "none" end
    local now = (GetTime and GetTime()) or 0
    if wantedUntil and now > wantedUntil then
        wantedTab, wantedUntil = nil, nil
        return "expired"
    end
    local tab = TabFor(wantedTab)
    if not tab then return "no tab" end
    -- The wish stays until the deadline: the storm of answers comes later.
    pcall(tab.OnClick, tab)
    return "tab"
end
Bars.PressWantedTab = PressWantedTab

-- =============================================================================
-- Frames
-- =============================================================================
local container
local slots, repSlots = {}, {}
local levelText, levelBox
local layoutBusy
local lastWidth = -1

local function LabelFont(fs)
    if not fs or not fs.GetFont then return end
    local size = S("labelFontSize")
    if not size or size <= 0 then return end
    local path, _, flags = fs:GetFont()
    if path then pcall(fs.SetFont, fs, path, size, flags) end
end

-- The tooltip of a profession or reputation bar.
local function ShowTooltip(bar)
    local d = bar.data
    if not d then return end
    GameTooltip:SetOwner(bar, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.name, 1, 1, 1)
    if d.isRep then
        GameTooltip:AddDoubleLine(d.standingText or "", string.format("%d / %d", d.rank, d.maxRank),
            0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(L.TIP_REP_LEFT, 0.4, 0.8, 1)
        GameTooltip:AddLine(L.TIP_REP_RIGHT, 0.4, 0.8, 1)
    else
        GameTooltip:AddDoubleLine(L.TIP_RANK, string.format("%d / %d", d.rank, d.maxRank), 0.8, 0.8, 0.8, 1, 1, 1)
        local remaining = d.maxRank - d.rank
        GameTooltip:AddDoubleLine(L.TIP_TO_CAP, tostring(remaining > 0 and remaining or 0), 0.8, 0.8, 0.8, 1, 1, 1)
        if (d.modifier or 0) ~= 0 then
            GameTooltip:AddDoubleLine(L.TIP_BONUS, string.format("%+d", d.modifier), 0.8, 0.8, 0.8, 0.2, 1, 0.2)
        end
        if (bar.open and bar.open:IsShown()) or (bar.click and bar.click.openSpell) then
            GameTooltip:AddLine(L.TIP_CLICK_OPEN, 0.4, 0.8, 1)
        end
    end
    GameTooltip:Show()
end
local function HideTooltip() GameTooltip:Hide() end

local function BuildBar(index)
    local bar = CreateFrame("Frame", nil, container)
    bar:EnableMouse(true)
    bar:Hide()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bar.bg = bg

    local borders = {}
    for i = 1, 4 do
        borders[i] = bar:CreateTexture(nil, "BORDER")
        ColorTexture(borders[i], unpack(CFG.BORDER_COLOR))
    end
    local top, bottom, left, right = unpack(borders)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)

    local sb = CreateFrame("StatusBar", nil, bar)
    sb:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
    sb:SetStatusBarTexture(CFG.BAR_TEXTURE)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    bar.sb = sb
    -- Dividers live on the status bar, above its fill.
    bar.dividers = {}

    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
    icon:SetTexCoord(CFG.ICON_CROP, 1 - CFG.ICON_CROP, CFG.ICON_CROP, 1 - CFG.ICON_CROP)
    icon:Hide()
    bar.icon = icon

    local name = bar:CreateFontString(nil, "OVERLAY", CFG.FONT_TEMPLATE)
    name:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
    name:SetJustifyH("LEFT")
    name:SetTextColor(unpack(CFG.NAME_COLOR))
    if name.SetWordWrap then name:SetWordWrap(false) end
    bar.nameText = name

    local value = bar:CreateFontString(nil, "OVERLAY", CFG.FONT_TEMPLATE)
    value:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 1)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(unpack(CFG.VALUE_COLOR))
    if value.SetWordWrap then value:SetWordWrap(false) end
    bar.valueText = value

    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", HideTooltip)

    -- The click area covers the whole strip: icon, name, value and bar.
    --
    -- A SecureActionButton, because casting a spell by name is protected. It
    -- gets NO script of its own on OnClick, neither SetScript (which silences
    -- the template's OnClick) nor HookScript (which taints the click path and
    -- makes WoW refuse the action): only its macro text decides.
    --
    -- useOnKeyDown is pinned to false: with "cast on key down" enabled a
    -- button listening only for the release would never fire, and release
    -- keeps dragging usable.
    local click = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
    click:SetAttribute("useOnKeyDown", false)
    click:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    click:SetScript("OnEnter", function() ShowTooltip(bar) end)
    click:SetScript("OnLeave", HideTooltip)
    bar.click = click

    -- A plain button above it for the spellbook route (OpenProfession).
    -- Blizzard's own profession tabs are plain buttons too.
    local open = CreateFrame("Button", nil, bar)
    open:SetFrameLevel(click:GetFrameLevel() + 1)
    open:RegisterForClicks("LeftButtonUp")
    open:SetScript("OnEnter", function() ShowTooltip(bar) end)
    open:SetScript("OnLeave", HideTooltip)
    open:SetScript("OnClick", function(self) OpenProfession(self.skillLine, self.spellOffset) end)
    open:Hide()
    bar.open = open

    bar.index = index
    return bar
end

-- Sizes that depend on settings. The secure click area may be moved only
-- out of combat; in combat it waits for PLAYER_REGEN_ENABLED.
local geometryPending = false
local function ApplyBarGeometry(bar)
    local textHeight, iconSize = S("textHeight"), S("iconSize")
    bar:SetHeight(S("barHeight"))
    bar.icon:SetSize(iconSize, iconSize)
    bar.nameText:SetHeight(textHeight)
    bar.valueText:SetHeight(textHeight)
    -- The empty part of the bar.
    local c = S("barBgColor")
    ColorTexture(bar.bg, c[1], c[2], c[3], S("barBgAlpha") / 100)
    -- The text line sits `textGap` above the bar.
    local gap = S("textGap")
    bar.icon:ClearAllPoints()
    bar.icon:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, gap)
    bar.valueText:ClearAllPoints()
    bar.valueText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, gap)
    bar.nameText:ClearAllPoints()
    bar.nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", bar.nameOffset or 0, gap)
    LabelFont(bar.nameText)
    LabelFont(bar.valueText)
    LabelFont(bar.standing)
    if InCombatLockdown and InCombatLockdown() then
        geometryPending = true
        return
    end
    for _, b in ipairs({ bar.click, bar.open }) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, textHeight + S("textGap"))
        b:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    end
end

-- The player's class colour, or nil.
local function ClassColour()
    if not UnitClass then return nil end
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c and c.r then return { c.r, c.g, c.b, 1 } end
    return nil
end

-- One screen pixel in UI units, so thin edges stay sharp at any UI scale.
local function OnePixel(frame)
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and scale and scale > 0 then
        return PixelUtil.GetPixelToUIUnitFactor() / scale
    end
    return 1
end

-- Four textures along the inside of `owner`, `inset` in from its edge, `size`
-- thick. Top and bottom span the full width, left and right fit in between.
local function NewRing(owner, layer, sublevel)
    local ring = {}
    for i = 1, 4 do ring[i] = owner:CreateTexture(nil, layer, nil, sublevel) end
    return ring
end

local function PlaceRing(ring, owner, size, inset)
    local top, bottom, left, right = ring[1], ring[2], ring[3], ring[4]
    for i = 1, 4 do ring[i]:ClearAllPoints() end
    top:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -inset, -inset)
    top:SetHeight(size)
    bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(size)
    left:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset - size)
    left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", inset, inset + size)
    left:SetWidth(size)
    right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -inset, -inset - size)
    right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -inset, inset + size)
    right:SetWidth(size)
end

local function ShowRing(ring, shown)
    for i = 1, 4 do ring[i]:SetShown(shown) end
end

local function PaintRing(ring, c)
    for i = 1, 4 do
        ring[i]:SetColorTexture(1, 1, 1, 1)
        ring[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
end

-- A vertical gradient, bottom colour first. Newer clients take colour
-- objects, older ones six numbers.
local function Gradient(piece, bottom, top)
    if CreateColor then
        local ok = pcall(piece.SetGradient, piece, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], bottom[4]),
            CreateColor(top[1], top[2], top[3], top[4]))
        if ok then return end
    end
    pcall(piece.SetGradient, piece, "VERTICAL", bottom[1], bottom[2], bottom[3], top[1], top[2], top[3])
end

-- Lit from above: top MID up to LIGHT, sides SHADE up to MID, bottom DARK up
-- to SHADE, so the pieces meet without a step.
local function PaintGold(ring)
    local G = CFG.GOLD
    PaintRing(ring, { 1, 1, 1, 1 })
    Gradient(ring[1], G.MID, G.LIGHT)
    Gradient(ring[2], G.DARK, G.SHADE)
    Gradient(ring[3], G.SHADE, G.MID)
    Gradient(ring[4], G.SHADE, G.MID)
end

-- Badge styles. Most are drawn for this addon (tools/badges/*.svg, rendered
-- by tools/make_badges): `inner` is the share of the texture's height the
-- dark middle takes, where the digits go; `aspect` its width to height;
-- `lift` moves the digits up by that share of the height (the crest's middle
-- sits high). The gold rings are Blizzard's own art: a round box, `scale` for
-- how far the art reaches past it and a dark disc behind the open ring. Their
-- atlases come from the Forever UI source, but not every module there loads,
-- so they are checked at runtime and offered only if the client has them.
local MEDIA = "Interface\\AddOns\\ForeverProgressBars\\Media\\"
--
-- `crop` cuts the empty margin off a texture (left and right texture
-- coordinates), `margin` is the room between the badge and the bars. The
-- crest's `inner` is larger than its dark middle really is: at the default
-- padding it looked too big (it looked right at 3 px).
Bars.ART_STYLES = {
    CREST       = { file = MEDIA .. "BadgeCrest.tga", inner = 0.76, lift = 0.03 },
    LAUREL      = { file = MEDIA .. "BadgeLaurel.tga", inner = 0.54 },
    -- The wing tips end at x 22 and 490 of 512.
    WINGS       = { file = MEDIA .. "BadgeWings.tga", inner = 0.62, aspect = 468 / 256,
                    crop = { 22 / 512, 490 / 512 }, margin = 2 },
    RING_GOLD   = { atlas = "communities-ring-gold", round = true, scale = 1.0, disc = true },
    RING_ORNATE = { atlas = "Artifacts-PerkRing-Final", round = true, scale = 1.2, disc = true },
}
Bars.LEVEL_STYLES = {
    "NONE", "CLASSIC", "GOLD", "CLASS",
    "CREST", "LAUREL", "WINGS", "RING_GOLD", "RING_ORNATE",
}
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function AtlasExists(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
end

-- The styles this client can draw, in menu order.
function Bars.AvailableLevelStyles()
    local list = {}
    for _, style in ipairs(Bars.LEVEL_STYLES) do
        local art = Bars.ART_STYLES[style]
        if not art or not art.atlas or AtlasExists(art.atlas) then list[#list + 1] = style end
    end
    return list
end

-- The chosen style, or Classic if this client lacks its art or the style
-- is no longer offered (an older version had more).
local function LevelStyle()
    local style = S("levelStyle")
    local known = false
    for _, s in ipairs(Bars.LEVEL_STYLES) do
        if s == style then known = true break end
    end
    if not known then return "CLASSIC" end
    local art = Bars.ART_STYLES[style]
    if art and art.atlas and not AtlasExists(art.atlas) then return "CLASSIC" end
    return style
end
Bars.LevelStyle = LevelStyle

local function ApplyLevelLook()
    if not levelText then return end
    local size, flag = S("levelFontSize"), S("levelFontFlag")
    local ok = pcall(levelText.SetFont, levelText, ns.Media.FontPath(S("levelFont")), size, flag)
    if not ok or not levelText:GetFont() then
        pcall(levelText.SetFont, levelText, ns.Media.DEFAULT_FONT, size, flag)
    end
    levelBox:SetHeight(size + 2 * S("levelBoxPadY"))

    local colour = CFG.LEVEL_COLORS[S("levelColor")] or (S("levelColor") == "CLASS" and ClassColour())
                   or CFG.LEVEL_COLORS.GOLD
    levelText:SetTextColor(colour[1], colour[2], colour[3])

    local style = LevelStyle()
    local ring, line = levelBox.ring, levelBox.line
    local px = OnePixel(levelBox)
    local art = Bars.ART_STYLES[style]
    levelBox.art:SetShown(art ~= nil)
    levelBox.disc:SetShown(art ~= nil and art.disc == true)
    if art then
        if art.atlas then
            levelBox.art:SetAtlas(art.atlas)
        else
            levelBox.art:SetTexture(art.file)
            local crop = art.crop or { 0, 1 }
            levelBox.art:SetTexCoord(crop[1], crop[2], 0, 1)
        end
        levelBox.bg:Hide()
        ShowRing(ring, false)
        ShowRing(line, false)
        return
    end
    levelBox.bg:SetShown(style ~= "NONE")
    ColorTexture(levelBox.bg, unpack(style == "CLASSIC" and CFG.LEVEL_BOX_BG or CFG.LEVEL_BOX_BG_DARK))
    ShowRing(ring, style == "CLASSIC" or style == "GOLD" or style == "CLASS")
    ShowRing(line, style == "GOLD")
    if style == "GOLD" then
        PlaceRing(ring, levelBox, 3 * px, 0)
        PaintGold(ring)
        PlaceRing(line, levelBox, px, 3 * px)
        PaintRing(line, CFG.GOLD.LINE)
    elseif style == "CLASS" then
        PlaceRing(ring, levelBox, 2 * px, 0)
        PaintRing(ring, ClassColour() or CFG.LEVEL_BOX_BORDER)
    else
        PlaceRing(ring, levelBox, px, 0)
        PaintRing(ring, CFG.LEVEL_BOX_BORDER)
    end
end

-- --------------------------------------------------------------------------
-- The backdrop behind everything: colour, opacity, and a flat or gold
-- border along its inside. Its size follows what is shown (see
-- LayoutBackdrop).
-- --------------------------------------------------------------------------
local backdrop

local function BuildBackdrop()
    backdrop = CreateFrame("Frame", "ForeverProgressBarsBackdrop", container)
    -- Below the bars: they are children of the container one level up.
    backdrop:SetFrameLevel(container:GetFrameLevel())
    backdrop.bg = backdrop:CreateTexture(nil, "BACKGROUND")
    backdrop.bg:SetAllPoints(backdrop)
    backdrop.ring = NewRing(backdrop, "BORDER")
    backdrop.line = NewRing(backdrop, "BORDER", 1)
    Bars.backdrop = backdrop
end

local function ApplyBackdropLook()
    if not backdrop then return end
    if not S("backdropShow") then
        backdrop:Hide()
        return
    end
    backdrop:Show()
    local c = S("backdropColor")
    backdrop.bg:SetColorTexture(c[1], c[2], c[3], S("backdropAlpha") / 100)
    local style, px = S("backdropBorder"), OnePixel(backdrop)
    local size = S("backdropBorderSize") * px
    ShowRing(backdrop.ring, style ~= "NONE")
    ShowRing(backdrop.line, style == "GOLD" and S("backdropBorderSize") >= 2)
    if style == "GOLD" then
        PlaceRing(backdrop.ring, backdrop, size, 0)
        PaintGold(backdrop.ring)
        PlaceRing(backdrop.line, backdrop, px, size - px)
        PaintRing(backdrop.line, CFG.GOLD.LINE)
    elseif style == "FLAT" then
        PlaceRing(backdrop.ring, backdrop, size, 0)
        PaintRing(backdrop.ring, S("backdropBorderColor"))
    end
end

local function BuildLevelBox()
    levelBox = CreateFrame("Frame", nil, container)
    local bg = levelBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(levelBox)
    levelBox.bg = bg
    levelBox.ring = NewRing(levelBox, "BORDER")
    levelBox.line = NewRing(levelBox, "BORDER", 1)
    -- Blizzard art for the badge styles, and a dark disc behind open rings.
    levelBox.disc = levelBox:CreateTexture(nil, "BACKGROUND")
    levelBox.disc:SetTexture(DISC)
    levelBox.disc:SetVertexColor(0, 0, 0, 0.75)
    levelBox.disc:SetPoint("CENTER")
    levelBox.art = levelBox:CreateTexture(nil, "ARTWORK")
    levelBox.art:SetPoint("CENTER")

    levelText = levelBox:CreateFontString(nil, "OVERLAY")
    levelText:SetPoint("CENTER", levelBox, "CENTER", 0, 0)
    levelText:SetJustifyH("CENTER")
    if levelText.SetWordWrap then levelText:SetWordWrap(false) end
    Bars.levelBox, Bars.levelText = levelBox, levelText
end

-- The reputation row: the same bars one row down. Left-click picks the
-- faction, right-click opens the reputation tab. The secure click area gets
-- no attributes here, so a click never casts anything.
local function BuildRepBar(slot)
    local bar = BuildBar(1000 + slot)
    bar.standing = bar.sb:CreateFontString(nil, "OVERLAY", CFG.FONT_TEMPLATE)
    bar.standing:SetPoint("CENTER", bar.sb, "CENTER", 0, 0)
    bar.standing:SetJustifyH("CENTER")
    bar.standing:SetTextColor(1, 1, 1)
    -- A shadow keeps it readable on a bright fill such as yellow.
    if bar.standing.SetShadowColor then
        bar.standing:SetShadowColor(0, 0, 0, 1)
        bar.standing:SetShadowOffset(1, -1)
    end
    if bar.standing.SetWordWrap then bar.standing:SetWordWrap(false) end

    bar.click:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    bar.click:SetScript("OnClick", function(_, button, down)
        -- Down and Up are registered, so OnClick fires twice per click;
        -- without this the menu would close again at once.
        if down then return end
        if button == "RightButton" then
            if ToggleCharacter then ToggleCharacter("ReputationFrame") end
        else
            ns.OpenFactionMenu(slot, bar)
        end
    end)
    return bar
end

-- =============================================================================
-- Layout
-- =============================================================================

local function LayoutDividers(bar, width)
    local usable = width - 2
    if usable <= 0 then
        for _, d in ipairs(bar.dividers) do d:Hide() end
        return
    end
    local segments = math.max(1, math.floor(usable / S("segmentWidth") + 0.5))
    local step = usable / segments
    for i = 1, segments - 1 do
        local d = bar.dividers[i]
        if not d then
            d = bar.sb:CreateTexture(nil, "OVERLAY")
            d:SetWidth(1)
            ColorTexture(d, unpack(CFG.SEGMENT_COLOR))
            bar.dividers[i] = d
        end
        local x = math.floor(i * step + 0.5)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", bar.sb, "TOPLEFT", x, 0)
        d:SetPoint("BOTTOMLEFT", bar.sb, "BOTTOMLEFT", x, 0)
        d:Show()
    end
    for i = segments, #bar.dividers do bar.dividers[i]:Hide() end
end

-- Fits the box to its digits and returns the room the centre needs. A round
-- style makes it a circle wide enough for the digits and the font's height.
local function UpdateLevelBox()
    local textWidth = levelText:GetStringWidth() or 0
    local w = math.max(S("levelBoxMinW"), textWidth + 2 * S("levelBoxPadX"))
    local h = S("levelFontSize") + 2 * S("levelBoxPadY")
    local art = Bars.ART_STYLES[LevelStyle()]
    local lift = 0
    if art and art.file then
        -- The digits (and at least the font's height) fill the badge's middle.
        local content = math.max(textWidth, S("levelFontSize")) + 2 * S("levelBoxPadX")
        h = content / art.inner
        w = h * (art.aspect or 1)
        levelBox.art:SetSize(w, h)
        lift = (art.lift or 0) * h
    elseif art and art.round then
        local d = math.max(textWidth + 2 * S("levelBoxPadX"), h)
        w, h = d, d
        levelBox.art:SetSize(d * art.scale, d * art.scale)
        levelBox.disc:SetSize(d * 0.9, d * 0.9)
    elseif art then
        levelBox.art:SetSize(w, h)
    end
    levelBox:SetWidth(w)
    levelBox:SetHeight(h)
    levelText:ClearAllPoints()
    levelText:SetPoint("CENTER", levelBox, "CENTER", 0, lift)
    local reach = art and art.round and w * art.scale or w
    local margin = art and art.margin or CFG.LEVEL_BOX_MARGIN
    return math.max(S("levelGap"), reach + 2 * margin)
end

local function Layout()
    if not container or layoutBusy then return end
    layoutBusy = true
    local width = container:GetWidth() or 0
    local spacing = S("spacing")

    levelBox:ClearAllPoints()
    levelBox:SetPoint("CENTER", container, "CENTER", 0, S("levelY"))

    local levelGap = UpdateLevelBox()
    local barWidth = (width - levelGap - 3 * spacing) / CFG.NUM_SLOTS
    if barWidth < 1 then layoutBusy = false; return end

    -- Slots 1|2, the level box, 3|4. 2*barWidth + 1.5*spacing + levelGap/2
    -- equals width/2, so the level sits exactly in the middle.
    local offsets = {
        0,
        barWidth + spacing,
        2 * barWidth + 2 * spacing + levelGap,
        3 * barWidth + 3 * spacing + levelGap,
    }
    local rowHeight = RowHeight()
    for i = 1, CFG.NUM_SLOTS do
        local bar = slots[i]
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", offsets[i], 0)
        bar:SetWidth(barWidth)
        LayoutDividers(bar, barWidth)
        -- A narrow bar clips the name, never the numbers.
        local valueWidth = bar.valueText:GetStringWidth() or 0
        bar.nameText:SetWidth(math.max(1, barWidth - valueWidth - 4 - (bar.nameOffset or 0)))
    end
    for i = 1, CFG.NUM_REP_SLOTS do
        local bar = repSlots[i]
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", offsets[i], -(rowHeight + CFG.REP_ROW_GAP))
        bar:SetWidth(barWidth)
        LayoutDividers(bar, barWidth)
        local valueWidth = bar.valueText:GetStringWidth() or 0
        bar.nameText:SetWidth(math.max(1, barWidth - valueWidth - 4))
    end
    lastWidth = width
    layoutBusy = false
    Bars.LayoutBackdrop()
end

-- The backdrop covers everything shown: from the text line above the top row
-- down to the reputation row (if one of its bars shows), and the level box
-- where it reaches past either, plus the padding all around. Offsets are
-- relative to the container, whose top is the top of the first text line.
function Bars.LayoutBackdrop()
    if not backdrop or not container then return end
    local rowHeight = RowHeight()
    local top, bottom = 0, -rowHeight
    for i = 1, CFG.NUM_REP_SLOTS do
        if repSlots[i] and repSlots[i]:IsShown() then
            bottom = -(2 * rowHeight + CFG.REP_ROW_GAP)
            break
        end
    end
    if levelBox then
        local centre = -rowHeight / 2 + S("levelY")
        local half = (levelBox:GetHeight() or 0) / 2
        top = math.max(top, centre + half)
        bottom = math.min(bottom, centre - half)
    end
    local pad = S("backdropPadding")
    backdrop:ClearAllPoints()
    backdrop:SetPoint("TOPLEFT", container, "TOPLEFT", -pad, top + pad)
    backdrop:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", pad, bottom - pad)
end

-- Position and width, from the settings. The width never exceeds the screen.
local function Place()
    if not container then return end
    local screen = (UIParent.GetWidth and UIParent:GetWidth()) or 0
    local width = Settings.Width(screen)
    if screen and screen > 0 then width = math.min(width, screen) end
    container:ClearAllPoints()
    container:SetPoint("TOP", UIParent, "TOP", S("x"), S("y"))
    container:SetWidth(width)
    container:SetHeight(RowHeight())
end

-- =============================================================================
-- Dragging and locking
-- =============================================================================
local function OnDragStart()
    if InCombatLockdown and InCombatLockdown() then return end
    container:StartMoving()
end

local function OnDragStop()
    container:StopMovingOrSizing()
    local cx = container:GetCenter()
    local ux = UIParent:GetCenter()
    local top, uiTop = container:GetTop(), UIParent:GetTop()
    if cx and ux and top and uiTop then
        -- One write for both: the second Set re-places with both values.
        ns.DB().x = math.floor(cx - ux + 0.5)
        Settings.Set("y", math.floor(top - uiTop + 0.5))
    else
        Place()
    end
end

-- Locked = not draggable AND click-through; otherwise the strip would still
-- swallow clicks into the world.
local function ApplyLock()
    if not container then return end
    local draggable = not S("locked")
    local widgets = { container }
    for i = 1, #slots do
        widgets[#widgets + 1] = slots[i]
        widgets[#widgets + 1] = slots[i].click
        widgets[#widgets + 1] = slots[i].open
    end
    container:SetMovable(draggable)
    container:EnableMouse(draggable)
    for _, w in ipairs(widgets) do
        if draggable then
            w:RegisterForDrag("LeftButton")
            w:SetScript("OnDragStart", OnDragStart)
            w:SetScript("OnDragStop", OnDragStop)
        else
            w:RegisterForDrag()
            w:SetScript("OnDragStart", nil)
            w:SetScript("OnDragStop", nil)
        end
    end
end

-- =============================================================================
-- Filling the profession bars
-- =============================================================================
local pendingRefresh, clickPending = false, false
local lastScan = { primaries = {}, secondaries = {} }
local warnedNoAPI = false

-- Wires a profession bar's click. Out of combat only: secure attributes.
local function ApplyClickTarget(bar)
    local btn = bar and bar.click
    if not btn then return end
    if InCombatLockdown and InCombatLockdown() then
        clickPending = true
        return
    end
    local line = bar.data
    local prof = line and line.prof
    local spell = prof and prof.openSpellName

    -- Guard against a spell ID that points at another profession: the IDs
    -- come from TBC, and a renamed one once made the Cooking bar open
    -- Enchanting. The spell's name must match the bar's (or an alias).
    if prof and spell and prof.spellName and line.name and prof.spellName ~= line.name then
        local alias = false
        for _, a in ipairs(prof.aliases or {}) do
            if a == line.name then alias = true break end
        end
        if not alias then spell = nil end
    end

    -- Where the client lists the profession in the spellbook: the plain
    -- button and OpenProfession. Otherwise the fallback, /cast by name.
    local skillLine, spellOffset = ProfessionInfo(line and line.name)
    bar.open.skillLine = spellOffset and skillLine or nil
    bar.open.spellOffset = spellOffset
    bar.open:SetShown(spellOffset ~= nil)
    if spellOffset then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn.openSpell = nil
        return
    end
    if spell then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/cast " .. spell)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
    end
    btn.openSpell = spell
end

local function ApplyClickTargets()
    clickPending = false
    for i = 1, #slots do ApplyClickTarget(slots[i]) end
end

local function FillSlot(index, line)
    local bar = slots[index]
    bar.data = line
    ApplyClickTarget(bar)
    if not line then
        bar:Hide()
        return
    end
    -- Room for the icon only when there is one.
    local icon = S("showIcons") and line.prof and line.prof.icon or nil
    if icon then
        bar.icon:SetTexture(icon)
        bar.icon:Show()
        bar.nameOffset = S("iconSize") + S("iconGap")
    else
        bar.icon:Hide()
        bar.nameOffset = 0
    end
    bar.nameText:ClearAllPoints()
    bar.nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", bar.nameOffset, S("textGap"))
    bar.nameText:SetText(line.name)
    bar.valueText:SetText(string.format("%d/%d", line.rank, line.maxRank))
    bar.sb:SetMinMaxValues(0, math.max(1, line.maxRank))
    bar.sb:SetValue(math.min(line.rank, line.maxRank))
    bar.sb:SetStatusBarColor(ColorForKey(line.key))
    bar:Show()
end

local function Refresh()
    if not container then return end
    ResolveProfessionNames()
    levelText:SetText(tostring(UnitLevel("player") or ""))

    local primaries, secondaries, reason = ScanSkills()
    if not primaries then
        if reason == "skillframe" then
            if C_Timer then C_Timer.After(CFG.SKILLFRAME_RETRY, Refresh) end
        elseif reason == "noapi" and not warnedNoAPI then
            warnedNoAPI = true
            Print(L.MSG_NO_SKILL_API)
        end
        Layout()
        return
    end
    lastScan.primaries, lastScan.secondaries = primaries, secondaries

    local shownPrimary, shownSecondary = {}, {}
    for _, line in ipairs(primaries) do
        if not Settings.IsHidden(line.name, line.key) and #shownPrimary < 2 then
            shownPrimary[#shownPrimary + 1] = line
        end
    end
    for _, line in ipairs(secondaries) do
        if not Settings.IsHidden(line.name, line.key) and #shownSecondary < 2 then
            shownSecondary[#shownSecondary + 1] = line
        end
    end
    -- Fixed places: an empty slot stays empty, nothing shifts.
    FillSlot(1, shownPrimary[1])
    FillSlot(2, shownPrimary[2])
    FillSlot(3, shownSecondary[1])
    FillSlot(4, shownSecondary[2])
    Layout()
end
Bars.Refresh = function() return Refresh() end

-- Every skill the last scan found, primaries first (for the options).
function Bars.KnownSkills()
    if #lastScan.primaries == 0 and #lastScan.secondaries == 0 then
        local p, s = ScanSkills()
        if p then lastScan.primaries, lastScan.secondaries = p, s end
    end
    local list = {}
    for _, l in ipairs(lastScan.primaries) do list[#list + 1] = l end
    for _, l in ipairs(lastScan.secondaries) do list[#list + 1] = l end
    return list
end

local function ScheduleRefresh(delay)
    if pendingRefresh or scanning then return end
    pendingRefresh = true
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or CFG.REFRESH_THROTTLE, function()
            pendingRefresh = false
            Refresh()
        end)
    else
        pendingRefresh = false
        Refresh()
    end
end

-- =============================================================================
-- Reputation
--
-- The same trap as the skill list: only factions under expanded headers are
-- listed. Colours come from FACTION_BAR_COLORS, the table the character
-- sheet uses.
-- =============================================================================
local scanningFactions = false
local factionCache

local function ScanFactions()
    if not Api.FactionAPIAvailable() then return nil end
    scanningFactions = true
    local collapsed, list, mutated = {}, {}, false
    local ok = pcall(function()
        local any = false
        for i = 1, Api.NumFactions() do
            local d = Api.FactionInfo(i)
            if d and d.isHeader and d.isCollapsed and d.name then
                collapsed[d.name] = true
                any = true
            end
        end
        if any then
            Api.ExpandFactionHeader(0)
            mutated = true
        end
        for i = 1, Api.NumFactions() do
            local d = Api.FactionInfo(i) or {}
            -- Headers can carry reputation of their own (Alliance Forces).
            if d.name and d.factionID and (not d.isHeader or d.hasRep) then
                list[#list + 1] = {
                    id = d.factionID, name = d.name, standing = d.standing,
                    min = d.min or 0, max = d.max or 0, value = d.value or 0,
                }
            end
        end
    end)
    if mutated then
        pcall(function()
            local headers = {}
            for i = 1, Api.NumFactions() do
                local d = Api.FactionInfo(i)
                if d and d.isHeader then headers[#headers + 1] = { index = i, name = d.name } end
            end
            for i = #headers, 1, -1 do
                if collapsed[headers[i].name] then Api.CollapseFactionHeader(headers[i].index) end
            end
        end)
    end
    scanningFactions = false
    if not ok then return nil end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ns.Factions(force)
    if force or not factionCache then factionCache = ScanFactions() end
    return factionCache or {}
end

-- "Friendly", "Honored", ... by the player's gender, as Blizzard's own
-- reputation page does it (GetText); the constant is the fallback.
local function StandingText(standing)
    if not standing then return "" end
    if type(GetText) == "function" then
        local ok, text = pcall(GetText, "FACTION_STANDING_LABEL" .. standing, UnitSex and UnitSex("player") or nil)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return _G["FACTION_STANDING_LABEL" .. standing] or ""
end
Bars.StandingText = StandingText

local function FactionColour(standing)
    local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
    if c and c.r then return c.r, c.g, c.b end
    return unpack(CFG.COLORS.UNKNOWN)
end

local function FillRepSlot(index)
    local bar = repSlots[index]
    local wanted = Settings.Reps()[index]
    bar.standing:SetText("")
    local found
    if wanted and wanted ~= 0 then
        for _, f in ipairs(ns.Factions()) do
            if f.id == wanted then found = f break end
        end
    end
    if not found then
        bar.data = nil
        bar:Hide()
        return
    end
    bar.data = {
        name = found.name, rank = found.value - found.min,
        maxRank = math.max(1, found.max - found.min),
        isRep = true, standingText = StandingText(found.standing),
    }
    bar.icon:Hide()
    bar.nameOffset = 0
    bar.nameText:ClearAllPoints()
    bar.nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, S("textGap"))
    bar.nameText:SetText(found.name)
    bar.valueText:SetText(string.format("%d/%d", bar.data.rank, bar.data.maxRank))
    bar.sb:SetMinMaxValues(0, bar.data.maxRank)
    bar.sb:SetValue(math.min(bar.data.rank, bar.data.maxRank))
    bar.sb:SetStatusBarColor(FactionColour(found.standing))
    bar.standing:SetText(bar.data.standingText)
    bar.standing:Show()
    bar:Show()
end

function ns.RefreshReputation()
    if not container then return end
    ns.Factions(true)
    for i = 1, CFG.NUM_REP_SLOTS do FillRepSlot(i) end
    Layout()
end

-- One faction menu for all four bars; menuSlot says which one.
local factionMenu, menuSlot

function ns.OpenFactionMenu(slot, anchor)
    if not (UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo
            and UIDropDownMenu_AddButton and ToggleDropDownMenu) then
        return false
    end
    menuSlot = slot
    if not factionMenu then
        factionMenu = CreateFrame("Frame", "ForeverProgressBarsFactionMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(factionMenu, function(_, level)
        local chosen = Settings.Reps()[menuSlot]
        local empty = UIDropDownMenu_CreateInfo()
        empty.text = L.REP_EMPTY
        empty.checked = (chosen == nil or chosen == 0)
        empty.func = function()
            Settings.SetRep(menuSlot, 0)
            if CloseDropDownMenus then CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(empty, level)
        for _, f in ipairs(ns.Factions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = f.name
            info.checked = (chosen == f.id)
            local id = f.id
            info.func = function()
                Settings.SetRep(menuSlot, id)
                if CloseDropDownMenus then CloseDropDownMenus() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")
    ToggleDropDownMenu(1, nil, factionMenu, anchor or "cursor", 0, 0)
    return true
end

-- =============================================================================
-- Build and apply
-- =============================================================================
local function Build()
    if container then return end
    container = CreateFrame("Frame", "ForeverProgressBarsFrame", UIParent)
    container:SetClampedToScreen(true)
    container:SetFrameStrata("MEDIUM")
    for i = 1, CFG.NUM_SLOTS do slots[i] = BuildBar(i) end
    for i = 1, CFG.NUM_REP_SLOTS do repSlots[i] = BuildRepBar(i) end
    BuildLevelBox()
    BuildBackdrop()
    container:SetScript("OnSizeChanged", function(_, w)
        if math.abs((w or 0) - lastWidth) < 0.5 then return end
        Layout()
    end)
    Bars.container = container
end

-- Everything that depends on the settings.
function Bars.ApplyAll()
    if not container then return end
    for i = 1, #slots do ApplyBarGeometry(slots[i]) end
    for i = 1, #repSlots do ApplyBarGeometry(repSlots[i]) end
    ApplyLevelLook()
    ApplyBackdropLook()
    Place()
    ApplyLock()
    Refresh()
    ns.RefreshReputation()
end

Settings.OnChange(function(key)
    if not container then return end
    if key == "x" or key == "y" or key == "width" then
        Place()
        Layout()
    elseif key == "locked" then
        ApplyLock()
    elseif key == "reps" then
        ns.RefreshReputation()
    elseif key == "hidden" then
        Refresh()
    elseif key == "minimapShow" or key == "minimapAngle" then
        return
    else
        Bars.ApplyAll()
    end
end)

Bars.Slot = function(i) return slots[i] end
Bars.RepSlot = function(i) return repSlots[i] end

-- =============================================================================
-- Status, for bug reports (/fpb status). Kept in English.
-- =============================================================================
function Bars.Status()
    local lines = {}
    local function add(...) lines[#lines + 1] = string.format(...) end
    local version, _, _, interface = GetBuildInfo()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    add("%s %s, client %s, interface %s", L.ADDON_NAME,
        tostring(getMetadata and getMetadata(ADDON, "Version") or "?"), tostring(version), tostring(interface))
    add("skills: %s, reputation: %s",
        Api.SkillAPIAvailable() and (hasCSkill() and "C_SkillInfo" or "global") or "MISSING",
        Api.FactionAPIAvailable() and (hasCRep() and "C_Reputation" or "global") or "MISSING")
    if container then
        add("frame: width %.0f, x %s, y %s, locked %s, shown %s",
            container:GetWidth() or 0, tostring(S("x")), tostring(S("y")),
            tostring(S("locked")), tostring((container:IsShown())))
    end
    for i = 1, #slots do
        local b = slots[i]
        local d = b.data
        add("  bar %d: %s%s", i, d and (d.name .. " " .. d.rank .. "/" .. d.maxRank) or "(empty)",
            d and ("  open=" .. (b.open:IsShown() and "spellbook" or (b.click.openSpell and "cast" or "none"))) or "")
    end
    for i = 1, #repSlots do
        local d = repSlots[i].data
        add("  reputation %d: %s", i, d and d.name or "(empty)")
    end
    return lines
end

-- =============================================================================
-- Events
-- =============================================================================
local WANTED_EVENTS = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "SKILL_LINES_CHANGED",
    "CHAT_MSG_SKILL",
    "PLAYER_LEVEL_UP",
    "LEARNED_SPELL_IN_SKILL_LINE",   -- 2.5 name of LEARNED_SPELL_IN_TAB
    "LEARNED_SPELL_IN_TAB",          -- older clients; RegisterEvent throws if unknown
    "PLAYER_REGEN_ENABLED",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_LIST_UPDATE",
    "UPDATE_FACTION",
}

local events = CreateFrame("Frame")
for _, e in ipairs(WANTED_EVENTS) do pcall(events.RegisterEvent, events, e) end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        ResolveProfessionNames()
        Build()
        Bars.ApplyAll()
        ScheduleRefresh(0)
        -- The faction list is not ready at login yet.
        if C_Timer and C_Timer.After then C_Timer.After(2, ns.RefreshReputation) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if container then
            Place()
            ScheduleRefresh()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        if levelText then levelText:SetText(tostring(... or UnitLevel("player"))) end
        ScheduleRefresh()
    elseif event == "UPDATE_FACTION" then
        -- Our own expand/collapse fires this again.
        if not scanningFactions then ns.RefreshReputation() end
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        PressWantedTab()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if clickPending then ApplyClickTargets() end
        if geometryPending then
            geometryPending = false
            for i = 1, #slots do ApplyBarGeometry(slots[i]) end
            for i = 1, #repSlots do ApplyBarGeometry(repSlots[i]) end
        end
    elseif event == "SKILL_LINES_CHANGED" then
        if scanning or GetTime() < suppressSkillEventsUntil then return end
        ScheduleRefresh()
    elseif not scanning then
        ScheduleRefresh()
    end
end)
