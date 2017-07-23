------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

Addon:SetDefaultModuleLibraries("AceEvent-3.0");

local AceDB = LibStub("AceDB-3.0");
local LibSharedMedia = LibStub("LibSharedMedia-3.0");

-- Adding default media to LibSharedMedia in case they're not already added
LibSharedMedia:Register("font", "DorisPP", [[Interface\AddOns\Experiencer\media\DORISPP.TTF]]);

EXPERIENCER_SPLITS_TIP = "You can now split Experiencer bar in up to three different sections allowing you to display more information at once.|n|nRight-click the bar to see options.";

local TEXT_VISIBILITY_HIDE      = 1;
local TEXT_VISIBILITY_HOVER     = 2;
local TEXT_VISIBILITY_ALWAYS    = 3;

local FrameLevels = {
	"rested",
	"visualSecondary",
	"visualPrimary",
	"change",
	"main",
	"color",
	"highlight",
	"textFrame",
};

Addon.activeModules = {}
Addon.orderedModules = {};

ExperiencerModuleBarsMixin = {
	module   = nil,
	moduleId = "",
	
	previousData     = nil,
	hasModuleChanged = false,
	changeTarget     = 0,
	
	hasBuffer        = false,
	bufferTimeout    = 0,
};

function Addon:GetPlayerClassColor()
	local _, class = UnitClass("player");
	return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or 'PRIEST'];
end

function Addon:GetBarColor()
	if(self.db.global.Color.UseClassColor) then
		return Addon:GetPlayerClassColor();
	else
		return {
			r = self.db.global.Color.r,
			g = self.db.global.Color.g,
			b = self.db.global.Color.b
		};
	end
end

function Addon:OnInitialize()
	local defaults = {
		char = {
			Visible 	    = true,
			TextVisibility  = TEXT_VISIBILITY_ALWAYS,
			
			ActiveModule    = nil, -- Old setting now obsolete
			NumSplits       = 1,
			ActiveModules   = { },
			
			DataBrokerSource = 1,
		},
		
		global = {
			AnchorPoint	    = "BOTTOM",
			BigBars         = false,
			FlashLevelUp    = true,
			
			FontFace = "DorisPP",
			FontScale = 1,
			
			Color = {
				UseClassColor = true,
				r = 1,
				g = 1,
				b = 1,
			},
			
			SplitsTipShown = false,
		}
	};
	
	self.db = AceDB:New("ExperiencerDB", defaults);
end

function ExperiencerSplitsAlertCloseButton_OnClick(self)
	Addon.db.global.SplitsTipShown = true;
end

function Addon:OnEnable()
	Addon:InitializeDataBroker();
	
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	Addon:RegisterEvent("PET_BATTLE_OPENING_START");
	Addon:RegisterEvent("PET_BATTLE_CLOSE");
	
	Addon:InitializeModules();
	
	if(self.db.char.ActiveModule ~= nil) then
		self.db.char.ActiveModules[1] = self.db.char.ActiveModule;
		self.db.char.ActiveModule = nil;
	end
	
	if(self.db.char.ActiveModules[1] == nil) then
		self.db.char.ActiveModules[1] = "experience";
	end
	
	for index = 1, self.db.char.NumSplits do
		if(self.db.char.ActiveModules[index]) then
			Addon:SetModule(index, self.db.char.ActiveModules[index], true);
		else
			local newModule = Addon:FindValidModuleForBar(index);
			Addon:SetModule(index, newModule.id, true);
		end
	end
	
	Addon:UpdateFrames();
	
	Addon:RefreshBars(true);
	Addon:UpdateVisiblity();
end

function Addon:IsBarVisible()
	return self.db.char.Visible;
end

function Addon:InitializeModules()
	for moduleId, module in Addon:IterateModules() do
		Addon.orderedModules[module.order] = module;
		
		if(module.savedvars) then
			module.db = AceDB:New("ExperiencerDB_module_" .. moduleId, module.savedvars);
		end
		
		module:Initialize();
	end
end

function Addon:RegisterModule(moduleId, prototype)
	if(Addon:GetModule(moduleId, true) ~= nil) then
		error(("Addon:RegisterModule(moduleId[, prototype]): Module '%s' is already registered."):format(tostring(moduleId)), 2);
		return;
	end
	
	local module = Addon:NewModule(moduleId, prototype or {});
	module.id = moduleId;

	module.Refresh = function(self, instant)
		Addon:RefreshModule(self, instant);
	end

	module.RefreshText = function(self)
		Addon:RefreshText(self);
	end
	
	return module;
end

function Addon:ToggleVisibility(visiblity)
	self.db.char.Visible = visiblity or not self.db.char.Visible;
	Addon:UpdateVisiblity();
end

function Addon:UpdateVisiblity()
	if(self.db.char.Visible) then
		Addon:ShowBar();
	else
		Addon:HideBar();
	end
end

function Addon:ShowBar()
	ExperiencerFrameBars:Show();
	
	if(Addon.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS) then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame:Show();
		end
	end
end

function Addon:HideBar()
	ExperiencerFrameBars:Hide();
end

function Addon:GetProgressColor(progress)
	local r = math.min(1.0, math.max(0.0, 2.0 - progress * 1.8));
	local g = math.min(1.0, math.max(0.0, progress * 2.0));
	local b = 0;
	
	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255);
end

function Addon:PlayerHasBuff(spellID)
	local spellName = GetSpellInfo(spellID);
	return UnitAura("player", spellName) ~= nil;
end

