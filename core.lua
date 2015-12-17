local ADDON_NAME, SHARED_DATA = ...;

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = A;
SHARED_DATA[1] = A;

local E = {};
SHARED_DATA[2] = E;
A.E = E;

local AceDB = LibStub("AceDB-3.0");

EXPERIENCER_MODE_XP = 0;
EXPERIENCER_MODE_REP = 1;

local ANCHOR_TOP = 1;
local ANCHOR_BOTTOM = 2;

function A:OnInitialize()
	-- SLASH_EXPERIENCER1	= "/exp";
	-- SLASH_EXPERIENCER2	= "/experiencer";
	-- SlashCmdList["EXPERIENCER"] = function(command) A:ConsoleHandler(command); end
	
	local defaults = {
		profile = {
			Enabled = true,
			StickyText = false,
			Mode = EXPERIENCER_MODE_XP,
			
			Session = {
				Exists = false,
				Time = 0,
				TotalXP = 0,
				AverageQuestXP = 0,
			}
		},
		global = {
			AnchorPoint	= ANCHOR_BOTTOM,
			BigBars = false,
			
			ShowGainedXP = true,
			ShowHourlyXP = true,
			ShowTimeToLevel = true,
			ShowQuestsToLevel = true,
			
			ShowGainedRep = true,
			AutoWatch = {
				Enabled = false,
				IgnoreGuild = true,
				IgnoreInactive = true,
				IgnoreBodyguard = true,
			},
			
			KeepSessionData = true,
			
			QuestXP = {
				ShowText = true,
				AddIncomplete = false,
				ShowVisualizer = true,
			},
		}
	};
	
	self.db = AceDB:New("ExperiencerDB", defaults);
end

function A:OnEnable()
	A:RegisterEvent("PLAYER_REGEN_DISABLED");
	
	A:RegisterEvent("UPDATE_FACTION");
	A:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");
	
	A:RegisterEvent("PET_BATTLE_OPENING_START");
	A:RegisterEvent("PET_BATTLE_CLOSE");
	
	if(not A:IsPlayerMaxLevel()) then
		A:RegisterEvent("CHAT_MSG_SYSTEM");
	
		A:RegisterEvent("PLAYER_XP_UPDATE");
		A:RegisterEvent("PLAYER_LEVEL_UP");
		
		A:RegisterEvent("UNIT_INVENTORY_CHANGED");
		A:RegisterEvent("QUEST_LOG_UPDATE");
	else
		self.db.profile.Mode = EXPERIENCER_MODE_REP;
	end
	
	A.GainUpdateTimer = 0;
	
	A.RecentReputations = {};
	
	A.IsVisible = true;
	A.NoReputation = false;
	A.TargetValue = 0;
	
	A.Session = {
		LoginTime 			= time(),
		ExperienceGained 	= 0,
		LastXP 				= UnitXP("player"),
		MaxXP 				= UnitXPMax("player"),
		
		QuestsToLevel 		= -1,
		AverageQuestXP 		= 0,
		
		Paused 		= false,
		PausedTime 	= 0,
	};
	
	A:SetMode(self.db.profile.Mode);
	A:ToggleVisibility(self.db.profile.Enabled);
	
	A:RestoreSession();
	
	A:RefreshBar(true);
end

function A:RestoreSession()
	if(not A:IsPlayerMaxLevel() and self.db.global.KeepSessionData and self.db.profile.Session.Exists) then
		local data = self.db.profile.Session;
		
		A.Session.LoginTime 		= A.Session.LoginTime - data.Time;
		A.Session.ExperienceGained 	= data.TotalXP;
		A.Session.AverageQuestXP 	= A.Session.AverageQuestXP;
		
		if(A.Session.AverageQuestXP > 0) then
			local remaining_xp = UnitXPMax("player") - UnitXP("player");
			A.Session.QuestsToLevel = ceil(remaining_xp / A.Session.AverageQuestXP);
		end
	end
