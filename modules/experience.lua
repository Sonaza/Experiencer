------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:RegisterModule("experience", {
	label       = "Experience",
	order       = 1,
	savedvars   = {
		char = {
			session = {
				Exists = false,
				Time = 0,
				TotalXP = 0,
				AverageQuestXP = 0,
			},
		},
		global = {
			ShowRemaining = true,
			ShowGainedXP = true,
			ShowHourlyXP = true,
			ShowTimeToLevel = true,
			ShowQuestsToLevel = true,
			KeepSessionData = true,
			
			QuestXP = {
				ShowText = true,
				AddIncomplete = false,
				ShowVisualizer = true,
			},
		},
	},
});

module.session = {
	LoginTime       = time(),
	GainedXP        = 0,
	LastXP          = UnitXP("player"),
	MaxXP           = UnitXPMax("player"),
	
	QuestsToLevel   = -1,
	AverageQuestXP  = 0,
	
	Paused          = false,
	PausedTime      = 0,
};

-- Required data for experience module
local HEIRLOOM_ITEMXP = {
	["INVTYPE_HEAD"] 		= 0.1,
	["INVTYPE_SHOULDER"] 	= 0.1,
	["INVTYPE_CHEST"] 		= 0.1,
	["INVTYPE_ROBE"] 		= 0.1,
	["INVTYPE_LEGS"] 		= 0.1,
	["INVTYPE_FINGER"] 		= 0.05,
	["INVTYPE_CLOAK"] 		= 0.05,
	
	-- Rings with battleground xp bonus instead
	[126948] 	= 0.0,
	[126949]	= 0.0,
};

local HEIRLOOM_SLOTS = {
	1, 3, 5, 7, 11, 12, 15,
};

local BUFF_MULTIPLIERS = {
	[46668]		= { multiplier = 0.1, }, -- Darkmoon Carousel Buff
	[178119] 	= { multiplier = 0.2, }, -- Excess Potion of Accelerated Learning
	[127250]	= { multiplier = 3.0, maxlevel = 84, }, -- Elixir of Ancient Knowledge
	[189375]	= { multiplier = 3.0, maxlevel = 99, }, -- Elixir of the Rapid Mind
};

local GROUP_TYPE = {
	SOLO 	= 0x1,
	PARTY 	= 0x2,
	RAID	= 0x3,
};

local QUEST_COMPLETED_PATTERN = "^" .. string.gsub(ERR_QUEST_COMPLETE_S, "%%s", "(.-)") .. "$";
local QUEST_EXPERIENCE_PATTERN = "^" .. string.gsub(ERR_QUEST_REWARD_EXP_I, "%%d", "(%%d+)") .. "$";

function module:Initialize()
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("PLAYER_XP_UPDATE");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("UPDATE_EXPANSION_LEVEL");
	
	module.playerCanLevel = not module:IsPlayerMaxLevel();
	
	module:RestoreSession();
end

function module:IsDisabled()
	return module:IsPlayerMaxLevel() or IsXPUserDisabled();
end

function module:AllowedToBufferUpdate()
	return true;
end

function module:Update(elapsed)
	local lastPaused = module.session.Paused;
	module.session.Paused = UnitIsAFK("player");
	
	if(module.session.Paused and lastPaused ~= module.session.Paused) then
		module:Refresh();
	elseif(not module.session.Paused and lastPaused ~= module.session.Paused) then
		module.session.LoginTime = module.session.LoginTime + math.floor(module.session.PausedTime);
		module.session.PausedTime = 0;
	end
	
	if(module.session.Paused) then
		module.session.PausedTime = module.session.PausedTime + elapsed;
	end
	
	if(module.db.global.KeepSessionData) then
		module.db.char.session.Exists = true;
		
		module.db.char.session.Time = time() - (module.session.LoginTime + math.floor(module.session.PausedTime));
		module.db.char.session.TotalXP = module.session.GainedXP;
		module.db.char.session.AverageQuestXP = module.session.AverageQuestXP;
	end
end

