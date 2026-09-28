

function onInit()
	initRegistrations();
	initOverrides();
end

function initRegistrations()
	ModifierManager.addModWindowPresets({ { sCategory = "general", tPresets = { "ADV", "DISADV" } } });
	ModifierManager.addKeyExclusionSets({ { "ADV", "DISADV" } });
end

local _fnOrigOnPreModRoll;
local _fnOrigOnPreResolve;

function initOverrides()
	_fnOrigOnPreModRoll = GameManager.getMultiKeyFunction("onActionPreModRoll", "");
	GameManager.setMultiKeyFunction("onActionPreModRoll", "", onPreModRoll);
	_fnOrigOnPreResolve = GameManager.getMultiKeyFunction("onActionPreResolve", "");
	GameManager.setMultiKeyFunction("onActionPreResolve", "", onPreResolve);
end

function onPreModRoll(rSource, rTarget, rRoll)
	onPreModRollKelADV(rSource, rTarget, rRoll);

	if _fnOrigOnPreModRoll then
		_fnOrigOnPreModRoll(rSource, rTarget, rRoll);
	end
end
function onPreModRollKelADV(rSource, rTarget, rRoll)
	rRoll.nKelADVDice = #(rRoll.aDice or {});
	if rRoll.nKelADVDice == 0 then
		return;
	end

	local nADV = #(EffectManager.getCompsDataByText(rSource, "keladvantage"));
	local nDIS = #(EffectManager.getCompsDataByText(rSource, "keldisadvantage"));
	rRoll.nKelADV = (rRoll.nKelADV or 0) + nADV - nDIS;
	if ModifierManager.getKey("ADV") then
		rRoll.nKelADV = rRoll.nKelADV + 1;
	end
	if ModifierManager.getKey("DISADV") then
		rRoll.nKelADV = rRoll.nKelADV - 1;
	end
	if rRoll.nKelADV == 0 then
		return;
	end

	local i = 1;
	local slot = i + 1;
	while rRoll.aDice[i] do
		table.insert(rRoll.aDice, slot, rRoll.aDice[i]);
		i = i + 2;
		slot = i + 1;
	end
end 

function onPreResolve(rSource, rTarget, rRoll)
	onPreResolveKelADV(rSource, rTarget, rRoll);

	if _fnOrigOnPreResolve then
		_fnOrigOnPreResolve(rSource, rTarget, rRoll);
	end
end
function onPreResolveKelADV(rSource, rTarget, rRoll)
	if #(rRoll.aDice or {}) <= 0 then
		return;
	end

	if (rRoll.nKelADV or 0) > 0 then
		local i = 1;
		local slot = i + 1;
		local sDropped = "";
		while rRoll.aDice[i] do
			if rRoll.aDice[i].result <= rRoll.aDice[slot].result then
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[i].result));
				table.remove(rRoll.aDice, i);
			else
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[slot].result));
				table.remove(rRoll.aDice, slot);
			end
			rRoll.aDice[i].type = "g" .. rRoll.aDice[i].type:sub(2);
			i = i + 1;
			slot = i + 1;
		end
		rRoll.sDesc = StringManager.append(rRoll.sDesc, string.format("[ADV] [DROPPED %s]", sDropped), " ");
		rRoll.aDice.expr = nil;
		rRoll.nTotal = ActionsManager.total(rRoll);
	elseif (rRoll.nKelADV or 0) < 0 then
		local i = 1;
		local slot = i + 1;
		local sDropped = "";
		while rRoll.aDice[i] do
			if rRoll.aDice[i].result >= rRoll.aDice[slot].result then
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[i].result));
				table.remove(rRoll.aDice, i);
			else
				sDropped = StringManager.append(sDropped, tostring(rRoll.aDice[slot].result));
				table.remove(rRoll.aDice, slot);
			end
			rRoll.aDice[i].type = "r" .. rRoll.aDice[i].type:sub(2);
			i = i + 1;
			slot = i+1;
		end
		rRoll.sDesc = StringManager.append(rRoll.sDesc, string.format("[DISADV] [DROPPED %s]", sDropped), " ");
		rRoll.aDice.expr = nil;
		rRoll.nTotal = ActionsManager.total(rRoll);
	end
end
