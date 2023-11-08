-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/ScriptManagerNeo"
require "Communications/QSystem"

QuestManager = ScriptManagerNeo:derive("QuestManager");
QuestManager.pause = true;

function QuestManager:end_create()
    if self.creator then
        self.quests_size = self.quests_size + 1; self.quests[self.quests_size] = self.creator:result();
        QuestLogger.print("[QSystem*] QuestManager: end_create - "..self.creator.quest.internal)
        self.creator = nil;
    end
end

function QuestManager:begin_create(name, file, mod)
    self:end_create(); -- finalize creation of previous quest, if not yet done
    if self.quests_size < 1000 then
        self.creator = QuestCreator:new(name, file, mod);
        QuestLogger.print("[QSystem*] QuestManager: begin_create - "..self.creator.quest.internal);
        return true;
    end
end

function QuestManager:getQuest(internal)
    for i = 1, self.quests_size do
        if self.quests[i].internal == internal then
            return self.quests[i]
        end
    end

    return nil
end

function QuestManager:getActiveQuest()
    for i = 1, self.quests_size do
        if self.quests[i].unlocked and not self.quests[i].hidden and not self.quests[i].completed and not self.quests[i].failed then
            return self.quests[i];
        end
    end

    return nil;
end

function QuestManager:getIndex(name)
    for i = 1, self.quests_size do
        if self.quests[i].name == name then
            return i
        end
    end

    return -1
end

function QuestManager:create_script(file, mod)
	return QScript:new(file, mod)
end

function QuestManager:parse(file, mod, language)
    local script = self:load_script(file, mod, true, language);
    if script == nil then return end

    local start_index = self.quests_size + 1;

    -- importing quests
    while true do
        local result = script:play(script);

        if result then
            if type(result) == 'string' then print(result) end
            break;
        end
    end

    local name = file:sub(1, file:lastIndexOf('.'));
    local quest_strings = self:load_script(name.."_quests.txt", mod, true, language);
    local task_strings = self:load_script(name.."_tasks.txt", mod, true, language);

    -- loading quest descriptions
    for i=start_index, self.quests_size do
        if not self.quests[i].hidden then
            local quest_id = tostring(self.quests[i].internal);
            if quest_strings then -- if file exists
                if quest_strings:jump(quest_id) then -- if label exists and jump is successful
                    if quest_strings:play(self.quests[i]) then -- name
                        if not quest_strings:play(self.quests[i]) then -- desc
                            print("[QSystem] QuestManager: Unexpected string intead of quest desc at line "..quest_strings.index-1);
                        end
                    else
                        print("[QSystem] QuestManager: Unexpected string intead of quest name at line "..quest_strings.index-1);
                    end
                end
            end

            if task_strings then -- if file exists
                for j = 1, #self.quests[i].tasks do
                    if not self.quests[i].tasks[j].hidden then -- don't lookup name for hidden tasks
                        local task_id = tostring(self.quests[i].tasks[j].internal);
                        if task_strings:jump(quest_id.."_"..task_id) then -- if label exists and jump is successful
                            if not task_strings:play(self.quests[i].tasks[j]) then -- name
                                print("[QSystem] QuestManager: Unexpected string intead of task name at line "..task_strings.index-1);
                            end
                        end
                    end
                end
            end
        end
    end
end

local quest_id = 1;
function QuestManager:update()
    if self.pid then
        self.quests[self.pid]:update();
        if not self.quests[self.pid].pid then
            self.pid = nil;
        end
    else
        if quest_id > self.active_size then
            quest_id = 1;
        else
            local id = self.active[quest_id];
            if self.quests[id].unlocked and not (self.quests[id].completed or self.quests[id].failed) then
                self.quests[id]:update();
                if self.quests[id].pid then
                    self.pid = id;
                end
            end
            quest_id = quest_id + 1;
        end
    end
end

function QuestManager.onTick()
    if QuestManager.pause then return end
    QuestManager.instance:update();
end

function QuestManager.onCharacterDeath(file, mod) -- mark unlocked quests as failed
    if QuestManager.instance then
        for i=1, QuestManager.instance.quests_size do
            if QuestManager.instance.quests[i].file == file and QuestManager.instance.quests[i].mod == mod then
                if QuestManager.instance.quests[i].unlocked and not QuestManager.instance.quests[i].completed then
                    QuestManager.instance.quests[i]:fail();
                end
            end
        end
    end
end

