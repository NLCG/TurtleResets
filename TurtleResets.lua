-- ============================================================================
-- TurtleResets - On-Demand Scan Version
-- ============================================================================

local _G = getfenv(0)
local time, date, tonumber, type, ipairs, pairs, string = _G.time, _G.date, _G.tonumber, _G.type, _G.ipairs, _G.pairs, _G.string
local CreateFrame, UIParent, GetSavedInstanceInfo, GetNumSavedInstances = _G.CreateFrame, _G.UIParent, _G.GetSavedInstanceInfo, _G.GetNumSavedInstances

local CYCLES = { ["R40"] = 604800, ["ONY"] = 432000, ["KARA"] = 432000, ["R20"] = 259200 }
local L = {}
local currentLockouts = {}
local inputFields = {}

local hasPfUI = _G.pfUI and _G.pfUI.api

-- ============================================================================
-- FONCTIONS CORE
-- ============================================================================

local function TR_SetLanguage(langCode)
    local targetLang = langCode
    -- Si la langue demandée n'existe pas, on bascule sur l'anglais
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
            group.hJ:SetText(L["LABEL_DAYS"] or "D")
            group.hH:SetText(L["LABEL_HOURS"] or "H")
            group.hM:SetText(L["LABEL_MINUTES"] or "M")
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
            elseif check("SCAN_ES") then sk="SCAN_ES"; rt="R40" -- Support Emerald Sanctum
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
    
    local ref = (TurtleResetsDB and TurtleResetsDB.refs) and TurtleResetsDB.refs[raidKey] or 0
    if ref == 0 then
        return styledNames, "|cff999999" .. (L["TO_SET"] or "To set") .. "|r"
    end
    
    local now = time()
    if ref < now then
        local cycle = CYCLES[raidKey] or 604800
        while ref < now do ref = ref + cycle end
        TurtleResetsDB.refs[raidKey] = ref
    end
    
    local dayIdx = tonumber(date("%w", ref))
    local dayName = (L["DAYS"] and L["DAYS"][dayIdx]) or ""
    local dayStr = (type(dayName) == "string") and dayName or ""
    
    return styledNames, "|cffffffff" .. dayStr .. " " .. date("%d/%m %H:%M", ref) .. "|r"
end

-- ============================================================================
-- UI
-- ============================================================================

local function TR_ApplySkin(f)
    if not f then return end
    if hasPfUI then _G.pfUI.api.CreateBackdrop(f) else
        f:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
            tile=true, tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}
        })
    end
end

local function TR_SkinButton(b)
    if not b or not hasPfUI then return end
    _G.pfUI.api.CreateBackdrop(b)
    b:SetNormalTexture(nil); b:SetPushedTexture(nil); b:SetHighlightTexture(nil)
    local border = b.backdrop or b
    local br, bg, bb = 0.5, 0.5, 0.5
    local yr, yg, yb = 1, 1, 0
    if _G.pfUI.cache and _G.pfUI.cache.color then
        local c = _G.pfUI.cache.color
        if c.border then br, bg, bb = c.border.r or br, c.border.g or bg, c.border.b or bb end
        if c.yellow then yr, yg, yb = c.yellow.r or yr, c.yellow.g or yg, c.yellow.b or yb end
    end
    b:SetScript("OnEnter", function() border:SetBackdropBorderColor(yr, yg, yb) end)
    b:SetScript("OnLeave", function() border:SetBackdropBorderColor(br, bg, bb) end)
    border:SetBackdropBorderColor(br, bg, bb)
end

