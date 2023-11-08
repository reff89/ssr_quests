-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Quests/Action"
require "Scripting/QuestCreator"

-- UnlockTask
local Action_UnlockTask = Action:derive("Action");
Action_UnlockTask.type = "UnlockTask";
function Action_UnlockTask.create(args)
    if #args ~= 2 then
        return "Wrong argument count. Must be 2";
    end
    args[2] = args[2]:ssplit(',');
    return Action_UnlockTask:new(args[1], args[2]);
end

function Action_UnlockTask:execute()
    self:setPending(true);
    local quest = QuestManager.instance:getQuest(self.quest_id);
    if quest then
        for i=1, #self.task_ids do
            local task = quest:getTask(self.task_ids[i]);
            if task then
                task:unlock();
            else
                print("[QSystem] (Error) Task not found - '"..tostring(self.task_ids[i]).."'. Action=UnlockTask");
                return;
            end
        end
        self:complete();
    else
        print("[QSystem] (Error) Quest not found - '"..tostring(self.quest_id).."'. Action=UnlockTask");
    end
end

function Action_UnlockTask:new(quest_id, task_ids)
	local o = {};
	o = Action:new(Action_UnlockTask.type);
	setmetatable(o, self);
	self.__index = self;

	o.quest_id = quest_id;
    o.task_ids = task_ids;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_UnlockTask;

-- CompleteTask
local Action_CompleteTask = Action:derive("Action");
Action_CompleteTask.type = "CompleteTask";
function Action_CompleteTask.create(args)
    if #args ~= 2 then
        return "Wrong argument count. Must be 2";
    end
    return Action_CompleteTask:new(args[1], args[2]);
end

function Action_CompleteTask:execute()
    self:setPending(true);
    local quest = QuestManager.instance:getQuest(self.quest_id);
    if quest then
        local task = quest:getTask(self.task_id);
        if task then
            task:complete();
            self:complete();
            SaveManager.save(); -- save data
        else
            print("[QSystem] (Error) Task not found - '"..tostring(self.task_id).."' in "..tostring(self.quest_id).."'. Action=CompleteTask");
        end
    else
        print("[QSystem] (Error) Quest not found - '"..tostring(self.quest_id).."'. Action=CompleteTask");
    end
end

function Action_CompleteTask:new(quest_id, task_id)
	local o = {};
	o = Action:new(Action_CompleteTask.type);
	setmetatable(o, self);
	self.__index = self;

	o.quest_id = quest_id;
    o.task_id = task_id;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_CompleteTask;

-- UnlockQuest
local Action_UnlockQuest = Action:derive("Action");
Action_UnlockQuest.type = "UnlockQuest";
function Action_UnlockQuest.create(args)
    if #args ~= 1 then
        return "Wrong argument count. Must be 1";
    end
    return Action_UnlockQuest:new(args[1]);
end

function Action_UnlockQuest:execute()
    self:setPending(true);
    local quest = QuestManager.instance:getQuest(self.quest_id);
    if quest then
        if quest.event then
            print("[QSystem] (Error) Attempt to manually unlock event quest - '"..tostring(self.quest_id).."'. Action=UnlockQuest");
        else
            quest:unlock();
        end
        self:complete();
    else
        print("[QSystem] (Error) Quest not found - '"..tostring(self.quest_id).."'. Action=UnlockQuest");
    end
end

function Action_UnlockQuest:new(quest_id, task_id)
	local o = {}
	o = Action:new(Action_UnlockQuest.type);
	setmetatable(o, self)
	self.__index = self

	o.quest_id = quest_id
    o.task_id = task_id

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_UnlockQuest;

-- CompleteQuest
local Action_CompleteQuest = Action:derive("Action");
Action_CompleteQuest.type = "CompleteQuest";
function Action_CompleteQuest.create(args)
    if #args ~= 1 then
        return "Wrong argument count. Must be 1";
    end
    return Action_CompleteQuest:new(args[1]);
end

function Action_CompleteQuest:execute()
    self:setPending(true);
    local quest = QuestManager.instance:getQuest(self.quest_id);
    if quest then
        quest:complete();
        self:complete();
        SaveManager.save(); -- save data
    else
        print("[QSystem] (Error) Quest not found - '"..tostring(self.quest_id).."'. Action=CompleteQuest");
    end
end

function Action_CompleteQuest:new(quest_id)
	local o = {};
	o = Action:new(Action_CompleteQuest.type);
	setmetatable(o, self);
	self.__index = self;

	o.quest_id = quest_id;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_CompleteQuest;

