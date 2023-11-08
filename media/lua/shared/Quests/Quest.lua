-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"

Quest =  ISBaseObject:derive("Quest")

local function markTasksAsCompleted(self)
    for i=1, self.tasks_size do
        if not self.tasks[i].completed and self.tasks[i].unlocked then
            self.tasks[i]:complete();
        end
    end
end

local function markTasksAsFailed(self)
    for i=1, self.tasks_size do
        if not self.tasks[i].completed and self.tasks[i].unlocked then
            self.tasks[i]:lock();
        end
    end
end

local function set_active(index) -- adds entry to the list of active quests
    if QuestManager.instance then
        QuestManager.instance.active_size = QuestManager.instance.active_size + 1; QuestManager.instance.active[QuestManager.instance.active_size] = index;
    end
end

local function set_inactive(index) -- removes entry from the list of active quests
    if QuestManager.instance then
        for i=1, QuestManager.instance.active_size do
            if QuestManager.instance.active[i] == index then
                table.remove(QuestManager.instance.active, i); QuestManager.instance.active_size = QuestManager.instance.active_size - 1;
                return;
            end
        end
    end
end


function Quest:update()
    if self.pid then
        if self.tasks[self.pid].unlocked and self.tasks[self.pid].pending and not self.tasks[self.pid].completed then
            self.tasks[self.pid]:update();
        else
            self.pid = nil;
        end
    else
        local i = 1;
        while i <= self.active_size do
            local id = self.active[i];
            if self.tasks[id].unlocked and not self.tasks[id].completed then
                self.tasks[id]:update();
                if self.tasks[id].completed then
                    i = i - 1;
                elseif self.tasks[id].pending then
                    self.pid = id;
                    break;
                end
            end
            i = i + 1;
        end
    end
end

function Quest:reload() -- for debugging purposes
    self.active_size = 0; self.active = {}; self.pid = nil;
    for i=1, self.tasks_size do
        if self.tasks[i].unlocked and not self.tasks[i].completed then
            self.tasks[i]:reload();
            self.active_size = self.active_size + 1; self.active[self.active_size] = i;
        end
    end
end

function Quest:reset()
    if self.unlocked and not self.completed and not self.failed then
        if not self.default then
            set_inactive(self.index); -- update the list of active quests
        end
    elseif self.default then
        set_active(self.index) -- update the list of active quests
    end
    self.unlocked = self.default;
    for i=1, self.tasks_size do
        self.tasks[i]:reset();
    end
    if self.unlocked and (self.daily or self.weekly) then -- save unlock date for recurring quests
        local tm = GetCurrentTime();
        local tm_wday = tm.tm_wday == 0 and 7 or tm.tm_wday;
        self.date = tostring(tm.tm_year).."-"..tostring(tm.tm_mon).."-"..tostring(tm.tm_mday).."-"..tostring(tm.tm_yday+(7-tm_wday));
    else
        self.date = nil;
    end
    self.completed = false;
    self.failed = false;
    self.pid = nil;
    SaveManager.onQuestDataChange();
    SaveManager.save();
    triggerEvent("OnQSystemUpdate", 1);
end

function Quest:updateEvent(status)
    if self.event then
        if status == nil then
            status = CharacterManager.instance:isEvent(self.event);
        end
        if status == true and not self.unlocked then
            self:unlock();
        elseif status == false and self.unlocked then
            self:reset();
        end
    end
end

function Quest:complete()
    if not self.completed and not self.failed then
        markTasksAsCompleted(self);
        self.completed = true;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 1);
        if CharacterManager.instance then
            CharacterManager.instance:onQuestCompleted(self.file, self.mod)
        end
        if not isServer() and not self.hidden then
            local function callback()
                if isClient() then
                    QuestLogger.report(getText("UI_QSystem_Logger_QuestCompleted", self:getName()));
                end
            end
            NotificationManager.add(callback, "questCompleted", true);
        end
        set_inactive(self.index); -- update the list of active quests
    end
end

function Quest:fail()
    if not self.failed and not self.completed then
        markTasksAsFailed(self);
        self.failed = true;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 1);
        if not isServer() and not self.hidden then
            local function callback()
                if isClient() then
                    QuestLogger.report(getText("UI_QSystem_Logger_QuestFailed", self:getName()));
                end
            end
            NotificationManager.add(callback, "questFailed", true);
        end
        set_inactive(self.index); -- update the list of active quests
    end
end

function Quest:unlock()
    if not self.unlocked then
        if self.daily or self.weekly then -- save unlock date for recurring quests
            local tm = GetCurrentTime();
            local tm_wday = tm.tm_wday == 0 and 7 or tm.tm_wday;
            self.date = tostring(tm.tm_year).."-"..tostring(tm.tm_mon).."-"..tostring(tm.tm_mday).."-"..tostring(tm.tm_yday+(7-tm_wday));
        end
        for i=1, self.tasks_size do
            if self.tasks[i].unlocked then
                self.tasks[i]:unlock(); -- trigger possible special events on task:unlock() overrides
            end
        end
        self.unlocked = true;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 1);
        if not isServer() and not self.hidden then
            local notify = not QInterface.instance:isTab(1);
            local function callback()
                if isClient() then
                    QuestLogger.report(getText("UI_QSystem_Logger_QuestUnlocked", self:getName()));
                end
                QTracker.track(self, notify);
            end
            if notify then
                NotificationManager.add(callback, "questUnlocked", true);
            else
                NotificationManager.add(callback, nil, true);
            end
        end
        set_active(self.index) -- update the list of active quests
    end
end

function Quest:lock()
    if self.unlocked then
        self.unlocked = false;
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 1);
        set_inactive(self.index); -- update the list of active quests
    end
    self:reload();
end

function Quest:getName()
    if self.name then
        return self.name
    else
        return self.internal
    end
end

function Quest:getDescription()
    if self.description then
        return self.description
    else
        return "n/a"
    end
end

function Quest:getTask(internal)
    for i = 1, self.tasks_size do
        if self.tasks[i].internal == internal then
            return self.tasks[i];
        end
    end

    return nil;
end

function Quest:new(internal, file, mod)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.index = QuestManager.instance.quests_size+1;

    o.internal = internal;
    o.name = nil;
    o.description = nil;

    o.tasks = {};
    o.tasks_size = 0;

    o.active = {}; -- unlocked tasks
    o.active_size = 0;

    o.hidden = false;

    o.completed = false;
    o.failed = false;
    o.unlocked = false;

    o.daily = false;
    o.weekly = false;
    o.event = nil;
    o.date = nil;

    o.file = file;
    o.mod = mod;

    o.pid = nil;
    o.default = false; -- default value of unlocked
    return o;
end