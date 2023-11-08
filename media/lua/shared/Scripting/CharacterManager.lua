-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/ScriptManagerNeo"
require "Communications/QSystem"

CharacterManager = ScriptManagerNeo:derive("CharacterManager");
CharacterManager.r_min = -999; CharacterManager.r_max = 999; -- minimum / maximum value of stat

QCharacter = {}

function QCharacter:getStat(id)
    for i=1, #self.stats do
        if self.stats[i][1] == id then
            return self.stats[i][2];
        end
    end
end

local function applyLimit(value)
    if value > CharacterManager.r_max then
        value = CharacterManager.r_max;
    elseif value < CharacterManager.r_min then
        value = CharacterManager.r_min
    end
    return value;
end

function QCharacter:setStat(id, value, override)
    local size = #self.stats;
    for i=1, size do
        if self.stats[i][1] == id then
            if override then
                self.stats[i][2] = applyLimit(value);
                SaveManager.onCharacterDataChange();
            end
            return self.stats[i][2];
        end
    end
    self.stats[size+1] = {id, applyLimit(value)};
    SaveManager.onCharacterDataChange();
    return self.stats[size+1];
end

function QCharacter:removeStat(id)
    for i=#self.stats, 1, -1 do
        if self.stats[i][1] == id then
            table.remove(self.stats, i);
            SaveManager.onCharacterDataChange();
            return true;
        end
    end
end

function QCharacter:increaseStat(id, value)
    local size = #self.stats;
    for i=1, size do
        if self.stats[i][1] == id then
            self.stats[i][2] = applyLimit(self.stats[i][2] + value);
            SaveManager.onCharacterDataChange();
            return self.stats[i][2];
        end
    end
    self.stats[size+1] = {id, applyLimit(value)};
    SaveManager.onCharacterDataChange();
    return self.stats[size+1][2];
end

function QCharacter:decreaseStat(id, value)
    local size = #self.stats;
    for i=1, size do
        if self.stats[i][1] == id then
            self.stats[i][2] = applyLimit(self.stats[i][2] - value);
            SaveManager.onCharacterDataChange();
            return self.stats[i][2];
        end
    end
    self.stats[size+1] = {id, applyLimit(0-value)};
    SaveManager.onCharacterDataChange();
    return self.stats[size+1][2];
end

function QCharacter:isAlive()
    return self.alive;
end

function QCharacter:setAlive(value)
    if (self.alive and not value) or (not self.alive and value) then
        self.alive = value;
        if QuestManager.instance and not value then
            QuestManager.onCharacterDeath(self.file, self.mod);
        end
        SaveManager.onCharacterDataChange();
        triggerEvent("OnQSystemUpdate", 0);
    end
end

function QCharacter:isRevealed()
    return self.revealed;
end

function QCharacter:reveal()
    if not self.revealed then
        self.revealed = true;
        if QInterface.instance then
            if QInterface.instance:isTab(2) then
                QInterface.instance.panel[2]:populateList();
            end
        end
        SaveManager.onCharacterDataChange();
        triggerEvent("OnQSystemUpdate", 0);
    end
end

function QCharacter:new(file, mod, language)
    local o = {};
    setmetatable(o, self);
    self.__index = self;

    o.displayName = nil;

    o.name = nil;

    o.alive = true;

    o.cleared_quests = 0;

    o.stats = {};
    o.labels = {};

    o.file = file;
    o.mod = mod;
    o.language = language;

    o.revealed = false;

    return o;
end


function CharacterManager:getCharacterIndex(name) -- @deprecated
    for i = 1, self.items_size do
        if self.items[i].name == name then
            return i
        end
    end

    return -1
end

function CharacterManager:indexOf(char_id)
    for i = 1, self.items_size do
        if self.items[i].name == char_id then
            return i;
        end
    end
end

function CharacterManager:getCharacterStat(char_id, stat_id)
    local index = self:indexOf(char_id);
    if index then
        return self.items[index]:getStat(stat_id);
    end
end

