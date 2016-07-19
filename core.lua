------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

local E = {};
Addon.E = E;

local AceDB = LibStub("AceDB-3.0");

EXPERIENCER_MODE_XP = 0;
EXPERIENCER_MODE_REP = 1;

local ANCHOR_TOP = 1;
local ANCHOR_BOTTOM = 2;

function Addon:OnInitialize()
	local moduleVars = Addon:GetModuleSavedVariableDefaults();
	
	local defaults = {
		char = {
			Visible = true,
			StickyText = false,
			Mode = EXPERIENCER_MODE_XP,
			
			modules = moduleVars.char,
		},
		
		global = {
			AnchorPoint	= ANCHOR_BOTTOM,
			BigBars = false,
			
			modules = moduleVars.global,
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
	Addon.NoReputation = false;
	
	Addon:SetMode(self.db.char.Mode);
	Addon:UpdateFrames();
end

Addon.modules = {};
function Addon:RegisterModule(name, module)
	if(Addon.modules[name]) then
		error(("Addon:RegisterModule(name, module): Module '%s' is already registered."):format(tostring(name)), 2);
		return;
	end
	
	Addon.modules[name] = module;
end

function Addon:GetModuleSavedVariableDefaults()
	local defaults = {
		char = {},
		global = {},
	};
	
	for moduleName, module in pairs(Addon.modules) do
		if(module.savedvars) then
			defaults.char[moduleName]   = module.savedvars.char;
			defaults.global[moduleName] = module.savedvars.global;
		end
	end
	
	return defaults;
end

function Addon:InitializeModules()
	for moduleName, module in pairs(Addon.modules) do
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
		
		module.db = {
			char = self.db.char.modules[moduleName],
			global = self.db.global.modules[moduleName],
		};
		
		module:Initialize();
	end
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

function Addon:OpenContextMenu()
	if(UnitAffectingCombat("player")) then return end
	
	if(not Addon.ContextMenu) then
		Addon.ContextMenu = CreateFrame("Frame", "ExperiencerContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
	end
	
	local contextMenuData = {
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
		{
			text = "Experience Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Reset XP Session",
			func = function()
				Addon:ResetSession();
			end,
			notCheckable = true,
		},
		{
			text = "Keep Session Data",
			func = function() self.db.global.KeepSessionData = not self.db.global.KeepSessionData; Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.KeepSessionData; end,
			isNotRadio = true,
		},
		{
			text = "Show Gained XP",
			func = function() self.db.global.ShowGainedXP = not self.db.global.ShowGainedXP; Addon:RefreshBar(); Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowGainedXP; end,
			isNotRadio = true,
		},
		{
			text = "Show XP per Hour",
			func = function() self.db.global.ShowHourlyXP = not self.db.global.ShowHourlyXP; Addon:RefreshBar(); Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowHourlyXP; end,
			isNotRadio = true,
		},
		{
			text = "Show Time to Level",
			func = function() self.db.global.ShowTimeToLevel = not self.db.global.ShowTimeToLevel; Addon:RefreshBar(); Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowTimeToLevel; end,
			isNotRadio = true,
		},
		{
			text = "Show Quests to Level",
			func = function() self.db.global.ShowQuestsToLevel = not self.db.global.ShowQuestsToLevel; Addon:RefreshBar(); Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowQuestsToLevel; end,
			isNotRadio = true,
		},
		{
			text = "Quest XP Visualizer",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Show Completed Quest XP",
					func = function() self.db.global.QuestXP.ShowText = not self.db.global.QuestXP.ShowText; Addon:RefreshBar(); end,
					checked = function() return self.db.global.QuestXP.ShowText; end,
					isNotRadio = true,
				},
				{
					text = "Also Add XP from Incomplete Quests",
					func = function() self.db.global.QuestXP.AddIncomplete = not self.db.global.QuestXP.AddIncomplete; Addon:RefreshBar(); end,
					checked = function() return self.db.global.QuestXP.AddIncomplete; end,
					isNotRadio = true,
				},
				{
					text = "Show Visualizer Bar",
					func = function() self.db.global.QuestXP.ShowVisualizer = not self.db.global.QuestXP.ShowVisualizer; Addon:RefreshBar(); end,
					checked = function() return self.db.global.QuestXP.ShowVisualizer; end,
					isNotRadio = true,
				},	
			},
		},
		{
			text = "",
			isTitle = true,
			notCheckable = true,
			disabled = true,
		},
		{
			text = "Reputation Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show Gained Reputation",
			func = function() self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep; Addon:RefreshBar(); Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowGainedRep; end,
			isNotRadio = true,
		},
		{
			text = "Auto Watch Most Recent Reputation",
			func = function() self.db.global.AutoWatch.Visible = not self.db.global.AutoWatch.Visible; Addon:OpenContextMenu(); end,
			checked = function() return self.db.global.AutoWatch.Visible; end,
			hasArrow = true,
			isNotRadio = true,
			menuList = {
				{
					text = "Ignore Guild Reputation",
					func = function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; Addon:OpenContextMenu(); end,
					checked = function() return self.db.global.AutoWatch.IgnoreGuild; end,
					isNotRadio = true,
				},
				{
					text = "Ignore Bodyguard Reputations",
					func = function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; Addon:OpenContextMenu(); end,
					checked = function() return self.db.global.AutoWatch.IgnoreBodyguard; end,
					isNotRadio = true,
				},
				{
					text = "Ignore Inactive Reputations",
					func = function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; Addon:OpenContextMenu(); end,
					checked = function() return self.db.global.AutoWatch.IgnoreInactive; end,
					isNotRadio = true,
				},
			},
		},
		{
			text = "Set Watched Faction",
			func = function() ToggleCharacter("ReputationFrame"); end,
			hasArrow = true,
			notCheckable = true,
			menuList = Addon:GetReputationsMenu(),
		},
	};
	
	if(self.db.char.Visible) then
		tinsert(contextMenuData, 2, {
			text = "Hide Experiencer Bar",
			func = function() self.db.char.Visible = false; Addon:ToggleVisibility(false); end,
			notCheckable = true,
		});
	else
		tinsert(contextMenuData, 2, {
			text = "Show Experiencer Bar",
			func = function() self.db.char.Visible = true; Addon:ToggleVisibility(true); end,
			notCheckable = true,
		});
	end
	
	if(not Addon:IsPlayerMaxLevel()) then
		if(self.db.char.Mode == EXPERIENCER_MODE_XP) then
			tinsert(contextMenuData, 3, {
				text = "Switch to Reputation Bar",
				func = function() Addon:SetMode(EXPERIENCER_MODE_REP); Addon:OpenContextMenu(); end,
				notCheckable = true,
			});
			
		elseif(self.db.char.Mode == EXPERIENCER_MODE_REP) then
			tinsert(contextMenuData, 3, {
				text = "Switch to Experience Bar",
				func = function() Addon:SetMode(EXPERIENCER_MODE_XP); Addon:OpenContextMenu(); end,
				notCheckable = true,
			});
			
		end
	end
	
	Addon.ContextMenu:SetPoint("BOTTOM", ExperiencerFrameBars.main, "TOP", 0, 0);
	EasyMenu(contextMenuData, Addon.ContextMenu, "cursor", 0, 0, "MENU");
	
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

function Addon:GetReputationID(faction_name)
	if(faction_name == GUILD) then
		return 2;
	end
	
	local numFactions = GetNumFactions();
	local index = 1;
	while index <= numFactions do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed, _, _, _, factionID = GetFactionInfo(index);
		
		if(isHeader and isCollapsed) then
			ExpandFactionHeader(index);
			numFactions = GetNumFactions();
		end
		
		if(name == faction_name) then return index, factionID end
			
		index = index + 1;
	end
	
	return nil
end

function Addon:GetRecentReputationsMenu()
	local factions = {
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Recent Reputations", isTitle = true, notCheckable = true,
		},
	};
		
	local recentReps = 0;
	
	for name, data in pairs(Addon.RecentReputations) do
		local faction_index = Addon:GetReputationID(name);
		local _, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(faction_index);
		local friend_level = select(7, GetFriendshipReputation(factionID));
		local standing_text = "";
		
		if(not isHeader or hasRep) then
			if(friend_level) then
				standing_text = friend_level;
			else
				standing_text = Addon:GetStandingColorText(standing)
			end
		end
		
		tinsert(factions, {
			text = string.format("%s (%s)  +%s rep this session", name, standing_text, BreakUpLargeNumbers(data.amount)),
			func = function() SetWatchedFactionIndex(faction_index); CloseMenus(); end,
			checked = function() return isWatched end,
		})
		
		recentReps = recentReps + 1;
	end
	
	if(recentReps == 0) then
		return false;
	end
	
	return factions;