end

function A:ResetSession()
	A.Session = {
		LoginTime 			= time(),
		ExperienceGained 	= 0,
		LastXP 				= UnitXP("player"),
		MaxXP 				= UnitXPMax("player"),
		
		AverageQuestXP		= 0,
		QuestsToLevel 		= -1,
		
		Paused = false,
		PausedTime = 0,
	};
	
	self.db.profile.Session = {
		Exists = false,
		Time = 0,
		TotalXP = 0,
		AverageQuestXP = 0,
	};
	
	A:RefreshBar();
end

local FormatTime
do
	local DAY_ABBR, HOUR_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
	local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");
	
	local DHMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
	local  HMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
	local   MS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
	local    S = format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

	function FormatTime(t)
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
end

function A:GetStandingColorText(standing)
	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honoured
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
	}
	
	return string.format('|cff%02x%02x%02x%s|r', colors[standing].r * 255, colors[standing].g * 255, colors[standing].b * 255, _G['FACTION_STANDING_LABEL' .. standing]);
end

function A:GetCurrentResolutionSize()
	local resolutions		= { GetScreenResolutions() };
	return strsplit("x", resolutions[GetCurrentResolution()]);
end

function A:IsPlayerMaxLevel(level)
	return MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] == (level or UnitLevel("player"));
end

function A:ConsoleHandler(command)
	
end

