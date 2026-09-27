local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings

function ns.ToggleLock()
    Settings.Set("locked", not Settings.Get("locked"))
    ns.Print(Settings.Get("locked") and L.MSG_LOCKED or L.MSG_UNLOCKED)
end

SLASH_FOREVERPROGRESSBARS1 = "/fpb"
SLASH_FOREVERPROGRESSBARS2 = "/foreverprogressbars"
SlashCmdList["FOREVERPROGRESSBARS"] = function(msg)
    local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
    if cmd == "" then
        ns.Window.Toggle()
    elseif cmd == "lock" then
        Settings.Set("locked", true)
        ns.Print(L.MSG_LOCKED)
    elseif cmd == "unlock" then
        Settings.Set("locked", false)
        ns.Print(L.MSG_UNLOCKED)
    elseif cmd == "status" then
        for _, line in ipairs(ns.Bars.Status()) do ns.Print(line) end
    else
        ns.Print(L.MSG_USAGE)
    end
end
