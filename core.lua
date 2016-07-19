------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

Addon.modules           = {};
Addon.orderedModules    = {};

local AceDB = LibStub("AceDB-3.0");

EXPERIENCER_MODE_XP = 0;
EXPERIENCER_MODE_REP = 1;

local ANCHOR_TOP = 1;
local ANCHOR_BOTTOM = 2;

function Addon:OnInitialize()
	local defaults = {
		char = {
			Visible 	    = true,
			StickyText      = false,
			
			ActiveModule    = "experience",
		},
		
		global = {
			AnchorPoint	= ANCHOR_BOTTOM,
			BigBars = false,
		}
	};
	
	self.db = AceDB:New("ExperiencerDB", defaults);
end

function Addon:OnEnable()
	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	
	Addon:RegisterEvent("PET_BATTLE_OPENING_START");
	Addon:RegisterEvent("PET_BATTLE_CLOSE");
	
	Addon:InitializeModules();
	Addon:RefreshBar(true);
	
	Addon.IsVisible = true;
	
	Addon:UpdateFrames();
end

function Addon:RegisterModule(name, module)
	if(Addon.modules[name]) then
		error(("Addon:RegisterModule(name, module): Module '%s' is already registered."):format(tostring(name)), 2);
		return;
	end
	
	Addon.modules[name]                = module;
	Addon.orderedModules[module.order] = module;
end

function Addon:GetModuleSavedVariableDefaults()
	local defaults = {
		char = {},
		global = {},
	};
	
	for moduleID, module in pairs(Addon.modules) do
		if(module.savedvars) then
			defaults.char[moduleID]   = module.savedvars.char;
			defaults.global[moduleID] = module.savedvars.global;
		end
	end
	
	return defaults;
end

function Addon:InitializeModules()
	for moduleID, module in pairs(Addon.modules) do
		module._eventFrame = CreateFrame("Frame");
		module._eventFrame:SetScript("OnEvent", function(self, event, ...)
			if(module[event]) then
				module[event](self, event, ...);
			end
		end);
		
		module.RegisterEvent = function(self, eventName)
			if(not self[eventName]) then
				error(("module:RegisterEvent(eventName): Event '%s' is not found on body."):format(tostring(eventName)), 2);
			else
				self._eventFrame:RegisterEvent(eventName);
			end
		end
		
		module.UnregisterEvent = function(self, eventName)
			if(not self[eventName]) then
				error(("module:UnregisterEvent(eventName): Event '%s' is not found on body."):format(tostring(eventName)), 2);
			else
				self._eventFrame:UnregisterEvent(eventName);
			end
		end
		
		module._dirty = false;
		module.MakeDirty = function(self, instant)
			module._dirty = true;
			Addon:RefreshModule(self);
		end
		
		if(module.savedvars) then
			module.db = AceDB:New("ExperiencerDB_module_" .. moduleID, module.savedvars);
		end
		
		module:Initialize();
	end
end

function Addon:RefreshModule(module)
	Addon:RefreshBar();
end

function Addon:IsBarEnabled()
	return self.db.char.Enabled;
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

