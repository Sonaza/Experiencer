------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("artifact", {
	label       = "Artifact",
	order       = 3,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowUnspentPoints = true,
			ShowTotalArtifactPower = false,
			ShowBagArtifactPower = true,
			UnspentInChatMessage = false,
		},
	},
});

module.levelUpRequiresAction = true;

function module:Initialize()
	self:RegisterEvent("ARTIFACT_XP_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
end

function module:IsDisabled()
	-- If player doesn't have Legion on their account or hasn't completed first quest of artifact chain
	return GetExpansionLevel() < 6 or not module:HasCompletedArtifactIntro();
end

function module:Update(elapsed)
	
end

function module:CanLevelUp()
	if(not HasArtifactEquipped()) then return false end
	
	local _, _, _, _, totalXP, pointsSpent = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP);
	return numPoints > 0;
end

function module:HasCompletedArtifactIntro()
	local quests = {
		40408, -- Paladin
		40579, -- Warrior
		40618, -- Hunter
		40636, -- Monk
		40646, -- Druid
		40684, -- Warlock
		40706, -- Priest
		40715, -- Death Knight
		40814, -- Demon Hunter
		40840, -- Rogue
		41085, -- Mage
		41335, -- Shaman
	};
	
	for _, questID in ipairs(quests) do
		if(IsQuestFlaggedCompleted(questID)) then return true end
	end
	
	return false;
end

function module:CalculateTotalArtifactPower()
	if(not HasArtifactEquipped()) then return 0 end
	
	local _, _, _, _, currentXP, pointsSpent = C_ArtifactUI.GetEquippedArtifactInfo();
	
	local totalXP = 0;
	
	for i=0, pointsSpent-1 do
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(i, 0);
		totalXP = totalXP + xpForNextPoint;
	end
	
	return totalXP + currentXP;
end

function module:GetText()
	if(not HasArtifactEquipped()) then
		return "No artifact equipped";
	end
	
	local outputText = {};
	
	local itemID, altItemID, name, icon, totalXP, pointsSpent = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP);
	
	local remaining         = xpForNextPoint - artifactXP;
	
	local progress          = artifactXP / (xpForNextPoint > 0 and xpForNextPoint or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	tinsert(outputText,
		("|cffffecB3%s|r (Rank %d):"):format(name, pointsSpent + numPoints)
	);
	
	if(self.db.global.ShowRemaining) then
		tinsert(outputText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(outputText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(artifactXP), BreakUpLargeNumbers(xpForNextPoint), progressColor, progress * 100)
		);
	end
	
	if(self.db.global.ShowTotalArtifactPower) then
		tinsert(outputText,
			("%s |cffffdd00total artifact power|r"):format(BreakUpLargeNumbers(module:CalculateTotalArtifactPower()))
		);
	end
	
	if(self.db.global.ShowBagArtifactPower) then
		local totalPower = module:FindPowerItemsInInventory();
		if(totalPower > 0) then
			tinsert(outputText,
				("%s |cffa8ff00artifact power in bags|r"):format(BreakUpLargeNumbers(totalPower))
			);
		end
	end
	
	if(self.db.global.ShowUnspentPoints and numPoints > 0) then
		tinsert(outputText,
			("|cff86ff33%d unspent point%s|r"):format(numPoints, numPoints == 1 and "" or "s")
		);
	end
	
	return table.concat(outputText, "  ");
end

function module:HasChatMessage()
	return HasArtifactEquipped(), "No artifact equipped.";
end

function module:GetChatMessage()
	local outputText = {};
	
	local itemID, altItemID, name, icon, totalXP, pointsSpent = C_ArtifactUI.GetEquippedArtifactInfo();
	local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP);
	
	local remaining = xpForNextPoint - artifactXP;
	local progress  = artifactXP / (xpForNextPoint > 0 and xpForNextPoint or 1);
	
	tinsert(outputText, ("%s is currently rank %s"):format(
		name,
		pointsSpent + numPoints
	));
	
	if(pointsSpent > 0) then
		tinsert(outputText, ("at %s/%s power (%.1f%%) with %d to go"):format(
			BreakUpLargeNumbers(artifactXP),	
			BreakUpLargeNumbers(xpForNextPoint),
			progress * 100,
			remaining
		));
	end
	
	if(self.db.global.UnspentInChatMessage and numPoints > 0) then
		tinsert(outputText,
			(" (%d unspent point%s)"):format(numPoints, numPoints == 1 and "" or "s")
		);
	end
	
	return table.concat(outputText, " ");