local function roundnum(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function Addon:FormatNumber(num)
	num = tonumber(num);
	
	if(num >= 1000000) then
		num = roundnum((num / 1000000), 2) .. "m";
	elseif(num >= 1000) then
		num = roundnum((num / 1000), 2) .. "k";
	end
	
	return num;
end

function Addon:FormatNumberFancy(num, billions)
	billions = billions or true;
	num = tonumber(num);
	
	local divisor = 1;
	local suffix = "";
	if(num >= 1e9 and billions) then
		suffix = "b";
		divisor = 1e9;
	elseif(num >= 1e6) then
		suffix = "m";
		divisor = 1e6;
	elseif(num >= 1e3) then
		suffix = "k";
		divisor = 1e3;
	end
	
	return BreakUpLargeNumbers(num / divisor) .. suffix;
end

function Addon:GetCurrentSplit()
	return Addon.db.char.NumSplits;
end

function Addon:RefreshModule(module, instant)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		if(moduleFrame.module == module) then
			moduleFrame:Refresh(instant);
			return;
		end
	end
end

function Addon:RefreshText(module)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		if(not module or moduleFrame.module == module) then
			moduleFrame:RefreshText();
		end
		if(moduleFrame.module == module) then return end
	end
end

function Addon:GetModuleFrame(index)
	assert(tonumber(index) ~= nil, "Index must be a number");
	local frameName = "ExperiencerFrameBarsModule" .. tonumber(index);
	return _G[frameName];
end

function Addon:GetModuleFrameIterator()
	return ipairs({
		Addon:GetModuleFrame(1),
		Addon:GetModuleFrame(2),
		Addon:GetModuleFrame(3),
	});
end

function Addon:UpdateFrames()
	local anchor = Addon.db.global.AnchorPoint or "BOTTOM";
	local offset = 0;
	if(anchor == "TOP") then offset = 1 end
	if(anchor == "BOTTOM") then offset = -1 end
	
	ExperiencerFrame:ClearAllPoints();
	ExperiencerFrame:SetPoint(anchor .. "LEFT", UIParent, anchor .. "LEFT", 0, offset);
	ExperiencerFrame:SetPoint(anchor .. "RIGHT", UIParent, anchor .. "RIGHT", 0, offset);
	
	if(not Addon.db.global.SplitsTipShown) then
		local alertFrame = ExperiencerFrame.SplitsAlert;
		
		alertFrame:ClearAllPoints();
		alertFrame.Arrow:ClearAllPoints();
		
		if(anchor == "BOTTOM") then
			alertFrame:SetPoint("BOTTOM", ExperiencerFrame, "TOP", 0, 30);
			alertFrame.Arrow:SetPoint("TOP", alertFrame, "BOTTOM", 0, 2);
			SetClampedTextureRotation(alertFrame.Arrow.Arrow, 0);
			SetClampedTextureRotation(alertFrame.Arrow.Glow, 0);
		elseif(anchor == "TOP") then
			alertFrame:SetPoint("TOP", ExperiencerFrame, "BOTTOM", 0, -30);
			alertFrame.Arrow:SetPoint("BOTTOM", alertFrame, "TOP", 0, -2);
			SetClampedTextureRotation(alertFrame.Arrow.Arrow, 180);
			SetClampedTextureRotation(alertFrame.Arrow.Glow, 180);
		end
		
		alertFrame.Arrow.Glow:Hide();
		alertFrame:Show();
	end
	
	if(not Addon.db.global.BigBars) then
		ExperiencerFrame:SetHeight(10);
	else
		ExperiencerFrame:SetHeight(17);
	end
	
	local numSplits = Addon:GetCurrentSplit();
	
	local width, height = ExperiencerFrameBars:GetSize();
	local sectionWidth = width / numSplits;
	
	local parentFrame = ExperiencerFrameBars;
	local moduleBar1 = Addon:GetModuleFrame(1);
	local moduleBar2 = Addon:GetModuleFrame(2);
	local moduleBar3 = Addon:GetModuleFrame(3);
	
	moduleBar1:ClearAllPoints();
	moduleBar2:ClearAllPoints();
	moduleBar3:ClearAllPoints();
	
	if(numSplits == 1) then
		moduleBar1:Show();
		moduleBar1:SetAllPoints(parentFrame);
		
		moduleBar2:Hide();
		moduleBar3:Hide();
	elseif(numSplits == 2) then
		moduleBar1:Show();
		moduleBar1:SetPoint("TOPLEFT",     parentFrame, "TOPLEFT",    0, 0);
		moduleBar1:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT", 0, 0);
		moduleBar1:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOM",     0, 0);
		
		moduleBar2:Show();
		moduleBar2:SetPoint("TOPRIGHT",    parentFrame, "TOPRIGHT",    0, 0);
		moduleBar2:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOM",      0, 0);
		moduleBar2:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0);
		
		moduleBar3:Hide();
	elseif(numSplits == 3) then
		moduleBar1:Show();
		moduleBar1:SetPoint("TOPLEFT",     parentFrame, "TOPLEFT",    0, 0);
		moduleBar1:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMLEFT", 0, 0);
		moduleBar1:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMLEFT", sectionWidth, 0);
		
		moduleBar2:Show();
		moduleBar2:SetPoint("TOP",         parentFrame, "TOP",    0, 0);
		moduleBar2:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOM", -sectionWidth / 2, 0);
		moduleBar2:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOM",  sectionWidth / 2, 0);
		
		moduleBar3:Show();
		moduleBar3:SetPoint("TOPRIGHT",    parentFrame, "TOPRIGHT",    0, 0);
		moduleBar3:SetPoint("BOTTOMLEFT",  parentFrame, "BOTTOMRIGHT", -sectionWidth, 0);
		moduleBar3:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0);
	end
	
	local c = Addon:GetBarColor();
	local ib = 1 - (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b); -- calculate inverse brightness
	
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		moduleFrame.main:SetStatusBarColor(c.r, c.g, c.b);
		moduleFrame.main:SetAnimatedTextureColors(c.r, c.g, c.b);
		
		moduleFrame.color:SetStatusBarColor(c.r, c.g, c.b, 0.23 + ib * 0.26); -- adjust color strength by brightness
		moduleFrame.rested:SetStatusBarColor(c.r, c.g, c.b, 0.3);
		
		moduleFrame.visualPrimary:SetStatusBarColor(c.r, c.g, c.b, 0.375);
		moduleFrame.visualSecondary:SetStatusBarColor(c.r, c.g, c.b, 0.375);
		
		moduleFrame.textFrame:ClearAllPoints();
		moduleFrame.textFrame:SetPoint(anchor, moduleFrame, anchor);
		moduleFrame.textFrame:SetWidth(sectionWidth);
		
		local fontPath = LibSharedMedia:Fetch("font", self.db.global.FontFace);
		ExperiencerFont:SetFont(fontPath, math.floor(10 * self.db.global.FontScale), "OUTLINE");
		ExperiencerBigFont:SetFont(fontPath, math.floor(13 * self.db.global.FontScale), "OUTLINE");
		
		local frameHeightMultiplier = (self.db.global.FontScale - 1.0) * 0.55 + 1.0;
		
		if(not Addon.db.global.BigBars) then
			moduleFrame.textFrame:SetHeight(math.max(18, 20 * frameHeightMultiplier));
			moduleFrame.textFrame.text:SetFontObject("ExperiencerFont");
		else
			moduleFrame.textFrame:SetHeight(math.max(24, 28 * frameHeightMultiplier));
			moduleFrame.textFrame.text:SetFontObject("ExperiencerBigFont");
		end
		
		for index, frameName in ipairs(FrameLevels) do
			local frame = moduleFrame[frameName];
			if(index == 1) then
				baseFrameLevel = frame:GetFrameLevel();
			else
				frame:SetFrameLevel(baseFrameLevel + index - 1);
			end
		end
	end
