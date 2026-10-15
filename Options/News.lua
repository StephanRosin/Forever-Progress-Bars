local ADDON, ns = ...

-- What's new, as in Forever Unit Frames (/fuf news): the news of a version,
-- keyed by the version in the TOC (## Version), one locale key per line,
-- and a button that opens where the news is. /fpb news shows it again.
--
-- It shows by itself once per new version with news, after an update: a
-- moment after the first loading screen is gone and out of combat. Not at
-- PLAYER_LOGIN: UIParent shows again after the loading screen and its
-- OnShow closes every UISpecialFrames window, ours included; the delay lets
-- that run first, and a hidden UIParent is waited for.
-- ForeverProgressBarsProfiles.newsSeen is the newest version this account
-- has had news for. It shows when newsSeen is older, or when there is none
-- but the account had settings before this login (an update from a
-- version before the news). A fresh install shows nothing and records the
-- version at once. The version is recorded once the window is visible.
local News = {}
ns.News = News

local L, Style, Widgets = ns.L, ns.Style, ns.Widgets

News.ENTRIES = {
    ["1.7.0"] = {
        lines = { "NEWS_1_7_0_STYLES", "NEWS_1_7_0_FOREVER", "NEWS_1_7_0_TEXTS", "NEWS_1_7_0_OWN",
            "NEWS_1_7_0_MENU", "NEWS_1_7_0_LEVEL", "NEWS_1_7_0_MORE" },
        -- The XP bar's page, or General where it is switched on.
        action = { text = "NEWS_OPEN_XP",
            run = function() ns.Window.Open(ns.Settings.Get("xpEnabled") and "xp" or "general") end },
    },
}

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

function News.Current() return getMetadata and getMetadata(ADDON, "Version") or nil end

function News.Entry(version)
    if type(version) ~= "string" then return nil end
    return News.ENTRIES[version]
end

-- -1, 0 or 1 as version a is older than, the same as or newer than b.
function News.Compare(a, b)
    local pa, pb = {}, {}
    for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

local hadSettings   -- the account held settings before this login
local waiting       -- logged in, the loading screen not yet gone

local function account() return ns.AccountDB() end
local function seenVersion()
    local seen = account().newsSeen
    return type(seen) == "string" and seen or nil
end

-- At ADDON_LOADED, before anything writes: did a profile hold anything?
-- (A profile stores only what differs from the defaults.)
function News.Begin(saved)
    hadSettings = false
    if type(saved) == "table" and type(saved.profiles) == "table" then
        for _, p in pairs(saved.profiles) do
            if type(p) == "table" and next(p) ~= nil then hadSettings = true end
        end
    end
    waiting = true
    local current = News.Current()
    if not hadSettings and not seenVersion() and News.Entry(current) then account().newsSeen = current end
end

function News.Due()
    local current = News.Current()
    if not News.Entry(current) then return false end
    local seen = seenVersion()
    if seen then return News.Compare(seen, current) < 0 end
    return hadSettings == true
end

-- The window ---------------------------------------------------------------------

local WIDTH, MIN_H, MAX_H = 560, 360, 600
local TITLE_H, FOOTER_H, INSET, LINE_GAP, BULLET_W, FONT = 32, 44, 16, 8, 12, 13
local WHEEL_STEP = 20
local WINDOW_NAME = "ForeverProgressBarsNews"

local frame, shown, lines = nil, nil, {}

local function close() if frame then frame:Hide() end end

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, MIN_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.title = Style.Text(bar, 16, "text")
    frame.title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    frame.sub = Style.Text(bar, 11, "muted")
    frame.sub:SetPoint("BOTTOMLEFT", frame.title, "BOTTOMRIGHT", 8, 1)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    frame.closeButton = Widgets.Button(footer, { text = "", width = 120, onClick = close })
    frame.closeButton:SetPoint("RIGHT", footer, "RIGHT", -12, 0)
    frame.actionButton = Widgets.Button(footer, { text = "", width = 200, onClick = function()
        local entry = News.Entry(shown)
        close()
        if entry and entry.action then entry.action.run() end
    end })
    frame.actionButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.hint = Style.Text(footer, 11, "muted")
    frame.hint:SetPoint("LEFT", footer, "LEFT", INSET, 0)
    frame.hint:SetPoint("RIGHT", frame.actionButton, "LEFT", -8, 0)
    frame.hint:SetJustifyH("LEFT")
    frame.footer = footer

    -- The list scrolls with the mouse wheel when taller than the window.
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -INSET)
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, INSET)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(frame.range or 0, v)))
    end)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH, 1)
    scroll:SetScrollChild(child)
    frame.scroll, frame.child = scroll, child
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, WINDOW_NAME) end
end

