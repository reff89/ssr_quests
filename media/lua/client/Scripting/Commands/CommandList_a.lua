-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Scripting/Objects/Command"

local type_dialogue = "DialoguePanel"
local type_character_desc = "CharacterPanel"

-- Commands (Dialogues)

function GetTextByTag(args)
    local size = #args;
    if size == 3 then
        if args[1] == "male" then
            if getPlayer():isFemale() then
                return args[3];
            else
                return args[2];
            end
        elseif args[1] == "female" then
            if getPlayer():isFemale() then
                return args[2];
            else
                return args[3];
            end
        elseif args[1] == "stat" then
            local id = CharacterManager.instance:indexOf(args[2]);
            if id then
                local stat = CharacterManager.instance.items[id]:getStat(args[3]);
                if stat then
                    return tostring(stat);
                else
                    return string.format("{character '%s' doesn't have stat '%s'}", args[2], tostring(args[3]));
                end
			else
				return string.format("{character '%s' not found}", tostring(args[2]));
            end
        end
    elseif size == 2 then
        if args[1] == "var" then
            local value = DialoguePanel.instance:getVar(args[2]) or "";
            return value;
        end
    elseif size == 1 then
        if args[1] == "nickname" then
            local player = getPlayer();
            if player then
                if isClient() then
                    return tostring(player:getDisplayName());
                else
                    return tostring(player:getDescriptor():getForename());
                end
            end
        elseif args[1] == "forename" then
            local player = getPlayer();
            if player then
                return tostring(player:getDescriptor():getForename());
            end
        elseif args[1] == "surname" then
            local player = getPlayer();
            if player then
                return tostring(player:getDescriptor():getSurname());
            end
        end
    end
end

-- m message
-- m speaker|message
-- m speaker|path_to_portrait|message
local m = Command:derive("m")
m.allow_tags = true;
function m:execute(sender)
    self:debug();
    local size = #self.args
    if size == 1 then
        sender.message.text = self.args[1];
        sender:clearAvatar();
    else
        if size == 3 then
            local path = self.args[2];
            local result = sender:setAvatar(path);
            if result == 1 then
                return "Invalid image path";
            elseif result == 2 then
                return "Invalid character id";
            end
        else
            sender:clearAvatar();
        end
        sender.message.text = " <RGB:1.0,0.9,0.7> ["..self.args[1].."] <LINE> <RGB:1,1,1> "..self.args[size];
    end
    if not sender:isVisible() then
        sender:setVisible(true);
    end
    sender.message:paginate();
    sender:pause(); -- wait for action
end

