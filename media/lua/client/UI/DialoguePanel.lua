-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"

DialoguePanel = ISPanel:derive("DialoguePanel");
DialoguePanel.instance = nil;

function DialoguePanel:initialise()
	ISPanel.initialise(self);
end

function DialoguePanel:onChoiceSelected(button, label)
	local offset = 2;
	for i=1, #self.buttons do
		if self.buttons[i]:isVisible() then
			offset = offset + 1;
		end
		self.buttons[i]:setVisible(false);
		 -- removed lock from choice
		self.buttons[i].image = nil;
		self.buttons[i]:setEnable(true);
	end
	self.input.enable = true;
	if self.script:jump(label) then
		self:showNext();
	else
		self:showError(string.format("[jump] Label '%s' not found at line %i. File=%s, Mod=%s", tostring(label), self.script.index-offset+button.internal, tostring(self.script.file), tostring(self.script.mod)));
	end
end

function DialoguePanel:onClick()
	self.voice = nil;
	self:showNext();
end

function DialoguePanel:showError(err_msg)
	self.message.text = "<RED>"..err_msg;
	self.message:paginate();
	self.input:setOnClick(self.close);
	self:setVisible(true);
	print(err_msg);
end

function DialoguePanel:pause()
	self.execute = false;
end

function DialoguePanel:showNext()
	if self.active then
		self.execute = true;
		while self.execute do
			local result = self.script:play(self);
			self.replay:setVisible(self.voice ~= nil);
			if result == -1 then -- close
				self:close();
				return;
			elseif result == -2 then -- wait for callback
				self.input.enable = false;
				break;
			elseif result then -- show error
				self:showError(tostring(result));
				return;
			end
		end
		SaveManager.save();
	end
end

function DialoguePanel:clearAvatar()
	self.model:setVisible(false);
	self.sprite = nil;
	self.portrait.tex = nil;
end

function DialoguePanel:setModel(model)
	if model == "3D:Player" then
		self.model:setCharacter(getPlayer());
		self.model:render();
		self.model:setVisible(true);
	else
		self:clearAvatar();
		return false;
	end
	self.sprite = model;
	return true;
end

function DialoguePanel:setSprite(sprite)
	useTextureFiltering(true);
	local status, tex = pcall(getTexture, "media/ui/"..tostring(sprite));
	useTextureFiltering(false);
	if status and tex then
		if self.sprite then self.model:setVisible(false); end
		self.portrait.tex_w = (self.portrait.width / tex:getHeight()) * tex:getWidth();
		self.portrait.tex_x = self.sprite_width - self.portrait.tex_w;
		self.portrait.tex = tex;
		self.sprite = sprite;
		return true;
	else
		self:clearAvatar();
		return false;
	end
end

function DialoguePanel:setAvatar(obj)
	if self.sprite == obj then
		return;
	else
		-- 3D model
		if obj:starts_with("3D:") then
			if self.portrait.tex then self:clearAvatar() end
			if not self.use3D then
				self:addChild(self.model);
				self.model:setState("idle");
				self.model:setDirection(IsoDirections.S);
				self.model:setIsometric(false);
				self.model:setZoom(15);
				self.model:setYOffset(-0.8);
				self.model:setXOffset(0);
				self.use3D = true;
				self.replay:bringToTop();
			end
			return self:setModel(obj) or 2;
		else
			return self:setSprite(obj) or 1;
		end
	end
end

function DialoguePanel:realign(max_width)
	local offset = 0;
	for i=1, 6 do
		if self.buttons[i]:isVisible() then
			if i-offset > 3 then
				self.buttons[i]:setX(max_width + 30*SSRLoader.scale)
			end
			self.buttons[i]:setWidth(max_width)
		else
			offset = offset - 1;
		end
	end
end

