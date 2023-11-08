-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

SaveManager = {}
SaveManager.enabled = true;
SaveManager.busy = false;

SaveManager.dataType = { "characters", "quests" }
SaveManager.flags = { false, false }

SaveManager.onCharacterDataChange = function (forced)
    if (QSystem.initialised and SaveManager.enabled) or forced then
        SaveManager.flags[1] = true;
    end
end

SaveManager.onQuestDataChange = function (forced)
    if (QSystem.initialised and SaveManager.enabled) or forced then
        SaveManager.flags[2] = true;
    end
end

SaveManager.pending = function ()
    for i=1, #SaveManager.flags do
        if SaveManager.flags[i] then return true; end
    end
end

SaveManager.load = function(progress)
    if progress[1] then
        CharacterManager.instance.flags = progress[1].flags or {}; -- flags
        CharacterManager.instance.flags_size = #CharacterManager.instance.flags;
        CharacterManager.instance.events = progress[1].events or {}; -- events
        -- last_save
        local status, value = pcall(tonumber, progress[1].last_save);
        if status and value then
            local world_age = GetWorldAgeSeconds();
            if world_age < value then -- reset events if world had character_id reset
                CharacterManager.instance.events = {};
            end
            CharacterManager.instance.last_save = world_age;
        end
        CharacterManager.instance.events_size = #CharacterManager.instance.events;
        CharacterManager.instance.achievements = progress[1].achievements or {};
        CharacterManager.instance.achievements_size = #CharacterManager.instance.achievements;

        for character_id=1, CharacterManager.instance.items_size do
            for i=1, #progress[1] do
                if CharacterManager.instance.items[character_id].file == progress[1][i].file and CharacterManager.instance.items[character_id].mod == progress[1][i].mod and CharacterManager.instance.items[character_id].name == progress[1][i].name then
                    -- stats
                    CharacterManager.instance.items[character_id].stats = progress[1][i].stats;
                    -- cleared quests
                    status, value = pcall(tonumber, progress[1][i].cleared_quests);
                    if status and value then
                        CharacterManager.instance.items[character_id].cleared_quests = value;
                    end
                    -- alive
                    if progress[1][i].alive == 1 then
                        CharacterManager.instance.items[character_id].alive = true;
                    elseif progress[1][i].alive == 0 then
                        CharacterManager.instance.items[character_id].alive = false;
                    end
                    -- revealed
                    if progress[1][i].revealed == 1 then
                        CharacterManager.instance.items[character_id].revealed = true;
                    elseif progress[1][i].revealed == 0 then
                        CharacterManager.instance.items[character_id].revealed = false;
                    end
                    QuestLogger.print("[QSystem*] SaveManager: Loaded data for character - "..tostring(CharacterManager.instance.items[character_id].name))
                    break;
                end
            end
        end
    end

    if progress[2] then
        local daily_reset, weekly_reset;
        -- для каждого квеста...
        for quest_id=1, QuestManager.instance.quests_size do
            -- берём данные прогресса квестов
            for b=1, #progress[2] do
                if progress[2][b].file == QuestManager.instance.quests[quest_id].file and progress[2][b].mod == QuestManager.instance.quests[quest_id].mod then
                    for c=1, #progress[2][b].data do
                        if progress[2][b].data[c].internal == QuestManager.instance.quests[quest_id].internal then
                            local quest_data = progress[2][b].data[c];

                            -- recurring quests
                            if quest_data.date then
                                local tm = GetCurrentTime();
                                local date = quest_data.date:ssplit('-');
                                for args=1, #date do
                                    local status;
                                    status, date[args] = pcall(tonumber, date[args]);
                                    if not status or not date[args] then
                                        print("[QSystem] SaveManager: Failed to parse date of quest - "..tostring(QuestManager.instance.quests[quest_id].internal))
                                        return;
                                    end
                                end

                                if quest_data.status > 1 then -- only reset completed/failed daily and weekly quests
                                    if QuestManager.instance.quests[quest_id].daily then
                                        if tm.tm_year > date[1] or (tm.tm_year == date[1] and (tm.tm_mon > date[2] or (tm.tm_mon == date[2] and tm.tm_mday > date[3]))) then
                                            QuestLogger.print("[QSystem*] SaveManager: Reset daily quest - "..tostring(QuestManager.instance.quests[quest_id].internal))
                                            SaveManager.onQuestDataChange(true);
                                            daily_reset = true;
                                            break;
                                        end
                                    elseif QuestManager.instance.quests[quest_id].weekly then
                                        if tm.tm_year > date[1] or (tm.tm_year == date[1] and tm.tm_yday > date[4]) then
                                            QuestLogger.print("[QSystem*] SaveManager: Reset weekly quest - "..tostring(QuestManager.instance.quests[quest_id].internal))
                                            SaveManager.onQuestDataChange(true);
                                            weekly_reset = true;
                                            break;
                                        end
                                    end
                                end

                                QuestManager.instance.quests[quest_id].date = quest_data.date; -- restore unlock date
                            end

                            QuestManager.instance.quests[quest_id].pid = nil;
                            if quest_data.status == 0 then -- locked
                                QuestManager.instance.quests[quest_id].unlocked = false;
                                QuestManager.instance.quests[quest_id].completed = false;
                                QuestManager.instance.quests[quest_id].failed = false;
                            else -- unlocked
                                QuestManager.instance.quests[quest_id].unlocked = true;
                                if quest_data.status == 1 then -- unlocked
                                    QuestManager.instance.quests[quest_id].completed = false;
                                    QuestManager.instance.quests[quest_id].failed = false;

                                    for task_id=1, QuestManager.instance.quests[quest_id].tasks_size do
                                        for args=1, #quest_data.tasks do
                                            local task_data = quest_data.tasks[args];
                                            if QuestManager.instance.quests[quest_id].tasks[task_id].internal == task_data[1] then
                                                QuestManager.instance.quests[quest_id].tasks[task_id].pid = nil;
                                                if task_data[2] == 0 then -- locked
                                                    QuestManager.instance.quests[quest_id].tasks[task_id].unlocked = false;
                                                    QuestManager.instance.quests[quest_id].tasks[task_id].pending = false;
                                                    QuestManager.instance.quests[quest_id].tasks[task_id].completed = false;
                                                else -- unlocked
                                                    if task_data[2] == 1 then -- unlocked
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].pending = false;
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].completed = false;
                                                        if task_data[3] then QuestManager.instance.quests[quest_id].tasks[task_id].extdata = task_data[3]; end
                                                    elseif task_data[2] == 2 then -- pending
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].completed = false;
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].pending = true;
                                                    elseif task_data[2] == 3 then -- completed
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].completed = true;
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].pending = true;
                                                    end
                                                    QuestManager.instance.quests[quest_id].tasks[task_id].unlocked = true;
                                                end

                                                if QuestManager.pause then -- reset actions (on load state)
                                                    for action_id=1, QuestManager.instance.quests[quest_id].tasks[task_id].actions_size do
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].pending = false;
                                                        QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].completed = false;
                                                    end
                                                end

                                                if task_data[4] then
                                                    for action_id=1, QuestManager.instance.quests[quest_id].tasks[task_id].actions_size do
                                                        for data_id=1, #task_data[4] do
                                                            if QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].hash and QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].hash == task_data[4][data_id] then
                                                                QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].completed = true;
                                                                QuestManager.instance.quests[quest_id].tasks[task_id].actions[action_id].pending = true;
                                                                task_data[4][data_id] = nil;
                                                                break;
                                                            end
                                                        end
                                                    end
                                                end
                                                break;
                                            end
                                        end
                                    end
                                elseif quest_data.status == 2 then -- completed
                                    QuestManager.instance.quests[quest_id].completed = true;
                                    QuestManager.instance.quests[quest_id].failed = false;
                                elseif quest_data.status == 3 then -- failed
                                    QuestManager.instance.quests[quest_id].completed = false;
                                    QuestManager.instance.quests[quest_id].failed = true;
                                end
                            end
                            QuestLogger.print("[QSystem*] SaveManager: Loaded data for quest - "..tostring(QuestManager.instance.quests[quest_id].internal))
                            break;
                        end
                    end
                end
            end
        end

        if isClient() then
            if weekly_reset then
                QuestLogger.report(getTextOrNull("UI_QSystem_Logger_WeeklyReset") or "<RGB:0.5,1.0,1.0> [INFO] Weekly quests have been reset.")
            end
            if daily_reset then
                QuestLogger.report(getTextOrNull("UI_QSystem_Logger_DailyReset") or "<RGB:0.5,1.0,1.0> [INFO] Daily quests have been reset.")
            end
        end
    end