function module:GetText()
	local primaryText = {};
	local secondaryText = {};
	
	local current_xp, max_xp    = UnitXP("player"), UnitXPMax("player");
	local rested_xp             = GetXPExhaustion() or 0;
	local remaining_xp          = max_xp - current_xp;
	
	local progress              = current_xp / (max_xp > 0 and max_xp or 1);
	local progressColor         = Addon:GetProgressColor(progress);
	
	if(self.db.global.ShowRemaining) then
		tinsert(primaryText,
			string.format("%s%s|r (%s%.1f|r%%)", progressColor, BreakUpLargeNumbers(remaining_xp), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			string.format("%s%s|r / %s (%s%.1f|r%%)", progressColor, BreakUpLargeNumbers(current_xp), BreakUpLargeNumbers(max_xp), progressColor, progress * 100)
		);
	end
	
	if(rested_xp > 0) then
		tinsert(primaryText,
			string.format("%d%% |cff6fafdfrested|r", math.ceil(rested_xp / max_xp * 100))
		);
	end
	
	if(module.session.GainedXP > 0) then
		local hourlyXP, timeToLevel = module:CalculateHourlyXP();
		
		if(self.db.global.ShowGainedXP) then
			tinsert(secondaryText,
				string.format("+%s |cffffcc00xp|r", BreakUpLargeNumbers(module.session.GainedXP))
			);
		end
		
		if(self.db.global.ShowHourlyXP) then
			tinsert(primaryText,
				string.format("%s |cffffcc00xp/h|r", BreakUpLargeNumbers(hourlyXP))
			);
		end
		
		if(self.db.global.ShowTimeToLevel) then
			tinsert(primaryText,
				string.format("%s |cff80e916until level|r", Addon:FormatTime(timeToLevel))
			);
		end
	end
	
	if(self.db.global.ShowQuestsToLevel) then
		if(module.session.QuestsToLevel > 0 and module.session.QuestsToLevel ~= math.huge) then
			tinsert(secondaryText,
				string.format("~%s |cff80e916quests|r", module.session.QuestsToLevel)
			);
		end
	end
	
	if(self.db.global.QuestXP.ShowText) then
		local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();
		
		local levelUpAlert = "";
		if(current_xp + completeXP >= max_xp) then
			levelUpAlert = " (|cfff1e229enough to level|r)";
		end
		
		if(not self.db.global.QuestXP.AddIncomplete) then
			tinsert(secondaryText,
				string.format("%s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(completeXP)), levelUpAlert)
			);
		elseif(self.db.global.QuestXP.AddIncomplete) then
			tinsert(secondaryText,
				string.format("%s |cffffdd00+|r %s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(completeXP)), BreakUpLargeNumbers(math.floor(incompleteXP)), levelUpAlert)
			);
		end
	end
	
	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return not module:IsPlayerMaxLevel() and not IsXPUserDisabled(), "Max level reached.";
end

function module:GetChatMessage()
	local current_xp, max_xp = UnitXP("player"), UnitXPMax("player");
	local remaining_xp = max_xp - current_xp;
	local rested_xp = GetXPExhaustion() or 0;

	local rested_xp_percent = floor(((rested_xp / max_xp) * 100) + 0.5);
	
	local max_xp_text = Addon:FormatNumber(max_xp);
	local current_xp_text = Addon:FormatNumber(current_xp);
	local remaining_xp_text = Addon:FormatNumber(remaining_xp);

	return string.format("Currently level %d at %s/%s (%d%%) with %s xp to go (%d%% rested)", 
		UnitLevel("player"),
		current_xp_text,
		max_xp_text, 
		math.ceil((current_xp / max_xp) * 100), 
		remaining_xp_text, 
		rested_xp_percent
	);
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = UnitLevel("player");
	data.min  	  = 0;
	data.max  	  = UnitXPMax("player");
	data.current  = UnitXP("player");
	data.rested   = (GetXPExhaustion() or 0);
	
	if(self.db.global.QuestXP.ShowVisualizer) then
		local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();
		
		data.visual = completeXP;
		
		if(self.db.global.QuestXP.AddIncomplete) then
			data.visual = { completeXP, totalXP };
		end
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Experience Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining XP",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max XP",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show gained XP",
			func = function() self.db.global.ShowGainedXP = not self.db.global.ShowGainedXP; module:RefreshText(); end,
			checked = function() return self.db.global.ShowGainedXP; end,
			isNotRadio = true,
		},
		{
			text = "Show XP per hour",
			func = function() self.db.global.ShowHourlyXP = not self.db.global.ShowHourlyXP; module:RefreshText(); end,
			checked = function() return self.db.global.ShowHourlyXP; end,
			isNotRadio = true,
		},
		{
			text = "Show time to level",
			func = function() self.db.global.ShowTimeToLevel = not self.db.global.ShowTimeToLevel; module:RefreshText(); end,
			checked = function() return self.db.global.ShowTimeToLevel; end,
			isNotRadio = true,
		},
		{
			text = "Show quests to level",
			func = function() self.db.global.ShowQuestsToLevel = not self.db.global.ShowQuestsToLevel; module:RefreshText(); end,
			checked = function() return self.db.global.ShowQuestsToLevel; end,
			isNotRadio = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Remember session data",
			func = function() self.db.global.KeepSessionData = not self.db.global.KeepSessionData; end,
			checked = function() return self.db.global.KeepSessionData; end,
			isNotRadio = true,
		},
		{
			text = "Reset session",
			func = function()
				module:ResetSession();
			end,
			notCheckable = true,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Quest XP Visualizer",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show completed quest XP",
			func = function() self.db.global.QuestXP.ShowText = not self.db.global.QuestXP.ShowText; module:Refresh(); end,
			checked = function() return self.db.global.QuestXP.ShowText; end,
			isNotRadio = true,
		},
		{
			text = "Also show XP from incomplete quests",
			func = function() self.db.global.QuestXP.AddIncomplete = not self.db.global.QuestXP.AddIncomplete; module:Refresh(); end,
			checked = function() return self.db.global.QuestXP.AddIncomplete; end,
			isNotRadio = true,
		},
		{
			text = "Display visualizer bar",
			func = function() self.db.global.QuestXP.ShowVisualizer = not self.db.global.QuestXP.ShowVisualizer; module:Refresh(); end,
			checked = function() return self.db.global.QuestXP.ShowVisualizer; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:RestoreSession()
	if(not self.db.char.session.Exists) then return end
	if(not self.db.global.KeepSessionData) then return end
	if(module:IsPlayerMaxLevel()) then return end
	
	local data = self.db.char.session;
	
	module.session.LoginTime        = module.session.LoginTime - data.Time;
	module.session.GainedXP         = data.TotalXP;
	module.session.AverageQuestXP   = module.session.AverageQuestXP;
	
	if(module.session.AverageQuestXP > 0) then
		local remaining_xp = UnitXPMax("player") - UnitXP("player");
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP);
	end
end

function module:ResetSession()
	module.session = {
		LoginTime        = time(),
		GainedXP         = 0,
		LastXP           = UnitXP("player"),
		MaxXP            = UnitXPMax("player"),
		
		AverageQuestXP   = 0,
		QuestsToLevel    = -1,
		
		Paused           = false,
		PausedTime       = 0,
	};
	
	self.db.char.session = {
		Exists           = false,
		Time             = 0,
		TotalXP          = 0,
		AverageQuestXP   = 0,
	};
	
	module:RefreshText();
end

function module:IsPlayerMaxLevel(level)
	return MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] == (level or UnitLevel("player"));
end

function module:CalculateHourlyXP()
	local hourlyXP, timeToLevel = 0, 0;
	
	local logged_time = time() - (module.session.LoginTime + math.floor(module.session.PausedTime));
	local coeff = logged_time / 3600;
	
	if(coeff > 0 and module.session.GainedXP > 0) then
		hourlyXP = math.ceil(module.session.GainedXP / coeff);
		timeToLevel = (UnitXPMax("player") - UnitXP("player")) / hourlyXP * 3600;
	end
	
	return hourlyXP, timeToLevel;
end

function module:GetGroupType()
	if(IsInRaid()) then
		return GROUP_TYPE.RAID;
	elseif(IsInGroup()) then
		return GROUP_TYPE.PARTY;
	end
	
	return GROUP_TYPE.SOLO;
end

local partyUnitID = { "player", "party1", "party2", "party3", "party4" };
function module:GetUnitID(group_type, index)
	if(group_type == GROUP_TYPE.SOLO or group_type == GROUP_TYPE.PARTY) then
		return partyUnitID[index];
	elseif(group_type == GROUP_TYPE.RAID) then
		return string.format("raid%d", index);
	end
	
	return nil;
end

local function GroupIterator()
	local index = 0;
	local groupType = module:GetGroupType();
	local numGroupMembers = GetNumGroupMembers();
	if(groupType == GROUP_TYPE.SOLO) then numGroupMembers = 1 end
	
	return function()
		index = index + 1;
		if(index <= numGroupMembers) then
			return index, module:GetUnitID(groupType, index);
		end
	end
end

function module:HasRecruitingBonus()
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

function module:CalculateXPMultiplier()
	local multiplier = 1.0;
	
	if(module:HasRecruitingBonus()) then
		multiplier = multiplier * 3.0;
	end
	
	for _, slotID in ipairs(HEIRLOOM_SLOTS) do
		local link = GetInventoryItemLink("player", slotID);
		
		if(link) then
			local _, _, itemRarity, _, _, _, _, _, itemEquipLoc = GetItemInfo(link);
			
			if(itemRarity == 7) then
				local itemID = tonumber(strmatch(link, "item:(%d*)")) or 0;
				local itemMultiplier = HEIRLOOM_ITEMXP[itemID] or HEIRLOOM_ITEMXP[itemEquipLoc];
				
				multiplier = multiplier + itemMultiplier;
			end
		end
	end
	
	local playerLevel = UnitLevel("player");
	
	for buffSpellID, buffMultiplier in pairs(BUFF_MULTIPLIERS) do
		if(Addon:PlayerHasBuff(buffSpellID)) then
			if(not buffMultiplier.maxlevel or (buffMultiplier.maxlevel and playerLevel <= buffMultiplier.maxlevel)) then
				multiplier = multiplier + buffMultiplier.multiplier;
			end
		end 
	end
	
	return multiplier;
end

function module:CalculateQuestLogXP()
	local completeXP, incompleteXP = 0, 0;
	if (GetNumQuestLogEntries() == 0) then return 0, 0, 0; end
	
	local index = 0;
	local lastSelected = GetQuestLogSelection();
	
	repeat
		index = index + 1;
		local questTitle, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index);
		
		if(not isHeader) then
			SelectQuestLogEntry(index);
			
			local requiredMoney = GetQuestLogRequiredMoney(index);
			local numObjectives = GetNumQuestLeaderBoards(index);
			
			if(isComplete and isComplete < 0) then
				isComplete = false;
			elseif(numObjectives == 0 and GetMoney() >= requiredMoney) then
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
	
	local multiplier = module:CalculateXPMultiplier();
	
	return completeXP * multiplier, incompleteXP * multiplier, (completeXP + incompleteXP) * multiplier;
