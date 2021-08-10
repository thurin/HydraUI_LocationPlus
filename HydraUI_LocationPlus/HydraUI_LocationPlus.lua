if (not HydraUIGlobal) then
    return
end

local HydraUI, GUI, Language, Assets, Settings, Defaults = HydraUIGlobal:get()

local DT = HydraUI:GetModule("DataText")

local Retail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local BCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local Classic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

local LT = nil
if (Retail) then
	LT = LibStub('LibTourist-3.0');
else
	LT = LibStub('LibTouristClassic-1.0');
end

local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat = ChatEdit_ChooseBoxForSend, ChatEdit_ActivateChat
local GetRealZoneText, GetSubZoneText = GetRealZoneText, GetSubZoneText
local IsInInstance, InCombatLockdown = IsInInstance, InCombatLockdown
local GetBindLocation = GetBindLocation
local GetProfessionInfo, GetProfessions = GetProfessionInfo, GetProfessions
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local C_CurrencyInfo_GetCurrencyListSize = C_CurrencyInfo.GetCurrencyListSize
local UIFrameFadeIn, UIFrameFadeOut, ToggleFrame = UIFrameFadeIn, UIFrameFadeOut, ToggleFrame


--------------------
-- Currency Table --
--------------------
-- Add below the currency id you wish to track.
-- Find the currency ids: http://www.wowhead.com/currencies .
-- Click on the wanted currency and in the address you will see the id.
-- e.g. for Bloody Coin, you will see http://www.wowhead.com/currency=789 . 789 is the id.
-- So, on this case, add 789, (don't forget the comma).
-- If there are 0 earned points, the currency will be filtered out.

local currency = {
	-- Shadowlands
	1751,	-- Freed Soul
	1754,	-- Argent Commendation
	1767,   -- Stygia
	1810,	-- Willing Soul
	1813,	-- Reservoir Anima
	1816,   -- Sinstone Fragments
	1820,	-- Infused Ruby
	1822,	-- Renown
	1828, 	-- Soul Ash
	1906,	-- Sould Cinders
	1885,   -- Grateful Offering
	1792,	-- Honor
	1602,	-- New Conquest Points
	1191,	-- Valor
	1977,	-- Stygian Ember
	1904,	-- Tower Knowledge
}

local LocationPlus = HydraUI:NewPlugin("HydraUI_LocationPlus")

function LocationPlus:CreateBar()
	self:SetSize(Settings["locationplus-width"], Settings["locationplus-height"])
	self:SetFrameStrata("MEDIUM")
	if Settings["locationplus-mouseover"] then
		self:SetAlpha(Settings["locationplus-mouseover-opacity"] / 100)
	end

    if Settings["reputation-enable"] then
		self:SetPoint("TOP", "HydraUI Reputation", "BOTTOM", 0, -8)
	elseif (Settings["experience-enable"] and UnitLevel("player") ~= MAX_PLAYER_LEVEL) then
		self:SetPoint("TOP", HydraUIExperienceBar, "BOTTOM", 0, -8)
    else
		self:SetPoint("TOP", HydraUI.UIParent, 0, -13)
	end

    self.BarBG = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.BarBG:SetPoint("TOPLEFT", self, 0, 0)
	self.BarBG:SetPoint("BOTTOMRIGHT", self, 0, 0)
	self.BarBG:SetBackdrop(HydraUI.BackdropAndBorder)
	self.BarBG:SetBackdropColor(HydraUI:HexToRGB(Settings["ui-window-main-color"]))
	self.BarBG:SetBackdropBorderColor(0, 0, 0)

    self.Texture = self.BarBG:CreateTexture(nil, "ARTWORK")
	self.Texture:SetPoint("TOPLEFT", self.BarBG, 1, -1)
	self.Texture:SetPoint("BOTTOMRIGHT", self.BarBG, -1, 1)
	self.Texture:SetTexture(Assets:GetTexture(Settings["ui-header-texture"]))
	self.Texture:SetVertexColor(HydraUI:HexToRGB(Settings["ui-window-main-color"]))

	self.BGAll = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.BGAll:SetPoint("TOPLEFT", self.BarBG, -3, 3)
	self.BGAll:SetPoint("BOTTOMRIGHT", self.BarBG, 3, -3)
	self.BGAll:SetBackdrop(HydraUI.BackdropAndBorder)
	self.BGAll:SetBackdropColor(HydraUI:HexToRGB(Settings["ui-window-bg-color"]))
	self.BGAll:SetBackdropBorderColor(0, 0, 0)

    self.Location = self.BGAll:CreateFontString(nil, "OVERLAY")
	self.Location:SetPoint("LEFT", self.BGAll, 10, 0)
	HydraUI:SetFontInfo(self.Location, Settings["ui-widget-font"], Settings["locationplus-font-size"])
	self.Location:SetJustifyH("LEFT")

    self.Coords = self.BGAll:CreateFontString(nil, "OVERLAY")
	self.Coords:SetPoint("RIGHT", self.BGAll, -10, 0)
	HydraUI:SetFontInfo(self.Coords, Settings["ui-widget-font"], Settings["locationplus-font-size"])
	self.Coords:SetJustifyH("RIGHT")

    HydraUI:CreateMover(self, 6)

end

local function GetLevelRange(zoneText, ontt)
	local mapID = GetBestMapForUnit("player")
	local zoneText = LT:GetMapNameByIDAlt(mapID) or UNKNOWN;
	local low, high = LT:GetLevel(zoneText)
	local dlevel
	if low > 0 and high > 0 then
		local r, g, b = LT:GetLevelColor(zoneText)
		if low ~= high then
			dlevel = format("|cff%02x%02x%02x%d-%d|r", r*255, g*255, b*255, low, high) or ""
		else
			dlevel = format("|cff%02x%02x%02x%d|r", r*255, g*255, b*255, high) or ""
		end

		if ontt then
			return dlevel
		else
			dlevel = format(" (%s) ", dlevel)
		end
	end

	return dlevel or ""
end

local function PvPorRaidFilter(zone)
	local isPvP, isRaid;

	isPvP = nil;
	isRaid = nil;

	if LT:IsBattleground(zone) then
		isPvP = true;
	end

	if(not isPvP and LT:GetInstanceGroupSize(zone) >= 10) then
		isRaid = true;
	end

	return (isPvP and "|cffff0000 "..PVP.."|r" or "")..(isRaid and "|cffff4400 "..RAID.."|r" or "")
end

local function GetRecomZones(zone)
	local low, high = LT:GetLevel(zone)
	local r, g, b = LT:GetLevelColor(zone)
	local zContinent = LT:GetContinent(zone)

	if PvPorRaidFilter(zone) == nil then return end

	GameTooltip:AddDoubleLine(
	"|cffffffff"..zone
	..PvPorRaidFilter(zone) or "",
	format("|cff%02xff00%s|r", continent == zContinent and 0 or 255, zContinent)
	..(" |cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))));
end

local function GetDungeonCoords(zone)
	local z, x, y = "", 0, 0;
	local dcoords

	if LT:IsInstance(zone) then
		z, x, y = LT:GetEntrancePortalLocation(zone);
	end

    if z == nil then
		dcoords = ""
    else
        x = tonumber(Round(x*100, 0))
        y = tonumber(Round(y*100, 0))
        dcoords = format(" |cffffffff(%d, %d)|r", x, y)
    end

	return dcoords
end

local function GetZoneDungeons(dungeon)
	local low, high = LT:GetLevel(dungeon)
	local r, g, b = LT:GetLevelColor(dungeon)
	local groupSize = LT:GetInstanceGroupSize(dungeon)
	local altGroupSize = LT:GetInstanceAltGroupSize(dungeon)
	local groupSizeStyle = (groupSize > 0 and format("|cFFFFFF00|r (%d", groupSize) or "")
	local altGroupSizeStyle = (altGroupSize > 0 and format("|cFFFFFF00|r/%d", altGroupSize) or "")
	local name = dungeon

	if PvPorRaidFilter(dungeon) == nil then return end

	GameTooltip:AddDoubleLine(
	"|cffffffff"..name
	..(groupSizeStyle or "")
	..(altGroupSizeStyle or "").."-"..PLAYER..") "
	..GetDungeonCoords(dungeon)
	..PvPorRaidFilter(dungeon) or "",
	("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))))
end

local function GetRecomDungeons(dungeon)
	local low, high = LT:GetLevel(dungeon);
	local r, g, b = LT:GetLevelColor(dungeon);
	local instZone = LT:GetInstanceZone(dungeon);
	local name = dungeon

	if PvPorRaidFilter(dungeon) == nil then return end

	if instZone == nil then
		instZone = ""
	else
		instZone = "|cFFFFA500 ("..instZone..")"
	end

	GameTooltip:AddDoubleLine(
	"|cffffffff"..name
	..instZone
	..GetDungeonCoords(dungeon)
	..PvPorRaidFilter(dungeon) or "",
	("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255,(low == high and low or ("%d-%d"):format(low, high))))
end

local function GetTokenInfo(id)
	local info = C_CurrencyInfo_GetCurrencyInfo(id)
	if info then
		return info.name, info.quantity, info.iconFileID, info.maxQuantity
	else
		return
	end
end

function LocationPlus:OnEnter()

	if Settings["locationplus-mouseover"] then
		self:SetAlpha(1)
	end

	if not Settings["locationplus-tooltip-show"] then
		GameTooltip:Hide()
		return
	end

	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -8)

	local mapID = GetBestMapForUnit("player")
	local zoneText = LT:GetMapNameByIDAlt(mapID) or UNKNOWN;
	local curPos = (zoneText.." ") or "";

	GameTooltip:ClearLines()

	-- Zone
	GameTooltip:AddDoubleLine("Zone : ", zoneText, 1, 1, 1, selectioncolor)

    -- Continent
	GameTooltip:AddDoubleLine(CONTINENT.." : ", LT:GetContinent(zoneText), 1, 1, 1, selectioncolor)

    -- Home
    GameTooltip:AddDoubleLine(HOME.." :", GetBindLocation(), 1, 1, 1, 0.41, 0.8, 0.94)

    -- Status
    if Settings["locationplus-tooltip-status"] then
        local PVPType, IsFFA, Faction = GetZonePVPInfo()
        local status

        if (PVPType == "friendly" or PVPType == "hostile") then
            status = format(FACTION_CONTROLLED_TERRITORY, Faction)
        elseif (PVPType == "sanctuary") then
            status = SANCTUARY_TERRITORY
        elseif IsFFA then
            status = FREE_FOR_ALL_TERRITORY
        else
            status = CONTESTED_TERRITORY
        end
        local Color = HydraUI.ZoneColors[PVPType or "other"]
        GameTooltip:AddDoubleLine(STATUS.." :", status, 1, 1, 1, Color[1], Color[2], Color[3])
    end

    -- Zone level range
    if Settings["locationplus-tooltip-level-range"] then
        local checklvl = GetLevelRange(zoneText, true)
        if checklvl ~= "" then
            GameTooltip:AddDoubleLine(LEVEL_RANGE.." : ", checklvl, 1, 1, 1)
        end
    end

    -- Recommended zones
    if Settings["locationplus-tooltip-recommended-zones"] then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Recommended Zones :", selectioncolor)
        for zone in LT:IterateRecommendedZones() do
            GetRecomZones(zone);
        end
    end

    -- Instances in the zone
    if Settings["locationplus-tooltip-zone-dungeons"] and LT:DoesZoneHaveInstances(zoneText) then

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(curPos..DUNGEONS.." :", selectioncolor)

        for dungeon in LT:IterateZoneInstances(zoneText) do
            GetZoneDungeons(dungeon);
        end
    end

    -- Recommended Instances
    local level = UnitLevel('player')
	if Settings["locationplus-tooltip-recommended-dungeons"] and LT:HasRecommendedInstances() and level >= 15 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Recommended Dungeons :", selectioncolor)

		for dungeon in LT:IterateRecommendedInstances() do
			GetRecomDungeons(dungeon);
		end
	end

	if Retail then
		if Settings["locationplus-tooltip-currency"] then
			local numEntries = C_CurrencyInfo_GetCurrencyListSize()
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(TOKENS.." :", selectioncolor)

			for _, id in pairs(currency) do
				local name, amount, icon, totalMax = GetTokenInfo(id)

				if(name and amount > 0) then
					icon = ("|T%s:12:12:1:0|t"):format(icon)

					if id == 1822 then -- Renown "cheat"
						amount = amount + 1
						totalMax = totalMax + 1
					end

					if totalMax == 0 then
						GameTooltip:AddDoubleLine(icon..format(" %s : ", name), format("%s", amount ), 1, 1, 1, selectioncolor)
					else
						GameTooltip:AddDoubleLine(icon..format(" %s : ", name), format("%s / %s", amount, totalMax ), 1, 1, 1, selectioncolor)
					end
				end
			end
		end

		local prof1, prof2, archy, fishing, cooking, firstAid = GetProfessions()
		if Settings["locationplus-tooltip-professions"] and (prof1 or prof2 or archy or fishing or cooking or firstAid) then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(TRADE_SKILLS.." :", selectioncolor)

			local proftable = { GetProfessions() }
			for _, id in pairs(proftable) do
				local name, icon, rank, maxRank, _, _, _, rankModifier = GetProfessionInfo(id)

				if rank < maxRank or (not E.db.locplus.profcap) then
					icon = ("|T%s:12:12:1:0|t"):format(icon)
					if (rankModifier and rankModifier > 0) then
						GameTooltip:AddDoubleLine(format("%s %s :", icon, name), (format("%s |cFF6b8df4+ %s|r / %s", rank, rankModifier, maxRank)), 1, 1, 1, selectioncolor)
					else
						GameTooltip:AddDoubleLine(format("%s %s :", icon, name), (format("%s / %s", rank, maxRank)), 1, 1, 1, selectioncolor)
					end
				end
			end
		end

	end

	-- Professions

	if Settings["locationplus-tooltip-hints"] then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine("Click : ", "Toggle WorldMap", 0.7, 0.7, 1, 0.7, 0.7, 1)
		GameTooltip:AddDoubleLine("RightClick : ", "Toggle Configuration",0.7, 0.7, 1, 0.7, 0.7, 1)
		-- GameTooltip:AddDoubleLine("ShiftClick : ", "Send position to chat",0.7, 0.7, 1, 0.7, 0.7, 1)
		-- GameTooltip:AddDoubleLine("CtrlClick : ", "Toggle Datatexts",0.7, 0.7, 1, 0.7, 0.7, 1)
	end

    GameTooltip:Show()
end

function LocationPlus:OnLeave()
    GameTooltip:Hide()

	if Settings["locationplus-mouseover"] then
		self:SetAlpha(Settings["locationplus-mouseover-opacity"] / 100)
	end
end

local Update = function(self, elapsed)
	self.Elapsed = self.Elapsed + elapsed

	if (self.Elapsed > 0.5) then
		local MapID = GetBestMapForUnit("player")

		if MapID then
			local Position = GetPlayerMapPosition(MapID, "player")

			if Position then
				local X, Y = Position:GetXY()
                if Settings["locationplus-detailed-coords"] then
                    self.Coords:SetFormattedText("%.2f, %.2f", X * 100, Y * 100)
                else
                    self.Coords:SetFormattedText("%.0f, %.0f", X * 100, Y * 100)
                end

			end
		end

		self.Elapsed = 0
	end
end

function LocationPlus:OnEvent(event)
	if event == "PLAYER_REGEN_ENABLED" then
		if Settings["locationplus-combat-hide"] then
			UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if Settings["locationplus-combat-hide"] then
			UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
		end
	else
		local subZoneText = GetMinimapZoneText() or ""
		local zoneText = GetRealZoneText() or UNKNOWN;
		local displayLine
		if Settings["locationplus-both"] and (subZoneText ~= "") and (subZoneText ~= zoneText) then
			displayLine = zoneText .. " - " .. subZoneText
		else
			displayLine = subZoneText
		end

		if Settings["locationplus-other"] == "RLEVEL" then
			local displaylvl = GetLevelRange(zoneText) or ""
			if displaylvl ~= "" then
				displayLine = displayLine.."  "..displaylvl
			end
		end

		local PVPType = GetZonePVPInfo()
		local Color = HydraUI.ZoneColors[PVPType or "other"]
		self.Location:SetText(displayLine)
		self.Location:SetTextColor(Color[1], Color[2], Color[3])
	end
end

local function OnMouseUp(self, btn)
    if btn == "LeftButton" then
        if IsShiftKeyDown() then
            -- local zoneText = GetRealZoneText() or UNKNOWN;
			-- local edit_box = ChatEdit_ChooseBoxForSend()
			-- local x, y = CreateCoords()
			-- local message
			-- local coords = x..", "..y
			-- 	if zoneText ~= GetSubZoneText() then
			-- 		message = format("%s: %s (%s)", zoneText, GetSubZoneText(), coords)
			-- 	else
			-- 		message = format("%s (%s)", zoneText, coords)
			-- 	end
			-- ChatEdit_ActivateChat(edit_box)
			-- edit_box:Insert(message)
        elseif IsControlKeyDown() then
        else
            if WorldMapFrame:IsShown() then
                WorldMapFrame:Hide()
            else
                WorldMapFrame:Show()
            end
        end
    end

    if btn == "RightButton" then
        GUI:Toggle()
    end
end

function LocationPlus:CreateDatatextPanels()
	self.LeftFrame = CreateFrame("Frame", "LocationPlusLeftDT", self, "BackdropTemplate")
	self.LeftFrame:SetHeight(Settings["locationplus-height"])
	self.LeftFrame:SetWidth(Settings["locationplus-datatexts-width"])
	self.LeftFrame:SetPoint("RIGHT", self, "LEFT", -9, 0)
	self.LeftFrame:SetBackdrop(HydraUI.BackdropAndBorder)
	self.LeftFrame:SetBackdropColor(0, 0, 0, 0)
	self.LeftFrame:SetBackdropBorderColor(0, 0, 0)

	self.LeftFrame.Tex = self.LeftFrame:CreateTexture(nil, "ARTWORK")
	self.LeftFrame.Tex:SetPoint("TOPLEFT", self.LeftFrame, 1, -1)
	self.LeftFrame.Tex:SetPoint("BOTTOMRIGHT", self.LeftFrame, -1, 1)
	self.LeftFrame.Tex:SetTexture(Assets:GetTexture(Settings["ui-header-texture"]))
	self.LeftFrame.Tex:SetVertexColor(HydraUI:HexToRGB(Settings["ui-window-main-color"]))

	self.LeftFrame.BGAll = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.LeftFrame.BGAll:SetPoint("TOPLEFT", self.LeftFrame, -3, 3)
	self.LeftFrame.BGAll:SetPoint("BOTTOMRIGHT", self.LeftFrame, 3, -3)
	self.LeftFrame.BGAll:SetBackdrop(HydraUI.BackdropAndBorder)
	self.LeftFrame.BGAll:SetBackdropColor(HydraUI:HexToRGB(Settings["ui-window-bg-color"]))
	self.LeftFrame.BGAll:SetBackdropBorderColor(0, 0, 0)

	self.RightFrame = CreateFrame("Frame", "LocationPlusRightDT", self, "BackdropTemplate")
	self.RightFrame:SetHeight(Settings["locationplus-height"])
	self.RightFrame:SetWidth(Settings["locationplus-datatexts-width"])
	self.RightFrame:SetPoint("LEFT", self, "RIGHT", 9, 0)
	self.RightFrame:SetBackdrop(HydraUI.BackdropAndBorder)
	self.RightFrame:SetBackdropColor(0, 0, 0, 0)
	self.RightFrame:SetBackdropBorderColor(0, 0, 0)

	self.RightFrame.Tex = self.RightFrame:CreateTexture(nil, "ARTWORK")
	self.RightFrame.Tex:SetPoint("TOPLEFT", self.RightFrame, 1, -1)
	self.RightFrame.Tex:SetPoint("BOTTOMRIGHT", self.RightFrame, -1, 1)
	self.RightFrame.Tex:SetTexture(Assets:GetTexture(Settings["ui-header-texture"]))
	self.RightFrame.Tex:SetVertexColor(HydraUI:HexToRGB(Settings["ui-window-main-color"]))

	self.RightFrame.BGAll = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.RightFrame.BGAll:SetPoint("TOPLEFT", self.RightFrame, -3, 3)
	self.RightFrame.BGAll:SetPoint("BOTTOMRIGHT", self.RightFrame, 3, -3)
	self.RightFrame.BGAll:SetBackdrop(HydraUI.BackdropAndBorder)
	self.RightFrame.BGAll:SetBackdropColor(HydraUI:HexToRGB(Settings["ui-window-bg-color"]))
	self.RightFrame.BGAll:SetBackdropBorderColor(0, 0, 0)

	local LeftFrameDT = DT:NewAnchor("LP-Left", self.LeftFrame)
	LeftFrameDT:SetSize(self.LeftFrame:GetSize())
	LeftFrameDT:SetPoint("CENTER", self.LeftFrame, 0, 0)
	DT:SetDataText("LP-Left", Settings["locationplus-datatexts-left"])

	local RightFrameDT = DT:NewAnchor("LP-Right", self.RightFrame)
	RightFrameDT:SetSize(self.LeftFrame:GetSize())
	RightFrameDT:SetPoint("CENTER", self.RightFrame, 0, 0)
	DT:SetDataText("LP-Right", Settings["locationplus-datatexts-right"])
end

function LocationPlus:Load()
    if not Settings["locationplus-enable"] then
        print("Location Disabled")
        return
    end
    print("Location Enabled")
    self:CreateBar()

	if Settings["locationplus-datatexts-show"] then
		self:CreateDatatextPanels()
	end

    self:OnEvent()

    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:SetScript("OnEvent", self.OnEvent)
    self.Elapsed = 0
	self:SetScript("OnUpdate", Update)
    self:SetScript("OnMouseUp", OnMouseUp)
    self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)

end

local UpdateBarWidth = function(value)
	LocationPlus:SetWidth(value)
end

local UpdateBarHeight = function(value)
	LocationPlus:SetHeight(value)
end

local UpdateZoneText = function(value)
    LocationPlus:OnEvent()
end

local UpdateBarFont = function()
	HydraUI:SetFontInfo(LocationPlus.Location,Settings["ui-widget-font"], Settings["locationplus-font-size"])
	HydraUI:SetFontInfo(LocationPlus.Coords,Settings["ui-widget-font"], Settings["locationplus-font-size"])
end

local UpdateDTBarWidth = function(value)
	LocationPlus.LeftFrame:SetWidth(value)
	DT:GetAnchor("LP-Left"):SetWidth(value)
	LocationPlus.RightFrame:SetWidth(value)
	DT:GetAnchor("LP-Right"):SetWidth(value)
end

local UpdateDataTextLeft = function(value)
	if Settings["locationplus-datatexts-show"] then
		DT:SetDataText("LP-Left", value)
	end
end

local UpdateDataTextRight = function(value)
	if Settings["locationplus-datatexts-show"] then
		DT:SetDataText("LP-Right", value)
	end
end

local UpdateMouseover = function(value)
	if value then
		LocationPlus:SetAlpha(Settings["locationplus-mouseover-opacity"] / 100)
	else
		LocationPlus:SetAlpha(1)
	end
end

local UpdateMouseoverOpacity = function(value)
	if Settings["locationplus-mouseover"] then
		LocationPlus:SetAlpha(value / 100)
	end
end

GUI:AddWidgets(Language["General"], "LocationPlus", function(left, right)
    right:CreateHeader("LocationPlus")
    right:CreateMessage("", string.format("|cffffa500%s|r|cffffffff%s|r by |cff00c0fa%s|r", "Location", "Plus", "Benik"))
    right:CreateLine("","")
    right:CreateMessage("", "Ported to |cFFFFC44DHydra|r|cFFFFFFFFUI|r by thurin with permission")
    right:CreateHeader("Usage")
    right:CreateLine("", "Click to Toggle WorldMap")
    right:CreateLine("", "Right Click to Toggle HUI Config")

    left:CreateHeader(Language["Enable"])
    left:CreateSwitch("locationplus-enable", Settings["locationplus-enable"], Language["Enable LocationPlus"], Language["Enable LocationPlus Plugin"], ReloadUI):RequiresReload(true)

    left:CreateHeader(Language["Location Panel"])
    left:CreateSwitch("locationplus-both", Settings["locationplus-both"], Language["Enable Both Zone and Subzone"], Language["Enable Both Zone and Subzone"], UpdateZoneText)
    left:CreateDropdown("locationplus-other", Settings["locationplus-other"], {[Language["None"]] = "NONE", ["Level Range"] = "RLEVEL"}, Language["Other Info"], Language["Show additional info in the location panel"], UpdateZoneText)
    left:CreateSwitch("locationplus-detailed-coords", Settings["locationplus-detailed-coords"], Language["Display Detailed Coords"], Language["Coords will be displayed with 2 digits"])
	left:CreateSlider("locationplus-width", Settings["locationplus-width"], 240, 400, 10, Language["Bar Width"], Language["Set the width of the location bar"], UpdateBarWidth)
	left:CreateSlider("locationplus-height", Settings["locationplus-height"], 6, 30, 1, Language["Bar Height"], Language["Set the height of the location bar"], UpdateBarHeight)
    left:CreateSlider("locationplus-font-size", Settings["locationplus-font-size"], 8, 32, 1, Language["Font Size"], Language["Set the font size of the location bar"], UpdateBarFont)
    left:CreateSwitch("locationplus-combat-hide", Settings["locationplus-combat-hide"], Language["Hide in Combat"], Language["Hide in Combat"])
	left:CreateSwitch("locationplus-mouseover", Settings["locationplus-mouseover"], Language["Display On Mouseover"], Language["Only display the Location Plus bar while mousing over it"], UpdateMouseover)
	left:CreateSlider("locationplus-mouseover-opacity", Settings["locationplus-mouseover-opacity"], 0, 100, 5, Language["Mouseover Opacity"], Language["Set the opacity of the Location Plus bar while not mousing over it"], UpdateMouseoverOpacity, nil, "%")

    left:CreateHeader(Language["Tooltip"])
    left:CreateSwitch("locationplus-tooltip-show", Settings["locationplus-tooltip-show"], Language["Show"], Language["Show Tooltip"])
    left:CreateLine("","")
    left:CreateSwitch("locationplus-tooltip-status", Settings["locationplus-tooltip-status"], Language["Status"], Language["Show Status on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-level-range", Settings["locationplus-tooltip-level-range"], Language["Level Range"], Language["Show Level Range on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-recommended-zones", Settings["locationplus-tooltip-recommended-zones"], Language["Recommended Zones"], Language["Show Recommended Zones on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-zone-dungeons", Settings["locationplus-tooltip-zone-dungeons"], Language["Zone Dungeons"], Language["Show Dungeons in the Zone on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-recommended-dungeons", Settings["locationplus-tooltip-recommended-dungeons"], Language["Recommended Dungeons"], Language["Show Recommended Dungeons on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-currency", Settings["locationplus-tooltip-currency"], Language["Currency"], Language["Show Currency on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-professions", Settings["locationplus-tooltip-professions"], Language["Professions"], Language["Show Professions on Tooltip"])
    left:CreateSwitch("locationplus-tooltip-hints", Settings["locationplus-tooltip-hints"], Language["Hints"], Language["Show Hints on Tooltip"])

    left:CreateHeader(Language["DataTexts"])
    left:CreateSwitch("locationplus-datatexts-show", Settings["locationplus-datatexts-show"], Language["Show"], Language["Show DataTexts"], ReloadUI):RequiresReload(true)
    left:CreateLine("","")
	left:CreateSlider("locationplus-datatexts-width", Settings["locationplus-datatexts-width"], 70, 200, 10, Language["DataText Width"], Language["Set the width of the DataText"], UpdateDTBarWidth)
	left:CreateDropdown("locationplus-datatexts-left", Settings["locationplus-datatexts-left"], DT.List, Language["Set Left Datatext"], Language["Set the information to be displayed in the left data text anchor"], UpdateDataTextLeft)
	left:CreateDropdown("locationplus-datatexts-right", Settings["locationplus-datatexts-right"], DT.List, Language["Set Right Datatext"], Language["Set the information to be displayed in the right data text anchor"], UpdateDataTextRight)


end)