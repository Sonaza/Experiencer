------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

local AceDB = LibStub("AceDB-3.0");

local TEXT_VISIBILITY_HIDE      = 1;
local TEXT_VISIBILITY_HOVER     = 2;
local TEXT_VISIBILITY_ALWAYS    = 3;

function Addon:OnInitialize()
	local defaults = {
		char = {
			Visible 	    = true,
			TextVisibility  = TEXT_VISIBILITY_ALWAYS,
			ActiveModule    = "experience",
		},
		
		global = {
			AnchorPoint	    = "BOTTOM",
			BigBars         = false,
			FlashLevelUp    = true,
			
			Color = {
				UseClassColor = true,
				r = 1,
				g = 1,
				b = 1,
			}
		}
	};
	
	self.db = AceDB:New("ExperiencerDB", defaults);
end

function Addon:OnEnable()
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	Addon:RegisterEvent("PET_BATTLE_OPENING_START");
	Addon:RegisterEvent("PET_BATTLE_CLOSE");
	
	Addon:UpdateFrames();
	
	Addon:InitializeModules();
	
	-- Just cycle through modules and set current active that is not disabled
	local currentIndex = Addon.modules[Addon.db.char.ActiveModule].order;
	local newModule = Addon:FindActiveModule(currentIndex, 1);
	Addon.db.char.ActiveModule = newModule.id;
	
	Addon:InitializeDataBroker();
	
	Addon:UpdateBars();
	Addon:UpdateText();
	
	Addon:UpdateVisiblity();
end

function Addon:IsBarVisible()
	return self.db.char.Visible;
end

Addon.modules           = {};
Addon.orderedModules    = {};
Addon.eventframes       = {};

setmetatable(Addon.modules, {
	__newindex = function(self, moduleID, module)
		if(type(module) ~= "table") then
			error("Unable to create new index: type is not a table", 2);
		end
		
		Addon.eventframes[moduleID] = CreateFrame("Frame");
		Addon.eventframes[moduleID]:SetScript("OnEvent", function(self, event, ...)
			if(module[event]) then
				module[event](module, event, ...);
			end
		end);
		
		rawset(self, moduleID, module);
	end
});

function Addon:NewModule(moduleID, module)
	if(Addon.modules[moduleID]) then
		error(("Addon:RegisterModule(moduleID[, module]): Module '%s' is already registered."):format(tostring(moduleID)), 2);
		return;
	end
	
	local module = module or {};
	module.id = moduleID;
	
	Addon.modules[moduleID] = module;
	
	module.RegisterEvent = function(self, eventName)
		if(not self[eventName]) then
			error(("module:RegisterEvent(eventName): Event '%s' is not found on body."):format(tostring(eventName)), 2);
		else
			Addon.eventframes[self.id]:RegisterEvent(eventName);
		end
	end

	module.UnregisterEvent = function(self, eventName)
		if(not self[eventName]) then
			error(("module:UnregisterEvent(eventName): Event '%s' is not found on body."):format(tostring(eventName)), 2);
		else
			Addon.eventframes[self.id]:UnregisterEvent(eventName);
		end
	end

	module.Refresh = function(self, instant)
		Addon:RefreshModule(self, instant);
	end

	module.RefreshText = function(self)
		Addon:UpdateText();
	end
	
	return module;
end

function Addon:InitializeModules()
	for moduleID, module in pairs(Addon.modules) do
		Addon.orderedModules[module.order] = module;
		
		if(module.savedvars) then
			module.db = AceDB:New("ExperiencerDB_module_" .. moduleID, module.savedvars);
		end
		
		module:Initialize();
	end
end

function Addon:RefreshModule(module, instant)
	Addon:UpdateBars(instant);
	Addon:UpdateText();
end

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

local FrameLevels = {
	"ExperiencerFrameBarsRested",
	"ExperiencerFrameBarsVisual",
	"ExperiencerFrameBarsChange",
	"ExperiencerFrameBarsMain",
	"ExperiencerFrameBarsColor",
	"ExperiencerFrameBarsHighlight",
	"ExperiencerBarTextFrame",
};

