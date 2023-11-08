-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Quests/Task"
require "Scripting/QuestCreator"
require "Communications/QSystem"

-- Have selected item(s) in your inventory
-- FindItem|item|...|item
-- FindItem|item,amount|...|item,amount
local Task_FindItem = Task:derive("Task")
Task_FindItem.type = "FindItem"
function Task_FindItem.create(internal, args)
	local items = {};
	local script_manager = getScriptManager();
	for i=1, #args do
		items[i] = args[i]:ssplit(',')
		if not script_manager:FindItem(tostring(items[i][1])) then
			return "Item doesn't exist - "..tostring(items[i][1]);
		end
		if #items[i] == 2 then
			local status;
			status, items[i][2] = pcall(tonumber, items[i][2]);
			if not status or not items[i][2] then
				return "Invalid argument";
			end
		else
			items[i][2] = 1;
		end
	end
	return Task_FindItem:new(internal, items);
end

function Task_FindItem:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			local pending = true;
			for i=1, #self.items do
				if self.inventory:getNumberOfItem(self.items[i][1], false, true) < self.items[i][2] then
					pending = false
					break;
				end
			end
			if pending then
				self:setPending(true);
			end
			self.timer = getTimeInMillis() + 250;
		end
	end

	Task.update(self);
end

function Task_FindItem:new(internal, items)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	-- items { { item_name, count }, ... }
	o.items = items
	o.inventory = getPlayer():getInventory();
	o.timer = 0;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_FindItem;


-- Go to location
-- GotoLocation|x,y,z|location_type|showOnMap
-- GotoLocation|x1,y1,x2,y2,z|showOnMap
local Task_GotoLocation = Task:derive("Task")
Task_GotoLocation.type = "GotoLocation"
function Task_GotoLocation.create(internal, args)
	local size = #args;
	if size > 3 or size < 1 then
		return "Wrong argument count. Must be 1, 2 or 3";
	end
	local coord = args[1]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if #coord == 3 and (size == 2 or size == 3) then
		if args[2] == "building" then
			args[2] = 0;
		elseif args[2] == "room" then
			args[2] = 1;
		elseif args[2] == "point" then
			args[2] = 2;
		else
			return "Invalid location type specified. Must be 'building', 'room' or 'point'";
		end
		return Task_GotoLocation:new_1(internal, coord[1], coord[2], coord[3], args[2], args[3] == "true");
	elseif #coord == 5 and (size == 1 or size == 2) then
		if coord[3] < coord[1] or coord[4] < coord[2] then
			return "Reversed coordinates detected. Make sure that x2 >= x1 and y2 >= y1";
		end
		return Task_GotoLocation:new_2(internal, coord[1], coord[2], coord[3], coord[4], coord[5], args[2] == "true");
	else
		return "Invalid syntax. Must be 'GotoLocation|x,y,z|loc_type' or 'GotoLocation|x1,y1,x2,y2,z'";
	end
end

function Task_GotoLocation:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			if self.isArea then
				local x = math.floor(getPlayer():getX())
				local y = math.floor(getPlayer():getY())
				local z = math.floor(getPlayer():getZ())
				if (x >= self.x1 and y >= self.y1) and (x <= self.x2 and y <= self.y2) and z == self.z then
					self:setPending(true);
					QuestLogger.print("[QSystem*] Entered target area. Task=GotoLocation")
				end
				self.timer = getTimeInMillis() + 500;
			else
				local square = getCell():getGridSquare(self.x, self.y, self.z);
				if square ~= nil then
					if self.locationType == 0 then
						if self.building == nil then
							local building = square:getBuilding()
							if building ~= nil then
								local def = building:getDef()
								if def ~= nil then
									self.building = building;
									QuestLogger.print("[QSystem*] Target building defined. Task=GotoLocation")
								end
							end
						elseif getPlayer():getSquare():getBuilding() == self.building then
							self:setPending(true);
							QuestLogger.print("[QSystem*] Entered target building. Task=GotoLocation")
						end
						self.timer = getTimeInMillis() + 1000;
					elseif self.locationType == 1 then
						if self.room == nil then
							local room = square:getRoom()
							if room ~= nil then
								self.room = room;
								QuestLogger.print("[QSystem*] Target room defined - '"..tostring(room:getName()).."'. Task=GotoLocation")
							end
						elseif getPlayer():getSquare():getRoom() == self.room then
							self:setPending(true);
							QuestLogger.print("[QSystem*] Entered target room. Task=GotoLocation")
						end
						self.timer = getTimeInMillis() + 500;
					elseif self.locationType == 2 then
						if getPlayer():getSquare() == square then
							self:setPending(true);
							QuestLogger.print("[QSystem*] Entered target square. Task=GotoLocation")
						end
						self.timer = getTimeInMillis() + 500;
					end
				end
			end
		end
	end

	Task.update(self);
end

function Task_GotoLocation:new_1(internal, x, y, z, locationType, showOnMap)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.isArea = false;
	o.x = x;
	o.y = y;
	o.z = z;
	o.locationType = locationType; -- 0 (Building), 1 (Room), 2 (Point)
	if o.locationType == 0 then
		o.building = nil;
	elseif o.locationType == 1 then
		o.room = nil;
	elseif o.locationType == 2 then
		-- TODO: use homing points and world markers for point targets
		-- addPlayerHomingPoint(getPlayer(), sq:getX(), sq:getY(), 0.8, 0.8, 0, 1);
	end

	o.showOnMap = showOnMap;
	o.timer = 0;
	return o
end

function Task_GotoLocation:new_2(internal, x1, y1, x2, y2, z, showOnMap)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.internal = internal;

	o.isArea = true;
	o.x1 = x1;
	o.y1 = y1;
	o.x2 = x2;
	o.y2 = y2;
	o.z = z;

	o.x = x1 + (x2 - x1) / 2;
	o.y = y1 + (y2 - y1) / 2;
	o.showOnMap = showOnMap;
	o.timer = 0;
	return o
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_GotoLocation;


