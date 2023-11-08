-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

QuestCreator = {};
QuestCreator.tasks = {};
QuestCreator.actions = {};

function QuestCreator:result()
    return self.quest;
end

function QuestCreator:create_task(task_type, internal, args)
    if task_type then
        for i=1, #QuestCreator.tasks do
            if QuestCreator.tasks[i].type == task_type then
                local result = QuestCreator.tasks[i].create(internal, args);
                if type(result) == "string" then
                    print(string.format("[QSystem] (Error) %s. Task=%s", result, task_type));
                    return;
                end
                return result;
            end
        end
    end
end

function QuestCreator:create_action(action_type, args)
    if action_type then
        for i=1, #QuestCreator.actions do
            if QuestCreator.actions[i].type == action_type then
                local hash = nil;
                if QuestCreator.actions[i].save then hash = tostring(LibDeflate:Crc32(action_type..table.concat(args), 0)) end
                local result = QuestCreator.actions[i].create(args);
                if type(result) == "string" then
                    print(string.format("[QSystem] (Error) %s. Action=%s", result, action_type));
                    return;
                end
                result.hash = hash;
                return result;
            end
        end
    end
end

function QuestCreator:new(name, file, mod)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.quest = Quest:new(name, file, mod);
    return o;
end