-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Communications/QSystem"

QSlide = ISPanel:derive("QSlide");
QSlide.instance = nil;

function QSlide:initialise()
	ISPanel.initialise(self);
end

function QSlide:createChildren()
	self.image = ISImageMod:new(0, 0, self.width, self.height, self.texture);
	self.image.scaledHeight = self.height;
	self.image.scaledWidth = (self.image.scaledHeight / self.texH) * self.texW;
	self.image.x = (self.width - self.image.scaledWidth) / 2
	self.image:initialise();
	self.image.backgroundColor.a = 0;
	self:addChild(self.image);
end

function QSlide:render()
	if self.timerStart then
		if self.image.backgroundColor.a > 0 then
			local delta = (UIManager.getMillisSinceLastRender() / 33.3) * 0.08;
			local value = self.image.backgroundColor.a - delta;
			if value > 0 then
				self.image.backgroundColor.a = value;
			else
				self.image.backgroundColor.a = 0;
			end
		elseif not self.done then
			self.done = true;
			if self.callback then
				self.callback();
			end
			QSlide.destroy();
		end
	elseif self.image.backgroundColor.a < 1 then
		local delta = (UIManager.getMillisSinceLastRender() / 33.3) * 0.2;
		local value = self.image.backgroundColor.a + delta;
		if value >= 1 then
			self.image.backgroundColor.a = 1;
			local function callback()
				self.timerStart = true;
			end
			SSRTimer.add_s(callback, self.delay, false);
		else
			self.image.backgroundColor.a = value;
		end
	end
end

function QSlide.destroy()
	if QSlide.instance then
		QSlide.instance:removeFromUIManager();
		QSlide.instance = nil;
	end
end

Events.OnScriptExit.Add(QSlide.destroy);
Events.OnQSystemReset.Add(QSlide.destroy);
Events.OnQSystemUpdate.Add(function (code) if code == 4 then QSlide.destroy() end end);

function QSlide:new(texture, callback, delay)
    local o = ISPanel:new(0, 0, 400, 400);
    setmetatable(o, self);
    self.__index = self;
	o.background = false;

    o.anchorLeft = true;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = true;

	o.texture = texture;
	o.texW = texture:getWidth();
	o.texH = texture:getHeight();
	o.callback = callback;

	o.x = (getCore():getScreenWidth() / 2) - (o.width / 2);
	local y = getCore():getScreenHeight() - o.height - 310*SSRLoader.scale;
	if y < 0 then
		o.y = (getCore():getScreenHeight() / 2) - (o.height / 2);
	else
		o.y = y;
	end

	o.timerStart = false;
	o.delay = delay or 2;
	o.done = false;

    return o;
end

function QSlide.create(texture, callback, time)
	QSlide.instance = QSlide:new(texture, callback, time);
	QSlide.instance:initialise();
	QSlide.instance:addToUIManager();
end