function Addon:UpdateFrames()
	ExperiencerFrame:ClearAllPoints();
	ExperiencerBarText:ClearAllPoints();
	
	local yo1, yo2, yo3, visualizerPad = -1, 9, 3, 0;
	
	if(Addon.db.global.BigBars) then
		yo1, yo2, yo3, visualizerPad = -1, 16, 7, 3;
		ExperiencerBarText:SetFontObject("ExperiencerBigFont");
	else
		ExperiencerBarText:SetFontObject("ExperiencerFont");
	end
	
	-- if(Addon.db.global.AnchorPoint == ANCHOR_TOP) then
	-- 	ExperiencerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -yo1);
	-- 	ExperiencerFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPRIGHT", 0, -yo2);
		-- ExperiencerBarText:SetPoint("TOP", ExperiencerFrameBars, "TOP", 0, -yo3);
		
	-- 	ExperiencerFrameBars.visual:SetPoint("BOTTOMLEFT", ExperiencerFrameBars, "BOTTOMLEFT", 4, 6 + visualizerPad);
	-- 	ExperiencerFrameBars.visual:SetPoint("TOPRIGHT", ExperiencerFrameBars, "TOPRIGHT", -4, -2);
		
	-- elseif(Addon.db.global.AnchorPoint == ANCHOR_BOTTOM) then
	-- 	ExperiencerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, yo1);
	-- 	ExperiencerFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, yo2);
		ExperiencerBarText:SetPoint("BOTTOM", ExperiencerFrameBars, "BOTTOM", 0, yo3);
		
	-- 	ExperiencerFrameBars.visual:SetPoint("BOTTOMLEFT", ExperiencerFrameBars, "BOTTOMLEFT", 4, 2);
	-- 	ExperiencerFrameBars.visual:SetPoint("TOPRIGHT", ExperiencerFrameBars, "TOPRIGHT", -4, -6 - visualizerPad);
	-- end
	
	local _, class = UnitClass("player");
	local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class];
	
	ExperiencerFrameBars.main:SetStatusBarColor(c.r, c.g, c.b);
	ExperiencerFrameBars.main:SetAnimatedTextureColors(c.r, c.g, c.b);
	ExperiencerFrameBars.main.accumulationTimeoutInterval = 1.0;
	
	ExperiencerFrameBars.color:SetStatusBarColor(c.r, c.g, c.b, 0.3);
	ExperiencerFrameBars.rested:SetStatusBarColor(c.r, c.g, c.b, 0.4);
	ExperiencerFrameBars.visual:SetStatusBarColor(1, 1, 0, 0.7);
	
	ExperiencerFrameBars.visual:SetFrameLevel(ExperiencerFrameBars.rested:GetFrameLevel()+1);
	ExperiencerFrameBars.gain:SetFrameLevel(ExperiencerFrameBars.visual:GetFrameLevel());
	ExperiencerFrameBars.main:SetFrameLevel(ExperiencerFrameBars.gain:GetFrameLevel()+1);
	ExperiencerFrameBars.color:SetFrameLevel(ExperiencerFrameBars.main:GetFrameLevel()+1);
	
	ExperiencerFrameBarsLabel:SetFrameLevel(ExperiencerFrameBars.main:GetFrameLevel()+2);
	
	Addon:RefreshBar(true);
end

function Addon:ShowBar()
	Addon.IsVisible = true;
	ExperiencerFrameBars:Show();
	
	ExperiencerBarText:Show();
	
	Addon:RefreshBar(true);
end

function Addon:HideBar()
	Addon.IsVisible = false;
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

function Addon:RefreshBar()
	Addon:UpdateActiveBar();
end

function Addon:UpdateActiveBar()
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local data = module:GetBarData();
	
	ExperiencerFrameBars.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
	
	ExperiencerFrameBars.color:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.color:SetValue(ExperiencerFrameBars.main:GetAnimatedValue());
	
	ExperiencerFrameBars.gain:SetMinMaxValues(data.min, data.max);
	ExperiencerFrameBars.gain:SetValue(data.current);
	
	if(module._dirty) then
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
	
	if(false and data.visual) then
		ExperiencerFrameBars.visual:Show();
		ExperiencerFrameBars.visual:SetMinMaxValues(data.min, data.max);
		ExperiencerFrameBars.visual:SetValue(data.visual);
	else
		ExperiencerFrameBars.visual:Hide();
	end
	
	local text = module:GetText() or "<Error: no module text>";
	ExperiencerBarText:SetText(text);
	
	module._dirty = false;
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
	
	if(IsShiftKeyDown()) then
		ChatFrame_OpenChat(msg);
	else
		DEFAULT_CHAT_FRAME.editBox:SetText(msg)
	end
end

function Experiencer_OnMouseDown(self, button)
	print("Experiencer_OnMouseDown", button);
	
	-- if(button == "LeftButton") then
	-- 	if(Addon.db.char.Visible) then
	-- 		if(Addon.db.char.Mode == EXPERIENCER_MODE_XP) then
	-- 			Addon:OutputExperience();
	-- 		else
	-- 			Addon:OutputReputation();
	-- 		end
	-- 	end
		
	if(button == "MiddleButton") then
		Addon.db.char.StickyText = true;
		-- not Addon.db.char.StickyText;
		-- if(Addon.db.char.StickyText) then
			ExperiencerBarText:Show();
		-- end
		
		-- Addon.db.char.Visible = not Addon.db.char.Visible;
	end
	
	if(button == "RightButton") then
		Addon:OpenContextMenu();
	end
end