end

function ExperiencerModuleBarsMixin:SetActiveModule(moduleId)
	assert(moduleId ~= nil);
	self.moduleId = moduleId;
	self.module = Addon:GetModule(moduleId);
	self:Refresh(true);
end

function ExperiencerModuleBarsMixin:RemoveActiveModule()
	self.moduleId = "";
	self.module = nil;
	self:Refresh(true);
end

function ExperiencerModuleBarsMixin:SetAnimationSpeed(speed)
	assert(speed and speed > 0);
	
	speed = (1 / speed) * 0.5;
	self.main.tileTemplateDelay = 0.3 * speed;
	
	local durationPerDistance = 0.008 * speed;
	
	for index, anim in ipairs({ self.main.Anim:GetAnimations() }) do
		if(anim.durationPerDistance) then
			anim.durationPerDistance = durationPerDistance;
		end
		if(anim.delayPerDistance) then
			anim.delayPerDistance = durationPerDistance;
		end
	end
end

function ExperiencerModuleBarsMixin:StopAnimation()
	for index, anim in ipairs({ self.main.Anim:GetAnimations() }) do
		anim:Stop();
	end	
end

function Addon:RefreshBars(instant)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		moduleFrame:Refresh(instant);
	end
end

function ExperiencerModuleBarsMixin:TriggerBufferedUpdate(instant)
	if(not self.module) then return end
	
	local data = self.module:GetBarData();
	
	local valueHasChanged = true;
	
	local isLoss = false;
	local changeCurrent = data.current;
	
	if(self.previousData and not self.hasModuleChanged) then
		if(data.level == self.previousData.level and data.current < self.previousData.current) then
			isLoss = true;
			changeCurrent = self.previousData.current;
		end
		
		if(data.level < self.previousData.level) then
			isLoss = true;
			changeCurrent = data.max;
		end
		
		if(data.current == self.previousData.current) then
			valueHasChanged = false;
		end
	end
	
	if(not isLoss) then
		self.main.accumulationTimeoutInterval = 0.01;
	else
		self.main.accumulationTimeoutInterval = 0.35;
	end
	
	self.main.matchBarValueToAnimation = true;
	
	self:SetAnimationSpeed(1.0);
	
	if(valueHasChanged and not self.hasModuleChanged) then
		if(self.previousData and not isLoss) then
			local current = data.current;
			local previous = self.previousData.current;
			
			if(not self.hasModuleChanged and self.previousData.level < data.level) then
				current = current + self.previousData.max;
			end
			
			local diff = (current - previous) / data.max;
			local speed = math.max(1, math.min(10, diff * 1.2 + 1.0));
			speed = speed * speed;
			self:SetAnimationSpeed(speed);
		end
		
		self.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
	else
		self.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
		self.main:ProcessChangesInstantly();
	end
	
	if(instant or isLoss) then
		self.main:ProcessChangesInstantly();
	end
	
	if(not instant and valueHasChanged and not self.hasModuleChanged) then
		if(not isLoss) then
			self.change.fadegain_in:Stop();
			self.change.fadegain_out:Stop();
			self.change.fadegain_out:Play();
		end
		self.main.spark.fade:Stop();
		self.main.spark.fade:Play();
	end
	
	self.previousData = data;
end

function Addon:ShouldShowSecondaryText(moduleIndex)
	return self.db.char.NumSplits < 3 or (Addon.Hovering and Addon:GetModuleIndexFromMousePosition() == moduleIndex);
