------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = {};
module.id       = "reputation";
module.name     = "Reputation";
module.order    = 2;

Addon:RegisterModule(module.id, module);

module.savedvars = {
	char = {
		
	},
	global = {
		ShowGainedRep = true,
		AutoWatch = {
			Enabled = false,
			IgnoreGuild = true,
			IgnoreInactive = true,
			IgnoreBodyguard = true,
		},
	},
};

module.recentReputations = {};

local BODYGUARD_FACTIONS = {
	[1738] = "Defender Illona",
	[1740] = "Aeda Brightdawn",
	[1733] = "Delvar Ironfist",
	[1739] = "Vivianne",
	[1737] = "Talonpriest Ishaal",
	[1741] = "Leorajh",
	[1736] = "Tormmok",
};

function module:Initialize()
	module:RegisterEvent("UPDATE_FACTION");
	module:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");
end

function module:IsDisabled()
	return false;
end

function module:Update()
	
end

function module:GetText()
	if(not Addon:HasWatchedReputation()) then
		return "No active watched reputation";
	end
	
	local outputText = {};
	
	local rep_text = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local remainingReputation = maxReputation - currentReputation;
	
	local progress = (currentReputation - minReputation) / (maxReputation - minReputation);
	local color = Addon:GetProgressColor(progress);
	
	local standingText = "";
	local friendLevel = select(7, GetFriendshipReputation(factionID));
	
	if(not friendLevel) then
		standingText = module:GetStandingColorText(standing);
	else
		standingText = friendLevel;
	end
	
	tinsert(outputText, string.format("%s (%s): %s%s|r (%s%d|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100));
	
	if(self.db.global.ShowGainedRep and module.recentReputations[name]) then
		tinsert(outputText, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
	end
	
	ExperiencerBarText:SetText(table.concat(rep_text, "  "));
	
	return table.concat(outputText, "  ");
end

function module:HasChatMessage()
	return not GetWatchedFactionInfo(), "No watched reputation.";
end

function module:GetChatMessage()
	local name, standing, min_rep, max_rep, rep_value, factionID = GetWatchedFactionInfo();
	
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
	
	return string.format("%s with %s: %s/%s (%d%%) with %s to go",
		standing_text,
		name,
		BreakUpLargeNumbers(rep_value - min_rep),
		BreakUpLargeNumbers(max_rep - min_rep),
		progress * 100,
		BreakUpLargeNumbers(remaining_rep)
	);
end

function module:GetBarData()
	local data    = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	
	data.min  	  = minReputation;
	data.max  	  = maxReputation;
	data.current  = currentReputation;
	data.rested   = nil;
	data.visual   = nil;
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Reputation Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show gained reputation",
			func = function() self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep; module:MarkDirty(); end,
			checked = function() return self.db.global.ShowGainedRep; end,
			isNotRadio = true,
		},
		{
			text = "Auto watch most recent reputation",
			func = function() self.db.global.AutoWatch.Visible = not self.db.global.AutoWatch.Visible; end,
			checked = function() return self.db.global.AutoWatch.Visible; end,
			hasArrow = true,
			isNotRadio = true,
			menuList = {
				{
					text = "Ignore guild reputation",
					func = function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; end,
					checked = function() return self.db.global.AutoWatch.IgnoreGuild; end,
					isNotRadio = true,
				},
				{
					text = "Ignore bodyguard reputations",
					func = function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; end,
					checked = function() return self.db.global.AutoWatch.IgnoreBodyguard; end,
					isNotRadio = true,
				},
				{
					text = "Ignore inactive reputations",
					func = function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; end,
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
			menuList = module:GetReputationsMenu(),
		},
	};
	
	return menudata;
end

------------------------------------------



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

function module:GetRecentReputationsMenu()
	local factions = {
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Recent Reputations", isTitle = true, notCheckable = true,
		},
	};
		
	local recentReps = 0;
	
	for name, data in pairs(module.recentReputations) do
		local faction_index = module:GetReputationID(name);
		local _, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(faction_index);
		local friend_level = select(7, GetFriendshipReputation(factionID));
		local standing_text = "";
		
		if(not isHeader or hasRep) then
			if(friend_level) then
				standing_text = friend_level;
			else
				standing_text = module:GetStandingColorText(standing)
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

function module:GetReputationsMenu()
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
				standing_text = module:GetStandingColorText(standing)
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
	
	local recent = module:GetRecentReputationsMenu();
	if(recent ~= false) then
		for _, data in ipairs(recent) do tinsert(factions, data) end
	end
	
	return factions;
end

------------------------------------------

function module:HasWatchedReputation()
	return GetWatchedFactionInfo() ~= nil;
end

function module:GetStandingColorText(standing)
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

function module:UPDATE_FACTION(event, ...)
	local set_value = false;
	
	local name = GetWatchedFactionInfo();
	if(name and Addon:IsBarEnabled() and not Addon.IsVisible) then
		Addon:ShowBar();
	end
	
	if(name ~= Addon.CurrentRep) then
		set_value = true;
	end
	
	module:MarkDirty(set_value);
	Addon.GainUpdateTimer = 0;
end

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match("Reputation with (.-) increased by (%d*)%.");
	if(not reputation or not module.recentReputations) then return end
	
	if(module.recentReputations[reputation] == nil) then
		module.recentReputations[reputation] = {
			amount = 0,
		};
	end
	
	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled) then
		if(Addon.CurrentRep ~= reputation) then
			Addon:UpdateAutoWatch(reputation);
		end
	end
end

function module:UpdateAutoWatch(reputation)
	if(self.db.global.AutoWatch.IgnoreGuild and reputation == GUILD) then return end
		
	local factionListIndex, factionID = Addon:GetReputationID(reputation);
	if(not factionListIndex) then return end
	
	if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
	if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
	
	SetWatchedFactionIndex(factionListIndex);
end