-- The i-th line: a bullet and a text that wraps.
local function line(i)
    if lines[i] then return lines[i] end
    local bullet = Style.Text(frame.child, FONT, "accent")
    bullet:SetText("•")
    local text = Style.Text(frame.child, FONT, "text")
    text:SetWidth(WIDTH - 2 * INSET - BULLET_W)
    text:SetJustifyH("LEFT")
    if text.SetWordWrap then text:SetWordWrap(true) end
    if i == 1 then
        text:SetPoint("TOPLEFT", frame.child, "TOPLEFT", INSET + BULLET_W, 0)
    else
        text:SetPoint("TOPLEFT", lines[i - 1].text, "BOTTOMLEFT", 0, -LINE_GAP)
    end
    bullet:SetPoint("TOPRIGHT", text, "TOPLEFT", -4, 0)
    lines[i] = { bullet = bullet, text = text }
    return lines[i]
end

local function render()
    local entry = News.Entry(shown)
    if not entry then return end
    frame.title:SetText(L.NEWS_TITLE:format(shown))
    frame.sub:SetText(L.ADDON_NAME)
    local listH = 0
    for i, key in ipairs(entry.lines) do
        local item = line(i)
        item.text:SetText(L[key])
        item.bullet:Show(); item.text:Show()
        local h = item.text:GetStringHeight()
        listH = listH + ((h and h > 0) and h or FONT) + (i > 1 and LINE_GAP or 0)
    end
    for i = #entry.lines + 1, #lines do lines[i].bullet:Hide(); lines[i].text:Hide() end
    frame.closeButton.text:SetText(L.NEWS_CLOSE)
    frame.hint:SetText(L.NEWS_AGAIN)
    frame.actionButton:SetShown(entry.action ~= nil)
    if entry.action then frame.actionButton.text:SetText(L[entry.action.text]) end
    local fixed = TITLE_H + FOOTER_H + 2 * INSET
    local height = math.min(MAX_H, math.max(MIN_H, fixed + listH))
    frame:SetHeight(height)
    frame.child:SetHeight(math.max(1, listH))
    frame.range = math.max(0, listH - (height - fixed))
    frame.scroll:SetVerticalScroll(0)
end

-- Shows the news of a version; false (nothing shown) when it has none.
function News.Open(version)
    if not News.Entry(version) then return false end
    if not frame then createWindow() end
    shown = version
    render()
    frame:Show()
    return true
end

function News.IsOpen() return frame ~= nil and frame:IsShown() end
News.Close = close

-- Showing at login ----------------------------------------------------------------

local SHOW_DELAY = 1   -- seconds after the loading screen

-- Out of combat, after the loading screen: shows the news if due and
-- records the version once the window is visible.
function News.AtLogin()
    if not News.Due() then return end
    if InCombatLockdown and InCombatLockdown() then
        News.afterCombat = true
        return
    end
    if not UIParent:IsShown() then
        News.afterUIParent = true
        return
    end
    local current = News.Current()
    if News.Open(current) and frame:IsVisible() then account().newsSeen = current end
end

local function later()
    if C_Timer and C_Timer.After then C_Timer.After(SHOW_DELAY, News.AtLogin) else News.AtLogin() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
pcall(events.RegisterEvent, events, "LOADING_SCREEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then News.Begin(ForeverProgressBarsProfiles) end
    elseif event == "LOADING_SCREEN_DISABLED" then
        -- The first loading screen only; later ones (zone changes) show nothing.
        if not waiting then return end
        waiting = false
        later()
    elseif event == "PLAYER_REGEN_ENABLED" and News.afterCombat then
        News.afterCombat = false
        later()
    end
end)

-- UIParent's next OnShow, when it was hidden at the time.
if UIParent and UIParent.HookScript then
    UIParent:HookScript("OnShow", function()
        if not News.afterUIParent then return end
        News.afterUIParent = false
        later()
    end)
end

-- A new language while open: the texts again.
if ns.Locale and ns.Locale.OnChange then
    ns.Locale.OnChange(function() if News.IsOpen() then render() end end)
end