function Addon:UpdateFrames()
	if(not Addon.db.global.BigBars) then
		ExperiencerFrame:SetHeight(10);
		ExperiencerBarTextFrame:SetHeight(20);
		ExperiencerBarText:SetFontObject("ExperiencerFont");
	else
		ExperiencerFrame:SetHeight(18);
		ExperiencerBarTextFrame:SetHeight(28);
		ExperiencerBarText:SetFontObject("ExperiencerBigFont");
	end
	
	local anchor = Addon.db.global.AnchorPoint or "BOTTOM";
	local offset = 0;
	if(anchor == "TOP") then offset = 1 end
	if(anchor == "BOTTOM") then offset = -1 end
	
	ExperiencerFrame:ClearAllPoints();
	ExperiencerFrame:SetPoint(anchor .. "LEFT", UIParent, anchor .. "LEFT", 0, offset);
	ExperiencerFrame:SetPoint(anchor .. "RIGHT", UIParent, anchor .. "RIGHT", 0, offset);
	ExperiencerBarTextFrame:ClearAllPoints();
	ExperiencerBarTextFrame:SetPoint(anchor, ExperiencerFrameBars, anchor);
	
	local c = Addon:GetBarColor();
	local ib = 1 - (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b); -- calculate inverse brightness
	
	ExperiencerFrameBars.main:SetStatusBarColor(c.r, c.g, c.b);
	ExperiencerFrameBars.main:SetAnimatedTextureColors(c.r, c.g, c.b);
	
	ExperiencerFrameBars.color:SetStatusBarColor(c.r, c.g, c.b, 0.23 + ib * 0.26); -- adjust color strength by brightness
	ExperiencerFrameBars.rested:SetStatusBarColor(c.r, c.g, c.b, 0.3);
	
	ExperiencerFrameBars.visual:SetStatusBarColor(c.r, c.g, c.b, 0.375);
	
	-----------------------------
	
	for index, frameName in ipairs(FrameLevels) do
		local frame = _G[frameName];
		if(index == 1) then
			baseFrameLevel = frame:GetFrameLevel();
		else
			frame:SetFrameLevel(baseFrameLevel+index-1);
		end
	end
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
		ExperiencerBarTextFrame:Show();
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

function Addon:SetActiveModule(moduleID)
	self.db.char.ActiveModule = moduleID;
	Addon:UpdateFrames();
end

function Addon:GetActiveModule()
	if(not Addon.modules[self.db.char.ActiveModule]) then
		error(("Addon:GetActiveModule(): Module '%s' is not registered."):format(tostring(self.db.char.ActiveModule)), 2);
	end
	return Addon.modules[self.db.char.ActiveModule];
end

function Addon:SetAnimationSpeed(speed)
	assert(speed and speed > 0);
	
	speed = (1 / speed) * 0.5;
	ExperiencerFrameBars.main.tileTemplateDelay = 0.3 * speed;
	
	local durationPerDistance = 0.008 * speed;
	
	for index, anim in ipairs({ ExperiencerFrameBars.main.Anim:GetAnimations() }) do
		if(anim.durationPerDistance) then
			anim.durationPerDistance = durationPerDistance;
		end
		if(anim.delayPerDistance) then
			anim.delayPerDistance = durationPerDistance;
		end
		
		local animtype = anim:GetObjectType();
	end
end

