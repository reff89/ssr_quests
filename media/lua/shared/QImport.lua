-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/TaskManager"

QImport = {}
QImport.scripts = {}
QImport.checksums = {}
QImport.language = "default";

QImport.calculateChecksums = function () -- server-side
	local languages = Translator.getAvailableLanguage();
	for lang_id=0, languages:size()-1 do
		local language = tostring(languages:get(lang_id));
		QImport.list(language);
		if QImport.scripts[1] then
			for entry_id=1, #QImport.scripts do
				if QImport.scripts[entry_id].char_data[1] then
					for i=1, #QImport.scripts[entry_id].char_data do
						CharacterManager.instance:parse(QImport.scripts[entry_id].char_data[i], QImport.scripts[entry_id].mod, QImport.scripts[entry_id].language);
					end
				end
				if QImport.scripts[entry_id].dialogue_data[1] then
					for i=1, #QImport.scripts[entry_id].dialogue_data do
						DialogueManager.instance:load_script(QImport.scripts[entry_id].dialogue_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
					end
				end
				if QImport.scripts[entry_id].quest_data[1] then
					for i=1, #QImport.scripts[entry_id].quest_data do
						QuestManager.instance:load_script(QImport.scripts[entry_id].quest_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
						local name = QImport.scripts[entry_id].quest_data[i]:sub(1, QImport.scripts[entry_id].quest_data[i]:lastIndexOf('.'));
						QuestManager.instance:load_script(name.."_quests.txt", QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
						QuestManager.instance:load_script(name.."_tasks.txt", QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
					end
				end
			end
		end
		triggerEvent("OnQSystemInit", nil);
		local entry = {};
		entry.language = language;
		entry.hash = ScriptManagerNeo.getChecksums();
		QImport.checksums[#QImport.checksums+1] = entry;
		ScriptManagerNeo.unload_scripts();
		triggerEvent("OnQSystemReset", nil);
	end
end


local Task_LoadQuests = AsyncTask:derive("AsyncTask")

function Task_LoadQuests:start()
	self.script = QuestManager.instance:load_script(self.file, self.mod, true, self.language);
    if self.script == nil then
        self.done = true;
    else
        self.step = 1;
		self.start_index = QuestManager.instance.quests_size + 1;
    end
end

function Task_LoadQuests:next()
    self.step = self.step + 1;
end

function Task_LoadQuests:update()
	if self.step == 1 then
		local ticks = 70;
		while ticks > 0 do
			local result = self.script:play(self.script);

			if result then
				if type(result) == 'string' then print(result); QuestManager.instance:end_create(); end
				return self:next();
			end
			ticks = ticks - 1;
		end
    elseif self.step == 2 then
		self.quest_strings = QuestManager.instance:load_script(self.name.."_quests.txt", self.mod, true, self.language);
		return self:next();
    elseif self.step == 3 then
		self.task_strings = QuestManager.instance:load_script(self.name.."_tasks.txt", self.mod, true, self.language);
		return self:next();
    elseif self.step == 4 then
		local ticks = 20;
		while ticks > 0 do
			if self.start_index > QuestManager.instance.quests_size then
				self.done = true;
				break;
			else
				if not QuestManager.instance.quests[self.start_index].hidden then
					local quest_id = tostring(QuestManager.instance.quests[self.start_index].internal);
					if self.quest_strings then -- if file exists
						if self.quest_strings:jump(quest_id) then -- if label exists and jump is successful
							if self.quest_strings:play(QuestManager.instance.quests[self.start_index]) then -- name
								if not self.quest_strings:play(QuestManager.instance.quests[self.start_index]) then -- desc
									print("[QSystem] (Warning) QuestManager: Unexpected string intead of quest desc at line "..tostring(self.quest_strings.index-1));
								end
							else
								print("[QSystem] (Warning) QuestManager: Unexpected string intead of quest name at line "..tostring(self.quest_strings.index-1));
							end
						else
							print(string.format("[QSystem] (Error) Label '%s' not found. File=%s, Mod=%s, Command=#jump", tostring(quest_id), tostring(self.quest_strings.file), tostring(self.quest_strings.mod)));
						end
					end

					if self.task_strings then -- if file exists
						for j = 1, QuestManager.instance.quests[self.start_index].tasks_size do
							if not QuestManager.instance.quests[self.start_index].tasks[j].hidden then -- don't lookup name for hidden tasks
								local task_id = quest_id.."_"..tostring(QuestManager.instance.quests[self.start_index].tasks[j].internal);
								if self.task_strings:jump(task_id) then -- if label exists and jump is successful
									if not self.task_strings:play(QuestManager.instance.quests[self.start_index].tasks[j]) then -- name
										print("[QSystem] (Warning) QuestManager: Unexpected string intead of task name at line "..tostring(self.task_strings.index-1));
									end
								else
									print(string.format("[QSystem] (Error) Label '%s' not found. File=%s, Mod=%s, Command=#jump", tostring(task_id), tostring(self.task_strings.file), tostring(self.task_strings.mod)));
								end
							end
						end
					end
				end
				self.start_index = self.start_index + 1;
			end
		end
    end
end

function Task_LoadQuests:new(callback, file, mod, language)
	local o = AsyncTask:new(callback);
	setmetatable(o, self);
	self.__index = self;

	o.name = file:sub(1, file:lastIndexOf('.'));
	o.file = file;
	o.mod = mod;
	o.language = language;

    o.script = nil;

	return o;
end


local Task_Import = AsyncTask:derive("AsyncTask")

function Task_Import:start()
	self.entry_id = self.entry_id + 1;
	if self.entry_id > self.size then
		if self.size == 0 then
			print("[QSystem] No data found! Aborted.")
		end
		self.done = true;
	else
		QuestLogger.print("[QSystem*] Loading data from mod "..tostring(QImport.scripts[self.entry_id].mod))
		self.characters = #QImport.scripts[self.entry_id].char_data;
		self.dialogues = #QImport.scripts[self.entry_id].dialogue_data;
		self.quests = #QImport.scripts[self.entry_id].quest_data;
		if self.characters > 0 then
			self:step_1();
		else
			self:step_2();
		end
	end
end

function Task_Import:step_1()
	self.step = 1;
	self.data_id = 1;
	QuestLogger.print("[QSystem*] Setting characters...")
end

function Task_Import:step_2()
	self.step = 2;
	self.data_id = 1;
	QuestLogger.print("[QSystem*] Setting dialogues...")
end

function Task_Import:step_3()
	self.step = 3;
	self.data_id = 1;
	QuestLogger.print("[QSystem*] Setting quests...")
end

function Task_Import:update()
	if self.step == 1 then
		if self.data_id > self.characters then
			return self:step_2();
		else
			CharacterManager.instance:parse(QImport.scripts[self.entry_id].char_data[self.data_id], QImport.scripts[self.entry_id].mod, QImport.scripts[self.entry_id].language);
		end
	elseif self.step == 2 then
		if self.data_id > self.dialogues then
			return self:step_3();
		else
			DialogueManager.instance:load_script(QImport.scripts[self.entry_id].dialogue_data[self.data_id], QImport.scripts[self.entry_id].mod, true, QImport.scripts[self.entry_id].language);
		end
	elseif self.step == 3 then
		if self.data_id > self.quests then
			return self:start();
		else
			TaskManager.add(Task_LoadQuests:new(nil, QImport.scripts[self.entry_id].quest_data[self.data_id], QImport.scripts[self.entry_id].mod, QImport.scripts[self.entry_id].language))
		end
	end
	self.data_id = self.data_id + 1;
end

function Task_Import:new(callback)
	local o = AsyncTask:new(callback);
	setmetatable(o, self);
	self.__index = self;

	o.entry_id = 0;
	o.data_id = 1;
	o.size = #QImport.scripts;

	return o;
end


QImport.reimport = function (callback) -- reloads all the scripts from disk
	QSystem.initialised = false;

	local reimport_start = getTimeInMillis();
	QTracker.clear(); -- clear tracker
	ScriptManagerNeo.unload_scripts(); -- unload scripts from memory
	triggerEvent("OnQSystemReset", nil); -- reset lists and static variables

	QImport.language = tostring(Translator.getLanguage());
	QImport.list(QImport.language); -- update file table
	TaskManager.add(Task_Import:new(function ()
		print("[QSystem] Reimport took "..tostring(getTimeInMillis() - reimport_start).." ms")
		triggerEvent("OnQSystemRestart", nil); -- reload plugins (NPC mod, etc)
		QSystem.initialised = true;
		triggerEvent("OnQSystemUpdate", 4); -- update panels
		if callback then callback(); end
	end))
end

QImport.reset = function (callback) -- reloads all the scripts from memory
    QSystem.initialised = false;

    local reset_start = getTimeInMillis();
    if DialoguePanel.instance then DialoguePanel.instance:close(); end
    QTracker.clear(); -- clear tracker
    triggerEvent("OnQSystemReset", nil); -- reset lists and static variables

    TaskManager.add(Task_Import:new(function ()
        print("[QSystem] Reset took "..tostring(getTimeInMillis() - reset_start).." ms")
        triggerEvent("OnQSystemRestart", nil); -- reload plugins (NPC mod, etc)
        QSystem.initialised = true;
        triggerEvent("OnQSystemUpdate", 4); -- update panels
		if callback then callback(); end
    end))
end

QImport.list = function (language)
	QImport.scripts = {};
	local list = getActivatedMods();
	for i=0, list:size()-1 do
		local mod = tostring(list:get(i));
		local _language = language;
		local reader = getModFileReader(mod, "media/data/".._language.."/FTable.ini", false);
		if not reader then
			reader = getModFileReader(mod, "media/data/default/FTable.ini", false);
			_language = "default";
		end
		if reader then
			QuestLogger.print("[QSystem*] Found 'FTable.ini' in the directory of mod '"..mod.."'. Language: ".._language)
			local entry = {};
			entry.mod = mod;
			entry.quest_data = {}
			entry.dialogue_data = {}
			entry.char_data = {}
			entry.language = _language;
			local line = reader:readLine();
			while line do
				if line:indexOf("quests") == 1 then
					local filename = line:substring(8);
					if filename:indexOf("_quests.txt") == -1 and filename:indexOf("_tasks.txt") == -1 then
						entry.quest_data[#entry.quest_data+1] = filename;
					else
						print(string.format("[QSystem] (Error) Invalid quest script '%s' detected in FTable.ini. Do not add _quests/_tasks scripts to this file!", tostring(filename)));
					end
				elseif line:indexOf("dialogues") == 1 then
					local filename = line:substring(11);
					entry.dialogue_data[#entry.dialogue_data+1] = filename;
				elseif line:indexOf("characters") == 1 then
					local filename = line:substring(12);
					if filename:indexOf("_pos.txt") == -1 then
						entry.char_data[#entry.char_data+1] = filename;
					else
						print(string.format("[QSystem] (Error) Invalid character script '%s' detected in FTable.ini. Do not add _pos scripts to this file!", tostring(filename)));
					end
				end
				line = reader:readLine();
			end
			reader:close();
			QImport.scripts[#QImport.scripts+1] = entry;
		end
	end
end

QImport.import = function ()
	if QImport.scripts[1] then
		for entry_id=1, #QImport.scripts do
			QuestLogger.print("[QSystem*] Loading data from mod "..tostring(QImport.scripts[entry_id].mod))
			if QImport.scripts[entry_id].char_data[1] then
				QuestLogger.print("[QSystem*] Setting characters...")
				for i=1, #QImport.scripts[entry_id].char_data do
					CharacterManager.instance:parse(QImport.scripts[entry_id].char_data[i], QImport.scripts[entry_id].mod, QImport.scripts[entry_id].language)
				end
			end
			if QImport.scripts[entry_id].dialogue_data[1] then
				QuestLogger.print("[QSystem*] Setting dialogues...")
				for i=1, #QImport.scripts[entry_id].dialogue_data do
					DialogueManager.instance:load_script(QImport.scripts[entry_id].dialogue_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language)
				end
			end
			if QImport.scripts[entry_id].quest_data[1] then
				QuestLogger.print("[QSystem*] Setting quests...")
				for i=1, #QImport.scripts[entry_id].quest_data do
					QuestManager.instance:parse(QImport.scripts[entry_id].quest_data[i], QImport.scripts[entry_id].mod, QImport.scripts[entry_id].language)
				end
			end
		end
	else
		print("[QSystem] No data found! Aborted.")
	end
end

QImport.init = function(callback)
	print("[QSystem] Initializing...")
	TaskManager.add(Task_Import:new(function ()
		triggerEvent("OnQSystemInit", nil);
		if callback then callback(); end
	end))
end

QImport.preinit = function()
	print("[QSystem] Pre-Initializing...");
	QImport.language = tostring(Translator.getLanguage());
	QImport.list(QImport.language);
	local start_time = getTimeInMillis();
	for entry_id=1, #QImport.scripts do
		print(string.format("[QSystem] Loading data from mod '%s'", tostring(QImport.scripts[entry_id].mod)));
		if QImport.scripts[entry_id].char_data[1] then
			for i=1, #QImport.scripts[entry_id].char_data do
				CharacterManager.instance:load_script(QImport.scripts[entry_id].char_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language)
			end
		end
		if QImport.scripts[entry_id].dialogue_data[1] then
			for i=1, #QImport.scripts[entry_id].dialogue_data do
				DialogueManager.instance:load_script(QImport.scripts[entry_id].dialogue_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language)
			end
		end
		if QImport.scripts[entry_id].quest_data[1] then
			for i=1, #QImport.scripts[entry_id].quest_data do
				QuestManager.instance:load_script(QImport.scripts[entry_id].quest_data[i], QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language)
				local name = QImport.scripts[entry_id].quest_data[i]:sub(1, QImport.scripts[entry_id].quest_data[i]:lastIndexOf('.'));
				QuestManager.instance:load_script(name.."_quests.txt", QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
				QuestManager.instance:load_script(name.."_tasks.txt", QImport.scripts[entry_id].mod, true, QImport.scripts[entry_id].language);
			end
		end
	end
	triggerEvent("OnQSystemPreInit", nil); -- preload plugin assets
	print("[QSystem] Finished loading data in "..tostring(getTimeInMillis() - start_time).." ms")
end

if not isServer() then
	Events.OnPostMapLoad.Add(QImport.preinit);
end