-- FailQuest
local Action_FailQuest = Action:derive("Action");
Action_FailQuest.type = "FailQuest";
function Action_FailQuest.create(args)
    if #args ~= 1 then
        return "Wrong argument count. Must be 1";
    end
    return Action_FailQuest:new(args[1]);
end

function Action_FailQuest:execute()
    self:setPending(true);
    local quest = QuestManager.instance:getQuest(self.quest_id);
    if quest then
        quest:fail();
        self:complete();
        SaveManager.save(); -- save data
    else
        print("[QSystem] (Error) Quest not found - '"..tostring(self.quest_id).."'. Action=FailQuest");
    end
end

function Action_FailQuest:new(quest_id)
	local o = {};
	o = Action:new(Action_FailQuest.type);
	setmetatable(o, self);
	self.__index = self;

	o.quest_id = quest_id;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_FailQuest;

-- SetFlag
local Action_SetFlag = Action:derive("Action");
Action_SetFlag.type = "SetFlag";
function Action_SetFlag.create(args)
    if #args ~= 2 then
        return "Wrong argument count. Must be 2";
    end
    local flag = tostring(args[1])
    if args[2] == 'true' then
	    return Action_SetFlag:new(flag, true);
    elseif args[2] == 'false' then
        return Action_SetFlag:new(flag, false);
    else
        return "Invalid syntax";
    end
end

function Action_SetFlag:execute()
    self:setPending(true);
    if self.value then
        CharacterManager.instance:addFlag(self.flag)
    else
        CharacterManager.instance:removeFlag(self.flag)
    end

    self:complete();
end

function Action_SetFlag:new(flag, value)
	local o = {}
	o = Action:new(Action_SetFlag.type);
	setmetatable(o, self)
	self.__index = self

    o.flag = flag
    o.value = value

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_SetFlag;

-- SetEvent
local Action_SetEvent = Action:derive("Action");
Action_SetEvent.type = "SetEvent";
function Action_SetEvent.create(args)
    local id = tostring(args[1]);
    local rt = args[2] == "true" or args[2] == "1";
    if args[2] ~= "false" and args[2] ~= "0" and not rt then
        return "Invalid argument";
    end
    if #args == 3 then
        local status, value = pcall(tonumber, args[3]);
        if status and value then
            return Action_SetEvent:new(id, value, rt);
        else
            return "Argument 3 is not a number";
        end
    elseif #args == 4 then
        local time = args[3]:ssplit(':');
        if #time == 2 then
            for i=1, #time do
                local status, value = pcall(tonumber, time[i]);
                if status and value then
                    time[i] = value;
                end
            end
        else
            return "Invalid time format in argument 3 - "..tostring(args[3]);
        end
        local status, value = pcall(tonumber, args[4]);
        if status and value then
            time[3] = value;
        else
            return "Argument 4 is not a number";
        end
        return Action_SetEvent:new(id, time, rt);
    else
        return "Wrong argument count. Must be 3 or 4";
    end
end

function Action_SetEvent:execute()
    self:setPending(true);
    CharacterManager.instance:setEvent(self.event, self.time, self.rt);
    self:complete();
end

function Action_SetEvent:new(event, time, rt)
	local o = {}
	o = Action:new(Action_SetEvent.type);
	setmetatable(o, self)
	self.__index = self

    o.event = event;
    o.time = time;
    o.rt = rt;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_SetEvent;


-- RunScript
-- RunScript|script
-- RunScript|script,label
local Action_RunScript = Action:derive("Action");
Action_RunScript.type = "RunScript";
function Action_RunScript.create(args)
    if #args ~= 1 then
        return "Wrong argument count. Must be 1";
    end
    local script = args[1]:ssplit(',');
    if #script == 2 then
        return Action_RunScript:new(script[1], script[2]);
    elseif #script == 1 then
        return Action_RunScript:new(args[1], nil);
    else
        return "Invalid syntax";
    end
end

function Action_RunScript:reload()
    self.error = false;
    Action.reload(self);
end

function Action_RunScript:reset()
    self.error = false;
    Action.reset(self);
end

function Action_RunScript:update()
    if not DialoguePanel.instance then
        self:complete();
    end
end

function Action_RunScript:execute()
    if getPlayer():isSeatedInVehicle() or DialogueManager.pause then return end
    if not DialoguePanel.instance and not self.error then
        if DialoguePanel.create(self.script, self.label) then
            self:setPending(true);
        else
            self.error = true;
        end
    end
end