function A:OpenContextMenu()
	if(UnitAffectingCombat("player")) then return end
	
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", "ExperiencerContextMenuFrame", UIParent, "UIDropDownMenuTemplate");
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
				self.db.profile.StickyText = not self.db.profile.StickyText;
				if(self.db.profile.StickyText) then
					UIFrameFadeOut(ExperiencerBarText, 0.1, 0, 1);
				else
					UIFrameFadeOut(ExperiencerBarText, 0.1, 1, 0);
				end
				A:OpenContextMenu();
			end,
			checked = function() return self.db.profile.StickyText; end,
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
					func = function() self.db.global.BigBars = not self.db.global.BigBars; A:UpdateFrames(); end,
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
						A:UpdateFrames();
					end,
					checked = function() return self.db.global.AnchorPoint == ANCHOR_BOTTOM; end,
				},
				{
					text = "Anchor to Top",
					func = function()
						self.db.global.AnchorPoint = ANCHOR_TOP;
						A:UpdateFrames();
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
				A:ResetSession();
			end,
			notCheckable = true,
		},
		{
			text = "Keep Session Data",
			func = function() self.db.global.KeepSessionData = not self.db.global.KeepSessionData; A:OpenContextMenu(); end,
			checked = function() return self.db.global.KeepSessionData; end,
			isNotRadio = true,
		},
		{
			text = "Show Gained XP",
			func = function() self.db.global.ShowGainedXP = not self.db.global.ShowGainedXP; A:RefreshBar(); A:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowGainedXP; end,
			isNotRadio = true,
		},
		{
			text = "Show XP per Hour",
			func = function() self.db.global.ShowHourlyXP = not self.db.global.ShowHourlyXP; A:RefreshBar(); A:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowHourlyXP; end,
			isNotRadio = true,
		},
		{
			text = "Show Time to Level",
			func = function() self.db.global.ShowTimeToLevel = not self.db.global.ShowTimeToLevel; A:RefreshBar(); A:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowTimeToLevel; end,
			isNotRadio = true,
		},
		{
			text = "Show Quests to Level",
			func = function() self.db.global.ShowQuestsToLevel = not self.db.global.ShowQuestsToLevel; A:RefreshBar(); A:OpenContextMenu(); end,
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
					func = function() self.db.global.QuestXP.ShowText = not self.db.global.QuestXP.ShowText; A:RefreshBar(); end,
					checked = function() return self.db.global.QuestXP.ShowText; end,
					isNotRadio = true,
				},
				{
					text = "Also Add XP from Incomplete Quests",
					func = function() self.db.global.QuestXP.AddIncomplete = not self.db.global.QuestXP.AddIncomplete; A:RefreshBar(); end,
					checked = function() return self.db.global.QuestXP.AddIncomplete; end,
					isNotRadio = true,
				},
				{
					text = "Show Visualizer Bar",
					func = function() self.db.global.QuestXP.ShowVisualizer = not self.db.global.QuestXP.ShowVisualizer; A:RefreshBar(); end,
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
			func = function() self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep; A:RefreshBar(); A:OpenContextMenu(); end,
			checked = function() return self.db.global.ShowGainedRep; end,
			isNotRadio = true,
		},
		{
			text = "Auto Watch Most Recent Reputation",
			func = function() self.db.global.AutoWatch.Enabled = not self.db.global.AutoWatch.Enabled; A:OpenContextMenu(); end,
			checked = function() return self.db.global.AutoWatch.Enabled; end,
			hasArrow = true,
			isNotRadio = true,
			menuList = {
				{
					text = "Ignore Guild Reputation",
					func = function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; A:OpenContextMenu(); end,
					checked = function() return self.db.global.AutoWatch.IgnoreGuild; end,
					isNotRadio = true,
				},
				{
					text = "Ignore Bodyguard Reputations",
					func = function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; A:OpenContextMenu(); end,
					checked = function() return self.db.global.AutoWatch.IgnoreBodyguard; end,
					isNotRadio = true,
				},
				{
					text = "Ignore Inactive Reputations",
					func = function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; A:OpenContextMenu(); end,
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
			menuList = A:GetReputationsMenu(),
		},
	};
	
	if(self.db.profile.Enabled) then
		tinsert(contextMenuData, 2, {
			text = "Hide Experiencer Bar",
			func = function() self.db.profile.Enabled = false; A:ToggleVisibility(false); end,
			notCheckable = true,
		});
	else
		tinsert(contextMenuData, 2, {
			text = "Show Experiencer Bar",
			func = function() self.db.profile.Enabled = true; A:ToggleVisibility(true); end,
			notCheckable = true,
		});
	end
	
	if(not A:IsPlayerMaxLevel()) then
		if(self.db.profile.Mode == EXPERIENCER_MODE_XP) then
			tinsert(contextMenuData, 3, {
				text = "Switch to Reputation Bar",
				func = function() A:SetMode(EXPERIENCER_MODE_REP); A:OpenContextMenu(); end,
				notCheckable = true,
			});
			
		elseif(self.db.profile.Mode == EXPERIENCER_MODE_REP) then
			tinsert(contextMenuData, 3, {
				text = "Switch to Experience Bar",
				func = function() A:SetMode(EXPERIENCER_MODE_XP); A:OpenContextMenu(); end,
				notCheckable = true,
			});
			
		end
	end
	
	A.ContextMenu:SetPoint("BOTTOM", ExperiencerBar, "TOP", 0, 0);
	EasyMenu(contextMenuData, A.ContextMenu, "cursor", 0, 0, "MENU");
	
	local mouseX, mouseY = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	
	local point, yoffset = "BOTTOM", 14;
	if(A.db.global.AnchorPoint == ANCHOR_TOP) then
		point = "TOP";
		yoffset = -14;
	end
	
	DropDownList1:ClearAllPoints();
	DropDownList1:SetPoint(point, ExperiencerBar, "CENTER", mouseX / scale - GetScreenWidth() / 2, yoffset);
end

function A:GetReputationID(faction_name)
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

function A:GetRecentReputationsMenu()
	local factions = {
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Recent Reputations", isTitle = true, notCheckable = true,
		},
	};
		
	local recentReps = 0;
	
	for name, data in pairs(A.RecentReputations) do
		local faction_index = A:GetReputationID(name);
		local _, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(faction_index);
		local friend_level = select(7, GetFriendshipReputation(factionID));
		local standing_text = "";
		
		if(not isHeader or hasRep) then
			if(friend_level) then
				standing_text = friend_level;
			else
				standing_text = A:GetStandingColorText(standing)
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

