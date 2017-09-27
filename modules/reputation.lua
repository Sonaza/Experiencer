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

module.tooltipText = "You can quickly scroll through recently gained reputations by scrolling the mouse wheel while holding down shift key."

module.recentReputations = {};
module.hasCustomMouseCallback = true;

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
	
	if(name) then
		module.recentReputations[name] = {
			amount = 0;
		};
	end
end

function module:IsDisabled()
	return false;
end

function module:Update(elapsed)
	
end

function module:GetSortedRecentList()
	local sortedList = {};
	for name, data in pairs(module.recentReputations) do
		tinsert(sortedList, {name = name, data = data});
	end
	table.sort(sortedList, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return a.name < b.name;
	end);
	for index, data in ipairs(sortedList) do
		module.recentReputations[data.name].sortedIndex = index;
	end
	return sortedList;
end

function module:OnMouseWheel(delta)
	if(IsShiftKeyDown()) then
		local recentRepsList = module:GetSortedRecentList();
		if(not recentRepsList or #recentRepsList == 0) then return end
		
		local currentIndex = nil;
		local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
		if(name) then
			currentIndex = module.recentReputations[name].sortedIndex;
		else
			currentIndex = 1;
		end
		
		currentIndex = currentIndex - delta;
		if(currentIndex > #recentRepsList) then currentIndex = 1 end
		if(currentIndex < 1) then currentIndex = #recentRepsList end
		
		if(recentRepsList[currentIndex]) then
			local factionIndex = module:GetReputationID(recentRepsList[currentIndex].name);
			SetWatchedFactionIndex(factionIndex);
		end
	end
end

function module:CanLevelUp()
	local _, _, _, _, _, factionID = GetWatchedFactionInfo();
	if(factionID and C_Reputation.IsFactionParagon(factionID)) then
		local _, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		return hasRewardPending;
	end
	return false;
end

function module:GetText()
	if(not module:HasWatchedReputation()) then
		return "No active watched reputation";
	end
	
	local primaryText = {};
	local secondaryText = {};
	
	local rep_text = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local friendLevel, friendThreshold, nextFriendThreshold = select(7, GetFriendshipReputation(factionID));
	
	local standingText = "";
	local isCapped = false;
	local hasRewardPending = false;
	local paragonLevel = 0;
	
	if(friendLevel) then
		standingText = friendLevel;
		if(not nextFriendThreshold) then
			isCapped = true;
		end
	else
		standingText = module:GetStandingColorText(standing);
		if(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
	end
	
	if(isCapped and C_Reputation.IsFactionParagon(factionID)) then
		currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;
		minReputation = 0;
		
		paragonLevel = math.floor(currentReputation / maxReputation);
		currentReputation = currentReputation % maxReputation;
		
		if(paragonLevel == 1) then
			standingText = module:GetStandingColorText(standing+1);
		elseif(paragonLevel > 1) then
			standingText = string.format("%dx %s", paragonLevel, module:GetStandingColorText(standing+1));
		end
	end
	
	if(not isCapped) then
		local remainingReputation = maxReputation - currentReputation;
		local realCurrentReputation = currentReputation - minReputation;
		local realMaxReputation = maxReputation - minReputation;
		
		local progress = realCurrentReputation / realMaxReputation;
		local color = Addon:GetProgressColor(progress);
		
		if(self.db.global.ShowRemaining) then
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100)
			);
		else
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r / %s (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(realCurrentReputation), BreakUpLargeNumbers(realMaxReputation), color, progress * 100)
			);
		end
	else
		tinsert(primaryText,
			string.format("%s (%s)", name, standingText)
		);
	end
	
	if(hasRewardPending) then
		tinsert(secondaryText, "|cff00ff00Paragon reward earned!|r");
	end
	
	if(self.db.global.ShowGainedRep and module.recentReputations[name]) then
		if(module.recentReputations[name].amount > 0) then
			tinsert(secondaryText, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
		end
	end
	
	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return GetWatchedFactionInfo() ~= nil, "No watched reputation.";
end

function module:GetChatMessage()
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local friendLevel, friendThreshold, nextFriendThreshold = select(7, GetFriendshipReputation(factionID));
	
	local standingText = "";
	local isCapped = false;
	local hasRewardPending = false;
	local paragonLevel = 0;
	
	if(friendLevel) then
		standingText = friendLevel;
		if(not nextFriendThreshold) then
			isCapped = true;
		end
	else
		standingText = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
		if(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
	end
	
	if(isCapped and C_Reputation.IsFactionParagon(factionID)) then
		currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;
		minReputation = 0;
		
		paragonLevel = math.floor(currentReputation / maxReputation);
		currentReputation = currentReputation % maxReputation;
	end
	
	if(not isCapped) then
		local remaining_rep = maxReputation - currentReputation;
		local progress = (currentReputation - minReputation) / (maxReputation - minReputation);
		
		local paragonText = "";
		if(paragonLevel > 0) then
			paragonText = string.format(" (%dx paragon)", paragonLevel);
		end
		
		return string.format("%s%s with %s: %s/%s (%d%%) with %s to go",
			standingText,
			paragonText,
			name,
			BreakUpLargeNumbers(currentReputation - minReputation),
			BreakUpLargeNumbers(maxReputation - minReputation),
			progress * 100,
			BreakUpLargeNumbers(remaining_rep)
		);
	else
		return string.format("%s with %s",
			standingText,
			name
		);
	end
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	if(module:HasWatchedReputation()) then
		local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
		data.id = factionID;
		
		local friendLevel, friendThreshold, nextFriendThreshold = select(7, GetFriendshipReputation(factionID));
		
		local standingText = "";
		local isCapped = false;
		local hasRewardPending = false;
		local paragonLevel = 0;
		
		if(friendLevel and not nextFriendThreshold) then
			isCapped = true;
		elseif(standing == MAX_REPUTATION_REACTION) then
			isCapped = true;
		end
		
		if(isCapped and C_Reputation.IsFactionParagon(factionID)) then
			currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
			isCapped = false;
			minReputation = 0;
			
			paragonLevel = math.floor(currentReputation / maxReputation);
			currentReputation = currentReputation % maxReputation;
		end
		
		data.level    = standing;
		
		if(not isCapped) then
			data.min  	 = minReputation;
			data.max  	 = maxReputation;
			data.current = currentReputation;
		else
			data.min     = 0;
			data.max     = 1;
			data.current = 1;
		end
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
	
	local recentRepsList = module:GetSortedRecentList();
	for _, rep in ipairs(recentRepsList) do
		local name = rep.name;
		local data = rep.data;
		
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
	end
	
	if(#recentRepsList == 0) then
		return false;
	end
	
	return factions;
end

function module:GetReputationProgressByFactionID(factionID)
	if(not factionID) then return nil end
	
	local name, _, standing, minReputation, maxReputation, currentReputation = GetFactionInfoByID(factionID);
	if(not name or not minReputation or not maxReputation) then return nil end
	
	local isCapped = false;
	local isParagon = false;
	
	local friendLevel, friendThreshold, nextFriendThreshold = select(7, GetFriendshipReputation(factionID));
	if(friendLevel) then
		if(not nextFriendThreshold) then
			isCapped = true;
		end
	else
		if(standing == MAX_REPUTATION_REACTION) then
			if(C_Reputation.IsFactionParagon(factionID)) then
				currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
				minReputation = 0;
				
				if(currentReputation >= maxReputation) then
					isParagon = true;
				end
				
				currentReputation = currentReputation % maxReputation;
			else
				isCapped = true;
			end
		end
	end
	
	return currentReputation - minReputation, maxReputation - minReputation, isCapped, isParagon;
end

function module:GetReputationsMenu()
	local factions = {};
	
	local previous, current = nil, nil;
	local depth = 0;
	
	local factionIndex = 1;
	while factionIndex <= GetNumFactions() do
		local name, _, standing, _, _, _, _, _, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID = GetFactionInfo(factionIndex);
		if(name) then
			local progressText = "";
			if(factionID) then
				local currentRep, nextThreshold, isCapped, isParagon = module:GetReputationProgressByFactionID(factionID);
				if(isParagon) then
					standing = standing + 1;
				end
				
				if(currentRep and not isCapped) then
					progressText = string.format("  (|cfffff2ab%s|r / %s)", BreakUpLargeNumbers(currentRep), BreakUpLargeNumbers(nextThreshold));
				end
			end
				
			local friendLevel = select(7, GetFriendshipReputation(factionID));
			local standingText = "";
			
			if(not isHeader or hasRep) then
				if(friendLevel) then
					standingText = friendLevel;
				else
					standingText = module:GetStandingColorText(standing);
				end
			end
			
			if(isHeader and isCollapsed) then
				ExpandFactionHeader(factionIndex);
			end
			
			if(isHeader and isChild and current) then -- Second tier header
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
						text = string.format("%s (%s)%s", name, standingText, progressText),
						hasArrow = true,
						func = function() SetWatchedFactionIndex(factionIndex); CloseMenus(); end,
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
					text = string.format("%s (%s)%s", name, standingText, progressText),
					func = function() SetWatchedFactionIndex(factionIndex); CloseMenus(); end,
					checked = function() return isWatched end,
				})
			end
		end
		
		factionIndex = factionIndex + 1;
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
		[9] = {r=0.00, g=1.00, b=1.00}, -- paragon
	}
	
	local label;
	if(standing < 9) then
		label = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
	else
		label = "Paragon";
	end
	
	return string.format('|cff%02x%02x%02x%s|r',
		colors[standing].r * 255,
		colors[standing].g * 255,
		colors[standing].b * 255,
		label
	);
end

function module:UPDATE_FACTION(event, ...)
	local name, _, _, _, _, factionID = GetWatchedFactionInfo();
	module.levelUpRequiresAction = (factionID and C_Reputation.IsFactionParagon(factionID));
	
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
	
	local isGuild = false;
	if(reputation == GUILD) then
		isGuild = true;
		
		local guildName = GetGuildInfo("player");
		if(guildName) then
			reputation = guildName;
		end
	end
	
	if(not module.recentReputations[reputation]) then
		module.recentReputations[reputation] = {
			amount = 0,
		};
	end
	
	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled) then
		local name = GetWatchedFactionInfo();
		if(name ~= reputation) then
			module:UpdateAutoWatch(reputation, isGuild);
		end
	end
end

function module:UpdateAutoWatch(reputation, isGuild)
	if(self.db.global.AutoWatch.IgnoreGuild and isGuild) then return end
		
	local factionListIndex, factionID = module:GetReputationID(reputation);
	if(not factionListIndex) then return end
	
	if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
	if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
	
	SetWatchedFactionIndex(factionListIndex);
end