end

function ExperiencerModuleBarsMixin:RefreshText()
	local text = "";
	local brokerText = "";
	
	if(self.module) then
		local primaryText, secondaryText = self.module:GetText();
		if(secondaryText and string.len(secondaryText) == 0) then secondaryText = nil end
		
		if(secondaryText and Addon:ShouldShowSecondaryText(self:GetID())) then
			text = string.trim(primaryText .. "  " .. secondaryText);
		elseif(secondaryText) then
			text = string.trim(primaryText .. "  |cffffff00+|r");
		else
			text = string.trim(primaryText);
		end
		
		brokerText = string.trim(primaryText .. "  " .. (secondaryText or ""));
	end
	
	self.textFrame.text:SetText(text);
	if(Addon.db.char.DataBrokerSource == self:GetID()) then
		Addon:UpdateDataBrokerText(brokerText);
	end
	
	local numSplits = Addon:GetCurrentSplit();
	
	local width, height = ExperiencerFrameBars:GetSize();
	local sectionWidth = width / numSplits;
	
	local stringWidth = self.textFrame.text:GetStringWidth();
	self.textFrame:SetWidth(math.max(sectionWidth, stringWidth + 26));
	self.textFrame:SetClampedToScreen(true);
	
	if(Addon.Hovering and Addon:GetModuleIndexFromMousePosition() == self:GetID()) then
		Addon.ExpandedTextField = self:GetID();
	elseif(Addon.ExpandedTextField == self:GetID()) then
		Addon.ExpandedTextField = nil;
	end
end

function ExperiencerModuleBarsMixin:Refresh(instant)
	self:RefreshText();
	
	self.hasModuleChanged = (self.module ~= self.previousModule);
	self.previousModule = self.module;
	
	local data;
	if(self.module) then
		data = self.module:GetBarData();
	else
		data          = {};
		data.id       = nil;
		data.level    = 0;
		data.min  	  = 0;
		data.max  	  = 1;
		data.current  = 0;
		data.rested   = nil;
		data.visual   = nil;
	end
	
	local valueHasChanged = true;
	
	local isLoss = false;
	local changeCurrent = data.current;
	
	self.hasDataIdChanged = self.previousData and self.previousData.id ~= data.id;
	
	if(self.previousData and not self.hasModuleChanged and not self.hasDataIdChanged) then
		if(data.level == self.previousData.level and data.current < self.previousData.current) then
			isLoss = true;
			changeCurrent = self.previousData.current;
		end
		
		if(data.level < self.previousData.level) then
			isLoss = true;
			changeCurrent = data.max;
		end
		
		if(data.current == self.previousData.current) then
			valueHasChanged = false;
		end
	end
	
	if(instant or isLoss) then
		self:TriggerBufferedUpdate(true);
	else
		self.hasBuffer = true;
		self.bufferTimeout = 0.5;
	end
	
	self.color:SetMinMaxValues(data.min, data.max);
	self.color:SetValue(self.main:GetContinuousAnimatedValue());
	
	self.change:SetMinMaxValues(data.min, data.max);
	if(not isLoss) then
		self.changeTarget = changeCurrent;
		if(not self.change.fadegain_in:IsPlaying()) then
			self.change:SetValue(self.main:GetContinuousAnimatedValue());
		end
	else
		self.changeTarget = self.main:GetContinuousAnimatedValue();
		self.change:SetValue(changeCurrent);
	end
	
	if(instant or self.hasModuleChanged or self.hasDataIdChanged) then
		self.changeTarget = changeCurrent;
		self.change:SetValue(self.changeTarget);
	end
	
	if(data.rested and data.rested > 0) then
		self.rested:Show();
		self.rested:SetMinMaxValues(data.min, data.max);
		self.rested:SetValue(self.main:GetContinuousAnimatedValue() + data.rested);
	else
		self.rested:Hide();
	end
	
	if(data.visual) then
		local primary, secondary;
		if(type(data.visual) == "number") then
			primary = data.visual;
		elseif(type(data.visual) == "table") then
			primary, secondary = unpack(data.visual);
		end
		
		if(primary and primary > 0) then
			self.visualPrimary:Show();
			self.visualPrimary:SetMinMaxValues(data.min, data.max);
			self.visualPrimary:SetValue(self.main:GetContinuousAnimatedValue() + primary);
		else
			self.visualPrimary:Hide();
		end
		
		if(secondary and secondary > 0) then
			self.visualSecondary:Show();
			self.visualSecondary:SetMinMaxValues(data.min, data.max);
			self.visualSecondary:SetValue(self.main:GetContinuousAnimatedValue() + secondary);
		else
			self.visualSecondary:Hide();
		end
	else
		self.visualPrimary:Hide();
		self.visualSecondary:Hide();
	end
	
	if(not instant and valueHasChanged) then
		if(not isLoss) then
			if(not self.change.fadegain_in:IsPlaying()) then
				self.change.fadegain_in:Play();
			end
		else
			self.change.fadeloss:Stop();
			self.change.fadeloss:Play();
		end
	end
end

function Addon:GetHoveredModule()
	local hoveredIndex = Addon:GetModuleIndexFromMousePosition();
	local moduleFrame = Addon:GetModuleFrame(hoveredIndex)
	if(moduleFrame) then
		return moduleFrame.module;
	end
	return nil;
end