end

SaveManager.save = function (forced, debug)
    if forced then
        for i=1, #SaveManager.flags do
            SaveManager.flags[i] = true;
        end
    elseif not SaveManager.pending() or not SaveManager.enabled then
        return;
    end

    if not SaveManager.busy then
        local function save()
            local data = SaveManager.data(); -- FIXME: implement sava data dividing to eliminate possibility of buffer overflow
            local size = 0;
            for i=1, #SaveManager.dataType do
                size = size + string.len(data[i] or "");
            end
            if size > 31800 then
                print("[QSystem] SaveManager: Unable to save progress due to buffer overflow.");
            else
                if QSystem.network then
                    local player = getPlayer();
                    if player then
                        local steamid = getCurrentUserSteamID() or player:getUsername();
                        sendClientCommand(player, 'QSystem', 'saveData', {steamid, data, debug});
                    else
                        print("[QSystem] SaveManager: Unable to get player data!");
                    end
                else
                    local file = tostring(getWorld():getWorld());
                    SaveManager.writeData(file, data);
                    print("[QSystem] SaveManager: Progress saved.");
                end
            end
            SaveManager.busy = false;
        end

        if debug then
            save();
        else
            SaveManager.busy = true;
            SSRTimer.add_s(save, 1, false);
        end
    end