-- Perform context action at coordinates or wait until flag is raised
-- ContextAction|Title|x,y,z
-- ContextAction|Title|x,y,z|time
-- ContextAction|Title|x,y,z|time,anim
-- ContextAction|Title|x,y,z|time|script|flag
-- ContextAction|Title|x,y,z|time|script,label|flag
local Task_ContextAction = Task:derive("Task")
Task_ContextAction.type = "ContextAction"
local caq = {}; -- context action queue

function Task_ContextAction.create(internal, args)
	if #args < 2 then
		return "Wrong argument count";
	end
	local coord = args[2]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if #args == 2 then
		return Task_ContextAction:new(internal, args[1], coord[1], coord[2], coord[3]);
	else
		args[3] = args[3]:ssplit(',');
		status, args[3][1] = pcall(tonumber, args[3][1]);
		if not status or not args[3][1] then
			return "Invalid time format";
		end
		if args[3][2] == "" then return "Invalid action animation"; end
		if #args == 5 then
			args[4] = args[4]:ssplit(',');
			local script, label = args[4][1], args[4][2];
			return Task_ContextAction:new(internal, args[1], coord[1], coord[2], coord[3], args[3][1], args[3][2], script, label, args[5]);
		else
			return Task_ContextAction:new(internal, args[1], coord[1], coord[2], coord[3], args[3][1], args[3][2]);
		end
	end
end

local marker_ids = {};
function Task_ContextAction.isValidMarker(id)
	if id then
		for i=1, #marker_ids do
			if marker_ids[i] == id then
				return true;
			end
		end
	end
end

Task_ContextAction.onQSystemUpdate = function(code)
	if code == 4 then
		for i=1, #marker_ids do
			if getWorldMarkers():removeGridSquareMarker(marker_ids[i]) then
				QuestLogger.print("[QSystem*] Removed world marker with id '"..tostring(marker_ids[i]).."'. Task=ContextAction")
			end
		end
		marker_ids = {};
	end
end

Task_ContextAction.onQSystemReset = function()
	caq = {};
	Task_ContextAction.onQSystemUpdate(4);
end

Events.OnQSystemUpdate.Add(Task_ContextAction.onQSystemUpdate);
Events.OnQSystemReset.Add(Task_ContextAction.onQSystemReset);

Task_ContextAction.createMenu = function(player, context, worldobjects)
	if caq[1] and #worldobjects > 0 then
		for i=#caq, 1, -1 do
			if QuestManager.instance.quests[caq[i][1]] then
				if QuestManager.instance.quests[caq[i][1]].unlocked and not (QuestManager.instance.quests[caq[i][1]].completed or QuestManager.instance.quests[caq[i][1]].failed) then
					if QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].unlocked and not (QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].pending or QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].completed) then
						local square = worldobjects[1]:getSquare();
						if QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].x == square:getX() and QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].y == square:getY() and QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].z == square:getZ() then
							if QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].time > 0 then
								context:addOptionOnTop(getText(QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].text), QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]], QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].start, nil);
							else
								context:addOptionOnTop(getText(QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].text), QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]], QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].perform, nil);
							end
						end
					end
				end
			end
		end
	end
end

Events.OnFillWorldObjectContextMenu.Add(Task_ContextAction.createMenu)

Task_ContextAction.render = function ()
	if caq[1] then
		for i=1, #caq do
			if QuestManager.instance.quests[caq[i][1]] then
				if QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].marker_id and QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].ghostSprite then
					QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].ghostSprite:RenderGhostTile(QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].x, QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].y, QuestManager.instance.quests[caq[i][1]].tasks[caq[i][2]].z)
				end
			end
		end
	end
end

Events.OnQSystemStart.Add(function () Events.OnPostFloorLayerDraw.Add(Task_ContextAction.render) end);


function Task_ContextAction:removeMarker()
	for i=#marker_ids, 1, -1 do
		if marker_ids[i] == self.marker:getID() then
			table.remove(marker_ids, i);
			break;
		end
	end
	getWorldMarkers():removeGridSquareMarker(self.marker);
	self.marker = nil;
	self.marker_id = nil;
end

function Task_ContextAction:reset()
	if Task_ContextAction.isValidMarker(self.marker_id) then -- remove marker if exists
		self:removeMarker();
	end
	Task.reset(self);
end

function Task_ContextAction:lock()
	if Task_ContextAction.isValidMarker(self.marker_id) then -- remove marker if exists
		self:removeMarker();
	end
	Task.lock(self);
end

function Task_ContextAction:complete()
	if Task_ContextAction.isValidMarker(self.marker_id) then -- remove marker if exists
		self:removeMarker();
	end
	Task.complete(self);
end

function Task_ContextAction:start()
	local player = getPlayer()
	ISTimedActionQueue.clear(player);
	if self.time > 0 then
		local square = getCell():getGridSquare(self.x, self.y, self.z);
		if square:isFree(false) then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(player, square));
		else
			square = luautils.getCorrectSquareForWall(player, square);
			if math.abs(square:getX() + 0.5 - player:getX()) > 1.6 or math.abs(square:getY() + 0.5 - player:getY()) > 1.6 then
				local adjacent = AdjacentFreeTileFinder.Find(square, player);
				if adjacent ~= nil then
					ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent));
				end
			end
		end
	end
	if not self.pending then
		ISTimedActionQueue.add(ContextAction:new(self, self.time, self.animation))
	end
end

function Task_ContextAction:perform()
	if self.flag then
		DialoguePanel.create(self.script, self.label);
	else
		self:setPending(true);
	end
end

