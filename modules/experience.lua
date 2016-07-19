------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

-- EXPERIENCER_MODULE_EXPERIENCE = Addon:GetUniqueModuleID();

local module = {};
Addon:RegisterModule("experience", module, EXPERIENCER_MODULE_EXPERIENCE);

module.savedvars = {
	char = {
		session = {
			Exists = false,
			Time = 0,
			TotalXP = 0,
			AverageQuestXP = 0,
		},
	},
	global = {
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
};

module.session = {
	LoginTime 			= time(),
	ExperienceGained 	= 0,
	LastXP 				= UnitXP("player"),
	MaxXP 				= UnitXPMax("player"),
	
	QuestsToLevel 		= -1,
	AverageQuestXP 		= 0,
	
	Paused 		= false,
	PausedTime 	= 0,
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
	if(not self:IsPlayerMaxLevel()) then
		self:RegisterEvent("CHAT_MSG_SYSTEM");
	
		self:RegisterEvent("PLAYER_XP_UPDATE");
		self:RegisterEvent("PLAYER_LEVEL_UP");
		
		self:RegisterEvent("UNIT_INVENTORY_CHANGED");
		self:RegisterEvent("QUEST_LOG_UPDATE");
	else
		-- self.db.profile.Mode = EXPERIENCER_MODE_REP;
	end
end

function module:IsDisabled()
	return false;
end

function module:Update()
	
end

function module:GetText()
	local outputText = {};
	
	local current_xp, max_xp    = UnitXP("player"), UnitXPMax("player");
	local rested_xp             = GetXPExhaustion() or 0;
	local remaining_xp          = max_xp - current_xp;
	
	local progress              = current_xp / (max_xp > 0 and max_xp or 1);
	local progressColor         = Addon:GetProgressColor(progress);
	
	tinsert(outputText,
		string.format("%s%s|r (%s%d|r%%)", progressColor, BreakUpLargeNumbers(remaining_xp), progressColor, 100 - progress * 100)
	);
	
	if(rested_xp > 0) then
		tinsert(outputText,
			string.format("%d%% |cff6fafdfrested|r", math.ceil(rested_xp / max_xp * 100))
		);
	end
	
	if(module.session.ExperienceGained > 0) then
		local hourlyXP, timeToLevel = Addon:CalculateHourlyXP();
		
		if(self.db.global.ShowGainedXP) then
			tinsert(outputText,
				string.format("+%s |cffffcc00xp|r", BreakUpLargeNumbers(module.session.ExperienceGained))
			);
		end
		
		if(self.db.global.ShowHourlyXP) then
			tinsert(outputText,
				string.format("%s |cffffcc00xp/h|r", BreakUpLargeNumbers(hourlyXP))
			);
		end
		
		if(self.db.global.ShowTimeToLevel) then
			tinsert(outputText,
				string.format("%s |cff80e916until level|r", Addon:FormatTime(timeToLevel))
			);
		end
	end
	
	if(module.session.QuestsToLevel > 0) then
		if(self.db.global.ShowQuestsToLevel and module.session.QuestsToLevel > 0) then
			tinsert(outputText,
				string.format("~%s |cff80e916quests|r", module.session.QuestsToLevel)
			);
		end
	end
	
	if(self.db.global.QuestXP.ShowText) then
		local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();
		
		local questXP = completeXP;
		if(self.db.global.QuestXP.AddIncomplete) then
			questXP = totalXP;
		end
		
		local levelUpAlert = "";
		if(current_xp + questXP >= max_xp) then
			levelUpAlert = " (|cfff1e229enough to level|r)";
		end
		
		tinsert(outputText,
			string.format("%s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(questXP)), levelUpAlert)
		);
	end
	
	return table.concat(outputText, "  ");
end

function module:GetBarData()
	local data    = {};
	data.level    = UnitLevel("player");
	data.min  	  = 0;
	data.max  	  = UnitXPMax("player");
	data.current  = UnitXP("player");
	data.rested   = data.current + (GetXPExhaustion() or 0);
	
	local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();
	local questXP = completeXP;
	
	if(self.db.global.QuestXP.AddIncomplete) then
		questXP = totalXP;
	end
	
	if(self.db.global.QuestXP.ShowVisualizer) then
		data.visual = data.current + questXP;
	end
	
	return data;
end

function module:GetOptionsMenu()
	
end

------------------------------------------

function module:RestoreSession()
	if(not module:IsPlayerMaxLevel() and self.db.global.KeepSessionData and self.db.profile.Session.Exists) then
		local data = self.db.profile.Session;
		
		module.session.LoginTime 		= module.session.LoginTime - data.Time;
		module.session.ExperienceGained = data.TotalXP;
		module.session.AverageQuestXP 	= module.session.AverageQuestXP;
		
		if(module.session.AverageQuestXP > 0) then
			local remaining_xp = UnitXPMax("player") - UnitXP("player");
			module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP);
		end
	end
end

function module:ResetSession()
	module.session = {
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
end

function module:IsPlayerMaxLevel(level)
	return MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] == (level or UnitLevel("player"));
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

function module:QUEST_LOG_UPDATE()
	Addon:RefreshBar();
end

function module:UNIT_INVENTORY_CHANGED()
	Addon:RefreshBar();
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
	
	module.session.ExperienceGained = module.session.ExperienceGained + gained;
	
	module.session.LastXP = current_xp;
	module.session.MaxXP = max_xp;
	
	if(module.session.AverageQuestXP > 0) then
		local remaining_xp = max_xp - current_xp;
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP);
	end
	
	Addon:RefreshBar();
	
	Addon.GainUpdateTimer = 0;
end

function module:UPDATE_EXHAUSTION()
	if(self.db.profile.Mode ~= EXPERIENCER_MODE_XP) then return end
	
	Addon:RefreshBar();
end

function module:PLAYER_LEVEL_UP(event, level)
	if(not self.db or self.db.profile.Mode ~= EXPERIENCER_MODE_XP) then return end
	
	if(Addon:IsPlayerMaxLevel(level)) then
		Addon:SetMode(EXPERIENCER_MODE_REP);
		
		Addon:UnregisterEvent("QUEST_COMPLETE");
		Addon:UnregisterEvent("CHAT_MSG_SYSTEM");
		Addon:UnregisterEvent("PLAYER_XP_UPDATE");
		
		Addon:UnregisterEvent("UNIT_INVENTORY_CHANGED");
		Addon:UnregisterEvent("QUEST_LOG_UPDATE");
		Addon:UnregisterEvent("UNIT_AURA");
	else
		module.session.MaxXP = UnitXPMax("player");
		
		local remaining_xp = module.session.MaxXP - UnitXP("player");
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP) - 1;
	end
end
