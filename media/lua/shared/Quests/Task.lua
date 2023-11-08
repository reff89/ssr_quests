-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"

Task =  ISBaseObject:derive("Task");

local function set_active(quest_id, index) -- adds entry to the list of active tasks
    if QuestManager.instance then
        if QuestManager.instance.quests[quest_id] then
            QuestManager.instance.quests[quest_id].active_size = QuestManager.instance.quests[quest_id].active_size + 1; QuestManager.instance.quests[quest_id].active[QuestManager.instance.quests[quest_id].active_size] = index;
        end
    end
end

local function set_inactive(quest_id, index) -- removes entry from the list of active tasks
    if QuestManager.instance then
        if QuestManager.instance.quests[quest_id] then
            for i=1, QuestManager.instance.quests[quest_id].active_size do
                if QuestManager.instance.quests[quest_id].active[i] == index then
                    table.remove(QuestManager.instance.quests[quest_id].active, i); QuestManager.instance.quests[quest_id].active_size = QuestManager.instance.quests[quest_id].active_size - 1;
                    return;
                end
            end
        end
    end
end

function Task:update()
    if self.pending and not self.completed then
        for i=1, self.actions_size do
            if not self.actions[i].completed then
                if self.actions[i].pending then
                    self.actions[i]:update();
                else
                    self.actions[i]:execute();
                end
                return;
            end
        end
        self:complete();
        SaveManager.save();
    end
end

function Task:getName()
    if self.name then
        return self.name;
    else
        return self.internal;
    end
end

function Task:getDetails()
    return "";
end

function Task:reload() -- for debugging purposes
    for i=1, self.actions_size do
        self.actions[i]:reload();
    end
end

function Task:reset()
    if self.unlocked and not self.completed then
        if not self.default then
            set_inactive(self.quest_id, self.index); -- update the list of active tasks
        end
    elseif self.default then
        set_active(self.quest_id, self.index) -- update the list of active tasks
    end
    self.unlocked = self.default;
    self.pending = false;
    self.completed = false;
    for i=1, self.actions_size do
        self.actions[i]:reset();
    end
    SaveManager.onQuestDataChange();
    SaveManager.save();
    triggerEvent("OnQSystemUpdate", 2);
end

function Task:unlock(extdata)
    if not self.unlocked then
        self.extdata = extdata or false;
        self.unlocked = true;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 2);
        if not self.hidden then
            NotificationManager.add(nil, "taskUpdated");
        end
        set_active(self.quest_id, self.index); -- update the list of active tasks
    end
end

function Task:lock()
    if self.unlocked then
        self.unlocked = false;
        self.pending = false;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 2);
        set_inactive(self.quest_id, self.index); -- update the list of active tasks
    end
end

function Task:complete()
    if not self.completed then
        self.completed = true;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 2);
        if not self.hidden then
            NotificationManager.add(nil, "taskUpdated");
        end
        set_inactive(self.quest_id, self.index); -- update the list of active tasks
    end
end

function Task:setPending(value)
    if self.pending ~= value then
        self.pending = value;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 2);
        SaveManager.save();
    end
end

function Task:addAction(action)
    self.actions_size = self.actions_size + 1; self.actions[self.actions_size] = action;
end

function Task:new(internal)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.index = QuestManager.instance.creator.quest.tasks_size+1;

    o.internal = internal;
    o.name = nil;

    o.actions = {};
    o.actions_size = 0;

    o.pending = false;

    o.completed = false;
    o.unlocked = false;
    o.hidden = false;

    o.extdata = false;
    o.default = false; -- default value of unlocked
    return o;
end