function Addon:OpenContextMenu()
	if(InCombatLockdown()) then return end
	
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", "ExperiencerContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local menudata = {
		{
			text = "Experiencer",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Keep Text Visible",
			func = function()
				self.db.char.StickyText = not self.db.char.StickyText;
				if(self.db.char.StickyText) then
					UIFrameFadeOut(ExperiencerBarText, 0.1, 0, 1);
				else
					UIFrameFadeOut(ExperiencerBarText, 0.1, 1, 0);
				end
				Addon:OpenContextMenu();
			end,
			checked = function() return self.db.char.StickyText; end,
			isNotRadio = true,
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
					func = function() self.db.global.BigBars = not self.db.global.BigBars; Addon:UpdateFrames(); end,
					checked = function() return self.db.global.BigBars; end,
					isNotRadio = true,
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
						self.db.global.AnchorPoint = ANCHOR_BOTTOM;
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.AnchorPoint == ANCHOR_BOTTOM; end,
				},
				{
					text = "Anchor to Top",
					func = function()
						self.db.global.AnchorPoint = ANCHOR_TOP;
						Addon:UpdateFrames();
					end,
					checked = function() return self.db.global.AnchorPoint == ANCHOR_TOP; end,
				},
			},
		},
		{
			text = "",
			isTitle = true,
			notCheckable = true,
			disabled = true,
		},
	};
	
	if(self.db.char.Visible) then
		tinsert(menudata, 2, {
			text = "Hide Experiencer Bar",
			func = function() self.db.char.Visible = false; Addon:ToggleVisibility(false); end,
			notCheckable = true,
		});
	else
		tinsert(menudata, 2, {
			text = "Show Experiencer Bar",
			func = function() self.db.char.Visible = true; Addon:ToggleVisibility(true); end,
			notCheckable = true,
		});
	end
	
	for index, module in pairs(Addon.orderedModules) do
		tinsert(menudata, {
			text = string.format("|cffffd200%s Options|r", module.name),
			notCheckable = true,
			hasArrow = true,
			menuList = module:GetOptionsMenu() or {},
			disabled = module:IsDisabled(),
		});
	end
	
	Addon.ContextMenu:SetPoint("BOTTOM", ExperiencerFrameBars.main, "TOP", 0, 0);
	EasyMenu(menudata, Addon.ContextMenu, "cursor", 0, 0, "MENU");
	
	local mouseX, mouseY = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	
	local point, yoffset = "BOTTOM", 14;
	if(Addon.db.global.AnchorPoint == ANCHOR_TOP) then
		point = "TOP";
		yoffset = -14;
	end
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, ExperiencerFrameBars.main, "CENTER", mouseX / scale - GetScreenWidth() / 2, yoffset);
end

function Experiencer_OnMouseWheel(self, delta)
	-- print("Experiencer_OnMouseWheel",delta )
end

function Experiencer_OnEnter(self)
	if(not Addon.db.char.Visible) then return end
	
	if(not Addon.db.char.StickyText) then
		UIFrameFadeIn(ExperiencerBarText, 0.1, 0, 1);
	end
end

function Experiencer_OnLeave(self)
	if(not Addon.db.char.Visible) then return end
	
	if(not Addon.db.char.StickyText) then
		UIFrameFadeOut(ExperiencerBarText, 0.1, 1, 0);
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	if(Addon.db and Addon.db.char.Mode == EXPERIENCER_MODE_XP and self.elapsed >= 2.0) then
		self.elapsed = 0;
		-- Addon:RefreshBar();
	end
	
	-- local lastPaused = Addon.Session.Paused;
	-- Addon.Session.Paused = UnitIsAFK("player");
	
	-- if(Addon.Session.Paused and lastPaused ~= Addon.Session.Paused) then
	-- 	Addon:RefreshBar();
	-- elseif(not Addon.Session.Paused and lastPaused ~= Addon.Session.Paused) then
	-- 	Addon.Session.LoginTime = Addon.Session.LoginTime + math.floor(Addon.Session.PausedTime);
	-- 	Addon.Session.PausedTime = 0;
	-- end
	
	-- if(Addon.Session.Paused) then
	-- 	Addon.Session.PausedTime = Addon.Session.PausedTime + elapsed;
	-- end
	
	-- if(Addon.db and Addon.db.global.KeepSessionData) then
	-- 	Addon.db.char.Session.Exists = true;
		
	-- 	Addon.db.char.Session.Time = time() - (Addon.Session.LoginTime + math.floor(Addon.Session.PausedTime));
	-- 	Addon.db.char.Session.TotalXP = Addon.Session.ExperienceGained;
	-- 	Addon.db.char.Session.AverageQuestXP = Addon.Session.AverageQuestXP;
	-- end
	
	local current = ExperiencerFrameBars.main:GetAnimatedValue();
	local minvalue, maxvalue = ExperiencerFrameBars.main:GetMinMaxValues();
	ExperiencerFrameBars.color:SetValue(current);
	
	ExperiencerFrameBars.main.spark:ClearAllPoints();
	ExperiencerFrameBars.main.spark:SetPoint("CENTER", ExperiencerFrameBars.main, "LEFT", (current / maxvalue) * ExperiencerFrameBars.main:GetWidth(), 0);
end