end

function module:UPDATE_EXPANSION_LEVEL()
	if(not playerCanLevel and not module:IsPlayerMaxLevel()) then
		DEFAULT_CHAT_FRAME:AddMessage(("|cfffaad07Experiencer|r %s"):format("Expansion level upgraded, you are able to gain experience again."));
	end
	module.playerCanLevel = not module:IsPlayerMaxLevel();
end

function module:QUEST_LOG_UPDATE()
	module:Refresh(true);
end

function module:UNIT_INVENTORY_CHANGED(event, unit)
	if(unit ~= "player") then return end
	module:Refresh();
end

function module:CHAT_MSG_SYSTEM(event, msg)
	if(msg:match(QUEST_COMPLETED_PATTERN) ~= nil) then
		Addon.QuestCompleted = true;
		return;
	end
	
	if(not Addon.QuestCompleted) then return end
	Addon.QuestCompleted = false;
	
	local xp_amount = msg:match(QUEST_EXPERIENCE_PATTERN);
	
	if(xp_amount ~= nil) then
		xp_amount = tonumber(xp_amount);
		
		local weigth = 0.5;
		if(module.session.AverageQuestXP > 0) then
			weigth = math.min(xp_amount / module.session.AverageQuestXP, 0.9);
			module.session.AverageQuestXP = module.session.AverageQuestXP * (1.0 - weigth) + xp_amount * weigth;
		else
			module.session.AverageQuestXP = xp_amount;
		end
		
		if(module.session.AverageQuestXP ~= 0) then
			local remaining_xp = UnitXPMax("player") - UnitXP("player");
			module.session.QuestsToLevel = math.floor(remaining_xp / module.session.AverageQuestXP);
			
			if(module.session.QuestsToLevel > 0 and xp_amount > 0) then
				local quests_text = string.format("%d more quests to level", module.session.QuestsToLevel);
				
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. quests_text .. ".|r");
				
				if(Parrot) then
					Parrot:ShowMessage(quests_text, "Errors", false, 1.0, 1.0, 0.1);
				end
			end
		end
	end
end

function module:PLAYER_XP_UPDATE(event)
	local current_xp = UnitXP("player");
	local max_xp = UnitXPMax("player");
	
	local gained = current_xp - module.session.LastXP;
	
	if(gained < 0) then
		gained = module.session.MaxXP - module.session.LastXP + current_xp;
	end
	
	module.session.GainedXP = module.session.GainedXP + gained;
	
	module.session.LastXP = current_xp;
	module.session.MaxXP = max_xp;
	
	if(module.session.AverageQuestXP > 0) then
		local remaining_xp = max_xp - current_xp;
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP);
	end
	
	module:Refresh();
end

function module:UPDATE_EXHAUSTION()
	module:Refresh();
end

function module:PLAYER_LEVEL_UP(event, level)
	if(module:IsPlayerMaxLevel(level)) then
		Addon:CheckDisabledStatus();
	else
		module.session.MaxXP = UnitXPMax("player");
		
		local remaining_xp = module.session.MaxXP - UnitXP("player");
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP) - 1;
	end
	
	module.playerCanLevel = not module:IsPlayerMaxLevel(level);
end