end

function Addon:GetReputationsMenu()
	local factions = {
		{
			text = "Choose Category",
			isTitle = true,
			notCheckable = true,
		},
	};
	
	local previous, current = nil, nil;
	local depth = 0;
	
	local numFactions = GetNumFactions();
	local index = 1;
	while index <= numFactions do
		local name, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(index);
		local friend_level = select(7, GetFriendshipReputation(factionID));
		local standing_text = "";
		local faction_index = index;
		
		if(not isHeader or hasRep) then
			if(friend_level) then
				standing_text = friend_level;
			else
				standing_text = Addon:GetStandingColorText(standing)
			end
		end
		
		if(isHeader and isCollapsed) then
			ExpandFactionHeader(index);
			numFactions = GetNumFactions();
		end
		
		if(isHeader and isChild) then -- Second tier header
			if(depth == 2) then
				current = previous;
				previous = nil;
			end
			
			if(not hasRep) then
				tinsert(current, {
					text = name,
					hasArrow = true,
					notCheckable = true,
					menuList = {},
				})
			else
				tinsert(current, {
					text = string.format("%s (%s)", name, standing_text),
					hasArrow = true,
					func = function() SetWatchedFactionIndex(faction_index); CloseMenus(); end,
					checked = function() return isWatched; end,
					menuList = {},
				})
			end
			
			previous = current;
			current = current[#current].menuList;
			tinsert(current, {
				text = name,
				isTitle = true,
				notCheckable = true,
			})
			
			depth = 2
			
		elseif(isHeader) then -- First tier header
			tinsert(factions, {
				text = name,
				hasArrow = true,
				notCheckable = true,
				menuList = {},
			})
			
			current = factions[#factions].menuList;
			tinsert(current, {
				text = name,
				isTitle = true,
				notCheckable = true,
			})
			
			depth = 1
		elseif(not isHeader) then -- First and second tier faction
			tinsert(current, {
				text = string.format("%s (%s)", name, standing_text),
				func = function() SetWatchedFactionIndex(faction_index); CloseMenus(); end,
				checked = function() return isWatched end,
			})
		end
		
		index = index + 1;
	end
	
	local recent = Addon:GetRecentReputationsMenu();
	if(recent ~= false) then
		for _, data in ipairs(recent) do tinsert(factions, data) end
	end
	
	return factions;
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
	
	if(Addon.db.global.AnchorPoint == ANCHOR_TOP) then
		ExperiencerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -yo1);
		ExperiencerFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPRIGHT", 0, -yo2);
		ExperiencerBarText:SetPoint("TOP", ExperiencerFrameBars, "TOP", 0, -yo3);
		
		ExperiencerFrameBars.visual:SetPoint("BOTTOMLEFT", ExperiencerFrameBars, "BOTTOMLEFT", 4, 6 + visualizerPad);
		ExperiencerFrameBars.visual:SetPoint("TOPRIGHT", ExperiencerFrameBars, "TOPRIGHT", -4, -2);
		
	elseif(Addon.db.global.AnchorPoint == ANCHOR_BOTTOM) then
		ExperiencerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, yo1);
		ExperiencerFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, yo2);
		ExperiencerBarText:SetPoint("BOTTOM", ExperiencerFrameBars, "BOTTOM", 0, yo3);
		
		ExperiencerFrameBars.visual:SetPoint("BOTTOMLEFT", ExperiencerFrameBars, "BOTTOMLEFT", 4, 2);
		ExperiencerFrameBars.visual:SetPoint("TOPRIGHT", ExperiencerFrameBars, "TOPRIGHT", -4, -6 - visualizerPad);
	end
	
	local _, class = UnitClass("player");
	local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class];
	
	ExperiencerFrameBars.main:SetStatusBarColor(c.r, c.g, c.b, 0.45);
	ExperiencerFrameBars.main:SetAnimatedTextureColors(c.r, c.g, c.b);
	ExperiencerFrameBars.main.accumulationTimeoutInterval = 0.01;
	
	-- /run ExperiencerFrameBars.main:SetAnimatedValues(140, 0, 1000)
	
	ExperiencerFrameBars.color:SetStatusBarColor(c.r, c.g, c.b);
	ExperiencerFrameBars.rested:SetStatusBarColor(c.r, c.g, c.b, 0.4);
	
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

