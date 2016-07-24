------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
Addon.callbacks = Addon.callbacks or LibStub("CallbackHandler-1.0"):New(Addon);
_G[ADDON_NAME] = Addon;

local AceDB = LibStub("AceDB-3.0");

function Addon:OnInitialize()
	local defaults = {
		char = {
			Visible 	    = true,
			StickyText      = false,
			ActiveModule    = "experience",
		},
		
		global = {
			AnchorPoint	= "BOTTOM",
			BigBars = false,
			
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
	
	Addon:UpdateBars();
	Addon:UpdateText();
	
	Addon:UpdateVisiblity();
	
end

Addon.modules           = {};
Addon.orderedModules    = {};
Addon.eventframes = {};

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

local mt = {
	
};

function Addon:NewModule(moduleID, module)
	if(Addon.modules[moduleID]) then
		error(("Addon:RegisterModule(moduleID[, module]): Module '%s' is already registered."):format(tostring(moduleID)), 2);
		return;
	end
	
	local module = module or {};
	setmetatable(module, mt);
	
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

function Addon:IsBarEnabled()
	return self.db.char.Enabled;
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
	ExperiencerFrame:ClearAllPoints();
	ExperiencerFrame:SetPoint(anchor .. "LEFT", UIParent, anchor .. "LEFT", 0, -1);
	ExperiencerFrame:SetPoint(anchor .. "RIGHT", UIParent, anchor .. "RIGHT", 0, -1);
	ExperiencerBarTextFrame:ClearAllPoints();
	ExperiencerBarTextFrame:SetPoint(anchor, ExperiencerFrameBars, anchor);
	
	local c = Addon:GetBarColor();
	local ib = 1 - (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b); -- calculate inverse brightness
	
	ExperiencerFrameBars.main:SetStatusBarColor(c.r, c.g, c.b);
	ExperiencerFrameBars.main:SetAnimatedTextureColors(c.r, c.g, c.b);
	ExperiencerFrameBars.main.accumulationTimeoutInterval = 1.0;
	
	ExperiencerFrameBars.color:SetStatusBarColor(c.r, c.g, c.b, 0.23 + ib * 0.26); -- adjust color strength by brightness
	ExperiencerFrameBars.rested:SetStatusBarColor(c.r, c.g, c.b, 0.3);
	
	ExperiencerFrameBars.visual:SetStatusBarColor(c.r, c.g, c.b, 0.375);
	
	ExperiencerFrameBars.visual:SetFrameLevel(ExperiencerFrameBars.rested:GetFrameLevel()+1);
	ExperiencerFrameBars.gain:SetFrameLevel(ExperiencerFrameBars.visual:GetFrameLevel());
	ExperiencerFrameBars.main:SetFrameLevel(ExperiencerFrameBars.gain:GetFrameLevel()+1);
	ExperiencerFrameBars.color:SetFrameLevel(ExperiencerFrameBars.main:GetFrameLevel()+1);
	ExperiencerBarTextFrame:SetFrameLevel(ExperiencerFrameBars.main:GetFrameLevel()+2);
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
	
	if(Addon.db.char.StickyText) then
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

function Addon:UpdateBars(instant)
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local data = module:GetBarData();
	
	if(not ExperiencerFrameBars.main:IsAnimating() or instant) then
		ExperiencerFrameBars.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
	end
	
	if(instant) then
		ExperiencerFrameBars.main:ProcessChangesInstantly();
	end
	
	ExperiencerFrameBars.color:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.color:SetValue(ExperiencerFrameBars.main:GetAnimatedValue());
	
	ExperiencerFrameBars.gain:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.gain:SetValue(data.current);
	
	if(not instant) then
		ExperiencerFrameBars.gain.fade:Play();
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
end

function Addon:UpdateText()
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local text = module:GetText() or "<Error: no module text>";
	ExperiencerBarText:SetText(text);
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

function Experiencer_OnMouseDown(self, button)
	CloseMenus();
	
	if(button == "LeftButton") then
		if(IsShiftKeyDown()) then
			Addon:SendModuleChatMessage();
		elseif(IsControlKeyDown()) then
			Addon:ToggleVisibility();
		end
	end
	
	if(button == "MiddleButton") then
		Addon.db.char.StickyText = not Addon.db.char.StickyText;
	end
	
	if(button == "RightButton") then
		Addon:OpenContextMenu();
	end
end

function Addon:FindActiveModule(currentIndex, direction)
	direction = direction or 1;
	local newIndex = currentIndex;
	
	if(Addon.orderedModules[newIndex]:IsDisabled()) then
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
		
		local newModule = Addon:FindActiveModule(currentIndex, -delta);
		Addon.db.char.ActiveModule = newModule.id;
		
		Addon:UpdateBars(true);
		Addon:UpdateText();
	end
end

function Addon:OpenContextMenu()
	if(InCombatLockdown()) then return end
	
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
			text = "Keep text visible",
			func = function()
				self.db.char.StickyText = not self.db.char.StickyText;
				if(self.db.char.StickyText) then
					ExperiencerBarTextFrame.fadeout:Stop();
					ExperiencerBarTextFrame.fadein:Play();
				else
					ExperiencerBarTextFrame.fadein:Stop();
					ExperiencerBarTextFrame.fadeout:Play();
				end
				Addon:OpenContextMenu();
			end,
			checked = function() return self.db.char.StickyText; end,
			isNotRadio = true,
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
	
	Addon.ContextMenu:SetPoint("BOTTOM", ExperiencerFrameBars.main, "TOP", 0, 0);
	EasyMenu(menudata, Addon.ContextMenu, "cursor", 0, 0, "MENU");
	
	local mouseX, mouseY = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	
	local point, yoffset = "BOTTOM", 14;
	if(Addon.db.global.AnchorPoint == "TOP") then
		point = "TOP";
		yoffset = -14;
	end
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, ExperiencerFrameBars.main, "CENTER", mouseX / scale - GetScreenWidth() / 2, yoffset);
end

function Experiencer_OnEnter(self)
	if(not Addon.db.char.StickyText) then
		ExperiencerBarTextFrame.fadeout:Stop();
		ExperiencerBarTextFrame.fadein:Play();
	end
end

function Experiencer_OnLeave(self)
	if(not Addon.db.char.StickyText) then
		ExperiencerBarTextFrame.fadein:Stop();
		ExperiencerBarTextFrame.fadeout:Play();
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	for _, module in pairs(Addon.modules) do
		module:Update(elapsed);
	end
	
	local current = ExperiencerFrameBars.main:GetAnimatedValue();
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
