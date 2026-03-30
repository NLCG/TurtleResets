-- ============================================================================
-- TurtleResets - Version Rectifiée (Correction Chevauchement & Détection)
-- ============================================================================

local _G = getfenv(0)
local time, date, tonumber, type, ipairs, pairs, string = _G.time, _G.date, _G.tonumber, _G.type, _G.ipairs, _G.pairs, _G.string
local CreateFrame, UIParent, GetSavedInstanceInfo, GetNumSavedInstances = _G.CreateFrame, _G.UIParent, _G.GetSavedInstanceInfo, _G.GetNumSavedInstances

local CYCLES = { ["R40"] = 604800, ["ONY"] = 432000, ["KARA"] = 432000, ["R20"] = 259200 }
local L = {}
local currentLockouts = {}
local inputFields = {}

-- 1. Détection stricte (évite le faux positif pFQuest)
local _, _, _, enabled = GetAddOnInfo("pfUI")
local hasPfUI = enabled

-- ============================================================================
-- FONCTIONS CORE
-- ============================================================================

local function TR_SetLanguage(langCode)
    local targetLang = langCode
    if not _G.TurtleResetsL[targetLang] then targetLang = "en" end
    L = _G.TurtleResetsL[targetLang]
    
    if TR_MainFrame then 
        TR_MainFrame.title:SetText(L["WINDOW_TITLE"] or "TurtleResets")
        TR_MainFrame.h2:SetText(L["TAB_INSTANCE"] or "Instance")
        TR_MainFrame.h3:SetText(L["TAB_RESET"] or "Next Reset")
    end
    
    if TR_OptionsFrame then
        TR_OptionsFrame.title:SetText(L["OPT_TITLE"] or "Settings")
        TR_OptionsFrame.saveBtn:SetText(L["BTN_SAVE"] or "Save")
        TR_OptionsFrame.cancelBtn:SetText(L["BTN_CANCEL"] or "Cancel")
        TR_OptionsFrame.langLbl:SetText(L["OPT_LANG"] or "Language")
        for id, group in pairs(inputFields) do
            if group.label then group.label:SetText(L["OPT_"..id] or id) end
            if group.hJ then group.hJ:SetText(L["LABEL_DAYS"] or "D") end
            if group.hH then group.hH:SetText(L["LABEL_HOURS"] or "H") end
            if group.hM then group.hM:SetText(L["LABEL_MINUTES"] or "M") end
        end
    end
end

local function TR_PerformScan()
    local now = time()
    currentLockouts = {}
    for i = 1, GetNumSavedInstances() do
        local name, _, reset = GetSavedInstanceInfo(i)
        if name and reset and reset > 0 then
            local function check(lk)
                for _, lt in pairs(_G.TurtleResetsL) do 
                    if lt[lk] and string.find(name, lt[lk]) then return true end 
                end
                return false
            end
            local sk, rt = nil, nil
            if check("SCAN_MC") then sk="SCAN_MC"; rt="R40"
            elseif check("SCAN_BWL") then sk="SCAN_BWL"; rt="R40"
            elseif check("SCAN_AQ40") then sk="SCAN_AQ40"; rt="R40"
            elseif check("SCAN_NAXX") then sk="SCAN_NAXX"; rt="R40"
            elseif check("SCAN_ES") then sk="SCAN_ES"; rt="R40"
            elseif check("SCAN_ONY") then sk="SCAN_ONY"; rt="ONY"
            elseif check("SCAN_KARA") then sk="SCAN_KARA"; rt="KARA"
            elseif check("SCAN_ZG") then sk="SCAN_ZG"; rt="R20"
            elseif check("SCAN_AQ20") then sk="SCAN_AQ20"; rt="R20" end
            if sk then currentLockouts[sk] = true end
            if rt then TurtleResetsDB.refs[rt] = now + reset end
        end
    end
end

local function TR_GetRaidStatus(raidKey, scanKeys, displayNames)
    local styledNames = ""
    for i, sk in ipairs(scanKeys) do
        local color = currentLockouts[sk] and "|cffff0000" or "|cff00ff00"
        local sep = (i > 1) and " / " or ""
        styledNames = styledNames .. sep .. color .. displayNames[i] .. "|r"
    end
    local ref = TurtleResetsDB.refs[raidKey] or 0
    if ref == 0 then return styledNames, "|cff999999" .. (L["TO_SET"] or "To set") .. "|r" end
    local now = time()
    if ref < now then
        local cycle = CYCLES[raidKey] or 604800
        while ref < now do ref = ref + cycle end
        TurtleResetsDB.refs[raidKey] = ref
    end
    local dayIdx = tonumber(date("%w", ref))
    local dayName = (L["DAYS"] and L["DAYS"][dayIdx]) or ""
    return styledNames, "|cffffffff" .. dayName .. " " .. date("%d/%m %H:%M", ref) .. "|r"
