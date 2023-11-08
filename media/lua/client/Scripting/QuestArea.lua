-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Communications/QSystem"

QuestArea = {};
QuestArea.list = {}; -- list of ids

local area_list = {};
local current_area = nil;
local leaving = false; -- triggered on area exit execute to execute script if exists

function QuestArea.current() -- returns current area id
    if current_area then
        return current_area.id;
    end
end

function QuestArea.isPlayingMusic() -- returns current area id
    if current_area then
        return current_area.bgm;
    end
end

function QuestArea.bgm(value, id) -- sets BGM for current area
    if id then
        for i=#area_list, 1, -1 do
            if area_list[i].id == id then
                area_list[i].bgm = value;
                return true;
            end
        end
    elseif current_area then
        current_area.bgm = value or false;
        return true;
    end
end


function QuestArea.create(id, zones, priority, bgm, default, script, label, callback_1, callback_2)
    local pos = 1;
    for i=#area_list+1, 1, -1 do
        if i > 1 then
            if priority < area_list[i-1].priority then
                pos = i;
                break;
            end
        end
    end
    local area = { id = id, zones = zones, priority = priority, bgm = bgm, default = default, script = script, label = label, update = callback_1, onRelease = callback_2 }
    table.insert(area_list, pos, area);
    QuestArea.update();
    return area_list[pos];
end

function QuestArea.release(id) -- deletes specified area
    for i=#area_list, 1, -1 do
        if area_list[i].id == id then
            if current_area == area_list[i] then
                current_area = nil;
                AudioManager.onScriptExit();
                leaving = false;
            end
            if area_list[i].onRelease then
                area_list[i].onRelease();
            end
            table.remove(area_list, i);
            return;
        end
    end
end

function QuestArea.restore(id) -- restores default BGM for specified area
    for i=#area_list, 1, -1 do
        if area_list[i].id == id then
            area_list[i].bgm = area_list[i].default;
            return;
        end
    end
end

function QuestArea.exists(id) -- checks if quest area with specified id already exists
    for i=#QuestArea.list, 1, -1 do
        if QuestArea.list[i] == id then
            return true;
        end
    end
end

local function validate(x, y, z, zones) -- check if player is inside quest zone
    for i=1, #zones do
        if x >= zones[i].x1 and x <= zones[i].x2 and y >= zones[i].y1 and y <= zones[i].y2 then
            if (z == zones[i].z or not zones[i].z) then
                return true;
            end
        end
    end
end

function QuestArea.update(forced)
    local player = getPlayer();
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ());

    if current_area then
        if validate(x, y, z, current_area.zones) then
            current_area.update();
            if leaving then -- if player went back to quest area during on area exit sequence
                if DialoguePanel.instance then
                    return;
                else
                    leaving = false;
                end
            end
            if current_area.bgm and (forced or not DialoguePanel.instance) then
                if current_area.bgm == "m" then
                    if not AudioManager.isMusicMuted() then
                        AudioManager.stop(1);
                    end
                elseif not AudioManager.isPlayingMusic(current_area.bgm) then
                    AudioManager.playBGM(current_area.bgm, true, false);
                end
            end
        else
            if leaving then
                if DialoguePanel.instance then
                    return;
                else
                    current_area = nil;
                end
            else
                leaving = true;
                if current_area.script then
                    DialoguePanel.create(current_area.script, current_area.label, true);
                end
                return QuestArea.update();
            end
        end
    end

    for i=1, #area_list do
        if validate(x, y, z, area_list[i].zones) then
            if current_area then
                if area_list[i] == current_area then
                    leaving = false;
                    return;
                elseif area_list[i].priority > current_area.priority then
                    current_area = area_list[i];
                    if leaving then -- stop bgm on quest area exit
                        AudioManager.onScriptExit(); leaving = false;
                    end
                    return QuestArea.update();
                end
            else
                current_area = area_list[i];
                if leaving then -- stop bgm on quest area exit
                    AudioManager.onScriptExit(); leaving = false;
                end
                return QuestArea.update();
            end
        end
    end
    if leaving then -- stop bgm on quest area exit
        AudioManager.onScriptExit(); leaving = false;
    end
end

function QuestArea.reset()
    current_area = nil;
    leaving = false;
    for i in pairs(area_list) do
        if area_list[i].onRelease then
            area_list[i].onRelease();
        end
        area_list[i] = nil;
    end
    area_list = {}
    QuestArea.list = {};
end

function QuestArea.init()
    SSRTimer.add_ms(QuestArea.update, 500, true);
    Events.OnScriptExit.Add(QuestArea.update);
end

Events.OnQSystemStart.Add(QuestArea.init);
Events.OnQSystemReset.Add(QuestArea.reset);

function QuestArea.onQSystemUpdate(code)
    if code == 4 then
        if QuestManager.instance then
            for i=1, #QuestManager.instance.quests do
                if QuestManager.instance.quests[i].unlocked and not QuestManager.instance.quests[i].completed and not QuestManager.instance.quests[i].failed then
                    for j=1, #QuestManager.instance.quests[i].tasks do
                        if QuestManager.instance.quests[i].tasks[j].type == "QuestArea" then
                            if QuestManager.instance.quests[i].tasks[j].unlocked and not QuestManager.instance.quests[i].tasks[j].pending and not QuestManager.instance.quests[i].tasks[j].completed then
                                QuestManager.instance.quests[i].tasks[j]:update();
                            end
                        end
                    end
                end
            end
        end
        QuestArea.update();
    end
end

Events.OnQSystemUpdate.Add(QuestArea.onQSystemUpdate);