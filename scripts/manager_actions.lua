function hasEffect(rActor, sEffect)
	if not sEffect or not rActor then
		return false;
	end
	local sLowerEffect = sEffect:lower();
	
	-- Iterate through each effect
	local aMatch = {};
	for _,v in pairs(DB.getChildren(ActorManager.getCTNode(rActor), "effects")) do
		local nActive = DB.getValue(v, "isactive", 0);
		if nActive ~= 0 then
			-- Parse each effect label
			local sLabel = DB.getValue(v, "label", "");
			local bTargeted = EffectManager.isTargetedEffect(v);
			local aEffectComps = EffectManager.parseEffect(sLabel);

			-- Iterate through each effect component looking for a type match
			local nMatch = 0;
			for kEffectComp, sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = parseEffectComp(sEffectComp);
				-- Check conditionals
				if rEffectComp.original:lower() == sLowerEffect then
					nMatch = kEffectComp;
				end
				
			end
			
			-- If matched, then remove one-off effects
			if nMatch > 0 then
				if nActive == 2 then
					DB.setValue(v, "isactive", "number", 1);
				else
					table.insert(aMatch, v);
					local sApply = DB.getValue(v, "apply", "");
					if sApply == "action" then
						EffectManager.notifyExpire(v, 0);
					elseif sApply == "roll" then
						EffectManager.notifyExpire(v, 0, true);
					elseif sApply == "single" then
						EffectManager.notifyExpire(v, nMatch, true);
					end
				end
			end
		end
	end
	
	if #aMatch > 0 then
		return true, #aMatch;
	end
	return false, 0;
end