end

-- ============================================================================
-- UI MAIN
-- ============================================================================

function TR_UpdateUI()
    if not TR_MainFrame or not TR_MainFrame:IsVisible() then return end
    -- Augmentation de la largeur standard pour éviter le chevauchement
    TR_MainFrame:SetWidth(hasPfUI and 280 or 350)
    TR_MainFrame:SetHeight(hasPfUI and 145 or 170)
    for i, data in ipairs(TR_MainFrame.raidList) do
        local styledNames, timer = TR_GetRaidStatus(data[1], data[2], data[3])
        TR_MainFrame.rows[i].name:SetText(styledNames)
        TR_MainFrame.rows[i].timer:SetText(timer)
    end
end

function TR_CreateUI()
    if TR_MainFrame then return end

    local f = CreateFrame("Frame", "TR_MainFrame", UIParent)
    f:SetPoint("CENTER", 0, 0)
    if hasPfUI then
        f:SetWidth(280); f:SetHeight(145); _G.pfUI.api.CreateBackdrop(f)
    else
        f:SetWidth(350); f:SetHeight(170)
        f:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
            tile=true, tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}
        })
    end

    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -12)

    local close = CreateFrame("Button", nil, f, (not hasPfUI and "UIPanelCloseButton" or nil))
    close:SetPoint("TOPRIGHT", -5, -5)
    if hasPfUI then
        close:SetWidth(15); close:SetHeight(15); _G.pfUI.api.CreateBackdrop(close)
        close.txt = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        close.txt:SetPoint("CENTER", 0, 0); close.txt:SetText("x")
    end
    close:SetScript("OnClick", function() TR_MainFrame:Hide(); if TR_OptionsFrame then TR_OptionsFrame:Hide() end end)

    local topOffset = hasPfUI and -35 or -40
    local lineSpacing = hasPfUI and 15 or 18

    f.h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.h2:SetPoint("TOPLEFT", 15, topOffset)
    f.h3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.h3:SetPoint("TOPRIGHT", -15, topOffset)

    f.rows = {}
    f.raidList = {
        { "R40", { "SCAN_MC", "SCAN_BWL", "SCAN_AQ40", "SCAN_NAXX", "SCAN_ES" }, { "MC", "BWL", "AQ40", "Naxx", "ES" } },
        { "ONY", { "SCAN_ONY" }, { "Onyxia" } },
        { "KARA", { "SCAN_KARA" }, { "Karazhan" } },
        { "R20", { "SCAN_ZG", "SCAN_AQ20" }, { "ZG", "AQ20" } }
    }

    for i, _ in ipairs(f.raidList) do
        local nm = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetPoint("TOPLEFT", 15, topOffset - (i * lineSpacing))
        nm:SetJustifyH("LEFT") -- Force l'alignement à gauche
        local tm = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tm:SetPoint("TOPRIGHT", -15, topOffset - (i * lineSpacing))
        tm:SetJustifyH("RIGHT") -- Force l'alignement à droite
        f.rows[i] = { name=nm, timer=tm }
    end

    local optBtn = CreateFrame("Button", nil, f, (not hasPfUI and "UIPanelButtonTemplate" or nil))
    optBtn:SetPoint("BOTTOM", 0, 15); optBtn:SetWidth(80); optBtn:SetHeight(18); optBtn:SetText("Options")
    if hasPfUI then
        _G.pfUI.api.CreateBackdrop(optBtn)
        local t = optBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", 0, 0); t:SetText("Options")
        optBtn:SetFontString(t)
    end
    optBtn:SetScript("OnClick", function() if TR_OptionsFrame:IsVisible() then TR_OptionsFrame:Hide() else TR_OptionsFrame:Show() end end)

    local opt = CreateFrame("Frame", "TR_OptionsFrame", UIParent)
    opt:SetPoint("LEFT", f, "RIGHT", 5, 0); opt:SetWidth(320); opt:SetHeight(420)
    if hasPfUI then _G.pfUI.api.CreateBackdrop(opt) else
        opt:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
            tile=true, tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}
        })
    end
    opt.title = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opt.title:SetPoint("TOP", 0, -15)

    local function CreateInputGroup(parent, y, rKey, uID)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 20, y)
        local function MB(x)
            local eb = CreateFrame("EditBox", nil, parent)
            eb:SetPoint("TOPLEFT", x, y - 30); eb:SetWidth(80); eb:SetHeight(24); eb:SetAutoFocus(false); eb:SetText("0")
            eb:SetFontObject("GameFontHighlightSmall"); eb:SetTextInsets(8, 0, 0, 0)
            if hasPfUI then _G.pfUI.api.CreateBackdrop(eb) else eb:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background", edgeFile="Interface\\Buttons\\UI-SliderBar-Border", tile=true, tileSize=8, edgeSize=8, insets={left=3, right=3, top=3, bottom=3}}) end
            local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            l:SetPoint("TOPLEFT", x, y - 14); l:SetTextColor(0.7, 0.7, 0.7)
            return eb, l
        end
        local d, ld = MB(20); local h, lh = MB(110); local m, lm = MB(200)
        inputFields[uID] = { key=rKey, label=lbl, hJ=ld, hH=lh, hM=lm, d=d, h=h, m=m }
    end

    CreateInputGroup(opt, -45, "R40", "R40"); CreateInputGroup(opt, -115, "ONY", "ONY")
    CreateInputGroup(opt, -185, "KARA", "KARA"); CreateInputGroup(opt, -255, "R20", "R20")

    opt.langLbl = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opt.langLbl:SetPoint("TOPLEFT", 20, -345)

    local startX = 100
    if _G.TurtleResetsL then
        for langCode, _ in pairs(_G.TurtleResetsL) do
            local b = CreateFrame("Button", nil, opt, (not hasPfUI and "UIPanelButtonTemplate" or nil))
            b:SetPoint("TOPLEFT", startX, -340); b:SetWidth(40); b:SetHeight(20); b:SetText(string.upper(langCode))
            if hasPfUI then
                _G.pfUI.api.CreateBackdrop(b)
                local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                t:SetPoint("CENTER", 0, 0); t:SetText(string.upper(langCode))
                b:SetFontString(t)
            end
            b:SetScript("OnClick", function() 
                TurtleResetsDB.lang = string.lower(this:GetText()); TR_SetLanguage(TurtleResetsDB.lang); TR_UpdateUI() 
            end)
            startX = startX + 45
        end
    end

    opt.saveBtn = CreateFrame("Button", nil, opt, (not hasPfUI and "UIPanelButtonTemplate" or nil))
    opt.saveBtn:SetPoint("BOTTOMLEFT", 20, 25); opt.saveBtn:SetWidth(130); opt.saveBtn:SetHeight(24); opt.saveBtn:SetText("Save")
    if hasPfUI then
        _G.pfUI.api.CreateBackdrop(opt.saveBtn)
        local t = opt.saveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", 0, 0); t:SetText("Save")
        opt.saveBtn:SetFontString(t)
    end
    opt.saveBtn:SetScript("OnClick", function()
        for _, fields in pairs(inputFields) do
            local d, h, m = tonumber(fields.d:GetText()) or 0, tonumber(fields.h:GetText()) or 0, tonumber(fields.m:GetText()) or 0
            if (d+h+m) > 0 then TurtleResetsDB.refs[fields.key] = time() + (d*86400) + (h*3600) + (m*60) end
            fields.d:SetText("0"); fields.h:SetText("0"); fields.m:SetText("0")
        end
        TR_UpdateUI(); opt:Hide()
    end)

    opt.cancelBtn = CreateFrame("Button", nil, opt, (not hasPfUI and "UIPanelButtonTemplate" or nil))
    opt.cancelBtn:SetPoint("BOTTOMRIGHT", -20, 25); opt.cancelBtn:SetWidth(130); opt.cancelBtn:SetHeight(24); opt.cancelBtn:SetText("Cancel")
    if hasPfUI then
        _G.pfUI.api.CreateBackdrop(opt.cancelBtn)
        local t = opt.cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", 0, 0); t:SetText("Cancel")
        opt.cancelBtn:SetFontString(t)
    end
    opt.cancelBtn:SetScript("OnClick", function() opt:Hide() end)
    
    f:Hide(); opt:Hide()
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "TurtleResets" then
        if not TurtleResetsDB then 
            local clientLang = string.sub(_G.GetLocale(), 1, 2)
            local defaultLang = _G.TurtleResetsL[clientLang] and clientLang or "en"
            TurtleResetsDB = { refs = { R40=0, ONY=0, KARA=0, R20=0 }, lang = defaultLang } 
        end
        TR_CreateUI()
        TR_SetLanguage(TurtleResetsDB.lang)
        this:UnregisterEvent("ADDON_LOADED")
    end
end)

_G.SLASH_TURTLERESETS1 = "/tr"
_G.SlashCmdList["TURTLERESETS"] = function()
    if not TR_MainFrame then TR_CreateUI() end
    if TR_MainFrame:IsVisible() then 
        TR_MainFrame:Hide(); if TR_OptionsFrame then TR_OptionsFrame:Hide() end
    else 
        _G.RequestRaidInfo(); TR_PerformScan(); TR_MainFrame:Show(); TR_UpdateUI() 
    end
end
