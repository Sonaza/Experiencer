local ADDON_NAME, SHARED_DATA = ...;

local A = unpack(SHARED_DATA);

local QUEST_COMPLETED_PATTERN = "^" .. string.gsub(ERR_QUEST_COMPLETE_S, "%%s", "(.-)") .. "$";
local QUEST_EXPERIENCE_PATTERN = "^" .. string.gsub(ERR_QUEST_REWARD_EXP_I, "%%d", "(%%d+)") .. "$";

function A:PLAYER_REGEN_DISABLED()
	CloseMenus();
end

function A:QUEST_LOG_UPDATE()
	A:RefreshBar();
end

function A:UNIT_INVENTORY_CHANGED()
	A:RefreshBar();
end

function A:UNIT_AURA()
	A:RefreshBar();
end

function A:CHAT_MSG_SYSTEM(event, msg)
	if(msg:match(QUEST_COMPLETED_PATTERN) ~= nil) then
		A.QuestCompleted = true;
		return;
	end
	
	if(not A.QuestCompleted) then return end
	A.QuestCompleted = false;
	
	local xp_amount = msg:match(QUEST_EXPERIENCE_PATTERN);
	
	if(xp_amount ~= nil) then
		xp_amount = tonumber(xp_amount);
		
		local weigth = 0.5;
		if(A.Session.AverageQuestXP > 0) then
			weigth = math.min(xp_amount / A.Session.AverageQuestXP, 0.9);
			A.Session.AverageQuestXP = A.Session.AverageQuestXP * (1.0 - weigth) + xp_amount * weigth;
		else
			A.Session.AverageQuestXP = xp_amount;
		end
		
		if(A.Session.AverageQuestXP ~= 0) then
			local remaining_xp = UnitXPMax("player") - UnitXP("player");
			A.Session.QuestsToLevel = math.floor(remaining_xp / A.Session.AverageQuestXP);
			
			if(A.Session.QuestsToLevel > 0 and xp_amount > 0) then
				local quests_text = string.format("%d more quests to level", A.Session.QuestsToLevel);
				
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. quests_text .. ".|r");
				
				if(Parrot) then
					Parrot:ShowMessage(quests_text, "Errors", false, 1.0, 1.0, 0.1);
				end
			end
		end
	end
end

function A:PLAYER_XP_UPDATE(event)
	if(self.db.profile.Mode ~= EXPERIENCER_MODE_XP) then return end
	
	local current_xp = UnitXP("player");
	local max_xp = UnitXPMax("player");
	
	local gained = current_xp - A.Session.LastXP;
	
	if(gained < 0) then
		gained = A.Session.MaxXP - A.Session.LastXP + current_xp;
	end
	
	A.Session.ExperienceGained = A.Session.ExperienceGained + gained;
	
	A.Session.LastXP = current_xp;
	A.Session.MaxXP = max_xp;
	
	if(A.Session.AverageQuestXP > 0) then
		local remaining_xp = max_xp - current_xp;
		A.Session.QuestsToLevel = ceil(remaining_xp / A.Session.AverageQuestXP);
	end
	
	A:RefreshBar();
	
	A.GainUpdateTimer = 0;
end

function A:UPDATE_EXHAUSTION()
	if(self.db.profile.Mode ~= EXPERIENCER_MODE_XP) then return end
	
	A:RefreshBar();
end

function A:PLAYER_LEVEL_UP(event, level)
	if(not self.db or self.db.profile.Mode ~= EXPERIENCER_MODE_XP) then return end
	
	if(A:IsPlayerMaxLevel(level)) then
		A:SetMode(EXPERIENCER_MODE_REP);
		
		A:UnregisterEvent("QUEST_COMPLETE");
		A:UnregisterEvent("CHAT_MSG_SYSTEM");
		A:UnregisterEvent("PLAYER_XP_UPDATE");
		
		A:UnregisterEvent("UNIT_INVENTORY_CHANGED");
		A:UnregisterEvent("QUEST_LOG_UPDATE");
		A:UnregisterEvent("UNIT_AURA");
	else
		A.Session.MaxXP = UnitXPMax("player");
		
		local remaining_xp = A.Session.MaxXP - UnitXP("player");
		A.Session.QuestsToLevel = ceil(remaining_xp / A.Session.AverageQuestXP) - 1;
	end
end

function A:UPDATE_FACTION(event, ...)
	if(self.db.profile.Mode ~= EXPERIENCER_MODE_REP) then return end
	
	local set_value = false;
	
	local name = GetWatchedFactionInfo();
	if(name and self.db.profile.Enabled and not A.IsVisible) then
		A:ShowBar();
	end
	
	if(name ~= A.CurrentRep) then
		set_value = true;
	end
	
	A:RefreshBar(set_value);
	A.GainUpdateTimer = 0;
end

local BODYGUARD_FACTIONS = {
	[1738] = "Defender Illona",
	[1740] = "Aeda Brightdawn",
	[1733] = "Delvar Ironfist",
	[1739] = "Vivianne",
	[1737] = "Talonpriest Ishaal",
	[1741] = "Leorajh",
	[1736] = "Tormmok",
};

function A:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match("Reputation with (.-) increased by (%d*)%.");
	if(not reputation or not A.RecentReputations) then return end
	
	if(A.RecentReputations[reputation] == nil) then
		A.RecentReputations[reputation] = {
			amount = 0,
		};
	end
	
	A.RecentReputations[reputation].amount = A.RecentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled) then
		if(A.CurrentRep ~= reputation) then
			A:UpdateAutoWatch(reputation);
		end
	end
end

function A:UpdateAutoWatch(reputation)
	if(self.db.global.AutoWatch.IgnoreGuild and reputation == GUILD) then return end
		
	local factionListIndex, factionID = A:GetReputationID(reputation);
	if(not factionListIndex) then return end
	
	if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
	if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
	
	SetWatchedFactionIndex(factionListIndex);
end

local hiddenForPetBattle = false;

function A:PET_BATTLE_OPENING_START(event)
	if(A.IsVisible) then
		hiddenForPetBattle = true;
		A:HideBar();
	end
end

function A:PET_BATTLE_CLOSE(event)
	if(hiddenForPetBattle) then
		A:ShowBar();
	end
	
	hiddenForPetBattle = false;
end