function Addon:UpdateBars(instant)
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local moduleChanged = (module ~= Addon.PreviousModule);
	Addon.PreviousModule = module;
	
	local data = module:GetBarData();
	
	local hasChanged = true;
	
	local isLoss = false;
	local changeCurrent = data.current;
	
	if(Addon.PreviousData and not moduleChanged) then
		if(data.level == Addon.PreviousData.level and data.current < Addon.PreviousData.current) then
			isLoss = true;
			changeCurrent = Addon.PreviousData.current;
		end
		
		if(data.level < Addon.PreviousData.level) then
			isLoss = true;
			changeCurrent = data.max;
		end
		
		if(data.current == Addon.PreviousData.current) then
			hasChanged = false;
		end
	end
	
	if(not isLoss) then
		ExperiencerFrameBars.main.accumulationTimeoutInterval = 0.6;
	else
		ExperiencerFrameBars.main.accumulationTimeoutInterval = 0.35;
	end
	
	Addon:SetAnimationSpeed(1.0);
	
	if(hasChanged) then
		if(Addon.PreviousData and not isLoss) then
			local current = data.current;
			local previous = Addon.PreviousData.current;
			
			if(not moduleChanged and Addon.PreviousData.level < data.level) then
				current = current + Addon.PreviousData.max;
			end
			
			local diff = (current - previous) / data.max;
			local speed = math.max(1, math.min(10, diff * 1.2 + 1.0));
			speed = speed * speed;
			Addon:SetAnimationSpeed(speed);
		end
		
		ExperiencerFrameBars.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
	else
		ExperiencerFrameBars.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
		ExperiencerFrameBars.main:ProcessChangesInstantly();
	end
	
	if(instant or isLoss) then
		ExperiencerFrameBars.main:ProcessChangesInstantly();
	end
	
	ExperiencerFrameBars.color:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.color:SetValue(ExperiencerFrameBars.main:GetContinuousAnimatedValue());
	
	ExperiencerFrameBars.change:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.change:SetValue(changeCurrent);
	
	if(not instant and hasChanged) then
		if(not isLoss) then
			ExperiencerFrameBars.change.fadegain:Stop();
			ExperiencerFrameBars.change.fadegain:Play();
		else
			ExperiencerFrameBars.change.fadeloss:Stop();
			ExperiencerFrameBars.change.fadeloss:Play();
		end
		ExperiencerFrameBars.main.spark.fade:Stop();
		ExperiencerFrameBars.main.spark.fade:Play();
	end
	
	if(data.rested) then
		ExperiencerFrameBars.rested:Show();
		ExperiencerFrameBars.rested:SetMinMaxValues(data.min, data.max);
		ExperiencerFrameBars.rested:SetValue(data.rested);
	else
		ExperiencerFrameBars.rested:Hide();
	end
	
	if(data.visual) then
		ExperiencerFrameBars.visual:Show();
		ExperiencerFrameBars.visual:SetMinMaxValues(data.min, data.max);
		ExperiencerFrameBars.visual:SetValue(data.visual);
	else
		ExperiencerFrameBars.visual:Hide();
	end
	
	Addon.PreviousData = data;
end

function Addon:UpdateText()
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local text = module:GetText() or "<Error: no module text>";
	ExperiencerBarText:SetText(text);
	
	Addon:UpdateDataBrokerText(text);
end