function Addon:SetMode(new_mode)
	self.db.char.Mode = new_mode;
	Addon:UpdateFrames();
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

function Addon:GetActiveModule()
	return Addon.modules["experience"];
end

function Addon:UpdateActiveBar()
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	local data = module:GetBarData();
	ASD = data;
	
	ExperiencerFrameBars.main:SetAnimatedValues(data.current, data.min, data.max, data.level);
	
	ExperiencerFrameBars.color:SetMinMaxValues(data.min, data.max);
	-- ExperiencerFrameBars.color:SetValue(data.current);
	ExperiencerFrameBars.color:SetValue(ExperiencerFrameBars.main:GetAnimatedValue());
	
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
	
	ExperiencerFrameBars.rested:Hide();
	ExperiencerFrameBars.color:Hide();
	ExperiencerFrameBars.visual:Hide();
	
	local text = module:GetText() or "<Error: no module text>";
	ExperiencerBarText:SetText(text);
end


function Addon:RefreshBar()
	-- if(not Addon.IsVisible and not Addon.NoReputation) then return end
	-- if(not self.db) then return end
	
	Addon:UpdateActiveBar();
	
	-- if(self.db.char.Mode == EXPERIENCER_MODE_XP) then
	-- 	Addon:RefreshExperienceBar(set_value)
	-- elseif(self.db.char.Mode == EXPERIENCER_MODE_REP) then
	-- 	if(Addon:HasWatchedReputation()) then
	-- 		Addon:RefreshReputationBar(set_value);
	-- 	else
	-- 		if(not Addon:IsPlayerMaxLevel()) then
	-- 			Addon:SetMode(EXPERIENCER_MODE_XP);
	-- 		else
	-- 			Addon:HideBar();
	-- 		end
	-- 	end
	-- end