function A:GetReputationsMenu()
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
				standing_text = A:GetStandingColorText(standing)
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
	
	local recent = A:GetRecentReputationsMenu();
	if(recent ~= false) then
		for _, data in ipairs(recent) do tinsert(factions, data) end
	end
	
	return factions;
end

function A:UpdateFrames()
	ExperiencerFrame:ClearAllPoints();
	ExperiencerBarText:ClearAllPoints();
	
	local yo1, yo2, yo3, visualizerPad = -1, 9, 3, 0;
	
	if(A.db.global.BigBars) then
		yo1, yo2, yo3, visualizerPad = -1, 16, 7, 3;
		ExperiencerBarText:SetFontObject("ExperiencerBigFont");
	else
		ExperiencerBarText:SetFontObject("ExperiencerFont");
	end
	
	if(A.db.global.AnchorPoint == ANCHOR_TOP) then
		ExperiencerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -yo1);
		ExperiencerFrame:SetPoint("BOTTOMRIGHT", UIParent, "TOPRIGHT", 0, -yo2);
		ExperiencerBarText:SetPoint("TOP", ExperiencerFrame, "TOP", 0, -yo3);
		
		ExperiencerVisualizerBar:SetPoint("BOTTOMLEFT", ExperiencerFrame, "BOTTOMLEFT", 4, 6 + visualizerPad);
		ExperiencerVisualizerBar:SetPoint("TOPRIGHT", ExperiencerFrame, "TOPRIGHT", -4, -2);
		
	elseif(A.db.global.AnchorPoint == ANCHOR_BOTTOM) then
		ExperiencerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, yo1);
		ExperiencerFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, yo2);
		ExperiencerBarText:SetPoint("BOTTOM", ExperiencerFrame, "BOTTOM", 0, yo3);
		
		ExperiencerVisualizerBar:SetPoint("BOTTOMLEFT", ExperiencerFrame, "BOTTOMLEFT", 4, 2);
		ExperiencerVisualizerBar:SetPoint("TOPRIGHT", ExperiencerFrame, "TOPRIGHT", -4, -6 - visualizerPad);
	end
	
	local _, class = UnitClass("player");
	local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class];
	
	ExperiencerBar:SetStatusBarColor(c.r, c.g, c.b, 0.35);
	ExperiencerColorBar:SetStatusBarColor(c.r, c.g, c.b);
	
	ExperiencerRestedBar:SetStatusBarColor(c.r, c.g, c.b, 0.4);
	
	ExperiencerGainBar:SetStatusBarColor(1, 1, 1);
	
	A:RefreshBar(true);
end

function A:ShowBar()
	ExperiencerBar:Show();
	ExperiencerColorBar:Show();
	ExperiencerGainBar:Show();
	ExperiencerRestedBar:Show();
	
	if(self.db.profile.StickyText) then
		ExperiencerBarText:Show();
	end
	
	if(not A.IsVisible) then
		A:RefreshBar(true);
	end
	
	A.IsVisible = true;
end

function ExperiencerBar_OnShow(self)
	A:RefreshBar(true);
end

function A:HideBar()
	ExperiencerBar:Hide();
	ExperiencerVisualizerBar:Hide();
	ExperiencerColorBar:Hide();
	ExperiencerGainBar:Hide();
	ExperiencerRestedBar:Hide();
	
	ExperiencerBarText:Hide();
	
	A.IsVisible = false;
end

function A:ToggleVisibility(visible)
	A.IsVisible = visible or (not A.IsVisible);
	
	if(visible) then
		A:ShowBar();
	else
		A:HideBar();
	end
end

function A:SetMode(new_mode)
	self.db.profile.Mode = new_mode;
	
	A:UpdateFrames();
	A:ToggleVisibility(true);
end