function CharacterManager:onQuestCompleted(file, mod)
    for i = 1, self.items_size do
        if self.items[i].mod == mod and self.items[i].file == file then
            self.items[i].cleared_quests = self.items[i].cleared_quests + 1;
            SaveManager.onCharacterDataChange();
            triggerEvent("OnQSystemUpdate", 0);
            return;
        end
    end
end

function CharacterManager:isEvent(id)
    for i=1, self.events_size do
        if self.events[i][1] == id then
            if self.events[i][3] then
                return getTimestamp() < self.events[i][2];
            else
                return GetWorldAgeSeconds() < self.events[i][2];
            end
        end
    end
    return false;
end

local function calculateTime(ch, cm, h, m, offset)
	local time = h * 3600 + m * 60 + offset * 86400;
	if offset == 0 and (ch > h or (ch == h and cm > m)) then
		time = time + (23 - ch) * 3600 + (60 - cm) * 60;
	else
		time = time - (ch * 3600 + cm * 60);
	end
	return time;
end

function CharacterManager:setEvent(id, time, rt)
    if type(time) == "table" then -- 00:00 format
        if rt then
            local current_time = GetCurrentTime();
            time = getTimestamp() + calculateTime(current_time.tm_hour, current_time.tm_min, time[1], time[2], time[3] or 0);
        else
            time = GetWorldAgeSeconds() + calculateTime(getGameTime():getHour(), getGameTime():getMinutes(), time[1], time[2], time[3] or 0);
        end
    elseif time < 9999 then -- offset format
        if rt then
            time = getTimestamp() + time * 3600;
        else
            time = GetWorldAgeSeconds() + time * 3600;
        end
    end -- timestamp format
    for i=1, self.events_size do
        if self.events[i][1] == id then
            if self.events[i][2] ~= time then
                self.events[i][2] = time;
                triggerEvent("OnQSystemUpdate", 0);
                SaveManager.onCharacterDataChange();
                SaveManager.save();
            end
            return;
        end
    end
    if rt then
        self.events_size = self.events_size + 1; self.events[self.events_size] = {id, time, true};
    else
        self.events_size = self.events_size + 1; self.events[self.events_size] = {id, time, false};
    end
    triggerEvent("OnEventStateChanged", tostring(id), true);
end

function CharacterManager:getEvent(id)
    for i=1, self.events_size do
        if self.events[i][1] == id then
            return self.events[i]; -- timestamp
        end
    end
end

function CharacterManager:removeEvent(index, event)
    table.remove(self.events, index); self.events_size = self.events_size - 1;
    triggerEvent("OnEventStateChanged", event, false);
end

function CharacterManager.update() -- every 5 seconds
    if CharacterManager.pause then return end
    local game_time = GetWorldAgeSeconds();
    CharacterManager.instance.last_save = game_time;
    for i=CharacterManager.instance.events_size, 1, -1 do
        if CharacterManager.instance.events[i][3] then -- real time
            if CharacterManager.instance.events[i][2] < getTimestamp() then
                if isClient() then QSystem.update() end
                CharacterManager.instance:removeEvent(i, tostring(CharacterManager.instance.events[i][1]));
            end
        else  -- game time
            if CharacterManager.instance.events[i][2] < game_time then
                CharacterManager.instance:removeEvent(i, tostring(CharacterManager.instance.events[i][1]));
            end
        end
    end
end

local function unlockAchievement(flag)
    if AchievementManager.list_size > 0 then
        for i=1, AchievementManager.list_size do
            if AchievementManager.list[i].flag == flag then
                if AchievementManager.list[i].unlocked == false then
                    AchievementManager.list[i].unlocked = true;
                    CharacterManager.instance.achievements_size = CharacterManager.instance.achievements_size + 1;
                    CharacterManager.instance.achievements[CharacterManager.instance.achievements_size] = AchievementManager.list[i].internal;
                    triggerEvent("OnAchievementUnlock", i);
                end
                return;
            end
        end
    end
end

