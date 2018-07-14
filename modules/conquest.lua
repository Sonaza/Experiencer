------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("conquest", {
	label       = "Conquest",
	order       = 5,
	savedvars   = {
		global = {
			ShowRemaining  = true,
			ShowSeasonHigh = true,
		},
	},
});

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

local CONQUEST_UNLOCK_LEVEL = 120;

function module:Initialize()
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("PVP_REWARDS_UPDATE");
end

function module:IsDisabled()
	return UnitLevel("player") < CONQUEST_UNLOCK_LEVEL;
end

function module:Update(elapsed)
	
end

function module:GetConquestLevelInfo()
	local CONQUEST_QUESTLINE_ID = 782;
	local quests = C_QuestLine.GetQuestLineQuests(CONQUEST_QUESTLINE_ID)
	local currentQuestID = quests[1];
	local stageIndex = 1;
	for i, questID in ipairs(quests) do
		if not IsQuestFlaggedCompleted(questID) and not C_QuestLog.IsOnQuest(questID) then
			break;
		end
		currentQuestID = questID;
		stageIndex = stageIndex;
	end

	if not HaveQuestData(currentQuestID) then
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
		return 0, 0, nil, 0;
	end

	local objectives = C_QuestLog.GetQuestObjectives(currentQuestID);
	if not objectives or not objectives[1] then
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
		return 0, 0, nil, 0;
	end

	local rewardItemID;
	if HaveQuestRewardData(currentQuestID) then
		local itemIndex = 1;
		rewardItemID = select(6, GetQuestLogRewardInfo(itemIndex, currentQuestID));
	else
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	end

	return objectives[1].numFulfilled, objectives[1].numRequired, rewardItemID, stageIndex;
end

function module:OnMouseDown(button)
	
end

function module:CanLevelUp()
	local conquest, conquestMax = module:GetConquestLevelInfo();
	return conquest == conquestMax;
end

function module:GetText()
	local primaryText = {};
	
	local conquest, conquestMax, rewardID, stageIndex = module:GetConquestLevelInfo();
	local remaining         = conquestMax - conquest;
	
	local progress          = conquest / (conquestMax > 0 and conquestMax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	tinsert(primaryText, 
		("|cffffd200Conquest Stage|r %d"):format(stageIndex)
	);
	
	if(self.db.global.ShowRemaining) then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(conquest), BreakUpLargeNumbers(conquestMax), progressColor, progress * 100)
		);
	end
	
	return table.concat(primaryText, "  "), nil;
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
	local conquest, conquestMax, rewardID, stageIndex = module:GetConquestLevelInfo();
	local remaining         = conquestMax - conquest;
	
	local progress          = conquest / (conquestMax > 0 and conquestMax or 1);
	
	local leveltext = ("Currently at stage %d"):format(stageIndex);
	
	return ("%s at %s/%s (%d%%) with %s to go"):format(
		leveltext,
		BreakUpLargeNumbers(conquest),	
		BreakUpLargeNumbers(conquestMax),
		math.ceil(progress * 100),
		BreakUpLargeNumbers(remaining)
	);
end

function module:GetBarData()
	local conquest, conquestMax, rewardID, stageIndex = module:GetConquestLevelInfo();
	local remaining         = conquestMax - conquest;
	
	local progress          = conquest / (conquestMax > 0 and conquestMax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	local data    = {};
	data.id       = nil;
	data.level    = stageIndex;
	
	data.min  	  = 0;
	data.max  	  = conquestMax;
	data.current  = conquest;
	
	data.visual   = nil;
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Conquest Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining conquest",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max conquest",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:GET_ITEM_INFO_RECEIVED()
	module:Refresh();
	self:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
end

function module:QUEST_LOG_UPDATE()
	module:Refresh();
end

function module:PVP_REWARDS_UPDATE()
	module:Refresh();
end