function parseEffectComp(s)
	local sType = nil;
	local aDice = {};
	local nMod = 0;
	local aRemainder = {};
	local nRemainderIndex = 1;
	
	local aWords, aWordStats = StringManager.parseWords(s, "%.%[%]%(%):");
	if #aWords > 0 then
		sType = aWords[1]:match("^([^:]+):");
		if sType then
			nRemainderIndex = 2;
			
			local sValueCheck = aWords[1]:sub(#sType + 2);
			if sValueCheck ~= "" then
				table.insert(aWords, 2, sValueCheck);
				table.insert(aWordStats, 2, { startpos = aWordStats[1].startpos + #sType + 1, endpos = aWordStats[1].endpos });
				aWords[1] = aWords[1]:sub(1, #sType + 1);
				aWordStats[1].endpos = #sType + 1;
			end
			
			if #aWords > 1 then
				if StringManager.isDiceString(aWords[2]) then
					aDice, nMod = StringManager.convertStringToDice(aWords[2]);
					nRemainderIndex = 3;
				end
			end
		end
		
		if nRemainderIndex <= #aWords then
			while nRemainderIndex <= #aWords and aWords[nRemainderIndex]:match("^%[%d?%a+%]$") do
				table.insert(aRemainder, aWords[nRemainderIndex]);
				nRemainderIndex = nRemainderIndex + 1;
			end
		end
		
		if nRemainderIndex <= #aWords then
			local sRemainder = s:sub(aWordStats[nRemainderIndex].startpos);
			local nStartRemainderPhrase = 1;
			local i = 1;
			while i < #sRemainder do
				local sCheck = sRemainder:sub(i, i);
				if sCheck == "," then
					local sRemainderPhrase = sRemainder:sub(nStartRemainderPhrase, i - 1);
					if sRemainderPhrase and sRemainderPhrase ~= "" then
						sRemainderPhrase = StringManager.trim(sRemainderPhrase);
						table.insert(aRemainder, sRemainderPhrase);
					end
					nStartRemainderPhrase = i + 1;
				elseif sCheck == "(" then
					while i < #sRemainder do
						if sRemainder:sub(i, i) == ")" then
							break;
						end
						i = i + 1;
					end
				elseif sCheck == "[" then
					while i < #sRemainder do
						if sRemainder:sub(i, i) == "]" then
							break;
						end
						i = i + 1;
					end
				end
				i = i + 1;
			end
			local sRemainderPhrase = sRemainder:sub(nStartRemainderPhrase, #sRemainder);
			if sRemainderPhrase and sRemainderPhrase ~= "" then
				sRemainderPhrase = StringManager.trim(sRemainderPhrase);
				table.insert(aRemainder, sRemainderPhrase);
			end
		end
	end

	return  {
		type = sType or "", 
		mod = nMod, 
		dice = aDice, 
		remainder = aRemainder, 
		original = StringManager.trim(s)
	};
end

function onInit()
	Oldroll = ActionsManager.roll;
	ActionsManager.roll = roll;
	
	OldresolveAction = ActionsManager.resolveAction;
	ActionsManager.resolveAction = resolveAction;
	
	ActionsManager.total = total;
end

function roll(rSource, vTargets, rRoll, bMultiTarget)
	rRoll.originaldicenumber = #rRoll.aDice or 0;
	if #rRoll.aDice > 0 then
		local _, nAdvantage =  hasEffect(rSource, "keladvantage");
		local _, nDisAdvantage =  hasEffect(rSource, "keldisadvantage");
		
		rRoll.adv = ( tonumber(rRoll.adv) or 0 ) + nAdvantage - nDisAdvantage;
		
		if rRoll.adv > 0 then
			local i = 1;
			local slot = i + 1;
			while rRoll.aDice[i] do
				table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
				i = i + 2;
				slot = i+1;
			end
		elseif rRoll.adv < 0 then
			local i = 1;
			local slot = i + 1;
			while rRoll.aDice[i] do
				table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
				i = i + 2;
				slot = i+1;
			end
		end
	end
	Oldroll(rSource, vTargets, rRoll, bMultiTarget);
end 

function resolveAction(rSource, rTarget, rRoll)
	if #rRoll.aDice > 0 then
		
		rRoll.adv = tonumber(rRoll.adv) or 0;
		
		if rRoll.adv > 0 then
			local i = 1;
			local slot = i+1;
			local sDropped = "";
			while rRoll.aDice[i] do
				if rRoll.aDice[i].result <= rRoll.aDice[slot].result then
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[i].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[i].result
					end
					table.remove(rRoll.aDice, i);
				else
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[slot].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[slot].result
					end
					table.remove(rRoll.aDice, slot);
				end
				rRoll.aDice[i].type = "g" .. string.sub(rRoll.aDice[i].type, 2);
				i = i + 1;
				slot = i+1;
			end
			rRoll.sDesc = rRoll.sDesc .. " [ADV]" .. " [DROPPED " .. sDropped .. "]";
			local nodeCT = ActorManager.getCTNode(rSource);
			local sOptDISADV = OptionsManager.getOption("DISADV");
			if sOptDISADV == "on" then
				EffectManager.removeEffect(nodeCT, "keladvantage");
			end
			rRoll.aDice.expr = nil;
		elseif rRoll.adv < 0 then
			local i = 1;
			local slot = i+1;
			local sDropped = "";
			while rRoll.aDice[i] do
				if rRoll.aDice[i].result >= rRoll.aDice[slot].result then
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[i].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[i].result
					end
					table.remove(rRoll.aDice, i);
				else
					if sDropped == "" then
						sDropped = sDropped .. rRoll.aDice[slot].result;
					else
						sDropped = sDropped .. ", " .. rRoll.aDice[slot].result
					end
					table.remove(rRoll.aDice, slot);
				end
				rRoll.aDice[i].type = "r" .. string.sub(rRoll.aDice[i].type, 2);
				i = i + 1;
				slot = i+1;
			end
			rRoll.sDesc = rRoll.sDesc .. " [DISADV]" .. " [DROPPED " .. sDropped .. "]";
			local nodeCT = ActorManager.getCTNode(rSource);
			local sOptDISADV = OptionsManager.getOption("DISADV");
			if sOptDISADV == "on" then
				EffectManager.removeEffect(nodeCT, "keldisadvantage");
			end
			rRoll.aDice.expr = nil;
		end
	end
	OldresolveAction(rSource, rTarget, rRoll);
end

function total(rRoll)
	local nTotal = 0;
	local corrector = {};
	local j = 1;
	for _,v in ipairs(rRoll.aDice) do
		-- KEL Removing bUseFGUDiceValues because it is always true for us (otherwise compatibility nasty)
		if v.value then
			corrector[j] = v.value;
		else
			corrector[j] = v.result;
		end
		j = j+1;
	end
	if rRoll.originaldicenumber then
		rRoll.originaldicenumber = tonumber(rRoll.originaldicenumber);
		if #rRoll.aDice > rRoll.originaldicenumber then
		
			rRoll.adv = tonumber(rRoll.adv) or 0;
			
			if rRoll.adv > 0 then
				local i = 1;
				local slot = i+1;
				while corrector[i] do
					if corrector[i] <= corrector[slot] then
						table.remove(corrector, i);
					else
						table.remove(corrector, slot);
					end
					i = i + 1;
					slot = i+1;
				end
			elseif rRoll.adv < 0 then
				local i = 1;
				local slot = i+1;
				while corrector[i] do
					if corrector[i] >= corrector[slot] then
						table.remove(corrector, i);
					else
						table.remove(corrector, slot);
					end
					i = i + 1;
					slot = i+1;
				end
			end
		end
	end
	for i = 1, #corrector do
		nTotal = nTotal + corrector[i];
	end
	nTotal = nTotal + rRoll.nMod;
	
	return nTotal;
end