end

local function roundnum(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num))
end

local function kilofy(num)
	num = tonumber(num);
	
	if(num > 1000000) then
		num = roundnum((num / 1000000), 2) .. "m";
	elseif(num > 1000) then
		num = roundnum((num / 1000), 2) .. "k";
	end
	
	return num;
end

function Addon:OutputExperience()
	if(not Addon:IsPlayerMaxLevel()) then
		local current_xp, max_xp = UnitXP("player"), UnitXPMax("player");
		local remaining_xp = max_xp - current_xp;
		local rested_xp = GetXPExhaustion() or 0;

		local rested_xp_percent = floor(((rested_xp / max_xp) * 100) + 0.5);
		
		local max_xp_text = kilofy(max_xp);
		local current_xp_text = kilofy(current_xp);
		local remaining_xp_text = kilofy(remaining_xp);

		local xp_text = string.format("Currently level %d with %s/%s (%d%%) %s xp to go (%d%% rested)", 
					UnitLevel("player"),
					current_xp_text,
					max_xp_text, 
					math.ceil((current_xp / max_xp) * 100), 
					remaining_xp_text, 
					rested_xp_percent);

		if(IsShiftKeyDown()) then
			ChatFrame_OpenChat(xp_text);
		else
			DEFAULT_CHAT_FRAME.editBox:SetText(xp_text)
		end
	else
		print("Max level reached.");
	end
