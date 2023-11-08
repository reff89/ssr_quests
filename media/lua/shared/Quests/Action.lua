-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"

Action =  ISBaseObject:derive("Action")

function Action:update()

end

function Action:reload() -- for debugging purposes

end

function Action:reset()
    self.pending = false;
    self.completed = false;
    triggerEvent("OnQSystemUpdate", 3);
end

function Action:execute()

end

function Action:setPending(value)
    self.pending = value;
    if self.save then
        SaveManager.onQuestDataChange();
        SaveManager.save();
    end
    triggerEvent("OnQSystemUpdate", 3);
end

function Action:complete()
    self.completed = true;
    triggerEvent("OnQSystemUpdate", 3);
end

function Action:new(internal)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.internal = internal;
    o.pending = false;
    o.completed = false;
    return o
end