end

function module:GetBarData()
	local data    = {};
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	if(HasArtifactEquipped()) then
		local itemID, altItemID, name, icon, totalXP, pointsSpent = C_ArtifactUI.GetEquippedArtifactInfo();
		local numPoints, artifactXP, xpForNextPoint = MainMenuBar_GetNumArtifactTraitsPurchasableFromXP(pointsSpent, totalXP);
		
		data.level    = pointsSpent + numPoints or 0;
		data.max  	  = xpForNextPoint;
		data.current  = artifactXP;
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Artifact Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining artifact power",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max artifact power",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show total artifact power",
			func = function() self.db.global.ShowTotalArtifactPower = not self.db.global.ShowTotalArtifactPower; module:RefreshText(); end,
			checked = function() return self.db.global.ShowTotalArtifactPower; end,
			isNotRadio = true,
		},
		{
			text = "Show unspent points",
			func = function() self.db.global.ShowUnspentPoints = not self.db.global.ShowUnspentPoints; module:RefreshText(); end,
			checked = function() return self.db.global.ShowUnspentPoints; end,
			isNotRadio = true,
		},
		{
			text = "Show sum of artifact power in bags",
			func = function() self.db.global.ShowBagArtifactPower = not self.db.global.ShowBagArtifactPower; module:RefreshText(); end,
			checked = function() return self.db.global.ShowBagArtifactPower; end,
			isNotRadio = true,
		},
		{
			text = "Include unspent points in chat message",
			func = function() self.db.global.UnspentInChatMessage = not self.db.global.UnspentInChatMessage; module:RefreshText(); end,
			checked = function() return self.db.global.UnspentInChatMessage; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:ARTIFACT_XP_UPDATE()
	module:Refresh();
end

function module:UNIT_INVENTORY_CHANGED(event, unit)
	if(unit ~= "player") then return end
	if(self:IsDisabled()) then
		Addon:CheckDisabledStatus();
	else
		module:Refresh(true);
	end
end

local APScannerTooltip = CreateFrame("GameTooltip", "ExperiencerAPScannerTooltip", nil, "GameTooltipTemplate");
function module:FindPowerItemsInInventory()
	local powers = {};
	
	local totalPower = 0;
	
	for container = 0, NUM_BAG_SLOTS do
		local numSlots = GetContainerNumSlots(container);
		
		for slot = 1, numSlots do
			local link = GetContainerItemLink(container, slot);
			if(link and GetItemSpell(link)) then
				APScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE");
				APScannerTooltip:SetHyperlink(link);
				
				if(ExperiencerAPScannerTooltipTextLeft2) then
					if(strfind(ExperiencerAPScannerTooltipTextLeft2:GetText(), ARTIFACT_POWER) ~= nil) then
						local power = module:GetItemArtifactPower(link);
						if(power) then
							totalPower = totalPower + power;
							tinsert(powers, {
								link = link,
								power = power,
							});
						end
					end
				end
			end
		end
	end
	
	return totalPower, powers;
end

function module:GetItemArtifactPower(link)
	if(not link) then return nil end
	
	APScannerTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	APScannerTooltip:SetHyperlink(link);
	
	local tooltipText = ExperiencerAPScannerTooltipTextLeft4:GetText();
	if(not tooltipText) then return nil end
	
	local power = tooltipText:gsub("[,%.]", ""):match("%d.-%s");
	if(power) then
		return tonumber(power);
	end
	
	return nil;
end