function DialoguePanel:createChildren()
	self.window = ISPanel:new(self.sprite_width / 2, 0, self.width - self.sprite_width, self.sprite_width)
	self.window.backgroundColor = {r=0.0, g=0.0, b=0.0, a=0.95};
	self.window.borderColor = {r=0.2, g=0.2, b=0.2, a=1.0};
	self.window:initialise();
	self:addChild(self.window);
	self.window:setX(self.sprite_width);

	self.message = ISRichTextPanel:new(0, 0, self.window:getWidth(), 80*SSRLoader.scale);
	self.message.background = false;
    self.message:setAnchorBottom(true);
    self.message:setAnchorRight(true);
    self.message:setAnchorTop(true);
    self.message:setAnchorLeft(true);
	self.window:addChild(self.message);

	self.input = ISButton:new(0, 0, self.message:getWidth(), self.window:getHeight(), "", self);
    self.input:initialise();
	self.input:setAnchorBottom(true);
    self.input:setAnchorRight(true);
    self.input:setAnchorTop(true);
    self.input:setAnchorLeft(true);
	self.input:setOnClick(self.onClick, nil)
	self.input.borderColor = {r=0.0, g=0.0, b=0.0, a=0};
	self.input.backgroundColor = {r=0, g=0, b=0, a=0.0};
	self.input.backgroundColorMouseOver = {r=1.0, g=1.0, b=1.0, a=0.1};
	self.window:addChild(self.input);

	self.buttons = {}
	self.btn_y = {}
	-- column 1
	local btn_offset, btn_height = 10*SSRLoader.scale, 20*SSRLoader.scale;
	for i=1, 6 do
		if i > 3 then
			self.btn_y[i] = self.message:getHeight() + btn_offset + (btn_height + btn_offset) * (i-4);
			self.buttons[i] = ISButton:new(80*SSRLoader.scale, self.btn_y[i], 50*SSRLoader.scale, btn_height, "Choice "..i, self)
		else
			self.btn_y[i] = self.message:getHeight() + btn_offset + (btn_height + btn_offset) * (i-1);
			self.buttons[i] = ISButton:new(10*SSRLoader.scale, self.btn_y[i], 50*SSRLoader.scale, btn_height, "Choice "..i, self)
		end
		self.buttons[i].internal = i;
		self.buttons[i]:initialise();
		self.window:addChild(self.buttons[i]);
		self.buttons[i]:setVisible(false);
	end

	self.portrait = ISPanel:new(0, 0, self.sprite_width, self.height);
	self.portrait:initialise();
	self.portrait.prerender = function (portrait)
		if portrait.tex then
			portrait:setStencilRect(0, 0, portrait.width, portrait.height);
			portrait:drawTextureScaled(portrait.tex, portrait.tex_x, 0, portrait.tex_w, portrait.height, 1, 1, 1, 1);
			portrait:clearStencilRect()
		end
	end
	self.portrait.tex_w = 0;
	self.portrait.tex_x = 0;
	self:addChild(self.portrait);

	self.model = ISUI3DModel:new(0, 0, self.sprite_width, self.height-4*SSRLoader.scale);
	local prerender = ISUI3DModel.prerender;
	self.model.prerender = function(sender)
		sender:drawRect(4, 4, self.sprite_width-8, self.sprite_width-8, 0.8, 0.2, 0.2, 0.2);
		prerender(sender);
	end
	self.use3D = false;

	self.replay = ISPanel:new(5*SSRLoader.scale, 5*SSRLoader.scale, 36*SSRLoader.scale, 36*SSRLoader.scale);
	self.replay:initialise();
	self.replay.prerender = function (replay)
		if replay:isMouseOver() then
			replay:drawTextureScaled(replay.hover, 0, 0, replay.width, replay.height, 1, 1, 1, 1);
		else
			replay:drawTextureScaled(replay.normal, 0, 0, replay.width, replay.height, 1, 1, 1, 1);
		end
	end
	self.replay.onMouseUp = function(replay, x, y)
		if self.voice then
			AudioManager.playVoice(self.voice);
		end
	end
	self.replay.normal = getTexture("media/ui/voice_btn_normal.png");
	self.replay.hover = getTexture("media/ui/voice_btn_hover.png");
	self:addChild(self.replay);
	self.active = true;
end

function DialoguePanel:close()
	self.active = false;
	self:setVisible(false);
	self:removeFromUIManager();
	DialoguePanel.instance = nil;

	SaveManager.save();

	Blocker.setEnabled(false);
	triggerEvent("OnScriptExit", nil);
end

function DialoguePanel:setVar(key, value)
	local size = #self.variables;
	for i=1, size do
		if self.variables[i][1] == key then
			self.variables[i][2] = value;
			return;
		end
	end

	self.variables[size+1] = {key, value};
end

function DialoguePanel:getVar(key)
	for i=1, #self.variables do
		if self.variables[i][1] == key then
			return self.variables[i][2];
		end
	end
end

function DialoguePanel:new()
	local w = 800*SSRLoader.scale;
	local h = 200*SSRLoader.scale;
	local x = getCore():getScreenWidth() / 2 - w / 2;
	local y = getCore():getScreenHeight() - h - 100;

	local o = ISPanel:new(x, y, w, h);
	setmetatable(o, self);
    self.__index = self;

	o.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0};
	o.borderColor = {r=0.2, g=0.2, b=0.2, a=1.0};

	o.font = UIFont.NewSmall;

	o.voice = nil;

	o.sprite = nil;
	o.sprite_width = 200*SSRLoader.scale;

	o.variables = {};
	o.callstack = {};
	o.script = nil;
	o.strict = true;
	return o;
end

local function create_panel()
	DialoguePanel.instance = DialoguePanel:new()
	DialoguePanel.instance:initialise()
	DialoguePanel.instance:setVisible(false);
	DialoguePanel.instance:addToUIManager();
end

DialoguePanel.onResolutionChange = function()
	if DialoguePanel.instance then
		local x = getCore():getScreenWidth() / 2 - DialoguePanel.instance:getWidth() / 2;
		local y = getCore():getScreenHeight() - DialoguePanel.instance:getHeight() - 100;
		DialoguePanel.instance:setX(x);
		DialoguePanel.instance:setY(y);
	end
end

Events.OnResolutionChange.Add(DialoguePanel.onResolutionChange);

DialoguePanel.create = function(script, label, forced)
	if DialogueManager.pause or DialoguePanel.instance or (getPlayer():isSeatedInVehicle() and not forced) then
		return false;
	else
		create_panel();
	end

	DialoguePanel.instance.script = DialogueManager.instance:load_script(script);
	if DialoguePanel.instance.script then
		if label then
			if not DialoguePanel.instance.script:jump(label) then
				DialoguePanel.instance:showError(string.format("[DialoguePanel] Label '%s' not found. File=%s, Mod=%s", tostring(label), tostring(DialoguePanel.instance.script.file), tostring(DialoguePanel.instance.script.mod)));
				return false;
			end
		end
		local function delayed_call()
			DialoguePanel.instance:showNext();
		end
		SSRTimer.add_ms(delayed_call, 0, false);
		getCell():setDrag(nil, 0);
		if getGameSpeed() > 1 and not isClient() then setGameSpeed(1) end
		return true;
	else
		DialoguePanel.instance:showError("[DialoguePanel] Failed to load script - "..tostring(script));
	end
end

DialoguePanel.onPlayerDeath = function ()
	if DialoguePanel.instance then
		DialoguePanel.instance:close();
	end
end

Events.OnPlayerDeath.Add(DialoguePanel.onPlayerDeath);