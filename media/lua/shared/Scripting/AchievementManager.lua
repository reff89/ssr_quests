-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "Communications/QSystem"

AchievementManager = {}
AchievementManager.list = {}
AchievementManager.list_size = 0;

function AchievementManager.add(internal, flag, image, name, description, hidden)
    for i=1, AchievementManager.list_size do
        if AchievementManager.list[i].internal == internal then
            return;
        end
    end

    local item = {};
    item.internal = tostring(internal);
    item.flag = flag;
    if image then
        local path = tostring(image);
        if not path:starts_with("media/ui/") then
            path = "media/ui/"..path;
        end
        local status, texture = pcall(getTexture, path);
        if status and texture then
            item.texture = texture;
        else
            QuestLogger.error = true;
            error("[QSystem] (Error) AchievementManager: Image doesn't exist at specified path", 2);
            return;
        end
    end
    if type(name) == "string" then
        item.name = getTextOrNull(string.format("UI_Achievement_%s_Name", item.internal)) or name;
    else
        QuestLogger.error = true;
        error("[QSystem] (Error) AchievementManager: No name specified", 2);
        return;
    end
    if type(description) == "string" then
        item.description = getTextOrNull(string.format("UI_Achievement_%s_Description", item.internal)) or description;
    end
    item.hidden = hidden or false;
    item.unlocked = false;

    AchievementManager.list_size = AchievementManager.list_size + 1; AchievementManager.list[AchievementManager.list_size] = item;
end

local function validate(id)
    for i=1, CharacterManager.instance.achievements_size do
        if CharacterManager.instance.achievements[i] == id then
            return false;
        end
    end
    return true;
end

function AchievementManager.init()
    if CharacterManager.instance then
        if AchievementManager.list_size > 0 then
            local achievement_id = {};
            for i=#AchievementManager.list, 1, -1 do -- формируем список id записей (порядок инвертирован)
                achievement_id[#achievement_id+1] = i;
            end

            for index=#achievement_id, 1, -1 do -- сразу выкидываем из цикла разблокированные трофеи (из файла сохранения)
                if validate(AchievementManager.list[achievement_id[index]].internal) == false then
                    AchievementManager.list[achievement_id[index]].unlocked = true; -- исключает данный трофей из проверки при добавления нового флага
                    table.remove(achievement_id, index);
                end
            end

            for flag_id=(CharacterManager.instance.flags_size > 0 and 1 or 0), CharacterManager.instance.flags_size do -- в порядке разблокировки флагов
                for index=#achievement_id, 1, -1 do -- проверяем какие трофеи можно разблокировать с текущим набором (от 1 до flag_id)
                    for i=tonumber(flag_id), 1, -1 do
                        if AchievementManager.list[achievement_id[index]].flag == CharacterManager.instance.flags[i] then
                            CharacterManager.instance.achievements_size = CharacterManager.instance.achievements_size + 1;
                            CharacterManager.instance.achievements[CharacterManager.instance.achievements_size] = AchievementManager.list[achievement_id[index]].internal;
                            SaveManager.onCharacterDataChange(true);
                            AchievementManager.list[achievement_id[index]].unlocked = true; -- исключает данный трофей из проверки при добавления нового флага
                            table.remove(achievement_id, index);
                            break;
                        end
                    end
                end
            end
        end
    end
end

Events.OnQSystemStart.Add(AchievementManager.init);


NGP = {}

local protected_flags = {}
local protected_stats = {}

function NGP.start()
    QSystem.pause();
    local flags = {};
    for a=1, CharacterManager.instance.flags_size do
        for b=1, #protected_flags do
            if CharacterManager.instance.flags[a] == protected_flags[b] then
                flags[#flags+1] = CharacterManager.instance.flags[a];
                break;
            end
        end
    end

    local stats = {};
    for a=1, CharacterManager.instance.items_size do
        stats[a] = {};
        for b=1, #CharacterManager.instance.items[a].stats do
            if protected_stats[CharacterManager.instance.items[a].name] then
                for c=1, #protected_stats[CharacterManager.instance.items[a].name] do
                    if protected_stats[CharacterManager.instance.items[a].name][c] == CharacterManager.instance.items[a].stats[b][1] then
                        stats[a][#stats[a]+1] = CharacterManager.instance.items[a].stats[b];
                        break;
                    end
                end
            end
        end
    end

    QImport.reset(function ()
        CharacterManager.instance.flags = flags or {};
        CharacterManager.instance.flags_size = #CharacterManager.instance.flags;
        for a=1, CharacterManager.instance.items_size do
            for b=1, #stats[a] do
                CharacterManager.instance.items[a]:setStat(stats[a][b][1], stats[a][b][2], true);
            end
        end
        SaveManager.save(true);
        QSystem.resume()
    end)
end

function NGP.protect_flag(flag)
    if type(flag) == "string" and flag ~= "" then
        protected_flags[#protected_flags+1] = flag;
    else
        QuestLogger.error = true;
        error("[QSystem] (Error) NGP: Invalid syntax. Usage: NGP.protect_flag(string)", 2);
    end
end

function NGP.protect_stat(character_id, stat_id)
    if (type(character_id) == "string" and type(stat_id) == "string") and (character_id ~= "" and stat_id ~= "") then
        if type(protected_stats[character_id]) ~= "table" then
            protected_stats[character_id] = {};
        end
        protected_stats[character_id][#protected_stats[character_id]+1] = stat_id;
    else
        QuestLogger.error = true;
        error("[QSystem] (Error) NGP: Invalid syntax. Usage: NGP.protect_stat(string, string)", 2);
    end
end