function A:GetProgressColor(progress)
	local r = math.min(1.0, math.max(0.0, 2.0 - progress * 1.8));
	local g = math.min(1.0, math.max(0.0, progress * 2.0));
	local b = 0;
	
	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255);
end

local heirloomItemXP = {
	["INVTYPE_HEAD"] 		= 0.1,
	["INVTYPE_SHOULDER"] 	= 0.1,
	["INVTYPE_CHEST"] 		= 0.1,
	["INVTYPE_ROBE"] 		= 0.1,
	["INVTYPE_LEGS"] 		= 0.1,
	["INVTYPE_FINGER"] 		= 0.05,
	["INVTYPE_CLOAK"] 		= 0.05,
	
	-- Darkmoon rings with battleground xp bonus instead
	[126948] 	= 0.0,
	[126949]	= 0.0,
};

local heirloomSlots = {
	1, 3, 5, 7, 11, 12, 15,
};

local buffMultipliers = {
	[46668]		= { multiplier = 0.1, }, -- Darkmoon Carousel Buff
	[178119] 	= { multiplier = 0.2, }, -- Excess Potion of Accelerated Learning
	[127250]	= { multiplier = 3.0, maxlevel = 84, }, -- Elixir of Ancient Knowledge
	[189375]	= { multiplier = 3.0, maxlevel = 99, }, -- Elixir of the Rapid Mind
};

function A:PlayerHasBuff(spellID)
	local spellName = GetSpellInfo(spellID);
	return UnitAura("player", spellName) ~= nil;
end

E.GROUP_TYPE = {
	SOLO 	= 0x1,
	PARTY 	= 0x2,
	RAID	= 0x3,
};

function A:GetGroupType()
	if(IsInRaid()) then
		return E.GROUP_TYPE.RAID;
	elseif(IsInGroup()) then
		return E.GROUP_TYPE.PARTY;
	end
	
	return E.GROUP_TYPE.SOLO;
end

local partyUnitID = { "player", "party1", "party2", "party3", "party4" };

function A:GetUnitID(group_type, index)
	if(group_type == E.GROUP_TYPE.SOLO or group_type == E.GROUP_TYPE.PARTY) then
		return partyUnitID[index];
	elseif(group_type == E.GROUP_TYPE.RAID) then
		return string.format("raid%d", index);
	end
	
	return nil;
end

local function GroupIterator()
	local index = 0;
	local groupType = A:GetGroupType();
	local numGroupMembers = GetNumGroupMembers();
	if(groupType == E.GROUP_TYPE.SOLO) then numGroupMembers = 1 end
	
	return function()
		index = index + 1;
		if(index <= numGroupMembers) then
			return index, A:GetUnitID(groupType, index);
		end
	end
end

function A:HasRecruitAFriendBonus()
	local playerLevel = UnitLevel("player");
	
	for index, unit in GroupIterator() do
		if(not UnitIsUnit("player", unit) and UnitIsVisible(unit) and IsReferAFriendLinked(unit)) then
			local unitLevel = UnitLevel(unit);
			if(math.abs(playerLevel - unitLevel) <= 4 and playerLevel < 90) then
				return true;
			end
		end
	end
	
	return false;
end

function A:CalculateXPMultiplier()
	local multiplier = 1.0;
	
	if(A:HasRecruitAFriendBonus()) then
		multiplier = multiplier * 3.0;
	end
	
	for _, slotID in ipairs(heirloomSlots) do
		local link = GetInventoryItemLink("player", slotID);
		
		if(link) then
			local _, _, itemRarity, _, _, _, _, _, itemEquipLoc = GetItemInfo(link);
			
			if(itemRarity == 7) then
				local itemID = tonumber(strmatch(link, "item:(%d*)")) or 0;
				local itemMultiplier = heirloomItemXP[itemID] or heirloomItemXP[itemEquipLoc];
				
				multiplier = multiplier + itemMultiplier;
			end
		end
	end
	
	local playerLevel = UnitLevel("player");
	
	for buffSpellID, buffMultiplier in pairs(buffMultipliers) do
		if(A:PlayerHasBuff(buffSpellID)) then
			if(not buffMultiplier.maxlevel or (buffMultiplier.maxlevel and playerLevel <= buffMultiplier.maxlevel)) then
				multiplier = multiplier + buffMultiplier.multiplier;
			end
		end 
	end
	
	return multiplier;
