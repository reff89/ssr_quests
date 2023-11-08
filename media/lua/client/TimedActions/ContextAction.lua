require "TimedActions/ISBaseTimedAction"

ContextAction = ISBaseTimedAction:derive("ContextAction");

function ContextAction:isValid()
	return true
end

function ContextAction:update()
	self.character:faceThisObject(self.object)
end

function ContextAction:waitToStart()
	self.character:faceThisObject(self.object)
	return self.character:shouldBeTurning()
end

function ContextAction:start()
	if self.maxTime > 42 and self.anim then
		self:setActionAnim(self.anim);
		if self.v1 and self.v2 then
			self.character:SetVariable(self.v1, self.v2);
		end
	end
end

function ContextAction:stop()
    ISBaseTimedAction.stop(self);
end

function ContextAction:perform()
	self.task:perform();
    -- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self);
end

function ContextAction:new(task, time, anim, v1, v2)
	local o = {}
	setmetatable(o, self)
	self.__index = self
    o.task = task;
	o.object = getCell():getGridSquare(task.x, task.y, task.z):getObjects():get(0)
	o.character = getPlayer()
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.maxTime = time * 43;
	o.anim = anim;
	o.v1 = v1;
	o.v2 = v2;
	return o;
end
