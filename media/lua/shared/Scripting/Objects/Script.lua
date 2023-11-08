-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"
require "Communications/QSystem"

Script = ISBaseObject:derive("Script");

function Script:add(item)
	self.lines[#self.lines+1] = item;
end

function Script:next()
	self.index = self.index+1;
end

function Script:reset()
	self.index = 1;
end

function Script:jump(label, keep_index)
	local label_index = self.labels[label];
	if label_index then
		self.index = label_index;
		QuestLogger.print("[QSystem*] #jump: Jump to - "..tostring(label));
		self.skip = -1;
		if not keep_index then
			self:next();
		end
		return true;
	end
end

function Script:get(i)
	return self.lines[i];
end

local commands_size = 0;
if not isServer() then
	Events.OnQSystemInit.Add(function () commands_size = #CommandList_a; end)
end

function Script:execute(sender, command)
	for i=1, commands_size do
		if CommandList_a[i]:validate_sender(sender.Type) then
			if CommandList_a[i]:validate_command(command) then
				local result = CommandList_a[i]:execute(sender);
				if type(result) == "string" then
					result = string.format("[QSystem] (Error) %s at line %i. File=%s, Mod=%s, Command=#%s", result, self.index, tostring(self.file), tostring(self.mod), CommandList_a[i].command);
				end
				self.index = self.index + 1;
				return result;
			end
		end
	end

	if sender.strict then
		return string.format("[QSystem] (Error) Unknown command '%s' at line - %i", tostring(command), self.index);
	end
	self.skip = self.layer+1;
	self:next();
end

function Script:play(sender)
	if self.index > #self.lines then return -1; end

	self.layer = GetBlockLayer(self.lines[self.index])
	local line = self.lines[self.index]:trim();

	if self.skip > self.layer then
		self.skip = -1;
	end
	if self.skip ~= -1 and self.skip <= self.layer then
		QuestLogger.print("[QSystem*] > Skipped line - "..line)
	elseif line:starts_with('#') then
		return self:execute(sender, string.sub(line, 2):trim());
	end

	self:next();
end

function Script:size()
	return #self.lines;
end

function Script:new(file, mod)
	local o = {};
	setmetatable(o, self);
	self.__index = self;

	o.file = file;
	o.mod = mod;
	o.lines = {};

	o.labels = {};

	o.layer = 0;
	o.skip = -1;

	o.index = 1;

	return o;
end