function Task_ContextAction:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			if Task_ContextAction.isValidMarker(self.marker_id) then
				if self.flag and not DialoguePanel.instance then
					if CharacterManager.instance:isFlag(self.flag) then
						self:setPending(true);
					end
				end
			else
				local square = getCell():getGridSquare(self.x, self.y, self.z);
				if square then
					self.marker = getWorldMarkers():addGridSquareMarker("circle_center_alt", "shiny_highlight", square, 1, 1, 1, true, 0.5, 0.01, 0.3, 1.0);
					self.marker_id = self.marker:getID();
					self.marker:setActive(true);
					table.insert(marker_ids, self.marker_id);
					self.ghostSprite = nil;
					for i=0,square:getObjects():size()-1 do
						local object = square:getObjects():get(i);
						if object:getProperties() and object:getProperties():Is(IsoFlagType.canBeRemoved) then
							self.ghostSprite = IsoSprite.new();
							self.ghostSprite:LoadFramesNoDirPageSimple("media/ui/shiny.png");
							break;
						end
					end
				end
			end
			self.timer = getTimeInMillis() + 250;
		end
	elseif Task_ContextAction.isValidMarker(self.marker_id) then -- remove marker before completing task
		self:removeMarker();
	else
		Task.update(self)
	end
end

function Task_ContextAction:new(internal, text, x, y, z, time, animation, script, label, flag)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.marker = nil;
	o.marker_id = nil;
	o.text = text;
	o.x = x;
	o.y = y;
	o.z = z;
	o.time = time or 0;
	o.animation = animation or false;

	o.script = script;
	o.label = label;
	o.flag = flag;

	o.timer = 0;
	table.insert(caq, { QuestManager.instance.quests_size + 1, QuestManager.instance.creator.quest.tasks_size + 1 });
	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_ContextAction;


-- Wait until...
-- WaitUntil|event|name|start/end
-- WaitUntil|time|rt|5
-- WaitUntil|time|rt|3:00|3
-- WaitUntil|epoch|rt|1676461957
local Task_WaitUntil = Task:derive("Task")
Task_WaitUntil.type = "WaitUntil"
function Task_WaitUntil.create(internal, args)
	if args[1] == "event" then
		if #args == 3 then
			if args[3] == "start" then
				return Task_WaitUntil:new_1(internal, args[2], true);
			elseif args[3] == "end" then
				return Task_WaitUntil:new_1(internal, args[2], false);
			else
				return "Unknown keyword in argument 3 - "..tostring(args[3]);
			end
		else
			return "Wrong argument count. Must be 3";
		end
	elseif args[1] == "time" then
		local rt = args[2] == "true";
		if args[2] ~= "false" and not rt then
			return "Argument 2 is not a boolean";
		end
		if #args == 3 then
			local status, value = pcall(tonumber, args[3]);
			if status and value then
				return Task_WaitUntil:new_2(internal, value, rt, true);
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
			return Task_WaitUntil:new_2(internal, time, rt, false);
		else
			return "Wrong argument count. Must be 3 or 4";
		end
	elseif args[1] == "epoch" then
		local rt = args[2] == "true";
		if args[2] ~= "false" and not rt then
			return "Argument 2 is not a boolean";
		end
		if #args == 3 then
			local status, value = pcall(tonumber, args[3]);
			if status and value then
				return Task_WaitUntil:new_3(internal, value, rt);
			else
				return "Argument 3 is not a number";
			end
		else
			return "Wrong argument count. Must be 3";
		end
	else
		return "Invalid syntax";
	end
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

function Task_WaitUntil:reset()
	self.extdata = false;
	Task.reset(self);
end

function Task_WaitUntil:lock()
	self.extdata = false;
	Task.lock(self);
end

function Task_WaitUntil:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			if self.event then
				local status = CharacterManager.instance:isEvent(self.event);
				if (self.start and status) or (not self.start and not status) then
					self:setPending(true);
				end
				self.timer = getTimeInMillis() + 5000;
			elseif self.time then
				if self.extdata then
					if self.rt then
						if getTimestamp() > self.extdata then
							if isClient() then QSystem.update() end
							self:setPending(true);
						end
					else
						if GetWorldAgeSeconds() > self.extdata then
							self:setPending(true);
						end
					end
				else
					if self.rt then
						if self.relative then
							self.extdata = getTimestamp() + self.time*60;
						else
							local current_time = GetCurrentTime();
							local time = calculateTime(current_time.tm_hour, current_time.tm_min, self.time[1], self.time[2], self.time[3]);
							self.extdata = getTimestamp() + time;
						end
					else
						if self.relative then
							self.extdata = GetWorldAgeSeconds() + self.time*60;
						else
							local time = calculateTime(getGameTime():getHour(), getGameTime():getMinutes(), self.time[1], self.time[2], self.time[3]);
							self.extdata = GetWorldAgeSeconds() + time;
						end
					end
					SaveManager.onQuestDataChange();
					SaveManager.save();
				end
				self.timer = getTimeInMillis() + 1000;
			elseif self.ts then
				if self.extdata then
					if self.rt then
						if getTimestamp() > self.extdata then
							if isClient() then QSystem.update() end
							self:setPending(true);
						end
					else
						if GetWorldAgeSeconds() > self.extdata then
							self:setPending(true);
						end
					end
				else
					self.extdata = self.ts;
					SaveManager.onQuestDataChange();
					SaveManager.save();
				end
				self.timer = getTimeInMillis() + 1000;
			end
		end
	end

	Task.update(self);
end

function Task_WaitUntil:new_1(internal, event, start)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.event = event;
	o.start = start; -- true (start), false (end)

	o.timer = 0;

	return o;
end

function Task_WaitUntil:new_2(internal, time, rt, relative)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.time = time; -- minutes OR { hour, minutes, offset }
	o.rt = rt;
	o.relative = relative;

	o.timer = 0;

	return o;
end

function Task_WaitUntil:new_3(internal, ts, rt)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.ts = ts; -- timestamp
	o.rt = rt;

	o.timer = 0;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_WaitUntil;

