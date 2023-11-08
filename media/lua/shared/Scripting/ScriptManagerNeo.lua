-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Objects/Script"

ScriptManagerNeo = ISBaseObject:derive("ScriptManagerNeo");
ScriptManagerNeo.pause = false;
local scripts = {};
local scripts_size = 0;

function ScriptManagerNeo.unload_scripts()
	scripts = {};
	scripts_size = 0;
end

function ScriptManagerNeo.getChecksums()
	local checksums = {};
	for i=1, scripts_size do
		checksums[i] = tostring(scripts[i].checksum);
	end
	return checksums;
end

function ScriptManagerNeo:create_script(file, mod)
	return Script:new(file, mod);
end

function ScriptManagerNeo:read_script(path, file, mod, silent)
    local reader = getModFileReader(mod, path, false);

	if reader == nil then
		if not isServer() then
			if silent then
				QuestLogger.print("[QSystem*] ScriptManagerNeo: File '"..path.."' not found!");
			else
				print("[QSystem] (Error) ScriptManagerNeo: File '"..path.."' not found!");
			end
		end
		return;
	end

	local script = self:create_script(file, mod);

	local text = {};
	local line = reader:readLine();

	if line then
		local i = 1;
		while line ~= nil do
			script:add(line);
			text[i] = line;
			local after_trim = line:trim();
			if after_trim:starts_with('*') then
				local label = string.sub(after_trim, 2);
				if script.labels[label] ~= nil then
					print("[QSystem] ScriptManagerNeo: Found duplicate of label '"..tostring(label).."' at line "..tostring(i));
				else
					script.labels[label] = i;
				end
			end
			line = reader:readLine();
			i = i + 1;
		end
	end
	reader:close();

	return script, tostring(LibDeflate:Crc32(table.concat(text), 0));
end

function ScriptManagerNeo:load_script(file, mod, forced, language, silent)
	local path = string.format("media/data/%s/%s/%s", language or QImport.language, self.directory, tostring(file));
    if not mod then
		mod = GetModIDFromPath(path)
		if not mod then
			path = string.format("media/data/default/%s/%s", self.directory, file);
			mod = GetModIDFromPath(path);
		end
	end

	-- try load from memory
    for i=1, scripts_size do
		if scripts[i].file == file and scripts[i].mod == mod and scripts[i].directory == self.directory then
			QuestLogger.print("[QSystem*] ScriptManagerNeo: Script '"..file.."' ("..mod..", "..self.directory..") loaded from memory");
			scripts[i].script:reset();
			return scripts[i].script;
		end
	end
	-- if doesn't exist, load from disk
	if forced then
		local entry = {};
		entry.file = file;
		entry.mod = mod;
		entry.directory = self.directory;
		entry.script, entry.checksum = self:read_script(path, file, mod, silent);
		if entry.script then
			scripts_size = scripts_size + 1; scripts[scripts_size] = entry;
			QuestLogger.print("[QSystem*] ScriptManagerNeo: Script '"..file.."' ("..mod..", "..self.directory..") loaded from disk");
			return entry.script;
		end
	end
end

function ScriptManagerNeo:new(directory)
	local o = {};
	setmetatable(o, self);
	self.__index = self;
	o.items = {};
	o.items_size = 0;
    o.directory = tostring(directory);
	return o
end