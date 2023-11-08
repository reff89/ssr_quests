-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "ISBaseObject"

AsyncTask = ISBaseObject:derive("AsyncTask");

function AsyncTask:start()

end

function AsyncTask:update()
	self.done = true;
end

function AsyncTask:finalize()
    if self.callback then
		self.callback();
	end
end

function AsyncTask:new(callback)
	local o = {};
	setmetatable(o, self);
	self.__index = self;

    o.callback = callback;
	o.done = false;

	return o;
end


TaskManager = {}
local queue = {};
local index = 0;

TaskManager.update = function ()
	if queue[1] then
		if queue[index].done then
			queue[index]:finalize();
			table.remove(queue, index);
			index = index - 1;
		else
			queue[index]:update();
		end
	end
end


Events.OnTick.Add(TaskManager.update);

TaskManager.add = function (task)
	if task.Type == "AsyncTask" then
		index = index + 1;
		queue[index] = task;
		queue[index]:start();
	end
end