-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/ScriptManagerNeo"

DialogueManager = ScriptManagerNeo:derive("DialogueManager")

function DialogueManager:new()
	local o = ScriptManagerNeo:new("dialogues");
	setmetatable(o, self);
	self.__index = self;
	return o;
end

DialogueManager.instance = DialogueManager:new();