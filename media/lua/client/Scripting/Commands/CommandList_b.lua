-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Objects/Command"

local type_quest = "QScript"
local type_quest_desc = { "Quest", "Task" }

local function is_end_create(layer, line_count, next_index, next_line)
    if next_index > line_count then
        return true;
    end

    if GetBlockLayer(next_line) < layer or next_line:trim() == "" then
        return true;
    end

    return false;
end

-- Commands (Quest Manager)

-- quest internal|arg1,arg2
local quest = Command:derive("quest")
function quest:execute(sender)
    self:debug();
    for i=1, QuestManager.instance.quests_size do
        if QuestManager.instance.quests[i].internal == self.args[1] then
            return "Attempt to create quest with existing ID '"..tostring(self.args[1]).."'";
        end
    end
    if QuestManager.instance:begin_create(self.args[1], sender.file, sender.mod) then
        for i=2, #self.args do
            if self.args[i] == "unlocked" then
                if QuestManager.instance.creator.quest.event then
                    return "Attempt to make quest both unlocked and event";
                else
                    QuestManager.instance.creator.quest.unlocked = true;
                    QuestManager.instance.creator.quest.default = true;
                end
            elseif self.args[i] == "hidden" then
                QuestManager.instance.creator.quest.hidden = true;
            elseif self.args[i] == "daily" then
                if QuestManager.instance.creator.quest.weekly then
                    return "Attempt to make quest both daily and weekly";
                else
                    QuestManager.instance.creator.quest.daily = true;
                end
            elseif self.args[i] == "weekly" and not QuestManager.instance.creator.quest.daily then
                if QuestManager.instance.creator.quest.daily then
                    return "Attempt to make quest both daily and weekly";
                else
                    QuestManager.instance.creator.quest.weekly = true;
                end
            elseif self.args[i]:starts_with("event/") then
                if QuestManager.instance.creator.quest.unlocked then
                    return "Attempt to make quest both unlocked and event";
                else
                    local args = self.args[i]:ssplit("/");
                    if #args == 2 then
                        QuestManager.instance.creator.quest.event = args[2];
                    end
                end
            else
                return "Unknown flag in argument "..tostring(i).."";
            end
        end

        local next_index = sender.index+1;
        if is_end_create(sender.layer, sender:size(), next_index, sender:get(next_index)) then
            QuestManager.instance:end_create();
        end
    else
        return "Quest limit reached (1000)";
    end
end

local task = Command:derive("task")
function task:execute(sender)
    self:debug();
    if QuestManager.instance.creator then
        if sender.layer == 1 then
            for i=1, QuestManager.instance.creator.quest.tasks_size do
                if QuestManager.instance.creator.quest.tasks[i].internal == self.args[1] then
                    return "Attempt to create task for quest '"..tostring(QuestManager.instance.creator.quest.internal).."' with existing ID '"..tostring(self.args[1]).."'";
                end
            end
            local internal = self.args[1];
            local unlocked = false;
            local hidden = QuestManager.instance.creator.quest.hidden;
            for i=2, #self.args do
                if self.args[i] == "unlocked" then
                    unlocked = true;
                elseif self.args[i] == "hidden" then
                    hidden = true;
                end
            end

            local task_type = nil;
            local task_args = {};

            local actions = {};
            local actions_size = 0;

            local skipped = 1;

            if GetBlockLayer(sender.lines[sender.index+skipped]) <= sender.layer then
                return "Missing indent in task block";
            end

            while GetBlockLayer(sender.lines[sender.index+skipped]) > sender.layer do
                local line = sender.lines[sender.index+skipped]:trim();
                if line == "" then
                    break; -- end of block
                elseif line:starts_with("#set ") then
                    task_args = line:sub(6):ssplit('|');
                    if task_type then print(string.format("[QSystem] (Warning) Task '%s' was redefined (%s -> %s) at line %i. File=%s, Mod=%s, Command=#set", internal, tostring(task_type), tostring(task_args[1]), sender.index+skipped, tostring(sender.file), tostring(sender.mod))) end
                    task_type = table.remove(task_args, 1);
                elseif line:starts_with("#action ") then
                    local action = {};
                    action.args = line:sub(9):ssplit('|');
                    action.type = table.remove(action.args, 1);
                    actions_size = actions_size + 1; actions[actions_size] = action;
                else
                    QuestLogger.print("[QSystem*] #task: Skipped argument "..tostring(line));
                end
                skipped = skipped + 1;
            end

            if task_type then
                local object = QuestManager.instance.creator:create_task(task_type, internal, task_args)
                if object then
                    local task_id = QuestManager.instance.creator.quest.tasks_size+1;
                    QuestManager.instance.creator.quest.tasks_size = task_id;
                    QuestManager.instance.creator.quest.tasks[task_id] = object;
                    QuestManager.instance.creator.quest.tasks[task_id].hidden = hidden;
                    QuestManager.instance.creator.quest.tasks[task_id].quest_id = QuestManager.instance.creator.quest.index;
                    for i=1, actions_size do
                        local action = QuestManager.instance.creator:create_action(actions[i].type, actions[i].args);
                        if action then
                            QuestManager.instance.creator.quest.tasks[task_id]:addAction(action);
                            QuestLogger.print("[QSystem*] #action: "..actions[i].type);
                        else
                            print(string.format("[QSystem] (Error) Unable to load action of type '%s' at line %i. File=%s, Mod=%s, Command=#action", tostring(actions[i].type), sender.index, tostring(sender.file), tostring(sender.mod)));
                        end
                    end
                    QuestManager.instance.creator.quest.tasks[task_id].unlocked = unlocked;
                    QuestManager.instance.creator.quest.tasks[task_id].default = unlocked and true or false;
                else
                    print(string.format("[QSystem] (Error) Unable to load task of type '%s' at line %i. File=%s, Mod=%s, Command=#set", tostring(task_type), sender.index, tostring(sender.file), tostring(sender.mod)));
                end
            else
                print(string.format("[QSystem] (Error) Task is undefined at line %i. File=%s, Mod=%s, Command=#task", sender.index, tostring(sender.file), tostring(sender.mod)));
            end

            sender.index = sender.index+skipped-1;
        else
            return "Missing indent in quest block";
        end
    else
        return "Task doesn't belong to any quest";
    end

    local next_index = sender.index+1;
    if is_end_create(sender.layer, sender:size(), next_index, sender:get(next_index)) then
        QuestManager.instance:end_create();
    end
end

CommandList_b[#CommandList_b+1] = quest:new("quest", 1, 4, type_quest);
CommandList_b[#CommandList_b+1] = task:new("task", 1, 3, type_quest);

-- Commands (Quest Panel)

local name = Command:derive("name")
function name:execute(sender)
    self:debug();
    sender.name = self.args[1];
    return true;
end

local desc = Command:derive("desc")
function desc:execute(sender)
    self:debug();
    sender.description = self.args[1];
    return true;
end

CommandList_b[#CommandList_b+1] = name:new("name", 1, nil, type_quest_desc);
CommandList_b[#CommandList_b+1] = desc:new("desc", 1, nil, type_quest_desc);