end

function Addon:OutputReputation()
	local name, standing, min_rep, max_rep, rep_value, factionID = GetWatchedFactionInfo();
	
	if(not name) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Experiencer|r No watched reputation.");
		return;
	end
	
	local remaining_rep = max_rep - rep_value;
	local progress = (rep_value - min_rep) / (max_rep - min_rep)
	
	local standing_text = "";
	local friend_text = select(7, GetFriendshipReputation(factionID));
	
	if(not friend_text) then
		standing_text = _G['FACTION_STANDING_LABEL' .. standing];
	else
		-- standing_text = friend_standing[standing];
		standing_text = select(7, GetFriendshipReputation(factionID));
	end
	
	local rep_text = string.format("%s with %s: %s/%s (%d%%) with %s to go",
						standing_text,
						name,
						BreakUpLargeNumbers(rep_value - min_rep),
						BreakUpLargeNumbers(max_rep - min_rep),
						progress * 100,
						BreakUpLargeNumbers(remaining_rep));
	
	if(IsShiftKeyDown()) then
		ChatFrame_OpenChat(rep_text);
	else
		DEFAULT_CHAT_FRAME.editBox:SetText(rep_text);
	end
end

function Addon:CalculateHourlyXP()
	local hourlyXP, timeToLevel = 0, 0;
	
	local logged_time = time() - (Addon.Session.LoginTime + math.floor(Addon.Session.PausedTime));
	local coeff = logged_time / 3600;
	
	if(coeff ~= 0 and Addon.Session.ExperienceGained > 0) then
		hourlyXP = math.ceil(Addon.Session.ExperienceGained / coeff);
		timeToLevel = (UnitXPMax("player") - UnitXP("player")) / hourlyXP * 3600;
	end
	
	return hourlyXP, timeToLevel
end

function Experiencer_OnMouseDown(self, button)
	if(button == "LeftButton") then
		if(Addon.db.char.Visible) then
			if(Addon.db.char.Mode == EXPERIENCER_MODE_XP) then
				Addon:OutputExperience();
			else
				Addon:OutputReputation();
			end
		end
		
	elseif(button == "MiddleButton") then
		if(IsShiftKeyDown()) then
			if(IsControlKeyDown() and not Addon:IsPlayerMaxLevel()) then
				if(Addon.db.char.Mode == EXPERIENCER_MODE_XP) then
					Addon:SetMode(EXPERIENCER_MODE_REP);
				else
					Addon:SetMode(EXPERIENCER_MODE_XP);
				end
			else
				Addon.db.char.Visible = not Addon.db.char.Visible;
				Addon:ToggleVisibility(Addon.db.char.Visible);
			end
		else
			Addon.db.char.StickyText = not Addon.db.char.StickyText;
			
			if(Addon.db.char.StickyText) then
				ExperiencerBarText:Show();
			end
		end
		
		CloseMenus();
		
	elseif(button == "RightButton") then
		Addon:OpenContextMenu()
	end
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
	
	ExperiencerFrameBars.color:SetValue(ExperiencerFrameBars.main:GetAnimatedValue());
end