function Addon:SendModuleChatMessage()
	local module = Addon:GetHoveredModule();
	if(not module) then return end
	
	local hasMessage, reason = module:HasChatMessage();
	if(not hasMessage) then
		DEFAULT_CHAT_FRAME:AddMessage(("|cfffaad07Experiencer|r %s"):format(reason));
		return;
	end
	
	local msg = module:GetChatMessage();
	
	if(IsControlKeyDown()) then
		ChatFrame_OpenChat(msg);
	else
		DEFAULT_CHAT_FRAME.editBox:SetText(msg)
	end
end

function Addon:ToggleTextVisilibity(visibility, noAnimation)
	if(visibility) then
		self.db.char.TextVisibility = visibility;
	elseif(self.db.char.TextVisibility == TEXT_VISIBILITY_HOVER) then
		self.db.char.TextVisibility = TEXT_VISIBILITY_ALWAYS;
	elseif(self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS) then
		self.db.char.TextVisibility = TEXT_VISIBILITY_HOVER;
	end
	
	if(not noAnimation) then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			if(self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS) then
				moduleFrame.textFrame.fadeout:Stop();
				moduleFrame.textFrame.fadein:Play();
			else
				moduleFrame.textFrame.fadein:Stop();
				moduleFrame.textFrame.fadeout:Play();
			end
		end
	end
end

function Addon:GetNumOfEnabledModules()
	local numTotalEnabled = 0;
	local numActiveEnabled = 0;
	
	for _, module in Addon:IterateModules() do
		if(not module:IsDisabled()) then
			numTotalEnabled = numTotalEnabled + 1;
		end
	end
	for _, moduleId in ipairs(self.db.char.ActiveModules) do
		local module = Addon:GetModule(moduleId, true);
		if(module and not module:IsDisabled()) then
			numActiveEnabled = numActiveEnabled + 1;
		end
	end
	return numTotalEnabled, numActiveEnabled;
end

