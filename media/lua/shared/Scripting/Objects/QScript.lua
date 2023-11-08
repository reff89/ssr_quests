-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Objects/Script"

QScript = Script:derive("QScript");

function QScript:execute(sender, command)
	for i=1, #CommandList_b do
		if CommandList_b[i]:validate_sender(sender.Type) then
			if CommandList_b[i]:validate_command(command) then
				local result = CommandList_b[i]:execute(sender);
				if type(result) == "string" then
					result = string.format("[QSystem] (Error) %s at line %i. File=%s, Mod=%s, Command=#%s", result, self.index, tostring(self.file), tostring(self.mod), CommandList_b[i].command);
				end
				self.index = self.index + 1;
				return result;
			end
		end
	end

	return "[QSystem] (Error) Unknown command '"..tostring(command).."' at line - "..tostring(self.index);
end