-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"

Command = ISBaseObject:derive("Command");
CommandList_a = {}; -- dialogue panel and character panel
CommandList_b = {}; -- quest creation

function Command:debug(mute)
    if mute then return end

    if self.deprecated then
        print(string.format("[QSystem] (Warning) #%s: %s is deprecated. %s.", tostring(self.Type), tostring(self.command), tostring(self.deprecated)));
    end

    if self.args[1] then
        local args = table.concat(self.args, "|")
        QuestLogger.print(string.format("[QSystem*] > #%s %s", tostring(self.command), args));
    else
        QuestLogger.print(string.format("[QSystem*] > #%s", tostring(self.command)));
    end
end


GetTextByTag = function(args) end -- virtual function

function Command:format(text)
    local strings = {};
    local p = 1;
    while string.len(text) > 0 do
        local tag_start = string.find(text, "${", 1, true);
        local tag_end = string.find(text, "}", 1, true);
        if tag_start and tag_end then
            strings[p] = string.sub(text, 1, tag_start-1);
            p = p + 1;
            text = string.sub(text, tag_start);
            tag_end = tag_end - tag_start;
            tag_start = 3;
            local another_tag = string.find(text, "${", 2, true);
            if another_tag and another_tag < tag_end then
                strings[p] = string.sub(text, 1, another_tag-1);
                text = string.sub(text, another_tag);
            else
                local tag = string.sub(text, tag_start, tag_end);
                local result = GetTextByTag(tag:ssplit(','));
                if result then
                    strings[p] = result;
                else
                    strings[p] = string.sub(text, 1, tag_end+1);
                end
                text = string.sub(text, tag_end+2);
            end
            p = p + 1;
        else
            strings[p] = text;
            break;
        end
    end

    return table.concat(strings);
end

function Command:validate_sender(sender_type)
    for i=1, #self.supported do
        if sender_type == self.supported[i] then
            return true;
        end
    end
    return false;
end

function Command:validate_command(command)
	if self.max_args > 0 then
		if command:starts_with(self.command.." ") then
            if self.allow_tags then
                self.args = self:format(command:sub(self.command_len+2)):ssplit('|');
            else
                self.args = command:sub(self.command_len+2):ssplit('|');
            end
			if #self.args >= self.min_args and #self.args <= self.max_args then
				return true;
			end
		end
    end
    if self.min_args == 0 then
        self.args = {};
        if command == self.command then
            return true;
        end
    end

	return false;
end

function Command:new(command, min_args, max_args, supported)
	local o = {};
	setmetatable(o, self);
	self.__index = self;

	o.command = command;
	o.command_len = string.len(command);
	o.min_args = min_args or 0;
	o.max_args = max_args or min_args;

    o.supported = {};
    if supported then
        if type(supported) == "table" then
            o.supported = supported;
        else
            o.supported[1] = supported;
        end
    end

	o.args = {};

	return o;
end