function Addon:CollapseActiveModules()
	local collapsedList = {};
	for _, moduleId in ipairs(self.db.char.ActiveModules) do
		local module = Addon:GetModule(moduleId, true);
		if(module and not module:IsDisabled()) then
			tinsert(collapsedList, moduleId);
		end
	end
	
	self.db.char.ActiveModules = {};
	if(#collapsedList > 0) then
		for index, moduleId in ipairs(collapsedList) do
			Addon:SetModule(index, moduleId, true);
		end
	else
		local newModule = Addon:FindValidModuleForBar(1);
		Addon:SetModule(index, newModule.id, true);
	end
	
	Addon:UpdateFrames();
	Addon:RefreshBars(true);
end

function Addon:CheckDisabledStatus()
	local numTotalEnabled, numActiveEnabled = Addon:GetNumOfEnabledModules();
	if(numActiveEnabled < self.db.char.NumSplits) then
		if(numTotalEnabled == numActiveEnabled) then
			self.db.char.NumSplits = numActiveEnabled;
			Addon:CollapseActiveModules();
		else
			for index = 1, self.db.char.NumSplits do
				local moduleId = self.db.char.ActiveModules[index];
				local module = Addon:GetModule(moduleId, true);
				if(module and module:IsDisabled()) then
					local newModule = Addon:FindValidModuleForBar(index);
					Addon:SetModule(index, newModule.id, true);
				end
			end
		end
	end
end

function Addon:SetModule(moduleIndex, moduleId, novalidation)
	if(not novalidation) then
		local alreadySet = nil;
		for i=1, 3 do
			if(i ~= moduleIndex and self.db.char.ActiveModules[i] == moduleId) then
				alreadySet = i;
				break;
			end
		end
		
		if(alreadySet) then
			self.db.char.ActiveModules[alreadySet] = self.db.char.ActiveModules[moduleIndex];
			
			local moduleFrame = Addon:GetModuleFrame(alreadySet);
			if(moduleFrame) then
				moduleFrame:SetActiveModule(self.db.char.ActiveModules[alreadySet]);
			end
		end
	end
	
	self.db.char.ActiveModules[moduleIndex] = moduleId;
	
	local moduleFrame = Addon:GetModuleFrame(moduleIndex);
	if(moduleId) then
		moduleFrame:SetActiveModule(moduleId);
	else
		moduleFrame:RemoveActiveModule();
	end
	
	Addon:UpdateFrames();
	Addon:RefreshBars(true);
end

function Addon:IsModuleInUse(moduleId, ignoreIndex)
	for index, activeModuleId in ipairs(self.db.char.ActiveModules) do
		if(index > self.db.char.NumSplits) then break end
		if(activeModuleId == moduleId and ignoreIndex ~= index) then
			return true;
		end
	end
	return false;
end

function Addon:FindValidModuleForBar(index, direction, findNext)
	findNext = findNext or false;
	direction = direction or 1;
	
	local newIndex = 1;
	local moduleFrame = Addon:GetModuleFrame(index);
	if(moduleFrame.module) then
		newIndex = moduleFrame.module.order;
	end
	
	local numModules = #Addon.orderedModules;
	local loops = 0;
	
	local orderedModule = Addon.orderedModules[newIndex];
	if(findNext or orderedModule:IsDisabled() or Addon:IsModuleInUse(orderedModule.id, index)) then
		repeat
			newIndex = newIndex + direction;
			if(newIndex > numModules) then newIndex = 1 end
			if(newIndex < 1) then newIndex = numModules end
			orderedModule = Addon.orderedModules[newIndex];
			
			local isValid = true;
			if(orderedModule:IsDisabled()) then
				isValid = false;
			elseif(Addon:IsModuleInUse(orderedModule.id, index)) then
				isValid = false;
			end
			
			loops = loops + 1;
		until(isValid or loops > numModules);
		
		-- Nothing found, not enough modules
		if(loops > numModules) then
			return nil;
		end
	end
	
	return orderedModule;
end

function Addon:GetAnchors(frame)
	local B, T = "BOTTOM", "TOP";
	local x, y = frame:GetCenter();
	
	if(y < _G.GetScreenHeight() / 2) then
		return B, T, 1;
	else
		return T, B, -1;
	end
end

function Addon:SetSplits(newSplits)
	local oldSplits = self.db.char.NumSplits;
	self.db.char.NumSplits = newSplits;
	
	if(oldSplits < newSplits) then
		for index=2, newSplits do
			local moduleId = self.db.char.ActiveModules[index];
			if(not moduleId) then
				local newModule = Addon:FindValidModuleForBar(index, 1, index);
				moduleId = newModule.id;
			end
			if(moduleId) then
				Addon:SetModule(index, moduleId, true);
			else
				self.db.char.NumSplits = index - 1;
				break;
			end
		end
	end
	
	Addon:UpdateFrames();
	Addon:RefreshText();
end

function Addon:GenerateFontsMenu(fontsMenu, fontsList, startIndex)
	local fontsAdded = 0;
	local numFonts = #fontsList;
	for index = startIndex, numFonts do
		local font = fontsList[index];
		tinsert(fontsMenu, {
			text = fontsList[index],
			func = function()
				self.db.global.FontFace = fontsList[index];
				Addon:UpdateFrames();
				CloseMenus();
			end,
			checked = function() return self.db.global.FontFace == fontsList[index]; end,
		});
		fontsAdded = fontsAdded + 1;
		if(fontsAdded > 30 and index < numFonts) then
			local subMenu = {};
			Addon:GenerateFontsMenu(subMenu, fontsList, index+1);
			tinsert(fontsMenu, {
				text = "|cffffd200More|r",
				hasArrow = true,
				menuList = subMenu,
				notCheckable = true,
			});
			break;
		end
	end
end

function Addon:GetSharedFonts()
	local sharedFonts = LibSharedMedia:List("font");
	local numFonts = #sharedFonts;
	
	local fontsMenu = {};
	Addon:GenerateFontsMenu(fontsMenu, sharedFonts, 1);
	
	return fontsMenu;
end

function Addon:GetFontScaleMenu()
	local windowScales = { 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.3, 1.4, 1.5, };
	local menu = {};
	
	for index, scale in ipairs(windowScales) do
		tinsert(menu, {
			text = string.format("%d%%", scale * 100),
			func = function()
				self.db.global.FontScale = scale;
				Addon:UpdateFrames();
				CloseMenus();
			end,
			checked = function() return self.db.global.FontScale == scale end,
		});
	end
	
	return menu;
end

function Addon:OpenContextMenu(anchorFrame, clickedModuleIndex)
	if(InCombatLockdown()) then return end
	anchorFrame = anchorFrame or ExperiencerFrameBars;
	
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", "ExperiencerContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local usedClassColor;
	
	local swatchFunc = function()
		if(usedClassColor == nil) then
			usedClassColor = self.db.global.Color.UseClassColor;
			self.db.global.Color.UseClassColor = false;
		end
		
		local r, g, b = ColorPickerFrame:GetColorRGB();
		self.db.global.Color.r = r;
		self.db.global.Color.g = g;
		self.db.global.Color.b = b;
		Addon:UpdateFrames();
	end
	
	local cancelFunc = function(values)
		if(usedClassColor == true) then
			self.db.global.Color.UseClassColor = true;
		end
		usedClassColor = nil;
		
		self.db.global.Color.r = values.r;
		self.db.global.Color.g = values.g;
		self.db.global.Color.b = values.b;
		Addon:UpdateFrames();
	end
	
	local numTotalEnabled = Addon:GetNumOfEnabledModules();
	
	local menudata = {
		{
			text = "Experiencer Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = ("%s bar"):format(self.db.char.Visible and "Hide" or "Show"),
			func = function()
				Addon:ToggleVisibility();
			end,
			notCheckable = true,
		},
		{
			text = "Flash when able to level up",
			func = function()
				self.db.char.FlashLevelUp = not self.db.char.FlashLevelUp;
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.FlashLevelUp; end,
			isNotRadio = true,
			tooltipTitle = "Flash when able to level up",
			tooltipText = "Used for Artifact and Honor",
			tooltipOnButton = 1,
		},
		{
			text = "Always show text",
			func = function()
				Addon:ToggleTextVisilibity(TEXT_VISIBILITY_ALWAYS);
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS; end,
		},
		{
			text = "Show text on hover",
			func = function()
				Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HOVER);
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.TextVisibility == TEXT_VISIBILITY_HOVER; end,
		},
		{
			text = "Always hide text",
			func = function()
				Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HIDE);
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.TextVisibility == TEXT_VISIBILITY_HIDE; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Frame Options",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Frame Options", isTitle = true, notCheckable = true,
				},
				{
					text = "Enlarge Experiencer Bar",
					func = function()
						self.db.global.BigBars = not self.db.global.BigBars;
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.BigBars; end,
					isNotRadio = true,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Font", isTitle = true, notCheckable = true,
				},
				{
					text = string.format("Font face |cffcccccc(%s)|r", self.db.global.FontFace),
					hasArrow = true,
					notCheckable = true,
					menuList = Addon:GetSharedFonts(),
				},
				{
					text = string.format("Font scale |cffcccccc(%d%%)|r", self.db.global.FontScale * 100),
					hasArrow = true,
					notCheckable = true,
					menuList = Addon:GetFontScaleMenu(),
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Bar Color", isTitle = true, notCheckable = true,
				},
				{
					text = "Use class color",
					func = function()
						self.db.global.Color.UseClassColor = true;
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.Color.UseClassColor; end,
				},
				{
					text = "Use custom color",
					func = function()
						self.db.global.Color.UseClassColor = false;
						Addon:UpdateFrames();
					end,
					checked = function() return not self.db.global.Color.UseClassColor; end,
				},
				{
					text = "Set custom color",
					func = function()
						local info = {};
						info.swatchFunc = swatchFunc;
						info.cancelFunc = cancelFunc;
						info.r = self.db.global.Color.r;
						info.g = self.db.global.Color.g;
						info.b = self.db.global.Color.b;
						OpenColorPicker(info);
						CloseMenus();
					end,
					notCheckable = true,
					swatchFunc = swatchFunc,
					cancelFunc = cancelFunc,
					hasColorSwatch = true,
					r = self.db.global.Color.r,
					g = self.db.global.Color.g,
					b = self.db.global.Color.b,
				},
				{
					text = " ", isTitle = true, notCheckable = true,
				},
				{
					text = "Frame Anchor", isTitle = true, notCheckable = true,
				},
				{
					text = "Anchor to Bottom",
					func = function()
						self.db.global.AnchorPoint = "BOTTOM";
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.AnchorPoint == "BOTTOM"; end,
				},
				{
					text = "Anchor to Top",
					func = function()
						self.db.global.AnchorPoint = "TOP";
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.AnchorPoint == "TOP"; end,
				},
			},
		},
		{
			text = "", isTitle = true, notCheckable = true,
		},
		{
			text = "Sections", isTitle = true, notCheckable = true,
		},
		{
			text = "Split into one",
			func = function()
				Addon:SetSplits(1);
				local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.NumSplits == 1; end,
		},
		{
			text = "Split into two",
			func = function()
				Addon:SetSplits(2);
				local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.NumSplits == 2; end,
			disabled = numTotalEnabled < 2,
		},
		{
			text = "Split into three",
			func = function()
				Addon:SetSplits(3);
				local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
				Addon:OpenContextMenu(anchorFrame, clickedModuleIndex);
			end,
			checked = function() return self.db.char.NumSplits == 3; end,
			disabled = numTotalEnabled < 3,
			tooltipTitle = "Split into three",
			tooltipText = "When splitting into three the text is shortened and you can hover over the bar to view full text.|n|nYou will see a plus symbol (+) when some information is hidden.",
			tooltipOnButton = 1,
		},
		{
			text = "", isTitle = true, notCheckable = true,
		},
	};
	
	tinsert(menudata, {
		text = "Displayed Bar",
		isTitle = true,
		notCheckable = true,
	});
	
	for index, module in pairs(Addon.orderedModules) do
		local menutext = module.label;
		
		if(module:IsDisabled()) then
			menutext = string.format("%s |cffcccccc(inactive)|r", menutext);
		elseif(self.db.char.ActiveModules[clickedModuleIndex] == module.id) then
			menutext = string.format("%s |cff53c4ff(current)|r", menutext);
		end
		
		tinsert(menudata, {
			text = menutext,
			func = function()
				Addon:SetModule(clickedModuleIndex, module.id);
			end,
			checked = function()
				for i=1, self.db.char.NumSplits do
					if(self.db.char.ActiveModules[i] == module.id) then
						return true;
					end
				end
				return false;
			end,
			hasArrow = true,
			menuList = module:GetOptionsMenu() or {},
			disabled = module:IsDisabled(),
			-- tooltipTitle = module.label,
			-- tooltipText = module.tooltipText,
			-- tooltipOnButton = module.tooltipText and 1,
		});
	end
	
	tinsert(menudata, { text = "", isTitle = true, notCheckable = true, });
	tinsert(menudata, {
		text = "Close",
		func = function() CloseMenus(); end,
		notCheckable = true,
	});
	
	Addon.ContextMenu:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 0);
	EasyMenu(menudata, Addon.ContextMenu, "cursor", 0, 0, "MENU");
	
	local mouseX = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	local point, relativePoint, sign = Addon:GetAnchors(anchorFrame);
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, anchorFrame, relativePoint, mouseX / scale - GetScreenWidth() / 2, 5 * sign);
	DropDownList1:SetClampedToScreen(true);