-- Clear specific quests
-- QuestCondition|quest1,...,questN
-- QuestCondition|quest1,quest2/quest3
local Task_QuestCondition = Task:derive("Task")
Task_QuestCondition.type = "QuestCondition"
function Task_QuestCondition.create(internal, args)
	if #args ~= 1 then
		return "Wrong argument count. Must be 1";
	end
	local groups = args[1]:ssplit("/");
	for group_id=1, #groups do
		local quests = {};
		local list = groups[group_id]:ssplit(",");
		for i=1, #list do
			local quest = QuestManager.instance.creator.quest.internal == list[i] and QuestManager.instance.creator.quest or QuestManager.instance:getQuest(list[i]);
			if quest then
				quests[#quests+1] = quest;
			end
		end
		groups[group_id] = quests;
	end

	if #groups == 0 then
		return "No valid quests specified  - "..tostring(args[2]);
	end
	return Task_QuestCondition:new(internal, groups);
end

function Task_QuestCondition:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			for group_id=1, #self.quests do
				local pending = true;
				for quest_id=1, #self.quests[group_id] do
					if not self.quests[group_id][quest_id].completed then
						pending = false;
						break;
					end
				end
				if pending then
					self:setPending(true);
					break;
				end
			end
			self.timer = getTimeInMillis() + 250;
		end
	end

	Task.update(self);
end

function Task_QuestCondition:new(internal, quests)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.quests = quests;
	o.timer = 0;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_QuestCondition;


-- Clear specific tasks
-- TaskCondition|quest|task1,...,taskN
-- TaskCondition|quest|task1,task2/task3
local Task_TaskCondition = Task:derive("Task")
Task_TaskCondition.type = "TaskCondition"
function Task_TaskCondition.create(internal, args)
	if #args ~= 2 then
		return "Wrong argument count. Must be 2";
	end
	local quest = QuestManager.instance.creator.quest.internal == args[1] and QuestManager.instance.creator.quest or QuestManager.instance:getQuest(args[1]);
	if not quest then
		return string.format("Quest '%s' not found", tostring(args[1]));
	end

	local groups = args[2]:ssplit("/");
	for group_id=1, #groups do
		local tasks = {};
		local list = groups[group_id]:ssplit(",");
		for i=1, #list do
			local task = quest:getTask(list[i]);
			if task then
				tasks[#tasks+1] = task;
			else
				return string.format("Task '%s' not found in quest '%s'", tostring(list[i]), tostring(quest.internal));
			end
		end
		groups[group_id] = tasks;
	end

	if #groups == 0 then
		return "No valid tasks specified  - "..tostring(args[2]);
	end
	return Task_TaskCondition:new(internal, quest, groups)
end

function Task_TaskCondition:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			for group_id=1, #self.tasks do
				local pending = true;
				for task_id=1, #self.tasks[group_id] do
					if not self.tasks[group_id][task_id].completed then
						pending = false;
						break;
					end
				end
				if pending then
					self:setPending(true);
					break;
				end
			end
			self.timer = getTimeInMillis() + 250;
		end
	end

	Task.update(self);
end

function Task_TaskCondition:new(internal, quest, tasks)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.quest = quest;
	o.tasks = tasks; -- task groups { {task_1, ...}, {task_1 ...}, ... }
	o.timer = 0;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_TaskCondition;


-- Raise specific flag
-- RaiseFlag|clear_flag
-- RaiseFlag|clear_flag|script,label
local Task_RaiseFlag = Task:derive("Task")
Task_RaiseFlag.type = "RaiseFlag"
function Task_RaiseFlag.create(internal, args)
	if #args ~= 1 and #args ~= 2 then
        return "Wrong argument count. Must be 1 or 2";
    end
	local flag_groups = args[1]:ssplit('/');
	for i=1, #flag_groups do
		flag_groups[i] = flag_groups[i]:ssplit(',');
	end
	if #args == 2 then
		local script = args[2]:ssplit(',');
		return Task_RaiseFlag:new(internal, flag_groups, script[1], script[2]);
	else
		return Task_RaiseFlag:new(internal, flag_groups);
	end
end

function Task_RaiseFlag:update()
	if not self.init then
		if self.script then
			self.init = DialoguePanel.create(self.script, self.label);
		else
			self.init = true;
		end
	elseif not self.pending then
		for group_id=1, #self.flags do
			local done = true;
			for flag_id=1, #self.flags[group_id] do
				if not CharacterManager.instance:isFlag(self.flags[group_id][flag_id]) then
					done = false;
				end
			end
			if done then
				self:setPending(true);
				break;
			end
		end
	end

	Task.update(self);
end

function Task_RaiseFlag:new(internal, flags, script, label)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.flags = flags;

	o.script = script;
	o.label = label;
	o.init = false;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_RaiseFlag;


-- Open specific container
-- OpenContainer|type|x,y,z
local Task_OpenContainer = Task:derive("Task")
Task_OpenContainer.type = "OpenContainer"
function Task_OpenContainer.create(internal, args)
	if #args ~= 2 then
		return "Wrong argument count. Must be 2";
	end
	local coord = args[2]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if #coord == 3 then
		return Task_OpenContainer:new(internal, args[1], coord[1], coord[2], coord[3]);
	else
		return "Invalid coordinates specified";
	end
end

function Task_OpenContainer:update()
	if not self.pending then
		local loot = getPlayerLoot(getPlayer():getPlayerNum());
		if loot then
			if loot.inventoryPane.inventory then
				local parent = loot.inventoryPane.inventory:getParent()
				if parent then
					local container = parent:getContainer()
					if container then
						if container:getType() == self.container then
							local square = container:getParent():getSquare()
							if square:getX() == self.x and square:getY() == self.y and square:getZ() == self.z then
								self:setPending(true);
							end
						end
					end
				end
			end
		end
	end

	Task.update(self);
end

function Task_OpenContainer:new(internal, container, x, y, z)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.x = x;
	o.y = y;
	o.z = z;
	o.container = container;

	return o
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_OpenContainer;


-- Take item(s) from specific container
-- LootContainer|type|x,y,z|item,is_single,custom_name|...|item,is_single,custom_name
local Task_LootContainer = Task:derive("Task")
Task_LootContainer.type = "LootContainer"
function Task_LootContainer.create(internal, args)
	if #args < 3 then
		return "Unexpected argument count. Must be at least 3";
	end
	local coord = args[2]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if #coord == 3 then
		local script_manager = getScriptManager();
		local items = {};
		for i=3, #args do
			local item = args[i]:trim():ssplit(',');
			if #item < 2 then
				return "Invalid item format";
			end
			if not script_manager:FindItem(tostring(item[1])) then
				return "Item doesn't exist - "..tostring(item[1]);
			end
			items[#items+1] = {};
			items[#items].type = item[1];
			if item[2] == "true" then
				items[#items].single = true;
			else
				items[#items].single = false;
			end
			items[#items].name = item[3] or false;
			items[#items].weight = item[4] or false;
		end
		return Task_LootContainer:new(internal, args[1], coord[1], coord[2], coord[3], items);
	else
		return "Invalid coordinates specified";
	end
end

function Task_LootContainer:reload()
	self.spawned = false;
	Task.reload(self);
end

function Task_LootContainer:reset()
	self.spawned = false;
	Task.reset(self);
end

function Task_LootContainer:unlock()
	self.spawned = false;
	Task.unlock(self);
end

function Task_LootContainer:lock()
	self.spawned = false;
	Task.lock(self);
end

function Task_LootContainer:update()
	if not self.pending then
		if not self.spawned then
			local loot = getPlayerLoot(getPlayer():getPlayerNum());
			if loot then
				if loot.inventoryPane.inventory then
					local parent = loot.inventoryPane.inventory:getParent()
					if parent then
						local container = parent:getContainer()
						if container then
							if container:getType() == self.container then
								local square = container:getParent():getSquare()
								if square:getX() == self.x and square:getY() == self.y and square:getZ() == self.z then
									self.items = SpawnVirtualItems(self.list, loot)
									self.spawned = true;
								end
							end
						end
					end
				end
			end
		else
			local pending = true;
			for i=1, #self.items do
				if self.items[i]:getModData().virtual then
					pending = false;
					break;
				end
			end
			if pending then
				self:setPending(true);
			end
		end
	else
		Task.update(self);
	end
end

function Task_LootContainer:new(internal, container, x, y, z, items)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.list = items or {};
	o.items = {};
	o.spawned = false;

	o.x = x;
	o.y = y;
	o.z = z;
	o.container = container;

	return o
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_LootContainer;


-- Kill specific amount of zombies
-- KillZombie|number
local Task_KillZombie = Task:derive("Task")
Task_KillZombie.type = "KillZombie"
function Task_KillZombie.create(internal, args)
	if #args == 1 then
		local status;
		status, args[1] = pcall(tonumber, args[1]);
		if not status or not args[1] then
			return "Argument is not a number";
		end
		if QuestManager.instance.creator then
			return Task_KillZombie:new(internal, QuestManager.instance.creator.quest.internal.."."..internal, args[1]);
		else
			return "There's a problem with quest creator";
		end
	end
end

function Task_KillZombie:resetCounter()
	local m = getPlayer():getModData();
	if m.Task_KillZombie then
		for i=1, #m.Task_KillZombie do
			if m.Task_KillZombie[i].id == self.id then
				m.Task_KillZombie[i].number = getPlayer():getZombieKills();
				break;
			end
		end
	end
end

function Task_KillZombie:save()
	local m = getPlayer():getModData();
	if m.Task_KillZombie then
		for i=1, #m.Task_KillZombie do
			if m.Task_KillZombie[i].id == self.id then
				self.extdata = self.extdata + getPlayer():getZombieKills() - m.Task_KillZombie[i].number;
				SaveManager.onQuestDataChange();
				table.remove(m.Task_KillZombie, i);
				break;
			end
		end
	end
end

function Task_KillZombie:unlock() -- reset counter for task on unlock
	self.extdata = 0;
	self:resetCounter();
	Task.unlock(self, self.extdata);
end

function Task_KillZombie:lock() -- reset counter for task on lock
	self.extdata = 0;
	self:resetCounter();
	Task.lock(self);
end

function Task_KillZombie:reset() -- reset counter for task on reset
	self.extdata = 0;
	self:resetCounter();
	Task.reset(self);
end

local kzq = {}
function Task_KillZombie.onPlayerDeath()
	if kzq[1] then
		for i=1, #kzq do
			if QuestManager.instance.quests[kzq[i][1]].unlocked and not (QuestManager.instance.quests[kzq[i][1]].completed or QuestManager.instance.quests[kzq[i][1]].failed) then
				if QuestManager.instance.quests[kzq[i][1]].tasks[kzq[i][2]].unlocked and not (QuestManager.instance.quests[kzq[i][1]].tasks[kzq[i][2]].pending or QuestManager.instance.quests[kzq[i][1]].tasks[kzq[i][2]].completed) then
					QuestManager.instance.quests[kzq[i][1]].tasks[kzq[i][2]]:save();
				end
			end
		end
	end
	SaveManager.save();
end
Events.OnPlayerDeath.Add(Task_KillZombie.onPlayerDeath);

function Task_KillZombie.onQSystemReset() -- reset all counter on reimport
	local player = getPlayer();
	if player then
		player:getModData().Task_KillZombie = {};
	end
end
Events.OnQSystemReset.Add(Task_KillZombie.onQSystemReset);

function Task_KillZombie:getDetails()
	local player = getPlayer();
	if player then
		local m = player:getModData().Task_KillZombie;
		if m then
			for i=1, #m do
				if m[i].id == self.id then
					local killed = self.extdata + player:getZombieKills() - m[i].number;
					return string.format(" [%d/%d]", killed, self.number);
				end
			end
		end
	end
	return Task.getDetails(self);
end

function Task_KillZombie:update()
	if not self.pending then
		local player = getPlayer();
		if player then
			local m = player:getModData();
			if m.Task_KillZombie then
				for i=#m.Task_KillZombie, 1, -1 do
					if m.Task_KillZombie[i].id == self.id then
						if self.extdata + player:getZombieKills() - m.Task_KillZombie[i].number >= self.number then
							table.remove(m.Task_KillZombie, i);
							self:setPending(true);
						end
						return;
					end
				end
				local entry = {};
				entry.id = self.id;
				entry.number = player:getZombieKills();
				table.insert(m.Task_KillZombie, entry);
			else
				m.Task_KillZombie = {};
			end
		end
	end

	Task.update(self);
end

function Task_KillZombie:new(internal, id, number)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.id = id;
	o.number = number;

	o.extdata = 0;
	table.insert(kzq, { QuestManager.instance.quests_size + 1, QuestManager.instance.creator.quest.tasks_size + 1 });
	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_KillZombie;


-- Clear the area from zombies
-- Secure|x,y,z|location_type
-- Secure|x1,y1,x2,y2,z
local Task_Secure = Task:derive("Task")
Task_Secure.type = "Secure"
function Task_Secure.create(internal, args)
	if #args ~= 1 and #args ~= 2 then
		return "Wrong argument count. Must be 1 or 2";
	end
	local coord = args[1]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if #coord == 3 and #args == 2 then
		if args[2] == "building" then
			args[2] = 0;
		elseif args[2] == "room" then
			args[2] = 1;
		else
			return "Invalid location type specified. Must be 'building', 'room' or 'point'";
		end
		return Task_Secure:new_1(internal, coord[1], coord[2], coord[3], args[2]);
	elseif #coord == 5 and #args == 1 then
		if coord[3] < coord[1] or coord[4] < coord[2] then
			return "Reversed coordinates detected. Make sure that x2 >= x1 and y2 >= y1";
		end
		return Task_Secure:new_2(internal, coord[1], coord[2], coord[3], coord[4], coord[5]);
	else
		return "Invalid syntax. Must be 'Secure|x,y,z|loc_type' or 'Secure|x1,y1,x2,y2,z'";
	end
end

local function getFloorCount(def)
	local level = 0;
	if def then
		local rooms = def:getRooms();
		if rooms then
			for i=0,rooms:size() - 1 do
				local room = rooms:get(i);
				local z = room:getZ();
				if z > level then
					level = z;
				end
			end
		end
	end
	return level;
end

function Task_Secure:reload() -- load state
	self.timer = getTimeInMillis() + 3000;
	Task.reload(self);
end

function Task_Secure:reset() -- reset progress
	self.timer = getTimeInMillis() + 3000;
	Task.reset(self);
end

function Task_Secure:unlock()
	self.timer = getTimeInMillis() + 3000;
	Task.unlock(self);
end

function Task_Secure:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			if self.isArea then
				local point_a = getCell():getGridSquare(self.x1, self.y1, self.z);
				local point_b = getCell():getGridSquare(self.x2, self.y2, self.z);
				if point_a and point_b then
					if not QZombieFactory.hasZombies(self.x1, self.y1, self.x2, self.y2, self.z, true) then
						local player = getPlayer();
						local x, y, z = player:getX(), player:getY(), player:getZ();
						if x >= self.x1 and x <= self.x2 and y >= self.y1 and y <= self.y2 and z == self.z then
							self:setPending(true);
						end
					end
				end
			else
				local square = getCell():getGridSquare(self.x, self.y, self.z);
				if square ~= nil then
					if self.locationType == 0 then
						if self.building == nil then
							local building = square:getBuilding()
							if building ~= nil then
								local def = building:getDef()
								if def ~= nil then
									self.building = building;
									QuestLogger.print("[QSystem*] Target building defined. Task=Secure")
								end
							end
						else
							local def = self.building:getDef();
							if def then
								local x1, y1, x2, y2, z = def:getX(), def:getY(), def:getX2(), def:getY2(), 0;
								local point_a = getCell():getGridSquare(x1, y1, z);
								local point_b = getCell():getGridSquare(x2, y2, z);
								if point_a and point_b then
									local floors = getFloorCount(def);
									if not QZombieFactory.hasZombies(x1, y1, x2, y2, floors, false) then
										if getPlayer():getSquare():getBuilding() == self.building then
											self:setPending(true);
											QuestLogger.print("[QSystem*] Entered target building. Task=Secure")
										end
									end
								end
							end
						end
					elseif self.locationType == 1 then
						if self.room == nil then
							local room = square:getRoom()
							if room ~= nil then
								self.room = room;
								QuestLogger.print("[QSystem*] Target room defined - '"..tostring(room:getName()).."'. Task=Secure")
							end
						else
							local def = self.room:getRoomDef();
							if def then
								local x1, y1, x2, y2, z = def:getX(), def:getY(), def:getX2(), def:getY2(), def:getZ();
								local point_a = getCell():getGridSquare(x1, y1, z);
								local point_b = getCell():getGridSquare(x2, y2, z);
								if point_a and point_b then
									if not QZombieFactory.hasZombies(x1, y1, x2, y2, z, true) then
										if getPlayer():getSquare():getRoom() == self.room then
											self:setPending(true);
											QuestLogger.print("[QSystem*] Entered target room. Task=Secure")
										end
									end
								end
							end
						end
					end
				end
			end
			self.timer = getTimeInMillis() + 1000;
		end
	end

	Task.update(self);
end

function Task_Secure:new_1(internal, x, y, z, locationType)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.isArea = false;
	o.x = x;
	o.y = y;
	o.z = z;
	o.locationType = locationType; -- 0 (Building), 1 (Room)
	if o.locationType == 0 then
		o.building = nil;
	elseif o.locationType == 1 then
		o.room = nil;
	end

	o.timer = getTimeInMillis() + 3000; -- on game start
	return o
end

function Task_Secure:new_2(internal, x1, y1, x2, y2, z)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.internal = internal;

	o.isArea = true;
	o.x1 = x1;
	o.y1 = y1;
	o.x2 = x2;
	o.y2 = y2;
	o.z = z;

	o.timer = getTimeInMillis() + 3000; -- on game start
	return o
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_Secure;

-- Clear if no zombies nearby
-- EnsureSafety|distance
local Task_EnsureSafety = Task:derive("Task")
Task_EnsureSafety.type = "EnsureSafety"
function Task_EnsureSafety.create(internal, args)
	if #args ~= 1 then
		return "Wrong argument count. Must be 1";
	end
	local status, value = pcall(tonumber, args[1]);
	if status and value then
		return Task_EnsureSafety:new(internal, value);
	else
		return "Distance is not a number";
	end
end

function Task_EnsureSafety:reload() -- load state
	self.timer = getTimeInMillis() + 3000;
	Task.reload(self);
end

function Task_EnsureSafety:reset() -- reset progress
	self.timer = getTimeInMillis() + 3000;
	Task.reset(self);
end

function Task_EnsureSafety:unlock()
	self.timer = getTimeInMillis() + 3000;
	Task.unlock(self);
end

function Task_EnsureSafety:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			local player = getPlayer();
			if player then
				local x, y = player:getX(), player:getY();
				local zombies = getCell():getObjectList();
				for i=zombies:size(), 1, -1 do
					local zombie = zombies:get(i-1)
					if instanceof(zombie, "IsoZombie") then
						local distance = math.sqrt((zombie:getX() - x)^2 + (zombie:getY() - y)^2);
						if distance < self.distance then
							self.timer = getTimeInMillis() + 6000;
							return;
						end
					end
				end
				self:setPending(true);
			end
		end
	end

	Task.update(self);
end

function Task_EnsureSafety:new(internal, distance)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.distance = distance;

	o.timer = getTimeInMillis() + 3000; -- on game start
	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_EnsureSafety;


-- Barricade doors or (and) windows on selected floor
-- BarricadeBuilding|x,y,z
-- BarricadeBuilding|x,y,z|type
local Task_BarricadeBuilding = Task:derive("Task")
Task_BarricadeBuilding.type = "BarricadeBuilding"
function Task_BarricadeBuilding.create(internal, args)
	if #args ~= 1 and #args ~= 2 then
		return "Wrong argument count. Must be 1 or 2";
	end
	local coord = args[1]:ssplit(',');
	local status;
	for i=1, #coord do
		status, coord[i] = pcall(tonumber, coord[i])
		if not status or not coord[i] then
			return "Coordinate is not a number";
		end
	end
	if args[2] == "doors" then
		return Task_BarricadeBuilding:new(internal, coord[1], coord[2], coord[3], 1);
	elseif args[2] == "windows" then
		return Task_BarricadeBuilding:new(internal, coord[1], coord[2], coord[3], 2);
	else
		return Task_BarricadeBuilding:new(internal, coord[1], coord[2], coord[3], 0);
	end
end

function Task_BarricadeBuilding:reload()
	self.exits = {};
	Task.reload(self);
end

function Task_BarricadeBuilding:reset()
	self.exits = {};
	Task.reset(self);
end

function Task_BarricadeBuilding:unlock()
	self.exits = {};
	Task.unlock(self);
end

function Task_BarricadeBuilding:lock()
	self.exits = {};
	Task.lock(self);
end

function Task_BarricadeBuilding:update()
	if not self.pending then
		if getTimeInMillis() > self.timer then
			local square = getCell():getGridSquare(self.x, self.y, self.z);
			if square ~= nil then
				if self.building == nil then
					local building = square:getBuilding()
					if building ~= nil then
						local def = building:getDef()
						if def ~= nil then
							self.building = building;
							self.exits = {};
							local x1, x2, y1, y2 = def:getX(), def:getX2(), def:getY(), def:getY2();
							for x = x1, x2  do
								for y = y1, y2 do
									local s = getCell():getGridSquare(x, y, self.z);
									if s then
										local object = s:getIsoDoor();
										if (self.target == 0 or self.target == 1) and object then
											if object:isExterior() then
												self.exits[#self.exits+1] = object;
											end
										end

										object = s:getWindow();
										if (self.target == 0 or self.target == 2) and object then
											if object:isExterior() then
												self.exits[#self.exits+1] = object;
											end
										end
									end
								end
							end
							QuestLogger.print("[QSystem*] Target building defined. Task=BarricadeBuilding")
						end
					end
				else
					local done = true;
					for i=1, #self.exits do
						if self.exits[i] then
							if not self.exits[i]:isBarricaded() then
								done = false;
								break;
							end
						else
							done = false;
							break;
						end
					end
					if done then
						self:setPending(true);
						QuestLogger.print("[QSystem*] All exits on floor "..tostring(self.z).." are barricaded. Task=BarricadeBuilding")
					end
				end
			end
			self.timer = getTimeInMillis() + 2000;
		end
	end

	Task.update(self);
end

function Task_BarricadeBuilding:new(internal, x, y, z, target)
	local o = {}
	o = Task:new(internal);
	setmetatable(o, self)
	self.__index = self

	o.x = x;
	o.y = y;
	o.z = z;
	o.building = nil;
	o.exits = {};
	o.target = target or 0; -- 0 (doors/windows), 1 (doors), 2 (windows)

	o.timer = 0;
	return o
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_BarricadeBuilding;

-- Deliver a specified number of selected item OR items that apply to selected ruleset
-- Deliver|item,number
-- Deliver|item,number,ruleset
-- Deliver|ruleset,number
local Task_Deliver = Task:derive("Task");
Task_Deliver.type = "Deliver";

function Task_Deliver.create(internal, args) -- TODO: forbid duplication
	local items = {};
	local script_manager = getScriptManager();
	for i=1, #args do
		local item = { item = nil, amount = 1, ruleset = nil };
		local arg = args[i]:ssplit(',');
		local ruleset_only = #(arg[1]:ssplit('.')) == 1;
		local ruleset = ruleset_only and arg[1] or arg[3];
		if ruleset then -- ruleset
			if not ItemFetcher.has_ruleset(ruleset) then
				return "Ruleset doesn't exist - "..tostring(ruleset);
			end
			item.ruleset = ruleset;
		end
		if not ruleset_only then
			if not script_manager:FindItem(tostring(arg[1])) then
				return "Item doesn't exist - "..tostring(arg[1]);
			end
			item.item = arg[1];
		end

		if arg[2] then
			local status;
			status, item.amount = pcall(tonumber, arg[2]);
			if not status or not item.amount then
				return "Invalid argument";
			end
		end
		items[i] = item;
	end
	return Task_Deliver:new(internal, items);
end

function Task_Deliver:update()
	if self.pending then
		if DialoguePanel.instance then return end
		Task.update(self);
	end
end

function Task_Deliver:new(internal, items)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	-- items { { item_name, count, ruleset }, ... }
	o.items = items;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_Deliver;

-- QuestArea
-- QuestArea|id|x1,y1,x2,y2,z|priority|bgm|script,label
local Task_QuestArea = Task:derive("Task");
Task_QuestArea.type = "QuestArea";

function Task_QuestArea.create(internal, args)
	if #args < 3 or #args > 5 then
		return "Wrong argument count. Must be 3, 4 or 5";
	end
	if QuestArea.exists(args[1]) then
		return string.format("Area with id '%s' already exists", tostring(args[1]));
	end
	local status;
	local zones = {};
	args[2] = args[2]:ssplit('/');
	for zone_id=1, #args[2] do
		local coord = args[2][zone_id]:ssplit(',');
		if #coord ~= 4 and #coord ~= 5 then
			return "Invalid coordinate format. Must be x1,y1,x2,y2 or x1,y1,x2,y2,z";
		end
		for i=1, #coord do
			status, coord[i] = pcall(tonumber, coord[i])
			if not status or not coord[i] then
				return "Coordinate is not a number";
			end
		end
		if coord[3] < coord[1] or coord[4] < coord[2] then
			return "Reversed coordinates detected. Make sure that x2 >= x1 and y2 >= y1";
		end
		zones[#zones+1] = { x1 = coord[1], y1 = coord[2], x2 = coord[3], y2 = coord[4], z = coord[5] };
	end
	status, args[3] = pcall(tonumber, args[3])
	if not status or not args[3] then
		return "Priority is not a number";
	end
	if not args[4] or args[4] == 'o' then
		args[4] = false;
	end
	local script = {}
	if args[5] then
		script = args[5]:ssplit(',');
	end
	return Task_QuestArea:new(internal, args[1], zones, args[3], args[4], script[1], script[2]);
end

function Task_QuestArea:init()
	local function callback_1()
		if self.area then
			if self.extdata ~= self.area.bgm then
				self.extdata = self.area.bgm or false;
				SaveManager.onQuestDataChange();
			end
		end
	end
	local function callback_2()
		self.area = nil;
	end
	self.area = QuestArea.create(self.id, self.zones, self.priority, self.extdata, self.bgm, self.script, self.label, callback_1, callback_2);
end

function Task_QuestArea:reload()
	QuestArea.release(self.id);
	Task.reload(self);
end

function Task_QuestArea:reset()
	QuestArea.release(self.id);
	self.extdata = self.bgm;
	Task.reset(self);
end

function Task_QuestArea:unlock()
	QuestArea.release(self.id);
	self.extdata = self.bgm;
	if not self.pending then
		self:init();
	end
	Task.unlock(self, self.extdata);
end

function Task_QuestArea:lock()
	QuestArea.release(self.id);
	self.extdata = self.bgm;
	Task.lock(self);
end

function Task_QuestArea:complete()
	QuestArea.release(self.id);
	self.extdata = self.bgm;
	Task.complete(self);
end

function Task_QuestArea:update()
	if not self.pending then
		if not self.area then
			self:init();
		end
	else
		QuestArea.release(self.id);
	end

	Task.update(self);
end

function Task_QuestArea:new(internal, id, zones, priority, bgm, script, label)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;

	o.id = id;
	o.zones = zones;

	o.priority = priority;

	o.bgm = bgm;

	o.script = script;
	o.label = label;

	o.extdata = bgm;
	o.area = nil;

	QuestArea.list[#QuestArea.list+1] = id;

	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_QuestArea;

-- Pending upon death, completion upon respawn
-- PlayerDeath
local Task_PlayerDeath = Task:derive("Task");
Task_PlayerDeath.type = "PlayerDeath";

function Task_PlayerDeath.create(internal, args)
	if #args > 0 then
		return "Invalid syntax";
	end
	return Task_PlayerDeath:new(internal);
end

local d_tasks = {}
function Task_PlayerDeath.OnPlayerDeath()
	if d_tasks[1] then
		for i=#d_tasks, 1, -1 do
			if d_tasks[i].active then
				d_tasks[i].active = false;
				d_tasks[i]:setPending(true);
			end
			table.remove(d_tasks, i);
		end
		SaveManager.save(true);
	end
end
Events.OnPlayerDeath.Add(Task_PlayerDeath.OnPlayerDeath);

function Task_PlayerDeath.onQSystemReset() -- reset active tasks
	d_tasks = {};
end
Events.OnQSystemReset.Add(Task_PlayerDeath.onQSystemReset);

function Task_PlayerDeath:reload()
	self.active = false;
	Task.reload(self)
end

function Task_PlayerDeath:reset()
	for i=#d_tasks, 1, -1 do
		if d_tasks[i].internal == self.internal then
			table.remove(d_tasks, i);
			break;
		end
	end
	self.active = false;
	Task.reset(self)
end

function Task_PlayerDeath:unlock()
	self.active = false;
	Task.unlock(self)
end

function Task_PlayerDeath:lock()
	for i=#d_tasks, 1, -1 do
		if d_tasks[i].internal == self.internal then
			table.remove(d_tasks, i);
			break;
		end
	end
	self.active = false;
	Task.lock(self)
end

function Task_PlayerDeath:update()
	if self.pending then
		if getPlayer():isDead() then return end
		Task.update(self);
	elseif not self.active then
		d_tasks[#d_tasks+1] = self;
		self.active = true;
	end
end

function Task_PlayerDeath:new(internal)
	local o = {};
	o = Task:new(internal);
	setmetatable(o, self);
	self.__index = self;
	o.active = false;
	return o;
end

QuestCreator.tasks[#QuestCreator.tasks+1] = Task_PlayerDeath;