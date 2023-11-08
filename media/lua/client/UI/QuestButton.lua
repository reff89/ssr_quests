-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Communications/QSystem"

QuestButton = ISPanel:derive("QuestButton");
QuestButton.read = true;
local allowDebugger = false;

function QuestButton:initialise()
    ISPanel.initialise(self);
end

function QuestButton:update()
	if not QuestButton.read then
		if self.timer > 6 then
			self.forward = true;
		elseif self.timer < 1 then
			self.forward = false;
		end

		if self.forward then
			self.timer = self.timer - (UIManager.getMillisSinceLastRender() / 33.3);
		else
			self.timer = self.timer + (UIManager.getMillisSinceLastRender() / 33.3);
		end
	end
end

function QuestButton:prerender()
	if QuestButton.read then
		self:drawTexture(self.readTexture, 0,0,self.alpha,1,1,1);
	else
		if self.timer > 6 then
			self:drawTexture(self.unreadTexture,0,0,self.alpha,1,1,1);
		elseif self.timer < 1 then
			self:drawTexture(self.readTexture,0,0,self.alpha,1,1,1);
		else
			self:drawTexture(self.texture[math.floor(self.timer)],0,0,self.alpha,1,1,1);
		end
	end
end

function QuestButton:showPanel()
	self.timer = 0;
	self.forward = false;
	if QuestButton.read then
		QInterface.instance:show();
	else
		QInterface.instance:show(1);
	end
	QInterface.instance:bringToTop();
end

function QuestButton:onMouseUp(x, y)
	self:showPanel();
end

function QuestButton:onMouseMove()
	if self.alpha == 1 then return end;
	self.alpha = 1;
end

function QuestButton:onMouseMoveOutside()
	if self.alpha == 0.75 then return end;
	self.alpha = 0.75;
end

function QuestButton:new(x, y)
    local o = ISPanel:new(x - 59, y - 35, 35, 35);
    setmetatable(o, self);
    self.__index = self;
    o.borderColor = {r=0, g=0, b=0, a=0};
    o.backgroundColor = {r=0, g=0, b=0, a=0};

    o.anchorLeft = false;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = false;

    o.readTexture = getTexture("media/ui/QuestB0.png");
    o.unreadTexture = getTexture("media/ui/QuestB5.png");

	o.timer = 8;
	o.forward = false;
	o.alpha = 0.75;

    o.noBackground = true;
    o.player = getPlayer();

	o.texture = {}
	for i=0, 5 do
      o.texture[i+1] = getTexture("media/ui/QuestB"..tostring(i)..".png");
    end

    return o
end


QDebugButton = ISPanel:derive("QDebugButton");

function QDebugButton:initialise()
    ISPanel.initialise(self);
end

function QDebugButton:prerender()
	self:drawTexture(self.icon, 0,0,self.alpha,1,1,1);
end

function QDebugButton:showPanel()
	if QuestDebugger.instance then
		local value = QuestDebugger.instance:isVisible();
		if not value then
			QuestDebugger.instance:populateList_C();
		end
		QuestDebugger.instance:setVisible(not value);
		QuestDebugger.instance:bringToTop();
	end
end

function QDebugButton:onMouseUp(x, y)
	self:showPanel();
end

function QDebugButton:onMouseMove()
	if self.alpha == 1 then return end;
	self.alpha = 1;
end

function QDebugButton:onMouseMoveOutside()
	if self.alpha == 0.75 then return end;
	self.alpha = 0.75;
end

function QDebugButton:new(x, y)
    local o = ISPanel:new(x - 59, y - 35, 35, 35);
    setmetatable(o, self);
    self.__index = self;
    o.borderColor = {r=0, g=0, b=0, a=0};
    o.backgroundColor = {r=0, g=0, b=0, a=0};

    o.anchorLeft = false;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = false;

    o.icon = getTexture("media/ui/QDebugger.png");

	o.timer = 8;
	o.forward = false;
	o.alpha = 0.75;

    o.noBackground = true;
    o.player = getPlayer();

    return o;
end

function QuestButton.onCreatePlayer()
	QuestButton.instance:setVisible(true);
	if allowDebugger then
		QDebugButton.instance:setVisible(true);
	end
end

function QuestButton.onPlayerDeath()
	QuestButton.instance:setVisible(false);
	QInterface.instance:setVisible(false);
	if allowDebugger then
		QDebugButton.instance:setVisible(false);
		QuestDebugger.instance:setVisible(false);
	end
end

QuestButton.onResolutionChange = function ()
	local x = getCore():getScreenWidth();
	if not SSRLoader.NFO then
		x = x - 144;
	else
		x = x - 215;
	end
	local y = getCore():getScreenHeight() - 66;

	if QuestButton.instance then
		x = x - QuestButton.instance.readTexture:getWidth() - 24;
		y = y - QuestButton.instance.readTexture:getHeight();
		QuestButton.instance:setX(x)
		QuestButton.instance:setY(y)

		if QDebugButton.instance then
			x = x - 10 - QDebugButton.instance.icon:getWidth() - 24;
			QDebugButton.instance:setX(x)
			QDebugButton.instance:setY(y)
		end
	end
end

Events.OnQSystemInit.Add(function ()
	QInterface.instance = QInterface:new();
	QInterface.instance:initialise();
	QInterface.instance:setVisible(false);
	QInterface.instance:addToUIManager();
end)

Events.OnQSystemStart.Add(function()
	local x = getCore():getScreenWidth();
	if not SSRLoader.NFO then
		x = x - 144;
	else
		x = x - 215;
	end
	local y = getCore():getScreenHeight() - 66;
	QuestButton.instance = QuestButton:new(x, y);
	QuestButton.instance:initialise();
	QuestButton.instance:backMost();
	QuestButton.instance:addToUIManager();

	if isClient() then
		local accessLevel = getAccessLevel();
		if accessLevel ~= "" and accessLevel ~= "None" then -- multiplayer with access level
			allowDebugger = true;
		end
	else -- singleplayer with debug on
		allowDebugger = isDebugEnabled();
	end

	if allowDebugger then
		QuestDebugger.instance = QuestDebugger:new();
		QuestDebugger.instance:initialise();
		QuestDebugger.instance:setVisible(false);
		QuestDebugger.instance:addToUIManager();

		x = QuestButton.instance:getX() - 10;
		QDebugButton.instance = QDebugButton:new(x, y);
		QDebugButton.instance:initialise();
		QDebugButton.instance:backMost();
		QDebugButton.instance:addToUIManager();
	end

	Events.OnResolutionChange.Add(QuestButton.onResolutionChange);
	Events.OnCreatePlayer.Add(QuestButton.onCreatePlayer);
	Events.OnPlayerDeath.Add(QuestButton.onPlayerDeath);
end);