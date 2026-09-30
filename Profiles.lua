--[[---------------------------------------------------------------------------
Profiles.lua -- named profiles: position, size and look of the bars, the
reputation factions and which skills are hidden.

Split like AceDB and Details! do it:

    ForeverProgressBarsProfiles   account wide   the profiles themselves
    ForeverProgressBarsChar       per character  which profile is active

A character stores only the NAME of its profile, so two characters can share
one profile: they point to the same entry, not to a copy.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

-- Every character starts on this one.
local DEFAULT = "Default"
ns.DEFAULT_PROFILE = DEFAULT

local ready = false

-- Deep copy. Profiles must not share sub tables, or a change to one would
-- silently change the profile it was copied from.
local function Copy(t)
    if type(t) ~= "table" then return t end
    local new = {}
    for k, v in pairs(t) do new[k] = Copy(v) end
    return new
end

local function Init()
    if ready then return end
    ready = true

    ForeverProgressBarsProfiles = ForeverProgressBarsProfiles or {}
    ForeverProgressBarsProfiles.profiles = ForeverProgressBarsProfiles.profiles or {}
    ForeverProgressBarsChar = ForeverProgressBarsChar or {}

    local profiles, char = ForeverProgressBarsProfiles.profiles, ForeverProgressBarsChar
    if not char.active then
        char.active = DEFAULT
    end
    -- A new character, or its profile was deleted on another character:
    -- start from an empty profile (the defaults) rather than from nothing.
    if not profiles[char.active] then
        profiles[char.active] = {}
    end
end

-- The active profile's settings. Initialised lazily, so it does not matter
-- who asks first.
function ns.DB()
    Init()
    return ForeverProgressBarsProfiles.profiles[ForeverProgressBarsChar.active]
end

-- Account wide values outside the profiles (the language).
function ns.AccountDB()
    Init()
    return ForeverProgressBarsProfiles
end

function ns.ActiveProfile()
    Init()
    return ForeverProgressBarsChar.active
end

-- Presets are profiles too, read-only: stored under "@" .. their id and
-- rebuilt from Settings.PRESETS when chosen and at every load, so changes
-- to them last only until the next reload. What is the player's own (lock,
-- minimap button, reputations, hidden skills) stays across rebuilds.
local PRESET_MARK = "@"
function ns.IsPreset(name) return type(name) == "string" and name:sub(1, 1) == PRESET_MARK end
function ns.PresetName(id) return PRESET_MARK .. id end
function ns.PresetId(name) return ns.IsPreset(name) and name:sub(2) or nil end

local OWN = { "locked", "minimapShow", "minimapAngle", "reps", "hidden" }

local function buildPreset(preset, keepFrom)
    local t = Copy(preset.values)
    for _, k in ipairs(OWN) do
        if keepFrom and keepFrom[k] ~= nil then t[k] = Copy(keepFrom[k]) end
    end
    -- Values equal to the default need not be stored.
    local defaults = ns.Settings.DEFAULTS
    for k, v in pairs(t) do
        if type(v) ~= "table" and v == defaults[k] then t[k] = nil end
    end
    return t
end

-- Rebuilds every preset profile (keepFrom: where the player's own values
-- come from; each preset's own stored ones by default).
function ns.RebuildPresets(keepFrom)
    Init()
    if not (ns.Settings and ns.Settings.PRESETS) then return end
    local profiles = ForeverProgressBarsProfiles.profiles
    for _, preset in ipairs(ns.Settings.PRESETS) do
        local name = PRESET_MARK .. preset.id
        profiles[name] = buildPreset(preset, keepFrom or profiles[name])
    end
end

-- The player's own profiles (sorted), then the presets in their order.
function ns.ProfileList()
    Init()
    local list = {}
    for name in pairs(ForeverProgressBarsProfiles.profiles) do
        if not ns.IsPreset(name) then list[#list + 1] = name end
    end
    table.sort(list)
    for _, preset in ipairs((ns.Settings and ns.Settings.PRESETS) or {}) do
        list[#list + 1] = PRESET_MARK .. preset.id
    end
    return list
end

-- The player's own profiles only (the last one cannot be deleted).
function ns.OwnProfileCount()
    local n = 0
    for _, name in ipairs(ns.ProfileList()) do
        if not ns.IsPreset(name) then n = n + 1 end
    end
    return n
end

local function applyLook()
    if ns.Settings then ns.Settings.Changed(nil) end
end

-- Switches to a profile. A name that does not exist yet is created from the
-- CURRENT settings, so "save as" is the same operation.
function ns.SwitchProfile(name)
    if type(name) ~= "string" or name == "" then return false end
    Init()
    if ns.IsPreset(name) then
        -- Fresh from the code; the player's own values come along from the
        -- profile being left when that is one of theirs.
        local id = ns.PresetId(name)
        local from = ns.DB()
        for _, preset in ipairs(ns.Settings.PRESETS) do
            if preset.id == id then
                ForeverProgressBarsProfiles.profiles[name] = buildPreset(preset,
                    ns.IsPreset(ForeverProgressBarsChar.active) and ForeverProgressBarsProfiles.profiles[name] or from)
            end
        end
        if not ForeverProgressBarsProfiles.profiles[name] then return false end
    elseif not ForeverProgressBarsProfiles.profiles[name] then
        ForeverProgressBarsProfiles.profiles[name] = Copy(ns.DB())
    end
    ForeverProgressBarsChar.active = name
    applyLook()
    return true
end

-- Copies another profile into the active one; you stay on your own profile.
function ns.CopyProfileFrom(name)
    Init()
    local source = ForeverProgressBarsProfiles.profiles[name]
    if not source or name == ForeverProgressBarsChar.active then return false end
    ForeverProgressBarsProfiles.profiles[ForeverProgressBarsChar.active] = Copy(source)
    applyLook()
    return true
end

-- Deletes a profile. If it was the active one, the character falls back to
-- the default profile instead of pointing to nothing.
function ns.DeleteProfile(name)
    Init()
    if ns.IsPreset(name) then return false end   -- presets stay
    local profiles = ForeverProgressBarsProfiles.profiles
    if not profiles[name] then return false end
    local wasActive = (ForeverProgressBarsChar.active == name)
    profiles[name] = nil
    if wasActive then
        profiles[DEFAULT] = profiles[DEFAULT] or {}
        ForeverProgressBarsChar.active = DEFAULT
        applyLook()
    end
    return true
end

-- Tests only: forget the lazy start.
function ns.ResetProfileState() ready = false end

-- ---------------------------------------------------------------------------
-- The dialogs behind the two profile buttons in the options. Written after
-- Blizzard's own dialogs: `hasEditBox = 1` and `dialog:GetEditBox()`. Their
-- text is set when they open, so it follows the chosen language.
-- ---------------------------------------------------------------------------
-- The options window (Options/Window.lua) sets ns.RefreshOptions.
local function refreshOptions()
    if ns.RefreshOptions then pcall(ns.RefreshOptions) end
end

local function saveAs(name)
    if name and name ~= "" then
        ns.SwitchProfile(name)
        refreshOptions()
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs["FOREVERPROGRESSBARS_PROFILE_NEW"] = {
        text = "",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 40,
        OnAccept = function(dialog)
            local box = dialog.GetEditBox and dialog:GetEditBox()
            saveAs(box and box:GetText())
        end,
        EditBoxOnEnterPressed = function(editBox)
            saveAs(editBox:GetText())
            editBox:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
    }

    StaticPopupDialogs["FOREVERPROGRESSBARS_PROFILE_DELETE"] = {
        text = "",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, name)
            ns.DeleteProfile(name)
            refreshOptions()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, exclusive = true,
    }
end

function ns.AskProfileName()
    if not StaticPopup_Show then return end
    StaticPopupDialogs["FOREVERPROGRESSBARS_PROFILE_NEW"].text = L.POPUP_PROFILE_NAME
    StaticPopup_Show("FOREVERPROGRESSBARS_PROFILE_NEW")
end

function ns.AskDeleteProfile()
    local name = ns.ActiveProfile()
    if ns.IsPreset(name) then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.ADDON_NAME .. ":|r " .. L.MSG_PRESET_NO_DELETE)
        end
        return
    end
    -- The last profile stays, or the character would have none.
    if ns.OwnProfileCount() <= 1 then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L.ADDON_NAME .. ":|r " .. L.MSG_LAST_PROFILE)
        end
        return
    end
    if not StaticPopup_Show then return end
    StaticPopupDialogs["FOREVERPROGRESSBARS_PROFILE_DELETE"].text = L.POPUP_PROFILE_DELETE
    StaticPopup_Show("FOREVERPROGRESSBARS_PROFILE_DELETE", name, nil, name)
end
