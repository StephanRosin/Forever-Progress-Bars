--[[---------------------------------------------------------------------------
XpInfo.lua -- extra lines on the XP bar, each off by default: time on this
level, time this session, XP per hour, time to the next level, quests
completed on this character, the rested bonus (only while there is one).
Each sits at one of the numbers' places
(XpBar.VALUE_PLACES) plus X/Y, in the numbers' font, and goes with the bar.

The session starts at login and survives /reload (kept per character in
ForeverProgressBarsChar.xpSession). The time on this level comes from
/played: asked for once per session, with the chat frames' line about it
muted for that one answer.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local Settings, L = ns.Settings, ns.L
local S = Settings.Get

local Info = {}
ns.XpInfo = Info

-- Order of the lines and of their option blocks; the settings are
-- xpInfo<id>, xpInfo<id>Place, xpInfo<id>X, xpInfo<id>Y.
Info.IDS = { "LevelTime", "SessionTime", "PerHour", "ToLevel", "Quests", "Rested" }

function Info.Now() return (GetServerTime or time)() end

-- 2d 14h 11m; below a minute "< 1m".
function Info.Duration(sec)
    sec = math.floor(sec or 0)
    if sec < 60 then return L.DUR_LESS end
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    local parts = {}
    if d > 0 then parts[#parts + 1] = L.DUR_D:format(d) end
    if d > 0 or h > 0 then parts[#parts + 1] = L.DUR_H:format(h) end
    parts[#parts + 1] = L.DUR_M:format(m)
    return table.concat(parts, " ")
end

-- XP per hour, or nil while there is nothing to go by.
function Info.PerHour(gained, seconds)
    if not gained or gained <= 0 or not seconds or seconds <= 0 then return nil end
    return gained / seconds * 3600
end

-- XP gained between two readings; across a level-up the rest of the old
-- level counts too.
function Info.Gain(lastXP, lastMax, xp)
    if xp >= lastXP then return xp - lastXP end
    return math.max(0, lastMax - lastXP) + xp
end

local function session()
    ns.DB()   -- makes sure ForeverProgressBarsChar exists
    return ForeverProgressBarsChar.xpSession
end

local function newSession()
    ns.DB()
    ForeverProgressBarsChar.xpSession = { start = Info.Now(), gained = 0,
        lastXP = UnitXP("player") or 0, lastMax = UnitXPMax("player") or 0 }
end

local levelBase, levelAt      -- seconds on this level at levelAt (from /played)
local questCount               -- nil until known

local function countQuests()
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ids = C_QuestLog.GetAllCompletedQuestIDs()
        return type(ids) == "table" and #ids or nil
    end
    if GetQuestsCompleted then
        local n = 0
        for _ in pairs(GetQuestsCompleted() or {}) do n = n + 1 end
        return n
    end
end

-- The text of one line now; "--" while it cannot be known yet.
function Info.Text(id)
    local s, now = session(), Info.Now()
    local none = L.XPINFO_NONE
    if id == "LevelTime" then
        return L.XPINFO_LEVELTIME:format(levelBase and Info.Duration(levelBase + now - levelAt) or none)
    elseif id == "SessionTime" then
        return L.XPINFO_SESSIONTIME:format(s and Info.Duration(now - s.start) or none)
    end
    local rate = s and Info.PerHour(s.gained, now - s.start)
    if id == "PerHour" then
        local big = BreakUpLargeNumbers or tostring
        return L.XPINFO_PERHOUR:format(rate and big(math.floor(rate)) or none)
    elseif id == "ToLevel" then
        local left = (UnitXPMax("player") or 0) - (UnitXP("player") or 0)
        return L.XPINFO_TOLEVEL:format(rate and Info.Duration(left / rate * 3600) or none)
    elseif id == "Quests" then
        return L.XPINFO_QUESTS:format(questCount and tostring(questCount) or none)
    elseif id == "Rested" then
        local rested, max = (GetXPExhaustion and GetXPExhaustion()) or 0, UnitXPMax("player") or 0
        local big = BreakUpLargeNumbers or tostring
        return L.XPINFO_RESTED:format(big(rested), max > 0 and math.floor(rested / max * 100) or 0)
    end
    return ""
end

local texts = {}   -- id -> FontString
function Info.TextOf(id) return texts[id] end

local function hasRested() return ((GetXPExhaustion and GetXPExhaustion()) or 0) > 0 end

function Info.Update()
    -- The rested line only while there is rested XP.
    if texts.Rested then texts.Rested:SetShown(S("xpInfoRested") and hasRested()) end
    for id, fs in pairs(texts) do
        if fs:IsShown() then fs:SetText(Info.Text(id)) end
    end
end

-- The lines' size: their own, or the numbers'.
function Info.FontSize()
    return S("xpInfoFontSize") > 0 and S("xpInfoFontSize") or ns.XpBar.ValueSize()
end

-- Creates, styles and places the lines that are on; hides the others.
-- Font and colour: their own, or the numbers'.
function Info.Apply()
    local bar = ns.Bars.XpSlot and ns.Bars.XpSlot()
    local layer = ns.XpBar.TextLayer()
    if not bar or not layer then return end
    local path, _, flags = bar.valueText:GetFont()
    if S("xpInfoFont") ~= "" then path = ns.Media.FontPath(S("xpInfoFont")) end
    local size = Info.FontSize()
    local r, g, b = bar.valueText:GetTextColor()
    if S("xpInfoColorOwn") then r, g, b = unpack(S("xpInfoColor")) end
    for _, id in ipairs(Info.IDS) do
        local key = "xpInfo" .. id
        local fs = texts[id]
        if S(key) and not fs then
            fs = layer:CreateFontString(nil, "OVERLAY")
            texts[id] = fs
        end
        if fs then
            fs:SetShown(S(key))
            if S(key) then   -- placed even while hidden (Rested), so it is ready
                if path then pcall(fs.SetFont, fs, path, size, flags) end
                if r then fs:SetTextColor(r, g, b) end
                ns.XpBar.PlaceText(fs, S(key .. "Place"), S(key .. "X"), S(key .. "Y"))
            end
        end
    end
    if S("xpInfoQuests") and not questCount then questCount = countQuests() end
    Info.Update()
end

-- /played without the chat line: the chat frames stop listening for this
-- one answer (at most a few seconds) and listen again after it.
local muted
local function unmute()
    if not muted then return end
    for _, f in ipairs(muted) do f:RegisterEvent("TIME_PLAYED_MSG") end
    muted = nil
end

local asked = false
local function askPlayed()
    if asked or not RequestTimePlayed then return end
    asked = true
    muted = {}
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local f = _G["ChatFrame" .. i]
        if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
            f:UnregisterEvent("TIME_PLAYED_MSG")
            muted[#muted + 1] = f
        end
    end
    RequestTimePlayed()
    C_Timer.After(5, unmute)
end

Settings.OnChange(function(key)
    if key == nil or key == "xpInfoLevelTime" then
        if S("xpInfoLevelTime") then askPlayed() end
    end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG",
    "QUEST_TURNED_IN", "UPDATE_EXHAUSTION" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_ENTERING_WORLD" then
        -- A fresh login starts a session; /reload and loading screens keep it.
        if a1 or not session() then newSession() end
        questCount = countQuests()
        if S("xpInfoLevelTime") then askPlayed() end
    elseif event == "PLAYER_XP_UPDATE" then
        local s = session()
        if s then
            local xp = UnitXP("player") or 0
            s.gained = s.gained + Info.Gain(s.lastXP, s.lastMax, xp)
            s.lastXP, s.lastMax = xp, UnitXPMax("player") or 0
        end
    elseif event == "PLAYER_LEVEL_UP" then
        levelBase, levelAt = 0, Info.Now()
    elseif event == "TIME_PLAYED_MSG" then
        levelBase, levelAt = a2 or 0, Info.Now()
        C_Timer.After(0, unmute)
    elseif event == "QUEST_TURNED_IN" then
        -- The list knows the quest a moment later.
        C_Timer.After(1, function() questCount = countQuests(); Info.Update() end)
    end
    Info.Update()
end)

-- The times run on: once a second, only while a line shows.
local since = 0
events:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 1 then return end
    since = 0
    Info.Update()
end)