end

function A:CalculateQuestLogXP()
	local completeXP, incompleteXP = 0, 0;
	
	if (GetNumQuestLogEntries() == 0) then return 0, 0, 0; end
	
	local index = 0;
	local lastSelected = GetQuestLogSelection();
	local playerMoney = GetMoney();
	
	repeat
		index = index + 1;
		local questTitle, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index);
		
		if(not isHeader) then
			SelectQuestLogEntry(index);
			
			local requiredMoney = GetQuestLogRequiredMoney(index);
			local numObjectives = GetNumQuestLeaderBoards(index);
			
			if(isComplete and isComplete < 0) then
				isComplete = false;
			elseif(numObjectives == 0 and playerMoney >= requiredMoney) then
				isComplete = true;
			end
			
			if(isComplete) then
				completeXP = completeXP + GetQuestLogRewardXP();
			else
				incompleteXP = incompleteXP + GetQuestLogRewardXP();
			end
		end
	until(questTitle == nil);
	
	SelectQuestLogEntry(lastSelected);
	
	local multiplier = A:CalculateXPMultiplier();
	
	return completeXP * multiplier, incompleteXP * multiplier, (completeXP + incompleteXP) * multiplier;
end

function A:RefreshExperienceBar(set_value)
	local current_xp, max_xp = UnitXP("player"), UnitXPMax("player");
	local rested_xp = GetXPExhaustion() or 0;
	local remaining_xp = max_xp - current_xp;
	
	A.TargetValue = current_xp;
	
	local completeXP, incompleteXP, totalXP = A:CalculateQuestLogXP();
	local questXP = completeXP;
	if(self.db.global.QuestXP.AddIncomplete) then
		questXP = totalXP
	end
	
	ExperiencerBar:SetMinMaxValues(0, max_xp)
	ExperiencerColorBar:SetMinMaxValues(0, max_xp);
	
	ExperiencerRestedBar:SetMinMaxValues(0, max_xp)
	
	ExperiencerGainBar:SetMinMaxValues(0, max_xp)
	ExperiencerGainBar:SetValue(current_xp);
	
	if(self.db.global.QuestXP.ShowVisualizer and A.IsVisible) then
		ExperiencerVisualizerBar:Show();
		ExperiencerVisualizerBar:SetMinMaxValues(0, max_xp);
		ExperiencerVisualizerBar:SetValue(current_xp + questXP);
		ExperiencerVisualizerBar:SetStatusBarColor(0.2, 0.65, 1.0, 0.6);
		
	else
		ExperiencerVisualizerBar:Hide();
	end
	
	if(set_value) then
		ExperiencerBar:SetValue(current_xp);
		ExperiencerColorBar:SetValue(current_xp);
	end
	
	ExperiencerRestedBar:SetValue(current_xp + rested_xp)
	
	
	local progress = current_xp / max_xp;
	local progressColor = A:GetProgressColor(progress);
	
	local outputText = {};
	
	tinsert(outputText,
		string.format("%s%s|r (%s%d|r%%)", progressColor, BreakUpLargeNumbers(remaining_xp), progressColor, 100 - progress * 100)
	);
	
	if(rested_xp > 0) then
		tinsert(outputText,
			string.format("%d%% |cff6fafdfrested|r", math.ceil(rested_xp / max_xp * 100))
		);
	end
	
	if(A.Session.ExperienceGained > 0) then
		local hourlyXP, timeToLevel = A:CalculateHourlyXP();
		
		if(self.db.global.ShowGainedXP) then
			tinsert(outputText,
				string.format("+%s |cffffcc00xp|r", BreakUpLargeNumbers(A.Session.ExperienceGained))
			);
		end
		
		if(self.db.global.ShowHourlyXP) then
			tinsert(outputText,
				string.format("%s |cffffcc00xp/h|r", BreakUpLargeNumbers(hourlyXP))
			);
		end
		
		if(self.db.global.ShowTimeToLevel) then
			tinsert(outputText,
				string.format("%s |cff80e916until level|r", FormatTime(timeToLevel))
			);
		end
	end
	
	if(A.Session.QuestsToLevel > 0) then
		if(self.db.global.ShowQuestsToLevel and A.Session.QuestsToLevel > 0) then
			tinsert(outputText,
				string.format("~%s |cff80e916quests|r", A.Session.QuestsToLevel)
			);
		end
	end
	
	if(self.db.global.QuestXP.ShowText) then
		local levelUpAlert = "";
		if(current_xp + questXP >= max_xp) then
			levelUpAlert = " (|cfff1e229enough to level|r)";
		end
		
		tinsert(outputText,
			string.format("%s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(questXP)), levelUpAlert)
		);
	end
	
	ExperiencerBarText:SetText(table.concat(outputText, "  "));
end

function A:HasWatchedReputation()
	return GetWatchedFactionInfo() ~= nil;
end

function A:RefreshReputationBar(set_value)
	if(not A:HasWatchedReputation()) then return end
	
	local name, standing, min_rep, max_rep, rep_value, factionID = GetWatchedFactionInfo();
	A.CurrentRep = name;
	
	local remaining_rep = max_rep - rep_value;
	
	ExperiencerGainBar:SetMinMaxValues(min_rep, max_rep)
	ExperiencerGainBar:SetValue(rep_value);
	
	ExperiencerRestedBar:SetMinMaxValues(min_rep, max_rep)
	ExperiencerRestedBar:SetValue(rep_value)
	
	ExperiencerBar:SetMinMaxValues(min_rep, max_rep)
	ExperiencerColorBar:SetMinMaxValues(min_rep, max_rep)
	
	ExperiencerVisualizerBar:Hide();
	
	if(set_value) then
		-- ExperiencerBar:SetStatusBarTexture("Interface\\AddOns\\Experiencer\\Media\\FlatRep")
		ExperiencerBar:SetValue(rep_value);
		ExperiencerColorBar:SetValue(rep_value);
	end
	
	A.TargetValue = rep_value;
	
	local rep_text = {};
	
	local progress = (rep_value - min_rep) / (max_rep - min_rep)
	local color = A:GetProgressColor(progress);
	
	local standing_text = "";
	local friend_level = select(7, GetFriendshipReputation(factionID));
	
	if(not friend_level) then
		standing_text = A:GetStandingColorText(standing);
	else
		standing_text = friend_level;
	end
	
	tinsert(rep_text, string.format("%s (%s): %s%s|r (%s%d|r%%)", name, standing_text, color, BreakUpLargeNumbers(remaining_rep), color, 100 - progress * 100));
	
	if(self.db.global.ShowGainedRep and A.RecentReputations[name] ~= nil) then
		tinsert(rep_text, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(A.RecentReputations[name].amount)));
	end
	
	ExperiencerBarText:SetText(table.concat(rep_text, "  "));