local function TR_CreateUI()
    local f = CreateFrame("Frame", "TR_MainFrame", UIParent)
    f:SetPoint("CENTER", 0, 0);
    -- Ajustement dynamique de la taille
    if hasPfUI then
        f:SetWidth(280)  -- Un peu moins large car pfUI est plus compact
        f:SetHeight(140) -- Moins haut pour resserrer l'espace
    else
        f:SetWidth(320)
        f:SetHeight(170)
    end
    TR_ApplySkin(f)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -12)
    
    local close = CreateFrame("Button", nil, f, (hasPfUI and nil or "UIPanelCloseButton"))
    close:SetPoint("TOPRIGHT", -5, -5)
    if hasPfUI then
        close:SetWidth(16); close:SetHeight(16); TR_SkinButton(close)
        close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        close.text:SetPoint("CENTER", 0, 0); close.text:SetText("x")
    end
    close:SetScript("OnClick", function() TR_MainFrame:Hide(); if TR_OptionsFrame then TR_OptionsFrame:Hide() end end)

    f.h2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.h2:SetPoint("TOPLEFT", 15, -40)
    f.h3 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.h3:SetPoint("TOPRIGHT", -15, -40)

    f.rows = {}
    -- Ajout de ES dans la liste d'affichage Raid 40
    f.raidList = {
        { "R40", { "SCAN_MC", "SCAN_BWL", "SCAN_AQ40", "SCAN_NAXX", "SCAN_ES" }, { "MC", "BWL", "AQ40", "Naxx", "ES" } },
        { "ONY", { "SCAN_ONY" }, { "Onyxia" } },
        { "KARA", { "SCAN_KARA" }, { "Karazhan" } },
        { "R20", { "SCAN_ZG", "SCAN_AQ20" }, { "ZG", "AQ20" } }
    }

    for i, data in ipairs(f.raidList) do
        local nm = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetPoint("TOPLEFT", 15, -40 - (i * 18))
        local tm = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tm:SetPoint("TOPRIGHT", -15, -40 - (i * 18))
        f.rows[i] = { name=nm, timer=tm }
    end

    local optBtn = CreateFrame("Button", nil, f, (hasPfUI and nil or "UIPanelButtonTemplate"))
    optBtn:SetPoint("BOTTOM", 0, 15); optBtn:SetWidth(80); optBtn:SetHeight(18); optBtn:SetText("Options")
    TR_SkinButton(optBtn)
    optBtn:SetScript("OnClick", function() if TR_OptionsFrame:IsVisible() then TR_OptionsFrame:Hide() else TR_OptionsFrame:Show() end end)

    local opt = CreateFrame("Frame", "TR_OptionsFrame", UIParent)
    opt:SetPoint("LEFT", f, "RIGHT", 5, 0); opt:SetWidth(320); opt:SetHeight(420); TR_ApplySkin(opt)
    opt.title = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opt.title:SetPoint("TOP", 0, -15)

    local function CreateInputGroup(parent, y, rKey, uID)
        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 20, y)
        local function MB(x)
            local eb = CreateFrame("EditBox", nil, parent)
            eb:SetPoint("TOPLEFT", x, y - 30); eb:SetWidth(80); eb:SetHeight(24); eb:SetAutoFocus(false); eb:SetText("0")
            eb:SetFontObject("GameFontHighlightSmall"); eb:SetTextInsets(8, 0, 0, 0); TR_ApplySkin(eb)
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
    for langCode, _ in pairs(_G.TurtleResetsL) do
        local b = CreateFrame("Button", nil, opt, (hasPfUI and nil or "UIPanelButtonTemplate"))
        b:SetPoint("TOPLEFT", startX, -340); b:SetWidth(40); b:SetHeight(20); b:SetText(string.upper(langCode)); TR_SkinButton(b)
        b:SetScript("OnClick", function() 
            -- Mémorisation forcée de la langue
            TurtleResetsDB.lang = string.lower(this:GetText()); TR_SetLanguage(TurtleResetsDB.lang); TR_UpdateUI() 
        end)
        startX = startX + 45
    end

    opt.saveBtn = CreateFrame("Button", nil, opt, (hasPfUI and nil or "UIPanelButtonTemplate"))
    opt.saveBtn:SetPoint("BOTTOMLEFT", 20, 25); opt.saveBtn:SetWidth(130); opt.saveBtn:SetHeight(24); TR_SkinButton(opt.saveBtn)
    opt.saveBtn:SetScript("OnClick", function()
        for _, fields in pairs(inputFields) do
            local d, h, m = tonumber(fields.d:GetText()) or 0, tonumber(fields.h:GetText()) or 0, tonumber(fields.m:GetText()) or 0
            if (d+h+m) > 0 then TurtleResetsDB.refs[fields.key] = time() + (d*86400) + (h*3600) + (m*60) end
            fields.d:SetText("0"); fields.h:SetText("0"); fields.m:SetText("0")
        end
        TR_UpdateUI(); opt:Hide()
    end)

    opt.cancelBtn = CreateFrame("Button", nil, opt, (hasPfUI and nil or "UIPanelButtonTemplate"))
    opt.cancelBtn:SetPoint("BOTTOMRIGHT", -20, 25); opt.cancelBtn:SetWidth(130); opt.cancelBtn:SetHeight(24); TR_SkinButton(opt.cancelBtn)
    opt.cancelBtn:SetScript("OnClick", function() opt:Hide() end)
    
    f:Hide(); opt:Hide()
end

function TR_UpdateUI()
    if not TR_MainFrame or not TR_MainFrame:IsVisible() then return end
    for i, data in ipairs(TR_MainFrame.raidList) do
        local styledNames, timer = TR_GetRaidStatus(data[1], data[2], data[3])
        TR_MainFrame.rows[i].name:SetText(styledNames)
        TR_MainFrame.rows[i].timer:SetText(timer)
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "TurtleResets" then
        if not TurtleResetsDB then 
            -- Détection automatique de la langue client
            local clientLang = string.sub(_G.GetLocale(), 1, 2)
            -- Fallback sur l'anglais si non supportée
            local defaultLang = _G.TurtleResetsL[clientLang] and clientLang or "en"
            
            TurtleResetsDB = { refs = { R40=0, ONY=0, KARA=0, R20=0 }, lang = defaultLang } 
        end
        TR_CreateUI()
        -- On applique la langue enregistrée (auto ou forcée)
        TR_SetLanguage(TurtleResetsDB.lang)
        this:UnregisterEvent("ADDON_LOADED")
    end
end)

_G.SLASH_TURTLERESETS1 = "/tr"
_G.SlashCmdList["TURTLERESETS"] = function()
    if TR_MainFrame:IsVisible() then 
        TR_MainFrame:Hide() 
    else 
        _G.RequestRaidInfo(); 
        TR_PerformScan(); 
        TR_MainFrame:Show(); 
        TR_UpdateUI() 
    end
end