end

function Addon:GetModuleIndexFromMousePosition()
	local mouseX = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	local width = ExperiencerFrameBars:GetSize() or 0;
	local sectionWidth = width / self.db.char.NumSplits;
	return math.floor((mouseX / scale) / sectionWidth) + 1;
end

function Addon:GetModuleFromModuleIndex(moduleIndex)
	local moduleFrame = Addon:GetModuleFrame(moduleIndex);
	if(moduleFrame and moduleFrame.module) then
		return moduleFrame.module;
	end
end

function Experiencer_OnMouseDown(self, button)
	CloseMenus();
	
	local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
	
	local clickedModule = Addon:GetModuleFromModuleIndex(clickedModuleIndex);
	if(clickedModule and clickedModule.hasCustomMouseCallback and clickedModule.OnMouseDown) then
		local hadAction = clickedModule:OnMouseDown(button);
		if(hadAction) then return end
	end
	
	if(button == "LeftButton") then
		if(IsShiftKeyDown()) then
			Addon:SendModuleChatMessage();
		elseif(IsControlKeyDown()) then
			Addon:ToggleVisibility();
		end
	end
	
	if(button == "MiddleButton" and Addon.db.char.TextVisibility ~= TEXT_VISIBILITY_HIDE) then
		Addon:ToggleTextVisilibity(nil, true);
	end
	
	if(button == "RightButton") then
		Addon:OpenContextMenu(self, clickedModuleIndex);
	end