end

function A:RefreshBar(set_value)
	-- if(not A.IsVisible and not A.NoReputation) then return end
	if(not self.db) then return end
	
	if(self.db.profile.Mode == EXPERIENCER_MODE_XP) then
		A:RefreshExperienceBar(set_value)
	elseif(self.db.profile.Mode == EXPERIENCER_MODE_REP) then
		if(A:HasWatchedReputation()) then
			A:RefreshReputationBar(set_value);
		else
			if(not A:IsPlayerMaxLevel()) then
				A:SetMode(EXPERIENCER_MODE_XP);
			else
				A:HideBar();
			end
		end
	end
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

function A:OutputExperience()
	if(not A:IsPlayerMaxLevel()) then
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

function A:OutputReputation()
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

function A:CalculateHourlyXP()
	local hourlyXP, timeToLevel = 0, 0;
	
	local logged_time = time() - (A.Session.LoginTime + math.floor(A.Session.PausedTime));
	local coeff = logged_time / 3600;
	
	if(coeff ~= 0 and A.Session.ExperienceGained > 0) then
		hourlyXP = math.ceil(A.Session.ExperienceGained / coeff);
		timeToLevel = (UnitXPMax("player") - UnitXP("player")) / hourlyXP * 3600;
	end
	
	return hourlyXP, timeToLevel