function CharacterManager:isAchievement(achievement)
	for i=1, self.achievements_size do
		if self.achievements[i] == achievement then
			QuestLogger.print("[QSystem*] CharacterManager: Achievement is unlocked - "..achievement);
			return true;
		end
	end
	return false;
end

function CharacterManager:addFlag(flag)
	for i=1, self.flags_size do
		if self.flags[i] == flag then
			QuestLogger.print("[QSystem*] CharacterManager: Flag already exists - "..flag);
			return;
		end
	end
	QuestLogger.print("[QSystem*] CharacterManager: Added flag - "..flag);
    self.flags_size = self.flags_size + 1; self.flags[self.flags_size] = flag;
    unlockAchievement(flag);
    SaveManager.onCharacterDataChange();
    triggerEvent("OnQSystemUpdate", 0);
end

function CharacterManager:isFlag(flag)
	for i=1, self.flags_size do
		if self.flags[i] == flag then
			QuestLogger.print("[QSystem*] CharacterManager: Flag is active - "..flag);
			return true;
		end
	end
	--QuestLogger.print("[QSystem*] CharacterManager: Flag is inactive - "..flag)
	return false;
end

function CharacterManager:removeFlag(flag)
	for i=1, self.flags_size do
		if self.flags[i] == flag then
			QuestLogger.print("[QSystem*] CharacterManager: Removed flag - "..flag);
			table.remove(self.flags, i); self.flags_size = self.flags_size - 1;
            SaveManager.onCharacterDataChange();
            triggerEvent("OnQSystemUpdate", 0);
			return;
		end
	end
	QuestLogger.print("[QSystem] CharacterManager: Flag doesn't exist - "..flag);
end

function CharacterManager:parse(file, mod, language)
    language = language or "default";
    local path = string.format("media/data/%s/%s/%s", language, tostring(self.directory), tostring(file));
    if not mod then mod = GetModIDFromPath(path); end

    local reader = getModFileReader(mod, path, false);

	if reader == nil then
		print("[QSystem] CharacterManager: File '"..path.."' not found!");
		return;
    else
        reader:close();
	end

    local script = self:load_script(file, mod, true, language); -- load script to memory
    local character = QCharacter:new(file, mod, language);

    for line_id=1, #script.lines do
        local line = script.lines[line_id]:trim();

        if line:starts_with("*") then
            character.labels[string.sub(line, 2)] = line_id;
        elseif line:starts_with("#name ") then
            local args = string.sub(line, 7):trim():ssplit("|");
            character.name = args[1];
            if #args > 1 then
                character.displayName = args[2];
            else
                character.displayName = character.name;
            end
        elseif line:starts_with("#set_stat ") then
            local args = string.sub(line, 11):trim():ssplit("|");
            if #args == 3 then
                if character.name == tostring(args[1]) then
                    character:setStat(tostring(args[2]), tonumber(args[3]), true);
                end
            end
        end
    end

    if character.name then
        for i=1, self.items_size do
            if character.name == self.items[i].name then
                print("[QSystem] CharacterManager: Character with internal name '"..tostring(character.name).."' already exists!");
                return;
            end
        end
        self.items_size = self.items_size + 1; self.items[self.items_size] = character;
        return true;
    else
        print("[QSystem] CharacterManager: Unable to load '"..path.."' due to internal name being undefined!");
    end
end

function CharacterManager:new()
    local o = ScriptManagerNeo:new("characters");
    setmetatable(o, self);
    self.__index = self;
    o.flags = {};
    o.flags_size = 0;
    o.events = {};
    o.events_size = 0;
    o.achievements = {};
    o.achievements_size = 0;
    o.last_save = 0;
    return o;
end

CharacterManager.instance = CharacterManager:new();

function CharacterManager.reset()
    if CharacterManager.instance then
        CharacterManager.instance.items_size = 0;
        CharacterManager.instance.items = {};
        CharacterManager.instance.flags_size = 0;
        CharacterManager.instance.flags = {};
        CharacterManager.instance.events_size = 0;
        CharacterManager.instance.events = {};
    end
end

Events.OnQSystemReset.Add(CharacterManager.reset);