function Action_RunScript:new(script, label)
	local o = {};
	o = Action:new(Action_RunScript.type);
	setmetatable(o, self);
	self.__index = self;

	o.script = script;
    o.label = label;

    o.error = false;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_RunScript;

local function validate_trait(name)
    for i=0, TraitFactory.getTraits():size()-1 do
        local trait = TraitFactory.getTraits():get(i);
        if name == trait:getType() then
            return true;
        end
    end
end

-- Reward
local Action_Reward = Action:derive("Action");
Action_Reward.type = "Reward";
Action_Reward.save = true;
function Action_Reward.create(args)
    local items = {};
    local traits = {};
    local perks = {};
    local rg = {}
    for i=1, #args do
        local entry = args[i]:ssplit(',');
        local size = #entry;
        if entry[1] == "EXP" and (size == 2 or size == 3) then
            if Perks.FromString(entry[2]) then
                local status, exp = nil, entry[3];
                if exp then
                    status, exp = pcall(tonumber, exp)
                    if not status or not exp then
                        return "Argument 3 is not a number";
                    end
                end
                perks[#perks+1] = { name = entry[2], amount = exp };
            else
                return "Perk "..tostring(entry[2]).." doesn't exist";
            end
        elseif entry[1] == "RNG" and size == 2 then
            if Reward.Pool.exists(entry[2]) then
                rg[#rg+1] = entry[2];
            else
                return "Reward pool '"..tostring(entry[2]).."' doesn't exist";
            end
        elseif size == 3 then
            if getScriptManager():FindItem(entry[1]) then
                local status;
                status, entry[2] = pcall(tonumber, entry[2]);
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
                    items[#items+1] = entry;
                else
                    return "Argument 2 is not a number";
                end
            else
                return "Item "..tostring(entry[1]).." doesn't exist";
            end
        elseif size == 1 then
            if validate_trait(entry[1]) then
                traits[#traits+1] = entry[1];
            else
                return "Trait "..tostring(entry[1]).." doesn't exist";
            end
        else
            return "Invaild arguments. Must be 'item_name,amount,grade' or 'trait_name'";
        end
    end
    if QuestManager.instance.creator then
        local info = string.format("Action_Reward, %s, %s", QuestManager.instance.creator.quest.internal, QuestManager.instance.creator.quest.tasks[#QuestManager.instance.creator.quest.tasks].internal);
        return Action_Reward:new(items, traits, perks, rg, info);
    else
        return "Unexpected error";
    end
end

function Action_Reward:reload()
    self.executed = false;
    Action.reload(self);
end

function Action_Reward:reset()
    self.batch_1 = #self.items == 0;
    self.batch_2 = #self.traits == 0;
    self.batch_3 = #self.perks == 0;
    self.executed = false;
    Action.reset(self);
end

function Action_Reward:update()
    if (self.batch_1 and self.batch_2 and self.batch_3) or not self.executed then
        self:complete();
    end
end

local function merge(table_1, table_2)
    local size = #table_1;
    for i=1, #table_2 do
        table_1[size+i] = table_2[i];
    end
    return table_1;
end

function Action_Reward:execute()
    if not self.pending then
        local items, traits, perks = {}, {}, {};
        for i=1, #self.rg do
            local reward_type, reward = Reward.Pool.pull(self.rg[i]);
            if reward_type == 1 then items[#items+1] = reward;
            elseif reward_type == 2 then traits[#traits+1] = reward;
            elseif reward_type == 3 then perks[#perks+1] = reward;
            end
        end
        items = merge(items, self.items);
        traits = merge(traits, self.traits);
        perks = merge(perks, self.perks);
        self.batch_1 = #items == 0;
        self.batch_2 = #traits == 0;
        self.batch_3 = #perks == 0;

        local function perk_done()
            self.batch_3 = true;
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
            self.batch_2 = true;
            if not self.batch_3 then
                Kamisama.addEXP(self.info, self.perks, perk_notification);
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
            self.batch_1 = true;
            if not self.batch_2 then
                Kamisama.addTraits(self.info, self.traits, trait_notification);
            elseif not self.batch_3 then
                Kamisama.addEXP(self.info, self.perks, perk_notification);
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

        if not self.batch_1 then
            QItemFactory.request(self.info, items, item_notification);
        elseif not self.batch_2 then
            Kamisama.addTraits(self.info, traits, trait_notification);
        elseif not self.batch_3 then
            Kamisama.addEXP(self.info, perks, perk_notification);
        end
        self.executed = true;
        self:setPending(true);
    end
end

function Action_Reward:new(items, traits, perks, rg, info)
	local o = {}
	o = Action:new(Action_Reward.type);
	setmetatable(o, self)
	self.__index = self

    o.items = {};
    for i=1, #items do
        o.items[#o.items+1] = QItemFactory.createEntry(items[i][1], items[i][2]);
        o.items[#o.items].grade = items[i][3];
    end
    o.traits = traits;
    o.perks = perks;
    o.rg = rg; -- randomly generated

    o.batch_1 = #items == 0;
    o.batch_2 = #traits == 0;
    o.batch_3 = #perks == 0;

    o.info = info;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_Reward;


-- SelectReward
local Action_SelectReward = Action:derive("Action");
Action_SelectReward.type = "SelectReward";
Action_SelectReward.save = true;
function Action_SelectReward.create(args)
    local items = {};
    local traits = {};
    local perks = {};
    local rg = {};
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
                perks[#perks+1] = { name = entry[2], amount = exp, bonus = bonus or false };
            else
                return "Perk "..tostring(entry[2]).." doesn't exist";
            end
        elseif entry[1] == "RNG" and (size == 2 or size == 3) then
            if Reward.Pool.exists(entry[2]) then
                rg[#rg+1] = { entry[2], entry[3] == 'true' or false };
            else
                return "Reward pool '"..tostring(entry[2]).."' doesn't exist";
            end
        elseif size == 3 or size == 4 then
            if getScriptManager():FindItem(entry[1]) then
                local status;
                status, entry[2] = pcall(tonumber, entry[2]);
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
                    entry[4] = entry[4] == 'true';
                    items[#items+1] = entry;
                else
                    return "Argument 2 is not a number";
                end
            else
                return "Item "..tostring(entry[1]).." doesn't exist";
            end
        elseif size == 1 or size == 2 then
            if validate_trait(entry[1]) then
                traits[#traits+1] = { name = entry[1], bonus = entry[2] == 'true' };
            else
                return "Trait "..tostring(entry[1]).." doesn't exist";
            end
        else
            return "Invaild arguments. Must be 'item_name,amount,grade' or 'trait_name'";
        end
    end
    if QuestManager.instance.creator then
        local info = string.format("Action_SelectReward, %s, %s", QuestManager.instance.creator.quest.internal, QuestManager.instance.creator.quest.tasks[#QuestManager.instance.creator.quest.tasks].internal);
        return Action_SelectReward:new(items, traits, perks, rg, info);
    else
        return "Unexpected error";
    end
end

function Action_SelectReward:reload()
    self.executed = false;
    Action.reload(self);
end

function Action_SelectReward:reset()
    self.executed = false;
    Action.reset(self);
end

function Action_SelectReward:update()
    if (self.batch_1 and self.batch_2 and self.batch_3) or not self.executed then
        self:complete();
    end
end

function Action_SelectReward:execute()
    if not self.pending then
        local function confirm(items, traits, perks)
            self.batch_1 = #items == 0;
            self.batch_2 = #traits == 0;
            self.batch_3 = #perks == 0;

            local function perk_done()
                self.batch_3 = true;
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
                self.batch_2 = true;
                if not self.batch_3 then
                    Kamisama.addEXP(self.info, perks, perk_notification);
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
                self.batch_1 = true;
                if not self.batch_2 then
                    Kamisama.addTraits(self.info, traits, trait_notification);
                elseif not self.batch_3 then
                    Kamisama.addEXP(self.info, perks, perk_notification);
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

            if not self.batch_1 then
                QItemFactory.request(self.info, items, item_notification);
            elseif not self.batch_2 then
                Kamisama.addTraits(self.info, traits, trait_notification);
            elseif not self.batch_3 then
                Kamisama.addEXP(self.info, perks, perk_notification);
            end
        end

        local items, traits, perks = {}, {}, {};
        for i=1, #self.rg do
            local reward_type, reward = Reward.Pool.pull(self.rg[i][1]);
            if reward_type == 1 then -- item
                reward.bonus = self.rg[i][2];
                items[#items+1] = reward;
            elseif reward_type == 2 then -- trait
                traits[#traits+1] = { name = reward, bonus = self.rg[i][2] };
            elseif reward_type == 3 then -- perk
                reward.bonus = self.rg[i][2];
                perks[#perks+1] = reward;
            end
        end
        items = merge(items, self.items);
        traits = merge(traits, self.traits);
        perks = merge(perks, self.perks);

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
        self.executed = true;
        self:setPending(true);
    end
end

function Action_SelectReward:new(items, traits, perks, rg, info)
	local o = {}
	o = Action:new(Action_SelectReward.type);
	setmetatable(o, self)
	self.__index = self

    o.items = {};
    for i=1, #items do
        o.items[#o.items+1] = QItemFactory.createEntry(items[i][1], items[i][2]);
        o.items[#o.items].grade = items[i][3];
        o.items[#o.items].bonus = items[i][4];
    end
    o.traits = traits;
    o.perks = perks;
    o.rg = rg; -- randomly generated

    o.info = info;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_SelectReward;

-- ApplyStat
local Action_ApplyStat = Action:derive("Action");
Action_ApplyStat.type = "ApplyStat";
function Action_ApplyStat.create(args)
    if #args < 1 then
        return "Wrong argument count. Must be at least 1";
    end
    local stats = {};
    local _stats = getPlayer():getStats();
    for i=1, #args do
        local stat = args[i]:ssplit(',');
        if #stat ~= 2 then
            return "No value specifed for stat";
        end

        if not _stats["get"..tostring(stat[1])] and stat[1] ~= "Unhappiness" and stat[1] ~= "Boredom" then
            return "Unknown stat - "..tostring(stat[1]);
        end

        local status;
        status, stat[2] = pcall(tonumber, stat[2])
        if not status or not stat[2] then
            return "Value is not a number";
        end

        stats[i] = stat;
    end
    return Action_ApplyStat:new(stats)
end

function Action_ApplyStat:reload()
    self.error = false;
    Action.reload(self);
end

function Action_ApplyStat:reset()
    self.error = false;
    Action.reset(self);
end

function Action_ApplyStat:update()
    if self.pending and not self.completed then
        if getPlayer():getHaloTimerCount() <= 0 then
            self:complete();
        end
    end
end

function Action_ApplyStat:execute()
    if not self.error then
        if ApplyStats(getPlayer(), self.stats) then
            self:setPending(true);
        else
            print("[QSystem] (Error) Unable to apply stats. Action=ApplyStat");
            self.error = true;
        end
    end
end

function Action_ApplyStat:new(stats)
	local o = {}
	o = Action:new(Action_ApplyStat.type);
	setmetatable(o, self)
	self.__index = self

	o.stats = stats;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_ApplyStat;

-- CreateHorde
local Action_CreateHorde = Action:derive("Action");
Action_CreateHorde.type = "CreateHorde";
function Action_CreateHorde.create(args)
    local args_size = #args;
    if args_size < 2 or args_size > 3 then
        return "Wrong argument count. Must be 2 or 3";
    end
    local coord = args[1]:ssplit(',');
    local coord_size = #coord;
    if coord_size == 5 or coord_size == 3 then
        local status;
        for i=1, coord_size do
            status, coord[i] = pcall(tonumber, coord[i])
            if not status or not coord[i] then
                return "Coordinate is not a number";
            end
        end
        status, args[2] = pcall(tonumber, args[2])
        if not status or not args[2] then
            return "Argument 2 is not a value";
        end
        if args[3] == 'true' then
            args[3] = true;
        elseif args[3] == 'false' then
            args[3] = false;
        elseif args[3] then
            return "Argument 3 is not a boolean";
        end
        if QuestManager.instance.creator then
            local info = string.format("Action_CreateHorde, %s, %s", QuestManager.instance.creator.quest.internal, QuestManager.instance.creator.quest.tasks[#QuestManager.instance.creator.quest.tasks].internal);
            if coord_size == 3 then
                return Action_CreateHorde:new(coord[1], coord[2], coord[1], coord[2], coord[3], args[2], args[3], info);
            else
                return Action_CreateHorde:new(coord[1], coord[2], coord[3], coord[4], coord[5], args[2], args[3], info);
            end
        else
            return "Unexpected error";
        end
    else
        return "Invalid coordinates specified (must be 'x,y,z' or 'x1,y1,x2,y2,z')";
    end
	
end

function Action_CreateHorde:execute()
    if not self.pending then
        local function callback()
            self:complete();
        end
        QZombieFactory.requestSpawn(self.info, self.x1, self.y1, self.x2, self.y2, self.z, self.amount, self.forced, callback);
        self:setPending(true);
    end
end

function Action_CreateHorde:new(x1, y1, x2, y2, z, amount, forced, info)
	local o = {}
	o = Action:new(Action_CreateHorde.type);
	setmetatable(o, self)
	self.__index = self

    o.info = info;
	o.x1 = x1;
	o.y1 = y1;
    o.x2 = x2;
	o.y2 = y2;
    o.z = z;
    o.amount = amount;

    o.forced = forced or false;

	return o;
end

QuestCreator.actions[#QuestCreator.actions+1] = Action_CreateHorde;