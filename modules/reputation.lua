------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:RegisterModule("reputation", {
	label 	    = "Reputation",
	order       = 2,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowGainedRep = true,
			
			AutoWatch = {
				Enabled = false,
				IgnoreGuild = true,
				IgnoreInactive = true,
				IgnoreBodyguard = true,
			},
		},
	},
});

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
	
	local name = GetWatchedFactionInfo();
	module.Tracked = name;
end

function module:IsDisabled()
	return false;
end

function module:Update(elapsed)
	
end

function module:GetText()
	if(not module:HasWatchedReputation()) then
		return "No active watched reputation";
	end
	
	local outputText = {};
	
	local rep_text = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local remainingReputation = maxReputation - currentReputation;
	
	local realCurrentReputation = currentReputation - minReputation;
	local realMaxReputation = maxReputation - minReputation;
	
	local progress = realCurrentReputation / realMaxReputation;
	local color = Addon:GetProgressColor(progress);
	
	local standingText = "";
	local friendLevel = select(7, GetFriendshipReputation(factionID));
	
	if(not friendLevel) then
		standingText = module:GetStandingColorText(standing);
	else
		standingText = friendLevel;
	end
	
	if(self.db.global.ShowRemaining) then
		tinsert(outputText,
			string.format("%s (%s): %s%s|r (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100)
		);
	else
		tinsert(outputText,
			string.format("%s (%s): %s%s|r / %s (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(realCurrentReputation), BreakUpLargeNumbers(realMaxReputation), color, progress * 100)
		);
	end
	
	if(self.db.global.ShowGainedRep and module.recentReputations[name]) then
		tinsert(outputText, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
	end
	
	ExperiencerBarText:SetText(table.concat(rep_text, "  "));
	
	return table.concat(outputText, "  ");
end

function module:HasChatMessage()
	return GetWatchedFactionInfo() ~= nil, "No watched reputation.";
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
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	if(module:HasWatchedReputation()) then
		local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
		
		data.level    = standing;
		data.min  	  = minReputation;
		data.max  	  = maxReputation;
		data.current  = currentReputation;
	end
	
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
			text = "Show remaining reputation",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max reputation",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show gained reputation",
			func = function() self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep; module:Refresh(); end,
			checked = function() return self.db.global.ShowGainedRep; end,
			isNotRadio = true,
		},
		{
			text = "Auto watch most recent reputation",
			func = function() self.db.global.AutoWatch.Enabled = not self.db.global.AutoWatch.Enabled; end,
			checked = function() return self.db.global.AutoWatch.Enabled; end,
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
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Set Watched Faction",
			isTitle = true,
			notCheckable = true,
		},
	};
	
	local reputationsMenu = module:GetReputationsMenu();
	for _, data in ipairs(reputationsMenu) do
		tinsert(menudata, data);
	end
	
	tinsert(menudata, { text = "", isTitle = true, notCheckable = true, });
	tinsert(menudata, {
		text = "Open reputations panel",
		func = function() ToggleCharacter("ReputationFrame"); end,
		notCheckable = true,
	});
	
	return menudata;
end

------------------------------------------

function module:GetReputationID(faction_name)
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
	local factions = {};
	
	local previous, current = nil, nil;
	local depth = 0;
	
	local numFactions = GetNumFactions();
	for index = 1, numFactions do
		local name, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(index);
		if(name) then
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
		end
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
		[6] = {r=0.00, g=1.00, b=0.00}, -- honored
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
	}
	
	return string.format('|cff%02x%02x%02x%s|r', colors[standing].r * 255, colors[standing].g * 255, colors[standing].b * 255, _G['FACTION_STANDING_LABEL' .. standing]);
end

function module:UPDATE_FACTION(event, ...)
	local name = GetWatchedFactionInfo();
	
	local instant = false;
	if(name ~= module.Tracked or not name) then
		instant = true;
	end
	module.Tracked = name;
	
	module:Refresh(instant);
end

local reputationPattern = FACTION_STANDING_INCREASED:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match(reputationPattern);
	amount = tonumber(amount) or 0;
	
	if(not reputation or not module.recentReputations) then return end
	
	if(not module.recentReputations[reputation]) then
		module.recentReputations[reputation] = {
			amount = 0,
		};
	end
	
	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled) then
		local name = GetWatchedFactionInfo();
		if(name ~= reputation) then
			module:UpdateAutoWatch(reputation);
		end
	end
end

function module:UpdateAutoWatch(reputation)
	if(self.db.global.AutoWatch.IgnoreGuild and reputation == GUILD) then return end
		
	local factionListIndex, factionID = module:GetReputationID(reputation);
	if(not factionListIndex) then return end
	
	if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
	if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
	
	SetWatchedFactionIndex(factionListIndex);
end