end

function Experiencer_OnMouseWheel(self, delta)
	local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
	
	local clickedModule = Addon:GetModuleFromModuleIndex(clickedModuleIndex);
	if(clickedModule and clickedModule.hasCustomMouseCallback and clickedModule.OnMouseWheel) then
		local hadAction = clickedModule:OnMouseWheel(delta);
		if(hadAction) then return end
	end
	
	if(IsControlKeyDown()) then
		local hoveredModuleIndex = Addon:GetModuleIndexFromMousePosition();
		
		local newModule = Addon:FindValidModuleForBar(hoveredModuleIndex, -delta, true);
		if(newModule) then
			Addon:SetModule(hoveredModuleIndex, newModule.id);
		else
			print("No available module :OOO");
		end
		
		Addon:RefreshBars(true);
	end
end

function Experiencer_OnEnter(self)
	Addon.Hovering = true;
	Addon:RefreshText();
	if(Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER) then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame.fadeout:Stop();
			moduleFrame.textFrame.fadein:Play();
		end
	end
end

function Experiencer_OnLeave(self)
	Addon.Hovering = false;
	Addon:RefreshText();
	if(Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER) then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame.fadein:Stop();
			moduleFrame.textFrame.fadeout:Play();
		end
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	Addon:CheckDisabledStatus();
	
	for _, module in Addon:IterateModules() do
		module:Update(elapsed);
	end
	
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		if(moduleFrame:IsVisible() and moduleFrame.module) then
			moduleFrame:OnUpdate(elapsed);
		end
	end
	
	if(Addon.Hovering) then
		Addon:RefreshText();
	end
end

function ExperiencerModuleBarsMixin:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	-- if(self.LastExpandedTextField ~= Addon.ExpandedTextField) then
	-- 	if(Addon.ExpandedTextField and Addon.ExpandedTextField ~= self:GetID()) then
	-- 		local diff = math.abs(self:GetID() - Addon.ExpandedTextField);
	-- 		if(diff == 1) then
	-- 			self.textFrame.fadeoutHalf:Play();
	-- 		else
	-- 			self.textFrame.fadeinHalf:Play();
	-- 		end
	-- 	elseif(Addon.ExpandedTextField ~= self:GetID()) then
	-- 		self.textFrame.fadeinHalf:Play();
	-- 	end
	-- end
	-- self.LastExpandedTextField = Addon.ExpandedTextField;
	
	if(self.hasBuffer) then
		self.bufferTimeout = self.bufferTimeout - elapsed;
		if(self.bufferTimeout <= 0.0) then
			self:TriggerBufferedUpdate();
			self.hasBuffer = false;
		end
	end
	
	local value = (self.changeTarget - self.change:GetValue()) * elapsed;
	if(value >= 0) then
		value = value / 0.175;
	else
		value = value / 0.325;
	end
	self.change:SetValue(self.change:GetValue() + value);
	
	if(self.previousData) then
		if(self.rested:IsVisible() and self.previousData.rested) then
			self.rested:SetValue(self.main:GetContinuousAnimatedValue() + self.previousData.rested);
		end
		
		if(self.previousData.visual) then
			local primary, secondary;
			if(type(self.previousData.visual) == "number") then
				primary = self.previousData.visual;
			elseif(type(self.previousData.visual) == "table") then
				primary, secondary = unpack(self.previousData.visual);
			end
			
			if(self.visualPrimary:IsVisible() and primary) then
				self.visualPrimary:SetValue(self.main:GetContinuousAnimatedValue() + primary);
			end
			
			if(self.visualSecondary:IsVisible() and secondary) then
				self.visualSecondary:SetValue(self.main:GetContinuousAnimatedValue() + secondary);
			end
		end
	end
	
	local current = self.main:GetContinuousAnimatedValue();
	local minvalue, maxvalue = self.main:GetMinMaxValues();
	self.color:SetValue(current);
	
	local progress = (current - minvalue) / (maxvalue - minvalue);
	
	if(progress > 0) then
		self.main.spark:Show();
		self.main.spark:ClearAllPoints();
		self.main.spark:SetPoint("CENTER", self.main, "LEFT", progress * self.main:GetWidth(), 0);
	else
		self.main.spark:Hide();
	end
	
	if(Addon.db.global.FlashLevelUp) then
		if(self.module.levelUpRequiresAction) then
			local canLevelUp = self.module:CanLevelUp();
			self.highlight:SetMinMaxValues(minvalue, maxvalue);
			self.highlight:SetValue(current);
			
			if(canLevelUp and not self.highlight:IsVisible()) then
				self.highlight.fadein:Play();
			elseif(not canLevelUp and self.highlight:IsVisible()) then
				self.highlight.flash:Stop();
				self.highlight.fadeout:Play();
			end
		else
			self.highlight:Hide();
		end
	end
end

local DAY_ABBR, HOUR_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local DHMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local  HMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local   MS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
local    S = format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

function Addon:FormatTime(t)
	if not t then return end

	local d, h, m, s = floor(t / 86400), floor((t % 86400) / 3600), floor((t % 3600) / 60), floor(t % 60)
	
	if d > 0 then
		return format(DHMS, d, h, m, s)
	elseif h > 0 then
		return format(HMS, h, m ,s)
	elseif m > 0 then
		return format(MS, m, s)
	else
		return format(S, s)
	end
end

if(not LibSharedMedia) then
	error("LibSharedMedia not loaded. You should restart the game.");
end