function QuestManager:new()
    local o = ScriptManagerNeo:new("quests");
    setmetatable(o, self);
    self.__index = self;
    o.quests = {};
    o.quests_size = 0;
    o.active = {};
    o.active_size = 0;
    o.creator = nil;
    o.pid = nil;
    return o;
end

QuestManager.instance = QuestManager:new();

function QuestManager.reset()
    if QuestManager.instance then
        QuestManager.instance.quests_size = 0;
        QuestManager.instance.quests = {};
    end
end

Events.OnQSystemReset.Add(QuestManager.reset);

function QuestManager.onQSystemUpdate(code)
    if code == 4 and QuestManager.instance then
        QuestManager.instance.active = {}; QuestManager.instance.active_size = 0; QuestManager.instance.pid = nil; quest_id = 1;
        for i=1, QuestManager.instance.quests_size do
            QuestManager.instance.quests[i]:reload();
            if QuestManager.instance.quests[i].unlocked and not (QuestManager.instance.quests[i].completed or QuestManager.instance.quests[i].failed) then
                QuestManager.instance.active_size = QuestManager.instance.active_size + 1; QuestManager.instance.active[QuestManager.instance.active_size] = i;
            end
            QuestManager.instance.quests[i]:updateEvent();
        end
    end
end

Events.OnQSystemUpdate.Add(QuestManager.onQSystemUpdate);

function QuestManager.onEventStateChanged(event, status)
    if QuestManager.instance then
        local report = true;
        for i=1, QuestManager.instance.quests_size do
            if QuestManager.instance.quests[i].event == event then
                if report then
                    if status then
                        QuestLogger.report(getText("UI_QSystem_Logger_EventStart", getTextOrNull("UI_QSystem_Event_"..event)));
                    else
                        QuestLogger.report(getText("UI_QSystem_Logger_EventEnd", getTextOrNull("UI_QSystem_Event_"..event)));
                    end
                    report = false;
                end
                QuestManager.instance.quests[i]:updateEvent(status);
            end
        end
        SaveManager.onQuestDataChange();
        triggerEvent("OnQSystemUpdate", 1);
    end
    SaveManager.onCharacterDataChange();
    SaveManager.save();
    triggerEvent("OnQSystemUpdate", 0);
end

Events.OnEventStateChanged.Add(QuestManager.onEventStateChanged);

function QuestManager.start() -- set unlock date for unlocked daily/weekly quests if missing
    if QuestManager.instance then
        for i=1, QuestManager.instance.quests_size do
            if QuestManager.instance.quests[i].unlocked and not QuestManager.instance.quests[i].date and (QuestManager.instance.quests[i].daily or QuestManager.instance.quests[i].weekly)  then
                local tm = GetCurrentTime();
                local tm_wday = tm.tm_wday == 0 and 7 or tm.tm_wday;
                QuestManager.instance.quests[i].date = tostring(tm.tm_year).."-"..tostring(tm.tm_mon).."-"..tostring(tm.tm_mday).."-"..tostring(tm.tm_yday+(7-tm_wday));
                SaveManager.onQuestDataChange(true);
            end
        end
    end
    SaveManager.save();
end

Events.OnQSystemStart.Add(QuestManager.start);
Events.OnQSystemRestart.Add(QuestManager.start);

function QuestManager.onCreatePlayer()
    if QuestManager.instance then
        SSRTimer.add_s(function () QuestManager.pause = false end, 1, false);
    end
end

function QuestManager.onPlayerDeath()
	if QuestManager.instance then
		QuestManager.pause = true;
        if QuestManager.instance.pid then
            local id_1 = QuestManager.instance.pid;
            if QuestManager.instance.quests[id_1].pid then
                local id_2 = QuestManager.instance.quests[id_1].pid;
                for id_3=1, QuestManager.instance.quests[id_1].tasks[id_2].actions_size do
                    if not QuestManager.instance.quests[id_1].tasks[id_2].actions[id_3].completed then
                        if QuestManager.instance.quests[id_1].tasks[id_2].actions[id_3].pending and not QuestManager.instance.quests[id_1].tasks[id_2].actions[id_3].save then
                            QuestManager.instance.quests[id_1].tasks[id_2].actions[id_3]:reset();
                        end
                        break;
                    end
                end
            end
        end
    end
end

Events.OnCreatePlayer.Add(QuestManager.onCreatePlayer);
Events.OnPlayerDeath.Add(QuestManager.onPlayerDeath);