local function roundnum(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

function Addon:FormatNumber(num)
	num = tonumber(num);
	
	if(num > 1000000) then
		num = roundnum((num / 1000000), 2) .. "m";
	elseif(num > 1000) then
		num = roundnum((num / 1000), 2) .. "k";
	end
	
	return num;
end

function Addon:SendModuleChatMessage()
	local module = Addon:GetActiveModule();
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
		if(self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS) then
			ExperiencerBarTextFrame.fadeout:Stop();
			ExperiencerBarTextFrame.fadein:Play();
		else
			ExperiencerBarTextFrame.fadein:Stop();
			ExperiencerBarTextFrame.fadeout:Play();
		end
	end
end

function Experiencer_OnMouseDown(self, button)
	CloseMenus();
	
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
		Addon:OpenContextMenu(self);
	end
end

function Addon:CheckDisabledStatus()
	if(Addon:GetActiveModule():IsDisabled()) then
		local currentIndex = Addon.modules[Addon.db.char.ActiveModule].order;
		Addon.db.char.ActiveModule = Addon:FindActiveModule(currentIndex, 1).id;
	end
end

function Addon:FindActiveModule(currentIndex, direction, findNext)
	findNext = findNext or false;
	direction = direction or 1;
	local newIndex = currentIndex;
	
	if(Addon.orderedModules[newIndex]:IsDisabled() or findNext) then
		repeat
			newIndex = newIndex + direction;
			if(newIndex > #Addon.orderedModules) then newIndex = 1 end
			if(newIndex < 1) then newIndex = #Addon.orderedModules end
		until(not Addon.orderedModules[newIndex]:IsDisabled());
	end
	
	return Addon.orderedModules[newIndex];
end

function Experiencer_OnMouseWheel(self, delta)
	if(IsControlKeyDown()) then
		local currentIndex = Addon.modules[Addon.db.char.ActiveModule].order;
		
		local newModule = Addon:FindActiveModule(currentIndex, -delta, true);
		Addon.db.char.ActiveModule = newModule.id;
		
		Addon:UpdateBars(true);
		Addon:UpdateText();
	end
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

function Addon:OpenContextMenu(anchorFrame)
	if(InCombatLockdown()) then return end
	anchorFrame = anchorFrame or ExperiencerFrameBars.main;
	
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
				Addon:OpenContextMenu();
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
				Addon:OpenContextMenu();
			end,
			checked = function() return self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS; end,
		},
		{
			text = "Show text on hover",
			func = function()
				Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HOVER);
				Addon:OpenContextMenu();
			end,
			checked = function() return self.db.char.TextVisibility == TEXT_VISIBILITY_HOVER; end,
		},
		{
			text = "Always hide text",
			func = function()
				Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HIDE);
				Addon:OpenContextMenu();
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
	};
	
	tinsert(menudata, {
		text = "Displayed Bar",
		isTitle = true,
		notCheckable = true,
	});
	
	for index, module in pairs(Addon.orderedModules) do
		local menutext = module.name;
		
		if(module:IsDisabled()) then
			menutext = string.format("%s |cffcccccc(inactive)|r", menutext);
		end
		
		tinsert(menudata, {
			text = menutext,
			func = function()
				self.db.char.ActiveModule = module.id;
				Addon:UpdateBars(true);
				Addon:UpdateText();
			end,
			checked = function()
				return self.db.char.ActiveModule == module.id;
			end,
			hasArrow = true,
			menuList = module:GetOptionsMenu() or {},
			disabled = module:IsDisabled(),
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
	
	local mouseX, mouseY = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	
	local point, relativePoint, sign = Addon:GetAnchors(anchorFrame);
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, anchorFrame, relativePoint, mouseX / scale - GetScreenWidth() / 2, 5 * sign);
	DropDownList1:SetClampedToScreen(true);
end

function Experiencer_OnEnter(self)
	if(Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER) then
		ExperiencerBarTextFrame.fadeout:Stop();
		ExperiencerBarTextFrame.fadein:Play();
	end
end

function Experiencer_OnLeave(self)
	if(Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER) then
		ExperiencerBarTextFrame.fadein:Stop();
		ExperiencerBarTextFrame.fadeout:Play();
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	for _, module in pairs(Addon.modules) do
		module:Update(elapsed);
	end
	
	local current = ExperiencerFrameBars.main:GetContinuousAnimatedValue();
	local minvalue, maxvalue = ExperiencerFrameBars.main:GetMinMaxValues();
	ExperiencerFrameBars.color:SetValue(current);
	
	local progress = (current - minvalue) / (maxvalue - minvalue);
	
	if(progress > 0) then
		ExperiencerFrameBars.main.spark:Show();
		ExperiencerFrameBars.main.spark:ClearAllPoints();
		ExperiencerFrameBars.main.spark:SetPoint("CENTER", ExperiencerFrameBars.main, "LEFT", progress * ExperiencerFrameBars.main:GetWidth(), 0);
	else
		ExperiencerFrameBars.main.spark:Hide();
	end
	
	if(Addon.db.global.FlashLevelUp) then
		local module = Addon:GetActiveModule();
		if(module.levelUpRequiresAction) then
			if(progress >= 1 and not ExperiencerFrameBars.highlight:IsVisible()) then
				ExperiencerFrameBars.highlight.fadein:Play();
			elseif(progress < 1 and ExperiencerFrameBars.highlight:IsVisible()) then
				ExperiencerFrameBars.highlight.flash:Stop();
				ExperiencerFrameBars.highlight.fadeout:Play();
			end
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