end


local serpent = require("serpent");

SaveManager.data = function(debug) -- returns serialized player data
	local data = {};

    if SaveManager.flags[1] then
        local progress = {};
        progress.flags = CharacterManager.instance.flags;
        progress.events = CharacterManager.instance.events;
        progress.achievements = CharacterManager.instance.achievements;
        CharacterManager.instance.last_save = GetWorldAgeSeconds();
        progress.last_save = CharacterManager.instance.last_save;
        for i=1, CharacterManager.instance.items_size do
            local char = {}
            char.file = CharacterManager.instance.items[i].file;
            char.mod = CharacterManager.instance.items[i].mod;
            char.name = CharacterManager.instance.items[i].name;
            char.cleared_quests = CharacterManager.instance.items[i].cleared_quests;
            char.alive = CharacterManager.instance.items[i].alive and 1 or 0;
            char.revealed = CharacterManager.instance.items[i].revealed and 1 or 0;
            char.stats = CharacterManager.instance.items[i].stats;
            progress[i] = char;
        end
        data[1] = serpent.dump(progress);
        SaveManager.flags[1] = false;
    else
        data[1] = false;
    end

    if SaveManager.flags[2] then
        local progress = {};
        local function get_id(file, mod)
            for i=1, #progress do
                if progress[i].file == file and progress[i].mod == mod then
                    return i;
                end
            end

            return -1;
        end

        for i=1, QuestManager.instance.quests_size do
            local q = QuestManager.instance.quests[i];
            if debug or q.unlocked then
                local file_id = get_id(q.file, q.mod)

                if file_id == -1 then
                    local t = {};
                    t.file = q.file;
                    t.mod = q.mod;
                    t.data = {};
                    file_id = #progress+1;
                    progress[file_id] = t;
                end

                local quest = {};
                quest.internal = q.internal;
                quest.status = 0;

                if q.completed then -- completed
                    quest.status = 2;
                elseif q.failed then -- failed
                    quest.status = 3;
                elseif q.unlocked then -- unlocked
                    quest.status = 1;
                end

                if q.date then
                    quest.date = q.date; -- save unlock date for recurring quests
                end

                if debug or quest.status == 1 then -- don't save tasks for completed/failed quests
                    quest.tasks = {};

                    for j=1, q.tasks_size do
                        local t = q.tasks[j];
                        local task = {};
                        task[1] = t.internal
                        task[2] = 0;

                        if t.completed then -- completed
                            task[2] = 3;
                        elseif t.pending then -- pending
                            task[2] = 2;
                        elseif t.unlocked then -- unlocked
                            task[2] = 1;
                            if t.extdata then
                                task[3] = t.extdata;
                            end
                        end

                        if task[2] ~= 3 then -- if task isn't completed
                            local actions = {}
                            for k=1, t.actions_size do
                                if t.actions[k].pending and t.actions[k].hash then -- save completed state for eligible actions
                                    actions[#actions+1] = t.actions[k].hash;
                                end
                            end

                            if actions[1] then
                                task[4] = actions;
                            end
                        end

                        quest.tasks[j] = task;
                    end
                end

                progress[file_id].data[#progress[file_id].data+1] = quest;
            end
        end
        data[2] = serpent.dump(progress)
        SaveManager.flags[2] = false;
    else
        data[2] = false;
    end

	return data;
end

local function readData(path)
    local reader = getFileReader(path, false);
    if reader then
        local lines = {};
        local line = reader:readLine();
        local count = 1;
        while line ~= nil do
            lines[count] = line;
            line = reader:readLine();
            count = count + 1;
        end
        reader:close();
        return table.concat(lines);
    else
        return false;
    end
end

SaveManager.readData = function(steamid) -- reads quest/characters data from files
	local args = {};

    for i=1, #SaveManager.dataType do
        args[i] = readData("QSystem/"..tostring(steamid).."_"..tostring(SaveManager.dataType[i])..".txt")
    end

	return args;
end

SaveManager.writeData = function(steamid, data) -- writes quest/characters data to files
    for i=1, #SaveManager.dataType do
        if data[i] then
            local path = "QSystem/"..tostring(steamid).."_"..tostring(SaveManager.dataType[i])..".txt";
            local writer = getFileWriter(path, true, false);
            writer:write(data[i]);
            writer:close();
            QuestLogger.print("[QSystem*] SaveManager: Writing "..tostring(SaveManager.dataType[i]).." data...");
        end
    end

	QuestLogger.print("[QSystem*] SaveManager: Progress saved. ID="..tostring(steamid))
end