CommandList_a[#CommandList_a+1] = m:new("m", 1, 3, type_dialogue);

-- show_panel
local show_panel = Command:derive("show_panel")
function show_panel:execute(sender)
    self:debug();
    if not sender:isVisible() then
        sender:setVisible(true);
    end
end

CommandList_a[#CommandList_a+1] = show_panel:new("show_panel", 0, nil, type_dialogue);

-- hide_panel
local hide_panel = Command:derive("hide_panel")
function hide_panel:execute(sender)
    self:debug();
    if sender:isVisible() then
        sender:setVisible(false);
    end
end

CommandList_a[#CommandList_a+1] = hide_panel:new("hide_panel", 0, nil, type_dialogue);

-- choice
--     label|text
--     label|text|flag|hidden
-- (up to six choices)
local lock_icon = getTexture("media/ui/lock_icon.png");
local choice = Command:derive("choice")
choice.allow_tags = true;
function choice:execute(sender)
    self:debug();
    local max_width = 135*SSRLoader.scale;

    -- parse choices
    local choices = {};
    local skipped = 1;

    while sender.script.lines[sender.script.index+skipped] and GetBlockLayer(sender.script.lines[sender.script.index+skipped]) > sender.script.layer do
        local args = self:format(sender.script.lines[sender.script.index+skipped]:trim()):ssplit('|');
        local size = #args;
        if size < 2 or size > 4 then
            return string.format("Invalid argument (%s)", tostring(skipped));
        end
        local _choice = {};
        _choice.target = args[1];
        _choice.text = args[2];
        if size == 3 then
            if args[3]:starts_with('!') then
                _choice.locked = CharacterManager.instance:isFlag(args[3]:sub(2));
            else
                _choice.locked = not CharacterManager.instance:isFlag(args[3]);
            end
        end
        _choice.hidden = args[4] == "true" or false;
        choices[#choices+1] = _choice;

        -- measure button width
        local width = getTextManager():MeasureStringX(sender.font, args[2]) + 10*SSRLoader.scale;
        if width > max_width then
            max_width = width;
        end

        skipped = skipped + 1;
    end

    if #choices == 0 then return "No choice options found"; end

    local panel_width = (sender.message:getWidth() / 2) - 20*SSRLoader.scale;
    if max_width > panel_width and #choices > 3 then
        max_width = panel_width;
    end

    local origin = {sender.script.file, sender.script.mod, sender.script.index-1}; -- save current address into call stack
    sender.callstack[#sender.callstack+1] = origin;
    sender.script.index = sender.script.index+skipped
    sender.script.skip = -1

    -- render buttons
    sender.input.enable = false
    local hidden = 0;
    for i=1, #choices do
        if i < 7 then
            if choices[i].hidden then
                hidden = hidden + 1;
            else
                sender.buttons[i]:setX(i-hidden > 3 and max_width+30*SSRLoader.scale or 10*SSRLoader.scale);
                sender.buttons[i]:setY(sender.btn_y[i-hidden]);
                sender.buttons[i]:setWidth(max_width);
                if choices[i].locked then -- set lock on choice if flag is not raised
                    sender.buttons[i].title = "";
                    sender.buttons[i].image = lock_icon;
                    sender.buttons[i].enable = false;
                    if not sender.buttons[i].borderColorEnabled then
                        sender.buttons[i].borderColorEnabled = { r = sender.buttons[i].borderColor.r, g = sender.buttons[i].borderColor.g, b = sender.buttons[i].borderColor.b, a = sender.buttons[i].borderColor.a };
                    end
                    sender.buttons[i]:setTextureRGBA(0.5, 0.5, 0.5, 0.7)
                    sender.buttons[i]:setBorderRGBA(0.5, 0.5, 0.5, 0.7)
                else
                    sender.buttons[i].title = choices[i].text
                end
                sender.buttons[i]:setOnClick(sender.onChoiceSelected, choices[i].target)
                sender.buttons[i]:setVisible(true)
            end
        else
            return "Too many choice options (Maximum is 6)";
        end
    end
    if not sender:isVisible() then
        sender:setVisible(true);
    end
    sender:pause(); -- wait for action
end

CommandList_a[#CommandList_a+1] = choice:new("choice", 0, nil, type_dialogue);

-- is_flag flag,true
-- is_flag flag_a,true|flag_b,false
local is_flag = Command:derive("is_flag")
function is_flag:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if arg[2] == 'true' then
            arg[2] = true;
        elseif arg[2] == 'false' then
            arg[2] = false;
        else
            return "Invalid syntax";
        end
        if CharacterManager.instance:isFlag(arg[1]) ~= arg[2] then
            QuestLogger.print("[QSystem*] #is_flag: Skipping block due to flag \""..tostring(arg[1]).."\" not being "..tostring(arg[2]))
            sender.script.skip = sender.script.layer+1;
            break;
        end
    end
end

CommandList_a[#CommandList_a+1] = is_flag:new("is_flag", 1, 10, {type_dialogue, type_character_desc});

-- set_flag flag,true
-- set_flag flag_a,true|flag_b,false
local set_flag = Command:derive("set_flag")
function set_flag:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if arg[2] == 'true' then
            CharacterManager.instance:addFlag(arg[1])
        elseif arg[2] == 'false' then
            CharacterManager.instance:removeFlag(arg[1])
        else
            return "Invalid syntax";
        end
    end
end

CommandList_a[#CommandList_a+1] = set_flag:new("set_flag", 1, 10, type_dialogue);

-- jump label
local jump = Command:derive("jump")
function jump:execute(sender)
    self:debug();
    local origin = {sender.script.file, sender.script.mod, sender.script.index}; -- save current address into call stack
    if not sender.script:jump(self.args[1], true) then
        return "Label '"..tostring(self.args[1]).."' not found";
    end
    if sender.Type == type_dialogue then sender.callstack[#sender.callstack+1] = origin; end
end

CommandList_a[#CommandList_a+1] = jump:new("jump", 1, nil, {type_dialogue, type_character_desc});

-- r_jump label,weight
-- r_jump labelA,25|labelB,50|labelC|60
local r_jump = Command:derive("r_jump")
function r_jump:execute(sender)
    self:debug();
    local origin = {sender.script.file, sender.script.mod, sender.script.index}; -- save current address into call stack
    local s, labels = 0, {};
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if #arg ~= 2 then
            return "Invalid syntax";
        end
        local status, weight = pcall(tonumber, arg[2]);
        if status and weight then
            if weight > 0 then
                labels[#labels+1] = { arg[1], weight };
                s = s + weight;
            else
                return "Weight must be greater than 0";
            end
        else
            return "Weight is not number";
        end
    end
    local hit = ZombRandFloat(0, s); -- ZombRandBetween(0, s)
    for i=1, #labels do
        s = s - labels[i][2];
        if hit >= s then
            if sender.script:jump(labels[i][1], true) then
                if sender.Type == type_dialogue then sender.callstack[#sender.callstack+1] = origin; end
                return;
            else
                return "Label '"..tostring(labels[i][1]).."' not found";
            end
        end
    end
end

CommandList_a[#CommandList_a+1] = r_jump:new("r_jump", 1, 10, type_dialogue);

-- roll label,chance
-- roll labelA,25|labelB,50|labelC|60
local roll = Command:derive("roll")
function roll:execute(sender)
    self:debug();
    local origin = {sender.script.file, sender.script.mod, sender.script.index}; -- save current address into call stack
    local hit = ZombRandBetween(0, 100);
    local label_1, minimum, label_2, maximum = nil, 999, nil, -1;
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if #arg ~= 2 then
            return "Invalid syntax";
        end
        local status, chance = pcall(tonumber, arg[2]);
        if status and chance then
            if chance < 0 or chance > 100 then
                return "Chance is out of range (0-100)";
            end
            local delta = chance - hit;
            if delta >= 0 and delta < minimum then
                label_1 = arg[1];
                minimum = delta;
                if delta == 0 then break; end
            end
            if chance > maximum then
                label_2 = arg[1];
                maximum = chance;
            end
        else
            return "Chance is not number";
        end
    end
    if label_1 then
        QuestLogger.print(string.format("[QSystem*] #roll: Result '%i'", hit));
    else
        label_1 = label_2;
        QuestLogger.print(string.format("[QSystem*] #roll: Result '%i' is out of range (0-%i)", hit, maximum));
    end

    if sender.script:jump(label_1, true) then
        if sender.Type == type_dialogue then sender.callstack[#sender.callstack+1] = origin; end
    else
        return "Label '"..tostring(arg[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = roll:new("roll", 2, 20, type_dialogue);

-- script filename
-- script filename|label
local run_script = Command:derive("script")
function run_script:execute(sender)
    self:debug();
    local origin = {sender.script.file, sender.script.mod, sender.script.index}; -- save current address into call stack
    local script = DialogueManager.instance:load_script(self.args[1]);
    if script then
        if sender.Type == type_dialogue then sender.callstack[#sender.callstack+1] = origin; end
        QuestLogger.print("[QSystem*] #script: Loaded script - "..tostring(self.args[1]));
        sender.script = script;
        if #self.args == 2 then -- jump
            if not sender.script:jump(self.args[2], true) then
                return "Label '"..tostring(self.args[2]).."' not found";
            end
        end
    else
        return "Failed to load script '"..tostring(self.args[1]).."'";
    end
end

CommandList_a[#CommandList_a+1] = run_script:new("script", 1, 2, type_dialogue);

-- ret
local ret = Command:derive("ret")
function ret:execute(sender)
    self:debug();
    local size = #sender.callstack;
    if size > 0 then
        local id = size;
        if self.args[1] then
            local status, offset = pcall(tonumber, self.args[1]);
            if status and offset then
                if offset < 0 then
                    return "Invalid offset";
                end
            else
                return "Offset is not a number";
            end
            id = size - offset;
            if id < 1 then
                id = 1;
            end
        end
        if sender.script.file == sender.callstack[id][1] and sender.script.mod == sender.callstack[id][2] then
            sender.script.index = sender.callstack[id][3];
        else
            sender.script = DialogueManager.instance:load_script(sender.callstack[id][1], sender.callstack[id][2]);
            sender.script.index = sender.callstack[id][3]+1;
        end
        for i=size, id, -1 do
            table.remove(sender.callstack, i);
        end
    else
        return "Attempt to return when call stack is empty";
    end
end

CommandList_a[#CommandList_a+1] = ret:new("ret", 0, 1, type_dialogue);

-- var
local var = Command:derive("var")
function var:execute(sender)
    self:debug();
    if DialoguePanel.instance then
        if string.find(self.args[2], "^[0-9a-zA-Z_,.:\"\'()]+%([0-9a-zA-Z_,.:\"\'()]*%)$") then
            local fn = loadstring("return "..self.args[2]);
            if fn then
                local status, result = pcall(fn);
                if status then
                    return DialoguePanel.instance:setVar(self.args[1], tostring(result));
                end
            end
            return string.format("Unable to call function '%s'", tostring(self.args[2]));
        else
            DialoguePanel.instance:setVar(self.args[1], self.args[2]);
        end
    else
        return "Attempt to set variable when dialogue panel is null";
    end
end

CommandList_a[#CommandList_a+1] = var:new("var", 2, nil, type_dialogue);

-- quest_unlock quest_internal
local quest_unlock = Command:derive("quest_unlock")
function quest_unlock:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        if quest.event then
            return "Attempt to manually unlock event quest";
        elseif not quest.unlocked then
            quest:unlock();
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = quest_unlock:new("quest_unlock", 1, nil, type_dialogue);

-- quest_lock quest_internal
local quest_lock = Command:derive("quest_lock")
function quest_lock:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        if quest.event then
            return "Attempt to manually lock event quest";
        else
            quest:lock();
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = quest_lock:new("quest_lock", 1, nil, type_dialogue);

-- quest_complete quest_internal
local quest_complete = Command:derive("quest_complete")
function quest_complete:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        quest:complete();
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = quest_complete:new("quest_complete", 1, nil, type_dialogue);

-- quest_fail quest_internal
local quest_fail = Command:derive("quest_fail")
function quest_fail:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        quest:fail();
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = quest_fail:new("quest_fail", 1, nil, type_dialogue);

-- quest_reset quest_internal
local quest_reset = Command:derive("quest_reset")
function quest_reset:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        quest:reset();
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = quest_reset:new("quest_reset", 1, nil, type_dialogue);

-- is_quest quest_internal|arg1,arg2/arg3
local is_quest = Command:derive("is_quest")
function is_quest:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local groups = self.args[2]:ssplit("/");
        local status = false;
        for group_id=1, #groups do
            local flags = groups[group_id]:ssplit(",");
            local group_status = true
            for i=1, #flags do
                if flags[i] == "completed" then
                    if not quest.completed then
                        group_status = false;
                        break;
                    end
                elseif flags[i] == "uncompleted" then
                    if quest.completed then
                        group_status = false;
                        break;
                    end
                elseif flags[i] == "locked" then
                    if quest.unlocked then
                        group_status = false;
                        break;
                    end
                elseif flags[i] == "unlocked" then
                    if not quest.unlocked then
                        group_status = false;
                        break;
                    end
                elseif flags[i] == "failed" then
                    if not quest.failed then
                        group_status = false;
                        break;
                    end
                elseif flags[i] == "unfailed" then
                    if quest.failed then
                        group_status = false;
                        break;
                    end
                else
                    return "Unexpected argument ("..tostring(flags[i])..")";
                end
            end
            if group_status then
                status = true;
                break;
            end
        end
        if not status then
            QuestLogger.print("[QSystem*] #is_quest: Skipping block due to quest '"..tostring(self.args[1]).."' not being "..tostring(self.args[2]))
            sender.script.skip = sender.script.layer+1;
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = is_quest:new("is_quest", 2, nil, type_dialogue);

-- task_unlock quest_internal|task_internal
local task_unlock = Command:derive("task_unlock")
function task_unlock:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local task = quest:getTask(self.args[2]);
        if task then
            if not task.unlocked then
                task:unlock();
                if not QInterface.instance:isTab(1) then
                    local function callback()
                        QTracker.track(quest, false);
                    end
                    NotificationManager.add(callback, nil, true);
                end
            end
        else
            return "Task '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = task_unlock:new("task_unlock", 2, nil, type_dialogue);

-- task_lock quest_internal|task_internal
local task_lock = Command:derive("task_lock")
function task_lock:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local task = quest:getTask(self.args[2]);
        if task then
            task:lock();
        else
            return "Task '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = task_lock:new("task_lock", 2, nil, type_dialogue);

-- task_complete quest_internal|task_internal
local task_complete = Command:derive("task_complete")
function task_complete:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local task = quest:getTask(self.args[2]);
        if task then
            task:complete();
        else
            return "Task '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = task_complete:new("task_complete", 2, nil, type_dialogue);

-- task_reset quest_internal|task_internal
local task_reset = Command:derive("task_reset")
function task_reset:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local task = quest:getTask(self.args[2]);
        if task then
            task:reset();
        else
            return "Task '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = task_reset:new("task_reset", 2, nil, type_dialogue);

-- is_task quest_internal|task_internal|arg1,arg2/arg3
local is_task = Command:derive("is_task")
function is_task:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        local task = quest:getTask(self.args[2]);
        if task then
            local groups = self.args[3]:ssplit("/");
            local status = false;
            for group_id=1, #groups do
                local flags = groups[group_id]:ssplit(",");
                local group_status = true
                for i=1, #flags do
                    if flags[i] == "completed" then
                        if not task.completed then
                            group_status = false;
                            break;
                        end
                    elseif flags[i] == "uncompleted" then
                        if task.completed then
                            group_status = false;
                            break;
                        end
                    elseif flags[i] == "locked" then
                        if task.unlocked then
                            group_status = false;
                            break;
                        end
                    elseif flags[i] == "unlocked" then
                        if not task.unlocked then
                            group_status = false;
                            break;
                        end
                    else
                        return "Unexpected argument ("..tostring(flags[i])..")";
                    end
                end
                if group_status then
                    status = true;
                    break;
                end
            end
            if not status then
                QuestLogger.print("[QSystem*] #is_task: Skipping block due to task \""..tostring(self.args[2]).."\" of quest '"..tostring(self.args[1]).."' not being "..tostring(self.args[3]))
                sender.script.skip = sender.script.layer+1;
            end
        else
            return "Task '"..tostring(self.args[2]).."' not found";
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = is_task:new("is_task", 3, nil, type_dialogue);

-- has_item Base.Axe
-- has_item Base.Apple,3
-- has_item Base.Apple,3,ruleset
-- has_item ruleset
-- has_item ruleset,3
local has_item = Command:derive("has_item")
function has_item:execute(sender)
    self:debug();
    for i=1,#self.args do
        self.args[i] = self.args[i]:trim():ssplit(',');
        local ruleset_only = #(self.args[i][1]:ssplit('.')) == 1;

        if #self.args[i] < 2 then
            self.args[i][2] = 1;
        else
            local status;
            status, self.args[i][2]  = pcall(tonumber, self.args[i][2]);
            if not status or not self.args[i][2] then
                return "Wrong quantity specified for item "..tostring(self.args[i][1]).."";
            end
        end

        local amount = ruleset_only and ItemFetcher.getNumberOfItem(nil, self.args[i][2], self.args[i][1]) or ItemFetcher.getNumberOfItem(self.args[i][1], self.args[i][2], self.args[i][3]);
        if type(amount) == "string" then return amount; end

        if amount < self.args[i][2] then
            if ruleset_only then
                QuestLogger.print("[QSystem*] #has_item: Skipping block due insufficient amount of items allowed by '"..tostring(self.args[i][1]).."' ruleset - "..tostring(amount).."/"..tostring(self.args[i][2]));
            else
                QuestLogger.print("[QSystem*] #has_item: Skipping block due insufficient amount of item '"..tostring(self.args[i][1]).."' - "..tostring(amount).."/"..tostring(self.args[i][2]));
            end
            sender.script.skip = sender.script.layer+1;
            return;
        end
    end
end

CommandList_a[#CommandList_a+1] = has_item:new("has_item", 1, 10, type_dialogue);

-- add_item Base.Axe
-- add_item Base.Axe|Base.Apple,3
local add_item = Command:derive("add_item")
function add_item:execute(sender)
    self:debug();
    local items = {}
    local script_manager = getScriptManager();
    for i=1,#self.args do
        self.args[i] = self.args[i]:trim():ssplit(',')
        if not script_manager:FindItem(self.args[i][1]) then
            return "Attempt to add non-existent item '"..tostring(self.args[i][1]).."'";
        end
        if #self.args[i] == 2 then
            local status;
            status, self.args[i][2]  = pcall(tonumber, self.args[i][2]);
            if not status or not self.args[i][2] then
                return "Wrong quantity specified for item "..tostring(self.args[i][1]).."";
            end
        else
            self.args[i][2] = 1;
        end
        local item = QItemFactory.createEntry(self.args[i][1], self.args[i][2]);
        items[i] = item;
    end
    local function callback()
        sender.input.enable = true;
        sender:showNext();
    end
    local info = string.format("add_item, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
    QItemFactory.request(info, items, callback);
    return -2;
end

CommandList_a[#CommandList_a+1] = add_item:new("add_item", 1, 10, type_dialogue);

-- remove_item Base.Axe
-- remove_item Base.Axe|Base.Apple,3
local remove_item = Command:derive("remove_item")
function remove_item:execute(sender)
    self:debug();
    local inventory = getPlayer():getInventory();
    local script_manager = getScriptManager();
    for i=1,#self.args do
        self.args[i] = self.args[i]:trim():ssplit(',')
        if #self.args[i] == 2 then
            if not script_manager:FindItem(self.args[i][1]) then
                return "Attempt to remove non-existent item '"..tostring(self.args[i][1]).."'";
            end
            local status;
            status, self.args[i][2]  = pcall(tonumber, self.args[i][2]);
            if not status or not self.args[i][2] then
                return "Wrong quantity specified for item "..tostring(self.args[i][1]).."";
            end
        else
            self.args[i][2] = 1;
        end
        local items = inventory:FindAll(self.args[i][1]);
        if items then
            for j=items:size()-1, 0, -1 do
                local item = items:get(j);
                if ItemFetcher.validate(item, "default") then
                    inventory:Remove(item);
                    self.args[i][2] = self.args[i][2] - 1;
                    if self.args[i][2] < 1 then
                        break;
                    end
                end
            end
        end
    end
end

CommandList_a[#CommandList_a+1] = remove_item:new("remove_item", 1, 10, type_dialogue);

-- is_event id|true
-- is_event id|false
local is_event = Command:derive("is_event")
function is_event:execute(sender)
    self:debug();
    if self.args[2] == 'true' then
        if not CharacterManager.instance:isEvent(self.args[1]) then
            QuestLogger.print("[QSystem*] #is_event: Skipping block due to event '"..tostring(self.args[1]).."' being inactive")
            sender.script.skip = sender.script.layer+1;
        end
    elseif self.args[2] == 'false' then
        if CharacterManager.instance:isEvent(self.args[1]) then
            QuestLogger.print("[QSystem*] #is_event: Skipping block due to event '"..tostring(self.args[1]).."' being active")
            sender.script.skip = sender.script.layer+1;
        end
    else
        return "Invalid syntax";
    end
end

CommandList_a[#CommandList_a+1] = is_event:new("is_event", 2, nil, type_dialogue);

-- set_event id|rt|timestamp
-- set_event id|rt|offset_h
-- set_event id|rt|time|offset_d
local set_event = Command:derive("set_event")
function set_event:execute(sender)
    self:debug();
    local id = tostring(self.args[1]);
    if self.args[2] == 'true' then
        self.args[2] = true;
    elseif self.args[2] == "false" then
        self.args[2] = false;
    else
        return "Invalid syntax";
    end
    local time = self.args[3]:ssplit(':');
    if #time == 2 then
        for i=1, 2 do
            local status, value = pcall(tonumber, time[i])
            if status and value then
                if value < 0 or (i == 1 and value > 23) or (i == 2 and value > 59) then
                    return "Invalid time format";
                else
                    time[i] = value;
                end
            else
                return "Invalid time format";
            end
        end
        if self.args[4] then
            local status, value = pcall(tonumber, self.args[4])
            if status and value then
                if value < 0 then
                    return "Negative time";
                elseif value > 416 then
                    time[3] = 416;
                else
                    time[3] = value;
                end
            else
                return "Invalid time shift";
            end
        end
        CharacterManager.instance:setEvent(id, time, self.args[2]);
    else
        local status, value = pcall(tonumber, self.args[3])
        if status and value then
            if value < 0 then
                return "Negative time";
            else
                CharacterManager.instance:setEvent(id, value, self.args[2]);
            end
        else
            return "Invalid time";
        end
    end
end

CommandList_a[#CommandList_a+1] = set_event:new("set_event", 3, 4, type_dialogue);

-- set_stat character|id|value
-- set_stat character|id|value|override
local set_stat = Command:derive("set_stat")
function set_stat:execute(sender)
    self:debug();
    local character_id = CharacterManager.instance:indexOf(self.args[1]);
    if character_id then
		local name =  tostring(self.args[2]);
		local status, value = pcall(tonumber, self.args[3]);
		if status and value then
			if CharacterManager.instance.items[character_id]:setStat(name, value, self.args[4]) then
				QuestLogger.print("[QSystem*] #set_stat: Set value of stat '"..name.."' for \""..tostring(CharacterManager.instance.items[character_id].name).."\" to "..tostring(value));
			end
		else
			return "Invalid syntax";
		end
	else
		return "Character doesn't exist";
	end
end

CommandList_a[#CommandList_a+1] = set_stat:new("set_stat", 3, 4, type_dialogue);

-- remove_stat character|id
local remove_stat = Command:derive("remove_stat")
function remove_stat:execute(sender)
    self:debug();
    local character_id = CharacterManager.instance:indexOf(self.args[1]);
    if character_id then
		local name =  tostring(self.args[2]);
		if CharacterManager.instance.items[character_id]:removeStat(name) then
			QuestLogger.print("[QSystem*] #remove_stat: Removed stat '"..name.."' for \""..tostring(CharacterManager.instance.items[character_id].name));
		end
	else
		return "Character doesn't exist";
	end
end

CommandList_a[#CommandList_a+1] = remove_stat:new("remove_stat", 2, nil, type_dialogue);

-- stat_inc character|id|value
local stat_inc = Command:derive("stat_inc")
function stat_inc:execute(sender)
    self:debug();
    local character_id = CharacterManager.instance:indexOf(self.args[1]);
    if character_id then
		local name = tostring(self.args[2]);
		local status, value = pcall(tonumber, self.args[3]);
		if status and value then
			CharacterManager.instance.items[character_id]:increaseStat(name, value)
			QuestLogger.print("[QSystem*] #stat_inc: Increased '"..name.."' for \""..tostring(CharacterManager.instance.items[character_id].name).."\" by "..tostring(value)..". Current = "..tostring(CharacterManager.instance.items[character_id]:getStat(name)));
		else
			return "Invalid syntax";
		end
	else
		return "Character doesn't exist";
	end
end

CommandList_a[#CommandList_a+1] = stat_inc:new("stat_inc", 3, nil, type_dialogue);

-- stat_dec character|id|value
local stat_dec = Command:derive("stat_dec")
function stat_dec:execute(sender)
    self:debug();
    local character_id = CharacterManager.instance:indexOf(self.args[1]);
    if character_id then
		local name = tostring(self.args[2]);
		local status, value = pcall(tonumber, self.args[3]);
		if status and value then
			CharacterManager.instance.items[character_id]:decreaseStat(name, value);
			QuestLogger.print("[QSystem*] #stat_dec: Decreased '"..name.."' for \""..tostring(CharacterManager.instance.items[character_id].name).."\" by "..tostring(value)..". Current = "..tostring(CharacterManager.instance.items[character_id]:getStat(name)));
		else
			return "Invalid syntax";
		end
	else
		return "Character doesn't exist";
	end
end

CommandList_a[#CommandList_a+1] = stat_dec:new("stat_dec", 3, nil, type_dialogue);

-- is_stat character,id,value,gt
-- is_stat character,id,value,lt
-- is_stat character,id,value,gt|character,id,value,lt
local is_stat = Command:derive("is_stat")
function is_stat:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if #arg == 4 then
            local character_id = CharacterManager.instance:indexOf(arg[1]);
            if character_id then
				local name = tostring(arg[2]);
				local value = CharacterManager.instance.items[character_id]:getStat(name);
				if value then
					local status = nil;
					status, arg[3] = pcall(tonumber, arg[3]);
					if status and arg[3] then
						if arg[4] == 'gt' then
							if value <= arg[3] then
								QuestLogger.print("[QSystem*] #is_stat: Skipping block due to '"..name.."' being lower than \""..tostring(arg[3]));
								sender.script.skip = sender.script.layer+1;
								break;
							end
						elseif arg[4] == 'lt' then
							if value >= arg[3] then
								QuestLogger.print("[QSystem*] #is_stat: Skipping block due to '"..name.."' being greater than \""..tostring(arg[3]));
								sender.script.skip = sender.script.layer+1;
								break;
							end
						end
					else
						return "Invalid argument";
					end
				else
					QuestLogger.print("[QSystem*] #is_stat: Skipping block due to stat '"..name.."' not being defined");
					sender.script.skip = sender.script.layer+1;
					break;
				end
			else
				return "Character doesn't exist";
			end
        else
            return "Invalid syntax";
        end
    end
end

CommandList_a[#CommandList_a+1] = is_stat:new("is_stat", 1, 2, {type_dialogue, type_character_desc});

-- is_cleared character,value,gt
-- is_cleared character,value,gt|character,value,lt
local is_cleared = Command:derive("is_cleared")
function is_cleared:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        local character_id = CharacterManager.instance:indexOf(arg[1]);
        if character_id then
			local status = nil;
			status, arg[2] = pcall(tonumber, arg[2]);
			if status then
				if arg[3] == 'gt' then
					if CharacterManager.instance.items[character_id].cleared_quests <= arg[2] then
						QuestLogger.print("[QSystem*] #cleared_quests: Skipping block due to cleared quests number for character '"..tostring(CharacterManager.instance.items[character_id].name).."' being lower than \""..tostring(arg[2]))
						sender.script.skip = sender.script.layer+1;
						break;
					end
				elseif arg[3] == 'lt' then
					if CharacterManager.instance.items[character_id].cleared_quests >= arg[2] then
						QuestLogger.print("[QSystem*] #cleared_quests: Skipping block due to cleared quests number for character '"..tostring(CharacterManager.instance.items[character_id].name).."' being greater than \""..tostring(arg[2]))
						sender.script.skip = sender.script.layer+1;
						break;
					end
				end
			else
				return "Invalid syntax";
			end
		else
			return "Character doesn't exist";
		end
    end
end

CommandList_a[#CommandList_a+1] = is_cleared:new("is_cleared", 1, 10, {type_dialogue, type_character_desc});

-- is_time HH:MM|HH:MM
local is_time = Command:derive("is_time")
function is_time:execute(sender)
    self:debug();
    local time = {};
    -- range
    for i=1, #self.args do
        local t = self.args[i]:ssplit(':');
        if #t == 2 then
            local minutes = string.len(t[2]);
            if string.len(t[1]) > 2 or minutes > 2 then
                return "Invalid time format";
            elseif minutes == 1 then
                t[2] = '0'..t[2]
            end
            local status;
            status, t = pcall(tonumber, (t[1]..t[2]));
            if not status or not t then
                return "Unable to convert range time to number";
            end
            time[i] = t;
        else
            return "Invalid time format";
        end
    end
    -- current time
    local hour, minutes = tostring(getGameTime():getHour()), tostring(getGameTime():getMinutes());
    if string.len(minutes) == 1 then
        minutes = '0'..minutes;
    end
    local status, current_time = pcall(tonumber, (hour..minutes));
    if not status or not current_time then
        return "Unable to convert current time to number";
    end

    if time[1] == time[2] then
        return;
    else
        local x = time[2] - current_time;
        local d = time[2] - time[1];
        if time[1] > time[2] then
            if not (x >= 0 or x <= d) then
                QuestLogger.print("[QSystem*] #is_time: Skipping block due to current time being out of range: "..tostring(self.args[1]).."-"..tostring(self.args[2]))
                sender.script.skip = sender.script.layer+1;
            end
        else
            if not (x >= 0 and x <= d) then
                QuestLogger.print("[QSystem*] #is_time: Skipping block due to current time being out of range: "..tostring(self.args[1]).."-"..tostring(self.args[2]))
                sender.script.skip = sender.script.layer+1;
            end
        end
    end
end

CommandList_a[#CommandList_a+1] = is_time:new("is_time", 2, nil, type_dialogue);

-- sfx filename_without_extension
local sfx = Command:derive("sfx")
function sfx:execute(sender)
    self:debug();
    if AudioManager.playSound(self.args[1]) then
        QuestLogger.print("[QSystem*] #sfx: Playing SFX - "..tostring(self.args[1]));
    end
end

CommandList_a[#CommandList_a+1] = sfx:new("sfx", 1, nil, type_dialogue);

-- voice filename_without_extension
local voice = Command:derive("voice")
function voice:execute(sender)
    self:debug();
    if AudioManager.playVoice(self.args[1]) then
        QuestLogger.print("[QSystem*] #voice: Playing Voice - "..tostring(self.args[1]));
        sender.voice = self.args[1];
    end
end

CommandList_a[#CommandList_a+1] = voice:new("voice", 1, nil, type_dialogue);

-- bgm filename_without_extension
-- bgm filename_without_extension|loop
-- bgm filename_without_extension|loop|fully
local bgm = Command:derive("bgm")
function bgm:execute(sender)
    self:debug();
    local size = #self.args;
    local loop = self.args[2] == "true";
    if size > 1 and not loop and self.args[2] ~= "false" then
        return "Invalid syntax";
    end
    local fully = self.args[3] == "true";
    if size == 3 and not fully and self.args[3] ~= "false" then
        return "Invalid syntax";
    end
    local function callback()
        if AudioManager.playBGM(self.args[1], loop, fully) then
            QuestLogger.print("[QSystem*] #bgm_start: Playing BGM - "..tostring(self.args[1]));
        end
        sender.input.enable = true;
        sender:showNext();
    end
    SSRTimer.add_ms(callback, 0, false); -- fixes sound caching lag, hopefully
    return -2;
end

CommandList_a[#CommandList_a+1] = bgm:new("bgm", 1, 3, type_dialogue);

-- stop channel
local stop = Command:derive("stop")
function stop:execute(sender)
    self:debug();
    if self.args[1] == "sfx" then
        AudioManager.stop(0);
    elseif self.args[1] == "bgm" then
        AudioManager.stop(1);
    elseif self.args[1] == "voice" then
        AudioManager.stop(2);
    else
        return string.format("Unknown channel '%s'", tostring(self.args[1]));
    end
end

CommandList_a[#CommandList_a+1] = stop:new("stop", 1, nil, type_dialogue);

-- set_volume master|volume
local set_volume = Command:derive("set_volume")
function set_volume:execute(sender)
    self:debug();
    local status, volume = pcall(tonumber, self.args[2]);
    if status and volume then
        if volume < 0 or volume > 10 then
            print("Volume is an integer in range from 0 to 10.");
            return "Invalid volume specified";
        end
    else
        return "Volume is not a number";
    end
    volume = volume / 10;
    if self.args[1] == "music" then
        AudioManager.setVolume(0, volume);
    elseif self.args[1] == "ambient" then
        AudioManager.setVolume(1, volume);
    else
        return string.format("Unknown master '%s'", tostring(self.args[1]));
    end
    QuestLogger.print(string.format("[QSystem] #set_volume: Changed %s volume to %i.", self.args[1], self.args[2]));
end

CommandList_a[#CommandList_a+1] = set_volume:new("set_volume", 2, nil, type_dialogue);

-- restore_volume
local restore_volume = Command:derive("restore_volume")
function restore_volume:execute(sender)
    self:debug();
    AudioManager.restoreVolume();
end

CommandList_a[#CommandList_a+1] = restore_volume:new("restore_volume", 0, nil, type_dialogue);

-- set_bg path_to_image
local set_bg = Command:derive("set_bg")
function set_bg:execute(sender)
    self:debug();
    local path = tostring(self.args[1]);
    if not path:starts_with("media/ui/") then
        path = "media/ui/"..path;
    end
    useTextureFiltering(true)
    local status, texture = pcall(getTexture, path);
    useTextureFiltering(false)
    if status and texture then
        SpriteRenderer.setBackground(texture);
    else
        return "Unable to load image";
    end
end

CommandList_a[#CommandList_a+1] = set_bg:new("set_bg", 1, nil, type_dialogue);

-- clear_bg
local clear_bg = Command:derive("clear_bg")
function clear_bg:execute(sender)
    self:debug();
    SpriteRenderer.clearBackground();
end

CommandList_a[#CommandList_a+1] = clear_bg:new("clear_bg", 0, nil, type_dialogue);

-- set_fg path_to_image
local set_fg = Command:derive("set_fg")
function set_fg:execute(sender)
    self:debug();
    local path = tostring(self.args[1]);
    if not path:starts_with("media/ui/") then
        path = "media/ui/"..path;
    end
    useTextureFiltering(true)
    local status, texture = pcall(getTexture, path);
    useTextureFiltering(false)
    if status and texture then
        SpriteRenderer.setForeground(texture);
    else
        return "Unable to load image";
    end
end

CommandList_a[#CommandList_a+1] = set_fg:new("set_fg", 1, nil, type_dialogue);

-- clear_fg
local clear_fg = Command:derive("clear_fg")
function clear_fg:execute(sender)
    self:debug();
    SpriteRenderer.clearForeground();
end

CommandList_a[#CommandList_a+1] = clear_fg:new("clear_fg", 0, nil, type_dialogue);

-- exit
local exit = Command:derive("exit")
function exit:execute(sender)
    self:debug();
    return -1;
end

CommandList_a[#CommandList_a+1] = exit:new("exit", 0, nil, {type_dialogue, type_character_desc});


-- Commands (Character Panel)

-- name text
local _name = Command:derive("name") -- dummy command for character panel
function _name:execute(sender)
    self:debug();
end

CommandList_a[#CommandList_a+1] = _name:new("name", 1, 2, type_character_desc);

-- set_stat character|id|value
local _set_stat = Command:derive("set_stat") -- dummy command for character panel
function _set_stat:execute(sender)
    self:debug();
end

CommandList_a[#CommandList_a+1] = _set_stat:new("set_stat", 3, nil, type_character_desc);

-- desc text
local desc = Command:derive("desc")
desc.allow_tags = true;
function desc:execute(sender)
    self:debug();
    sender.panel.profile.text = tostring(self.args[1]);
end

CommandList_a[#CommandList_a+1] = desc:new("desc", 1, nil, type_character_desc);

-- desc_append text
local desc_append = Command:derive("desc_append")
desc_append.allow_tags = true;
function desc_append:execute(sender)
    self:debug();
    sender.panel.profile.text = sender.panel.profile.text.." <LINE> "..tostring(self.args[1]);
end

CommandList_a[#CommandList_a+1] = desc_append:new("desc_append", 1, nil, type_character_desc);

-- set_alive character,1
-- set_alive characterA,1|characterB,0
local set_alive = Command:derive("set_alive")
function set_alive:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        local character_id = CharacterManager.instance:indexOf(arg[1]);
        if character_id then
			if arg[2] == 'true'  then
				CharacterManager.instance.items[character_id]:setAlive(true)
			elseif arg[2] == 'false' then
				CharacterManager.instance.items[character_id]:setAlive(false)
			else
				return "Invalid syntax";
			end
		else
			return "Character doesn't exist";
		end
    end
end

CommandList_a[#CommandList_a+1] = set_alive:new("set_alive", 1, 10, type_dialogue);

-- is_alive character,1
-- is_alive characterA,1|characterB,0
local is_alive = Command:derive("is_alive")
function is_alive:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        local character_id = CharacterManager.instance:indexOf(arg[1]);
        if character_id then
			if arg[2] == 'true' then
				arg[2] = true;
			elseif arg[2] == 'false' then
				arg[2] = false;
			else
				return "Invalid syntax";
			end
			if CharacterManager.instance.items[character_id]:isAlive() ~= arg[2] then
				QuestLogger.print("[QSystem*] #is_alive: Skipping block due to character \""..tostring(arg[1]).."\" not being "..tostring(arg[2] and "alive" or "deceased"))
				sender.script.skip = sender.script.layer+1;
				break;
			end
		else
			return "Character doesn't exist";
        end
    end
end

CommandList_a[#CommandList_a+1] = is_alive:new("is_alive", 1, 10, {type_dialogue, type_character_desc});

-- reveal character
local reveal = Command:derive("reveal")
function reveal:execute(sender)
    self:debug();
    local character_id = CharacterManager.instance:indexOf(self.args[1]);
    if character_id then
        CharacterManager.instance.items[character_id]:reveal();
	else
		return "Character doesn't exist";
    end
end

CommandList_a[#CommandList_a+1] = reveal:new("reveal", 1, nil, type_dialogue);

-- is_revealed character,1
-- is_revealed characterA,1|characterB,0
local is_revealed = Command:derive("is_revealed")
function is_revealed:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        local character_id = CharacterManager.instance:indexOf(arg[1]);
        if character_id then
			if arg[2] == 'true' then
				arg[2] = true;
			elseif arg[2] == 'false' then
				arg[2] = false;
			else
				return "Invalid syntax";
			end
			if CharacterManager.instance.items[character_id]:isRevealed() ~= arg[2] then
				QuestLogger.print("[QSystem*] #is_revealed: Skipping block due to character \""..tostring(arg[1]).."\" "..tostring(arg[2] and "not being revealed" or "being revealed"))
				sender.script.skip = sender.script.layer+1;
				break;
			end
		else
			return "Character doesn't exist";
		end
    end
end

CommandList_a[#CommandList_a+1] = is_revealed:new("is_revealed", 1, 10, {type_dialogue, type_character_desc});


-- Commands (Visual effects)

-- fade_out
-- fade_out color
-- fade_out color|speed
-- fade_out color|speed|is_async
local fade_out = Command:derive("fade_out")
function fade_out:execute(sender)
    self:debug();
    local function callback()
        sender.input.enable = true;
        sender:showNext();
    end
    local color = { r = 0, g = 0, b = 0 };
    local status, speed = pcall(tonumber, self.args[2] or 1);
    if not status or not speed then
        return "Speed is not a number";
    end
    if self.args[1] then
        if self.args[1] == "white" then
            color = { r = 1, g = 1, b = 1 }
        elseif self.args[1] == "black" then
            -- do nothing
        elseif self.args[1] == "red" then
            color = { r = 1, g = 0, b = 0 }
        else
            self.args[1] = self.args[1]:ssplit(',');
            if #self.args[1] == 3 then
                local status;
                for i=1, 3 do
                    status, self.args[1][i] = pcall(tonumber, self.args[1][i]);
                    if not status or not self.args[1][i] then
                        return "Argument is not number";
                    elseif self.args[1][i] < 0 or self.args[1][i] > 1 then
                        return "Invalid color format";
                    end
                end
                color = { r = self.args[1][1], g = self.args[1][2], b = self.args[1][3] }
            else
                return "Invalid color format";
            end
        end
    end
    if self.args[3] == "true" or self.args[3] == "1" then
        Dissolve.setFadeOut(nil, color, speed);
    else
        if Dissolve.setFadeOut(callback, color, speed) then
            return -2; -- wait for callback
        end
    end
end

CommandList_a[#CommandList_a+1] = fade_out:new("fade_out", 0, 3, type_dialogue);

-- fade_in
-- fade_in speed
-- fade_in speed|is_async
local fade_in = Command:derive("fade_in")
function fade_in:execute(sender)
    self:debug();
    local function callback()
        sender.input.enable = true;
        sender:showNext();
    end

    local status, speed = pcall(tonumber, self.args[1] or 1);
    if not status or not speed then
        return "Speed is not a number";
    end
    if self.args[2] == "true" or self.args[2] == "1" then
        Dissolve.setFadeIn(nil, speed);
    else
        if Dissolve.setFadeIn(callback, speed) then
            return -2; -- wait for callback
        end
    end
end

CommandList_a[#CommandList_a+1] = fade_in:new("fade_in", 0, 2, type_dialogue);

-- door x,y,z|open/close/lock/unlock
-- door x,y,z|open/close|silent
local door = Command:derive("door")
function door:execute(sender)
    self:debug();
    local coord = self.args[1]:ssplit(',');
    if #coord ~= 3 then
        return "["..tostring(self.Type).."] Invalid syntax";
    end
    local status;
    for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "["..tostring(self.Type).."] Coordinate is not a number";
		end
	end
    local square = getCell():getGridSquare(coord[1], coord[2], coord[3]);
    if square then
        local door_obj = square:getIsoDoor();
        if door_obj then
            if self.args[2] == "lock" then
                if #self.args == 2 then
                    door_obj:setLockedByKey(true);
                    door_obj:getModData().CustomLock = true;
                    door_obj:transmitModData();
                else
                    return "Invalid syntax";
                end
            elseif self.args[2] == "unlock" then
                if #self.args == 2 then
                    door_obj:setLockedByKey(false);
                    door_obj:getModData().CustomLock = false;
                    door_obj:transmitModData();
                else
                    return "Invalid syntax";
                end
            elseif self.args[2] == "open" then
                if not door_obj:IsOpen() then
                    if #self.args == 2 then
                        door_obj:ToggleDoor(getPlayer());
                    elseif self.args[3] == "silent" then
                        door_obj:ToggleDoorSilent();
                    else
                        return "Invalid keyword - "..tostring(self.args[3]);
                    end
                end
            elseif self.args[2] == "close" then
                if door_obj:IsOpen() then
                    if #self.args == 2 then
                        door_obj:ToggleDoor(getPlayer());
                    elseif self.args[3] == "silent" then
                        door_obj:ToggleDoorSilent();
                    else
                        return "Invalid keyword - "..tostring(self.args[3]);
                    end
                end
            else
                return "Invalid action - "..tostring(self.args[2]);
            end
        else
            --return "Unable to find the door at specified coordinates";
        end
    else
        return "Invalid coordinates specified";
    end
end

CommandList_a[#CommandList_a+1] = door:new("door", 2, 3, type_dialogue);

-- window x,y,z|open/close/lock/unlock
-- window x,y,z|open/close
local window = Command:derive("window")
function window:execute(sender)
    self:debug();
    local coord = self.args[1]:ssplit(',');
    if #coord ~= 3 then
        return "["..tostring(self.Type).."] Invalid syntax";
    end
    local status;
    for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i]);
		if not status or not coord[i] then
			return "["..tostring(self.Type).."] Coordinate is not a number";
		end
	end
    local square = getCell():getGridSquare(coord[1], coord[2], coord[3]);
    if square then
        local window_obj = square:getWindow();
        if window_obj then
            if self.args[2] == "lock" then
                if #self.args == 2 then
                    window_obj:setPermaLocked(true);
                    window_obj:transmitModData()
                else
                    return "Invalid syntax";
                end
            elseif self.args[2] == "unlock" then
                if #self.args == 2 then
                    window_obj:setPermaLocked(false);
                    window_obj:transmitModData()
                else
                    return "Invalid syntax";
                end
            elseif self.args[2] == "open" then
                if not window_obj:IsOpen() then
                    window_obj:ToggleWindow(getPlayer());
                end
            elseif self.args[2] == "close" then
                if window_obj:IsOpen() then
                    window_obj:ToggleWindow(getPlayer());
                end
            else
                return "Invalid action - "..tostring(self.args[2]);
            end
        else
            --return "Unable to find the door at specified coordinates";
        end
    else
        return "Invalid coordinates specified";
    end
end

CommandList_a[#CommandList_a+1] = window:new("window", 2, nil, type_dialogue);

-- cutscene true
-- cutscene false
local cutscene = Command:derive("cutscene")
function cutscene:execute(sender)
    self:debug();
    if self.args[1] == "true" then
        Blocker.setEnabled(true);
    elseif self.args[1] == "false" then
        Blocker.setEnabled(false);
    else
        return "Invalid syntax";
    end
end

CommandList_a[#CommandList_a+1] = cutscene:new("cutscene", 1, nil, type_dialogue);

local function forceExitVehicle()
    local player = getPlayer();
    if player:isSeatedInVehicle() then
        local vehicle = player:getVehicle()
        local seat = vehicle:getSeat(player)
        vehicle:exit(player)
        vehicle:setCharacterPosition(player, seat, "outside")
        player:PlayAnim("Idle")
        triggerEvent("OnExitVehicle", player)
        vehicle:updateHasExtendOffsetForExitEnd(player);
    end
end

-- look_at x,y|async
local look_at = Command:derive("look_at")
function look_at:execute(sender)
    self:debug();
    local coords = self.args[1]:ssplit(',');
    local size = #coords;
    if size == 2 then
        local status;
        for i=1, size do
            status, coords[i] = pcall(tonumber, coords[i]);
            if not status or not coords[i] then
                return "Coordinate is not a number";
            end
        end
    else
        return "Invalid syntax";
    end
    local square = getCell():getGridSquare(coords[1], coords[2], 0);
    if square then
        if self.args[2] == "true" then
            getPlayer():faceLocation(coords[1], coords[2]);
        elseif #self.args == 1 or self.args[2] == "false" then
            local target_angle;
            local last_angle = math.floor(getPlayer():getAnimAngle());
            local function callback()
                local player = getPlayer();
                local current_angle = math.floor(player:getAnimAngle());
                if current_angle == target_angle or current_angle == last_angle then
                    if current_angle == last_angle then print("[QSystem] #look_at: Stuck! Force completing!") end
                    if not Blocker.cutscene then Blocker.setBlockMovement(false) end
                    sender.input.enable = true;
                    sender:showNext();
                else
                    last_angle = current_angle;
                    SSRTimer.add_ms(callback, 300, false);
                end
            end
            forceExitVehicle()
            Blocker.setBlockMovement(true);
            getPlayer():faceLocation(coords[1], coords[2]);
            target_angle = math.floor(getPlayer():getDirectionAngle());
            SSRTimer.add_ms(callback, 500, false);
            return -2;
        else
            return "Invalid syntax";
        end
    end
end

CommandList_a[#CommandList_a+1] = look_at:new("look_at", 1, 2, type_dialogue);

require "TimedActions/ISTimedActionQueue"
function stopDoingActionThatCanBeCancelled(playerObj)
    if DialoguePanel.instance then
        if not DialoguePanel.instance.input.enable then
            print("Attempt to clean queue during script execution (1)");
            return;
        end
    end
	playerObj:StopAllActionQueue()
end

require "ISUI/Maps/ISWorldMap"
local ISWorldMap_ToggleWorldMap = ISWorldMap.ToggleWorldMap;
ISWorldMap.ToggleWorldMap = function(playerNum)
    if DialoguePanel.instance then
        if not DialoguePanel.instance.input.enable then
            print("Attempt to clean queue during script execution (2)");
            return;
        end
    end
    ISWorldMap_ToggleWorldMap(playerNum)
end

-- walk_to x,y,z|async
local walk_to = Command:derive("walk_to")
function walk_to:execute(sender)
    self:debug();
    local coords = self.args[1]:ssplit(',');
    local size = #coords;
    if size == 3 then
        local status;
        for i=1, size do
            status, coords[i] = pcall(tonumber, coords[i]);
            if not status or not coords[i] then
                return "Coordinate is not a number";
            end
        end
        coords[1] = math.floor(coords[1]) + 0.5;
        coords[2] = math.floor(coords[2]) + 0.5;
    else
        return "Invalid syntax";
    end

    local square = getCell():getGridSquare(coords[1], coords[2], coords[3]);
    if square then
        if getPlayer():getSquare() ~= square then
            local action = ISWalkToTimedAction:new(getPlayer(), square);
            action.start = function (obj)
                obj.action:setUseProgressBar(false);
                ISWalkToTimedAction.start(obj)
            end
            if self.args[2] == "true" then
                ISTimedActionQueue.add(action);
            elseif #self.args == 1 or self.args[2] == "false" then
                action.stop = function () end
                action.forceStop = function () end
                action.forceComplete = function (o)
                    if action.completed then
                        return true;
                    else
                        ISWalkToTimedAction.forceComplete(o);
                        action.completed = true;
                        if getPlayer():getPathFindBehavior2():update() == BehaviorResult.Succeeded then
                            QuestLogger.print("[QSystem*] #walk_to: Arrived to destination.")
                            return true;
                        end
                        print("[QSystem] #walk_to: Stuck! Force completing!");
                    end
                end
                local function callback()
                    if not Blocker.cutscene then Blocker.setBlockMovement(false) end
                    sender.input.enable = true;
                    sender:showNext();
                end
                local x, y;
                local function checkPos()
                    local player = getPlayer();
                    if x == player:getX() and y == player:getY() then
                        if not action:forceComplete() then
                            if square:isFree(true) then
                                local info = string.format("walk_to, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
                                Kamisama.requestTeleport(info, coords[1], coords[2], coords[3]);
                            end
                        end
                    else
                        --print(string.format("[QSystem] #walk_to: Moving x=%.2f y=%.2f", player:getX(), player:getY()));
                        x = player:getX();
                        y = player:getY();
                        SSRTimer.add_ms(checkPos, 1000, false);
                    end
                end
                action:setOnComplete(SSRTimer.add_ms, callback, 100, false);
                forceExitVehicle()
                Blocker.setBlockMovement(true);
                ISTimedActionQueue.add(action);
                SSRTimer.add_ms(checkPos, 500, false);
                return -2;
            else
                return "Invalid syntax";
            end
        end
    end
end

CommandList_a[#CommandList_a+1] = walk_to:new("walk_to", 1, 2, type_dialogue);


-- apply_stat stat,value
-- apply_stat statA,value|statB,value
local apply_stat = Command:derive("apply_stat")
function apply_stat:execute(sender)
    self:debug();
    local stats = {};
    local data = getPlayer():getStats();
    for i=1, #self.args do
        local stat = self.args[i]:ssplit(',');
        if #stat ~= 2 then
            return "No value specifed for stat";
        end

        if not data["get"..tostring(stat[1])] and stat[1] ~= "Unhappiness" and stat[1] ~= "Boredom" then
            return "Unknown stat '"..tostring(stat[1]).."'";
        end

        local status;
        status, stat[2] = pcall(tonumber, stat[2]);
        if not status or not stat[2] then
            return "Value is not a number";
        end

        stats[i] = stat;
    end
    if not ApplyStats(getPlayer(), stats) then
        return "Unable to apply stats";
    end
end

CommandList_a[#CommandList_a+1] = apply_stat:new("apply_stat", 1, 10, type_dialogue);

local function validate_trait(name)
    for i=0, TraitFactory.getTraits():size()-1 do
        local trait = TraitFactory.getTraits():get(i);
        if name == trait:getType() then
            return true;
        end
    end
end

-- is_trait trait,1
local is_trait = Command:derive("is_trait")
function is_trait:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if validate_trait(arg[1]) then
            local status = getPlayer():getTraits():contains(arg[1]);
            if arg[2] == 'true' then
                arg[2] = true;
            elseif arg[2] == 'false' then
                arg[2] = false;
            else
                return "Invalid syntax";
            end
            if status ~= arg[2] then
                QuestLogger.print("[QSystem*] #is_trait: Skipping block due to player "..tostring(arg[2] and "not having trait " or " having trait ")..tostring(arg[1]))
                sender.script.skip = sender.script.layer+1;
                break;
            end
        else
            return "Non-existent trait '"..tostring(arg[1]).."' specified";
        end
    end
end

CommandList_a[#CommandList_a+1] = is_trait:new("is_trait", 1, 10, type_dialogue);

-- is_perk perk,level,gt
-- is_perk perk,level,lt
local is_perk = Command:derive("is_perk")
function is_perk:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if #arg == 3 then
            local perk = Perks.FromString(arg[1]);
            if perk then
                local player = getPlayer();
				local level = player and player:getPerkLevel(perk);
				if level then
					local status;
					status, arg[2] = pcall(tonumber, arg[2]);
					if status and arg[2] then
						if arg[3] == 'gt' then
							if level <= arg[2] then
								QuestLogger.print("[QSystem*] #is_perk: Skipping block due to level of perk '"..arg[1].."' being lower than \""..tostring(arg[2]));
								sender.script.skip = sender.script.layer+1;
								break;
							end
						elseif arg[3] == 'lt' then
							if level >= arg[2] then
								QuestLogger.print("[QSystem*] #is_perk: Skipping block due to level of perk '"..arg[1].."' being greater than \""..tostring(arg[2]));
								sender.script.skip = sender.script.layer+1;
								break;
							end
                        else
                            return "Invalid syntax";
						end
					else
						return "Invalid argument";
					end
				else
					return "Unable to get perk level";
				end
			else
				return "Perk '"..tostring(arg[1]).."' doesn't exist";
			end
        else
            return "Invalid syntax";
        end
    end
end

CommandList_a[#CommandList_a+1] = is_perk:new("is_perk", 1, 10, type_dialogue);

-- pop_up image|time
local pop_up = Command:derive("pop_up")
function pop_up:execute(sender)
    self:debug();
    local path = tostring(self.args[1]);
    if not path:starts_with("media/ui/") then
        path = "media/ui/"..path;
    end
    local function callback()
        sender.input.enable = true;
        sender:showNext();
    end
    local status, texture = pcall(getTexture, path);
    if status and texture then
        if #self.args == 2 then
            status, self.args[2] = pcall(tonumber, self.args[2]);
            if status and self.args[2] then
                if self.args[2] > 0 then
                    QSlide.create(texture, callback, self.args[2]);
                    return -2;
                end
            end
            return "Invalid time specified";
        else
            QSlide.create(texture, callback);
            return -2;
        end
    else
        return "Unable to load image";
    end
end

CommandList_a[#CommandList_a+1] = pop_up:new("pop_up", 1, 2, type_dialogue);

-- teleport x,y,z
local teleport = Command:derive("teleport")
function teleport:execute(sender)
    self:debug();
    local coords = self.args[1]:ssplit(',');
    local status;
    for i = 1, #coords do
        status, coords[i]  = pcall(tonumber, coords[i]);
        if not status or not coords[i] then
            return "Invalid coordinates";
        else
            coords[i] = math.floor(coords[i]);
        end
    end
    coords[1] = coords[1] + 0.5;
    coords[2] = coords[2] + 0.5;
    local function callback()
        sender.input.enable = true;
        sender:showNext();
    end
    local player = getPlayer() if player then ISTimedActionQueue.clear(player) end
    local info = string.format("teleport, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
    Kamisama.requestTeleport(info, coords[1], coords[2], coords[3], callback);
    return -2;
end

CommandList_a[#CommandList_a+1] = teleport:new("teleport", 1, nil, type_dialogue);

-- create_horde x,y,z|number
-- create_horde x,y,z|number|forced
-- create_horde x1,y1,x2,y2,z|number
-- create_horde x1,y1,x2,y2,z|number|forced
local create_horde = Command:derive("create_horde")
function create_horde:execute(sender)
    self:debug();
    self.args[1] = self.args[1]:ssplit(',');
    local coord_size, status = #self.args[1], nil;
    if coord_size == 3 or coord_size == 5 then
        for i=1, coord_size do
            status, self.args[1][i]  = pcall(tonumber, self.args[1][i]); -- coordinates conversion
            if not status or not self.args[1][i] then
                return "Invalid coordinates";
            end
        end
        status, self.args[2]  = pcall(tonumber, self.args[2]); -- number conversion
        if status or self.args[2] then
            if self.args[3] == 'true' then -- boolean conversion
                self.args[3] = true;
            elseif self.args[3] == 'false' then
                self.args[3] = false;
            elseif self.args[3] then
                return "Argument 3 is not a boolean";
            end
            local function callback()
                sender.input.enable = true;
                sender:showNext();
            end
            local info = string.format("create_horde, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
            if coord_size == 3 then
                QZombieFactory.requestSpawn(info, self.args[1][1], self.args[1][2], self.args[1][1], self.args[1][2], self.args[1][3], self.args[2], self.args[3], callback);
            else
                QZombieFactory.requestSpawn(info, self.args[1][1], self.args[1][2], self.args[1][3], self.args[1][4], self.args[1][5], self.args[2], self.args[3], callback);
            end
            return -2;
        else
            return "Argument is not a number";
        end
    else
        return "Invalid coordinates specified (must be 'x,y,z' or 'x1,y1,x2,y2,z')";
    end
end

CommandList_a[#CommandList_a+1] = create_horde:new("create_horde", 2, 3, type_dialogue);

-- remove_zombies radius|x,y,z|type
-- 1 - zeds; 2 - zeds & reanimated players; 3 - bodies; 4 - bodies (incl.players)
local remove_zombies = Command:derive("remove_zombies")
function remove_zombies:execute(sender)
    self:debug();
    local status;
    status, self.args[1]  = pcall(tonumber, self.args[1]);
    if not status or not self.args[1] then
        return "Invalid radius";
    end
    self.args[2] = self.args[2]:ssplit(',');
    if #self.args[2] == 3 then
        for i=1, 3 do
            status, self.args[2][i]  = pcall(tonumber, self.args[2][i]);
            if not status or not self.args[2][i] then
                return "Invalid coordinates";
            end
        end
        local function callback()
            sender.input.enable = true;
            sender:showNext();
        end
        local info = string.format("remove_zombies, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
        if self.args[3] == '1' then
            QZombieFactory.requestDespawn(info, self.args[1], self.args[2][1], self.args[2][2], self.args[2][3], false, false, callback);
        elseif self.args[3] == '2' then
            QZombieFactory.requestDespawn(info, self.args[1], self.args[2][1], self.args[2][2], self.args[2][3], true, false, callback);
        elseif self.args[3] == '3' then
            QZombieFactory.requestDespawn(info, self.args[1], self.args[2][1], self.args[2][2], self.args[2][3], false, true, callback);
        elseif self.args[3] == '4' then
            QZombieFactory.requestDespawn(info, self.args[1], self.args[2][1], self.args[2][2], self.args[2][3], true, true, callback);
        else
            return "Invalid type";
        end
        return -2;
    else
        return "Invalid coordinates";
    end
end

CommandList_a[#CommandList_a+1] = remove_zombies:new("remove_zombies", 3, nil, type_dialogue);

-- wait seconds
local wait = Command:derive("wait")
function wait:execute(sender)
    self:debug();
    local status, time = pcall(tonumber, self.args[1])
    if status and time then
        local function callback()
            sender.input.enable = true;
            sender:showNext();
        end
        SSRTimer.add_s(callback, time, false);
        return -2;
    else
        return "Invalid time";
    end
end

CommandList_a[#CommandList_a+1] = wait:new("wait", 1, nil, type_dialogue);

-- is_lua code|bool
local is_lua = Command:derive("is_lua")
function is_lua:execute(sender)
    self:debug();
    local fn = loadstring("return "..self.args[1]);
    if fn then
        local status, r = pcall(fn);
        if status then
            if self.args[2] == 'true' then
                self.args[2] = true;
            elseif self.args[2] == 'false' then
                self.args[2] = false;
            else
                return "Invalid syntax";
            end
            r = r or false;
            if r ~= self.args[2] then
                QuestLogger.print("[QSystem*] #is_trait: Skipping block due to return value being "..tostring(self.args[2]))
                sender.script.skip = sender.script.layer+1;
            end
            return;
        end
    end
    return "Failed to execute lua code";
end

CommandList_a[#CommandList_a+1] = is_lua:new("is_lua", 2, nil, type_dialogue);

-- execute code
local lua = Command:derive("lua")
function lua:execute(sender)
    self:debug();
    local fn = loadstring(self.args[1])
    if fn then
        local status = pcall(fn);
        if status then
            return;
        end
    end
    return "Failed to execute lua code";
end

CommandList_a[#CommandList_a+1] = lua:new("lua", 1, nil, type_dialogue);

local function list_rewards(args, reward_select)
    local list_items = {};
    local list_traits = {};
    local list_perks = {};
    for i=1, #args do
        local entry = args[i]:ssplit(',');
        local size = #entry;
        if entry[1] == "EXP" and (size > 1 and size < 5) then
            if Perks.FromString(entry[2]) then
                local status, exp, bonus;
                if size == 4 then
                    exp = entry[3];
                    bonus = entry[4] == 'true';
                elseif size == 3 then
                    bonus = entry[3] == 'true';
                    if not bonus and entry[3] ~= 'false' then
                        exp = entry[3];
                    end
                end
                if exp then
                    status, exp = pcall(tonumber, exp)
                    if not status or not exp then
                        return "Argument 3 is not a number";
                    end
                end
                list_perks[#list_perks+1] = { name = entry[2], amount = exp, bonus = bonus or false };
            else
                return "Perk "..tostring(entry[2]).." doesn't exist";
            end
        elseif entry[1] == "RNG" and (size == 2 or size == 3) then
            if Reward.Pool.exists(entry[2]) then
                local reward_type, reward = Reward.Pool.pull(entry[2]);
                if reward_type == 1 then -- item
                    reward.bonus = entry[3] == 'true' or false;
                    list_items[#list_items+1] = reward;
                elseif reward_type == 2 then -- trait
                    if reward_select then
                        list_traits[#list_traits+1] = { name = reward, bonus = entry[3] == 'true' or false };
                    else
                        list_traits[#list_traits+1] = entry[2];
                    end
                elseif reward_type == 3 then -- perk
                    reward.bonus = entry[3] == 'true' or false;
                    list_perks[#list_perks+1] = reward;
                end
            else
                return "Reward pool '"..tostring(entry[2]).."' doesn't exist";
            end
        elseif size == 3 or size == 4 then
            if getScriptManager():FindItem(entry[1]) then
                local status;
                status, entry[2] = pcall(tonumber, entry[2])
                if status and entry[2] then
                    if entry[3] == "unique" then
                        entry[3] = 4;
                    elseif entry[3] == "special" then
                        entry[3] = 3;
                    elseif entry[3] == "rare" then
                        entry[3] = 2;
                    elseif entry[3] == "common" then
                        entry[3] = 1;
                    else
                        return "Unknown item grade";
                    end
                    local item = QItemFactory.createEntry(entry[1], entry[2]);
                    item.grade = entry[3];
                    item.bonus = entry[4] == 'true';
                    list_items[#list_items+1] = item;
                else
                    return "Argument 2 is not a number";
                end
            else
                return "Item "..tostring(entry[1]).." doesn't exist";
            end
        elseif size == 1 or size == 2 then
            if validate_trait(entry[1]) then
                if reward_select then
                    list_traits[#list_traits+1] = { name = entry[1], bonus = entry[2] == 'true' or false };
                else
                    list_traits[#list_traits+1] = entry[1];
                end
            else
                return "Trait "..tostring(entry[1]).." doesn't exist";
            end
        else
            return "Invaild arguments. Must be 'item_name,amount,grade' or 'trait_name'";
        end
    end
    return list_items, list_traits, list_perks;
end

-- reward
local reward = Command:derive("reward")
reward.allow_tags = true;
function reward:execute(sender)
    self:debug();
    local items, traits, perks = list_rewards(self.args);
    if type(items) == "string" then
        return items;
    end
    local info = string.format("reward, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
    local batch_1 = #items == 0;
    local batch_2 = #traits == 0;
    local batch_3 = #perks == 0;

    local function perk_done()
        if sender.active then
            sender.input.enable = true;
            sender:showNext();
        end
    end

    local function perk_notification()
        local cards = {};
        for i=1, #perks do
            local perk = Perks.FromString(perks[i].name);
            cards[#cards+1] = Reward.Card:createEXP(perk, perks[i].amount);
        end
        local notification = Reward.Notification:new(cards, perk_done);
        notification:initialise();
        notification:addToUIManager();
        Reward.Notification.instance = notification;
    end

    local function trait_done()
        if sender.active then
            if batch_3 then
                sender.input.enable = true;
                sender:showNext();
            else
                Kamisama.addEXP(info, perks, perk_notification);
            end
        end
    end

    local function trait_notification()
        local cards = {};
        for i=1, #traits do
            local trait = TraitFactory.getTrait(traits[i]);
            cards[#cards+1] = Reward.Card:createTrait(trait);
        end
        local notification = Reward.Notification:new(cards, trait_done);
        notification:initialise();
        notification:addToUIManager();
        Reward.Notification.instance = notification;
    end

    local function item_done()
        if sender.active then
            if not batch_2 then
                Kamisama.addTraits(info, traits, trait_notification);
            elseif not batch_3 then
                Kamisama.addEXP(info, perks, perk_notification);
            else
                sender.input.enable = true;
                sender:showNext();
            end
        end
    end

    local function item_notification()
        local cards = {};
        for i=1, #items do
            local item = getScriptManager():FindItem(items[i].name);
            cards[#cards+1] = Reward.Card:createItem(item, items[i].amount, items[i].grade);
        end
        local notification = Reward.Notification:new(cards, item_done);
        notification:initialise();
        notification:addToUIManager();
        Reward.Notification.instance = notification;
    end

    if not batch_1 then
        QItemFactory.request(info, items, item_notification);
    elseif not batch_2 then
        Kamisama.addTraits(info, traits, trait_notification);
    elseif not batch_3 then
        Kamisama.addEXP(info, perks, perk_notification);
    end
    return -2;
end

CommandList_a[#CommandList_a+1] = reward:new("reward", 1, 3, type_dialogue);

-- reward_select
local reward_select = Command:derive("reward_select")
reward_select.allow_tags = true;
function reward_select:execute(sender)
    self:debug();
    local info = string.format("reward_select, %s, %s, line %d", sender.script.mod, sender.script.file, sender.script.index);
    local function confirm(items, traits, perks)
        local batch_1 = #items == 0;
        local batch_2 = #traits == 0;
        local batch_3 = #perks == 0;

        local function perk_done()
            if sender.active then
                sender.input.enable = true;
                sender:showNext();
            end
        end

        local function perk_notification()
            local cards = {};
            for i=1, #perks do
                local perk = Perks.FromString(perks[i].name);
                cards[#cards+1] = Reward.Card:createEXP(perk, perks[i].amount);
            end
            local notification = Reward.Notification:new(cards, perk_done);
            notification:initialise();
            notification:addToUIManager();
            Reward.Notification.instance = notification;
        end

        local function trait_done()
            if sender.active then
                if batch_3 then
                    sender.input.enable = true;
                    sender:showNext();
                else
                    Kamisama.addEXP(info, perks, perk_notification);
                end
            end
        end

        local function trait_notification()
            local cards = {};
            for i=1, #traits do
                local trait = TraitFactory.getTrait(traits[i]);
                cards[#cards+1] = Reward.Card:createTrait(trait);
            end
            local notification = Reward.Notification:new(cards, trait_done);
            notification:initialise();
            notification:addToUIManager();
            Reward.Notification.instance = notification;
        end

        local function item_done()
            if sender.active then
                if not batch_2 then
                    Kamisama.addTraits(info, traits, trait_notification);
                elseif not batch_3 then
                    Kamisama.addEXP(info, perks, perk_notification);
                else
                    sender.input.enable = true;
                    sender:showNext();
                end
            end
        end

        local function item_notification()
            local cards = {};
            for i=1, #items do
                local item = getScriptManager():FindItem(items[i].name);
                cards[#cards+1] = Reward.Card:createItem(item, items[i].amount, items[i].grade);
            end
            local notification = Reward.Notification:new(cards, item_done);
            notification:initialise();
            notification:addToUIManager();
            Reward.Notification.instance = notification;
        end

        if not batch_1 then
            QItemFactory.request(info, items, item_notification);
        elseif not batch_2 then
            Kamisama.addTraits(info, traits, trait_notification);
        elseif not batch_3 then
            Kamisama.addEXP(info, perks, perk_notification);
        end
    end

    local items, traits, perks = list_rewards(self.args, true);
    if type(items) == "string" then
        return items;
    end
    local lots = {};
    for i=1, #items do
        lots[#lots+1] = Reward.Card:createItem(getScriptManager():FindItem(items[i].name), items[i].amount, items[i].grade);
        lots[#lots].bonus = items[i].bonus;
    end
    for i=1, #traits do
        lots[#lots+1] = Reward.Card:createTrait(TraitFactory.getTrait(traits[i].name));
        lots[#lots].bonus = traits[i].bonus;
    end
    for i=1, #perks do
        lots[#lots+1] = Reward.Card:createEXP(Perks.FromString(perks[i].name), perks[i].amount);
        lots[#lots].bonus = perks[i].bonus;
    end
    local selection = Reward.Selection:new(lots, confirm);
    selection:initialise();
    selection:addToUIManager();
    Reward.Selection.instance = selection;
    return -2;
end

CommandList_a[#CommandList_a+1] = reward_select:new("reward_select", 2, 3, type_dialogue);

-- deliver quest|task
local deliver = Command:derive("deliver")
function deliver:execute(sender)
    self:debug();
    local quest = QuestManager.instance:getQuest(self.args[1]);
    if quest then
        if quest.completed or quest.failed or not quest.unlocked then
            QuestLogger.print("[QSystem*] #deliver: Skipping block due to quest '"..tostring(self.args[1]).."' being locked, completed or failed")
            sender.script.skip = sender.script.layer+1;
        else
            local task = quest:getTask(self.args[2]);
            if task then
                if task.type == "Deliver" then
                    if task.unlocked and not task.pending and not task.completed then
                        local function onConfirm()
                            sender.input.enable = true;
                            sender:showNext();
                        end
                        local function onCancel()
                            QuestLogger.print("[QSystem*] #deliver: Skipping block due delivery being canceled")
                            sender.script.skip = sender.script.layer+1;
                            onConfirm();
                        end
                        sender:setVisible(false);
                        local fetcher = ItemFetcher.UI:new(task, onConfirm, onCancel)
                        fetcher:initialise();
                        fetcher:addToUIManager();
                        return -2;
                    else
                        QuestLogger.print("[QSystem*] #deliver: Skipping block due to task \""..tostring(self.args[2]).."\" of quest '"..tostring(self.args[1]).."' being locked or completed")
                        sender.script.skip = sender.script.layer+1;
                    end
                else
                    return "Type of task '"..tostring(self.args[2]).."' is not Delivery";
                end
            else
                return "Task '"..tostring(self.args[2]).."' not found";
            end
        end
    else
        return "Quest '"..tostring(self.args[1]).."' not found";
    end
end

CommandList_a[#CommandList_a+1] = deliver:new("deliver", 2, nil, type_dialogue);

-- reset_area id|refresh
local reset_area = Command:derive("reset_area")
function reset_area:execute(sender)
    self:debug();
    QuestArea.restore(self.args[1]);
    if self.args[2] then
        if self.args[2] == "true" then
            QuestArea.update(true);
        elseif self.args[2] ~= "false" then
            return "Invalid syntax";
        end
    end
end

CommandList_a[#CommandList_a+1] = reset_area:new("reset_area", 1, 2, type_dialogue);

-- update_area id|bgm|refresh
local update_area = Command:derive("update_area")
function update_area:execute(sender)
    self:debug();
    local music_track = self.args[2] ~= "o" and self.args[2] or false;
    if QuestArea.bgm(music_track, self.args[1]) then
        if self.args[3] then
            if self.args[3] == "true" then
                QuestArea.update(true);
            elseif self.args[3] ~= "false" then
                return "Invalid syntax";
            end
        end
    else
        return string.format("QuestArea with id '%s' doesn't exist", tostring(self.args[1]));
    end
end

CommandList_a[#CommandList_a+1] = update_area:new("update_area", 2, 3, type_dialogue);


-- is_achievement achievement,true
-- is_achievement achievement_a,true|achievement_b,false
local is_achievement = Command:derive("is_achievement")
function is_achievement:execute(sender)
    self:debug();
    for i=1, #self.args do
        local arg = self.args[i]:ssplit(',');
        if arg[2] == 'true' then
            arg[2] = true;
        elseif arg[2] == 'false' then
            arg[2] = false;
        else
            return "Invalid syntax";
        end
        if CharacterManager.instance:isAchievement(arg[1]) ~= arg[2] then
            QuestLogger.print("[QSystem*] #is_achievement: Skipping block due to achievement \""..tostring(arg[1]).."\" not being "..(arg[2] and "unlocked" or "locked"))
            sender.script.skip = sender.script.layer+1;
            break;
        end
    end
end

CommandList_a[#CommandList_a+1] = is_achievement:new("is_achievement", 1, 10, {type_dialogue, type_character_desc});

-- start_ngp forced
local start_ngp = Command:derive("start_ngp")
function start_ngp:execute(sender)
    self:debug();
    local function callback(target, button, param1, param2)
        if button.internal == "YES" then  -- start
            NGP.start()
        else -- cancel
            sender.input.enable = true;
            sender:showNext();
        end
    end
    if self.args[1] == 'true' then
        callback(nil, { internal = "YES" });
    elseif self.args[1] == nil or self.args[1] == 'false' then
        local modal = ISModalDialogMod:new(getCore():getScreenWidth() / 2 - 175*SSRLoader.scale, getCore():getScreenHeight() / 2 - 75*SSRLoader.scale, 350*SSRLoader.scale, 130*SSRLoader.scale, true, nil, callback);
        modal.text = getTextOrNull("UI_QSystem_NGP_Warning") or "<CENTRE> You are about to start New Game+. <LINE> Current save data will be overwritten. <LINE> <LINE> Proceed?";
        modal.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.8};
        modal.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
        modal:initialise()
        modal:addToUIManager()
        modal:setCapture(true);
        modal:paginate();
    else
        return "Invalid syntax";
    end
    return -2;
end

CommandList_a[#CommandList_a+1] = start_ngp:new("start_ngp", 0, 1, type_dialogue);