end

function Experiencer_OnMouseDown(self, button)
	if(button == "LeftButton") then
		if(A.db.profile.Enabled) then
			if(A.db.profile.Mode == EXPERIENCER_MODE_XP) then
				A:OutputExperience();
			else
				A:OutputReputation();
			end
		end
		
	elseif(button == "MiddleButton") then
		if(IsShiftKeyDown()) then
			if(IsControlKeyDown() and not A:IsPlayerMaxLevel()) then
				if(A.db.profile.Mode == EXPERIENCER_MODE_XP) then
					A:SetMode(EXPERIENCER_MODE_REP);
				else
					A:SetMode(EXPERIENCER_MODE_XP);
				end
			else
				A.db.profile.Enabled = not A.db.profile.Enabled;
				A:ToggleVisibility(A.db.profile.Enabled);
			end
		else
			A.db.profile.StickyText = not A.db.profile.StickyText;
			
			if(A.db.profile.StickyText) then
				ExperiencerBarText:Show();
			end
		end
		
		CloseMenus();
		
	elseif(button == "RightButton") then
		A:OpenContextMenu()
	end
end

function Experiencer_OnEnter(self)
	if(not A.db.profile.Enabled) then return end
	
	if(not A.db.profile.StickyText) then
		UIFrameFadeIn(ExperiencerBarText, 0.1, 0, 1);
	end
end

function Experiencer_OnLeave(self)
	if(not A.db.profile.Enabled) then return end
	
	if(not A.db.profile.StickyText) then
		UIFrameFadeOut(ExperiencerBarText, 0.1, 1, 0);
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	
	if(A.db and A.db.profile.Mode == EXPERIENCER_MODE_XP and self.elapsed >= 2.0) then
		self.elapsed = 0;
		A:RefreshBar();
	end
	
	local lastPaused = A.Session.Paused;
	A.Session.Paused = UnitIsAFK("player");
	
	if(A.Session.Paused and lastPaused ~= A.Session.Paused) then
		A:RefreshBar();
	elseif(not A.Session.Paused and lastPaused ~= A.Session.Paused) then
		A.Session.LoginTime = A.Session.LoginTime + math.floor(A.Session.PausedTime);
		A.Session.PausedTime = 0;
	end
	
	if(A.Session.Paused) then
		A.Session.PausedTime = A.Session.PausedTime + elapsed;
	end
	
	if(A.db and A.db.global.KeepSessionData) then
		A.db.profile.Session.Exists = true;
		
		A.db.profile.Session.Time = time() - (A.Session.LoginTime + math.floor(A.Session.PausedTime));
		A.db.profile.Session.TotalXP = A.Session.ExperienceGained;
		A.db.profile.Session.AverageQuestXP = A.Session.AverageQuestXP;
	end
	
	A.GainUpdateTimer = A.GainUpdateTimer + elapsed;
	
	if(A.GainUpdateTimer >= 1.0) then
		local current_value = ExperiencerBar:GetValue();
		
		ExperiencerBar:SetValue(current_value + (A.TargetValue - current_value) / 17);
		ExperiencerColorBar:SetValue(current_value + (A.TargetValue - current_value) / 17);
	end
end

