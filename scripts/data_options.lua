function onInit()
	registerOptions();
end

function registerOptions()
	OptionsManager.registerOption2("DISADV",false, "option_header_DISADV", "option_label_DISADV", "option_entry_cycler", 
		{ labels = "option_val_off", values = "off", baselabel = "option_val_on", baseval = "on", default = "on" });
end
