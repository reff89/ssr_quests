-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Communications/QSystem"

Reward = {};
Grade = { Common = 1, Rare = 2, Special = 3, Unique = 4 }

Reward.Card = ISPanel:derive("Card");

function Reward.Card:initialise()
	ISPanel.initialise(self);
end

function Reward.Card:prerender()
	self:drawTextureScaled(self.body, (self.width - self.tex_grade_w) / 2, 0, self.tex_grade_w, self.tex_grade_h,  self.alpha, 1, 1, 1);
	if self.texture then
		self:drawTextureScaled(self.texture, (self.width / 2 - 35*SSRLoader.scale) + ((70*SSRLoader.scale - self.tex_icon_w) / 2), 85*SSRLoader.scale, self.tex_icon_w, self.tex_icon_h,  self.alpha, 1, 1, 1);
	end

	if self.type == 2 then
		if self.amount then
			self:drawTextRight(tostring(self.amount), self.width - 30*SSRLoader.scale, 200*SSRLoader.scale, 1.0, 1.0, 1.0, self.alpha, UIFont.NewLarge);
		else
			self:drawTextRight("Level UP", self.width - 30*SSRLoader.scale, 200*SSRLoader.scale, 1.0, 1.0, 1.0, self.alpha, UIFont.NewLarge);
		end
	elseif self.amount then
		self:drawTextRight("x"..tostring(self.amount), self.width - 30*SSRLoader.scale, 200*SSRLoader.scale, 1.0, 1.0, 1.0, self.alpha, UIFont.NewLarge);
	end

	self:setStencilRect(14*SSRLoader.scale, 19*SSRLoader.scale, self.width-30*SSRLoader.scale, 19*SSRLoader.scale)
	self:drawText(self.name, 16*SSRLoader.scale, 19*SSRLoader.scale, 1.0, 1.0, 1.0, self.alpha, UIFont.Medium);
	self:clearStencilRect()
end

local function loadTexture(id, icons)
	if id > -1 and id < icons:size() then
		return getTexture("Item_"..tostring(icons:get(id)));
	end
end

-- getScriptManager():FindItem(v)
function Reward.Card:createItem(item, amount, grade)
    local o = ISPanel:new(0, 0, 250*SSRLoader.scale, 300*SSRLoader.scale);
    setmetatable(o, self);
    self.__index = self;
	o.background = false;

	o.name = item:getDisplayName() or "N/A";
	local bracket = o.name:indexOf('(');
	if bracket ~= -1 then
		o.name = string.sub(o.name, 1, bracket-1);
	end
	o.name = o.name:trim();
	o.amount = amount;
	o.texture = QItemFactory.getTextureFromItem(item);

	o.grade = grade;
	if grade == 4 then -- unique
		o.body = getTexture("media/ui/loot_unique.png");
    elseif grade == 3 then -- special
		o.body = getTexture("media/ui/loot_special.png");
	elseif grade == 2 then -- rare
		o.body = getTexture("media/ui/loot_rare.png");
	else -- common
		o.body = getTexture("media/ui/loot_common.png");
	end

	o.alpha = 1.0;
	o.tex_grade_h = 300;
	o.tex_grade_w = (o.tex_grade_h / o.body:getHeight()) * o.body:getWidth();
	o.tex_grade_w = o.tex_grade_w*SSRLoader.scale; o.tex_grade_h = o.tex_grade_h*SSRLoader.scale;
	if o.texture then
		o.tex_icon_h = 100;
		o.tex_icon_w = (o.tex_icon_h / o.texture:getHeight()) * o.texture:getWidth();
		o.tex_icon_w = o.tex_icon_w*SSRLoader.scale; o.tex_icon_h = o.tex_icon_h*SSRLoader.scale;
	end

	o.internal = item:getFullName();
    o.type = 0;
    return o;
end

--TraitFactory.getTrait(v)
function Reward.Card:createTrait(trait)
    local o = ISPanel:new(0, 0, 250*SSRLoader.scale, 300*SSRLoader.scale);
    setmetatable(o, self);
    self.__index = self;
	o.background = false;

	o.name = trait:getLabel() or "N/A";
	o.texture = trait:getTexture();

    o.body = getTexture("media/ui/loot_unique.png");

	o.alpha = 1.0;
	o.tex_grade_h = 300;
	o.tex_grade_w = (o.tex_grade_h / o.body:getHeight()) * o.body:getWidth();
	o.tex_grade_w = o.tex_grade_w*SSRLoader.scale; o.tex_grade_h = o.tex_grade_h*SSRLoader.scale;
	if o.texture then
		o.tex_icon_h = 100;
		o.tex_icon_w = (o.tex_icon_h / o.texture:getHeight()) * o.texture:getWidth();
		o.tex_icon_w = o.tex_icon_w*SSRLoader.scale; o.tex_icon_h = o.tex_icon_h*SSRLoader.scale;
	end

	o.internal = trait:getType();
    o.type = 1;
    return o;
end

--Perks.FromString(v)
function Reward.Card:createEXP(perk, exp)
    local o = ISPanel:new(0, 0, 250*SSRLoader.scale, 300*SSRLoader.scale);
    setmetatable(o, self);
    self.__index = self;
	o.background = false;

	o.name = perk:getName() or "N/A";
	o.amount = exp;
	o.texture = getTexture("media/ui/perk_icon.png");

    o.body = getTexture("media/ui/loot_unique.png");

	o.alpha = 1.0;
	o.tex_grade_h = 300;
	o.tex_grade_w = (o.tex_grade_h / o.body:getHeight()) * o.body:getWidth();
	o.tex_grade_w = o.tex_grade_w*SSRLoader.scale; o.tex_grade_h = o.tex_grade_h*SSRLoader.scale;
	if o.texture then
		o.tex_icon_h = 100;
		o.tex_icon_w = (o.tex_icon_h / o.texture:getHeight()) * o.texture:getWidth();
		o.tex_icon_w = o.tex_icon_w*SSRLoader.scale; o.tex_icon_h = o.tex_icon_h*SSRLoader.scale;
	end

	o.internal = perk:getId();
    o.type = 2;
    return o;
end


Reward.Notification = ISPanel:derive("Reward.Notification");
Reward.Notification.instance = nil;

function Reward.Notification:initialise()
	ISPanel.initialise(self);
end

function Reward.Notification:createChildren()
	for i=1, #self.cards do
		self.cards[i]:setX(5*SSRLoader.scale + 260*SSRLoader.scale * (i-1));
		self.cards[i]:setY(60*SSRLoader.scale);
		self:addChild(self.cards[i])
	end

	local function callback()
        self.timerStart = true;
    end

    SSRTimer.add_s(callback, 2, false)
end

function Reward.Notification:prerender()
	self:drawTextureScaled(self.tex_header, self.width / 2 - (self.tex_w) / 2, 0, self.tex_w, self.tex_h, self.cards[1].alpha, 1, 1, 1);
end

function Reward.Notification:render()
	if self.timerStart then
		for i=1, #self.cards do
			if self.cards[i].alpha > 0 then
				local delta = (UIManager.getMillisSinceLastRender() / 33.3) * 0.08;
				local value = self.cards[i].alpha - delta;
				if value > 0 then
					self.cards[i].alpha = value;
				else
					self.cards[i].alpha = 0;
				end
			else
				self.done = true;
			end
		end
	end
end

function Reward.Notification:update()
	if self.done then
		self:removeFromUIManager();
		Reward.Notification.instance = nil;
		if self.callback then
			self.callback();
		end
	end
end

function Reward.Notification:new(cards, callback)
    local o = ISPanel:new(0, 0, 260*SSRLoader.scale * #cards, (300+60)*SSRLoader.scale);
    setmetatable(o, self)
    self.__index = self
	o.background = false;

	o.cards = cards;

	o.x = (getCore():getScreenWidth() / 2) - (o.width / 2);
	o.y = (getCore():getScreenHeight() / 2) - (o.height / 2) - 60*SSRLoader.scale;

    o.anchorLeft = true;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = true;

	local language, status = tostring(Translator.getLanguage());
	local path;
	if cards[1].type == 2 then
		path = "media/ui/labels/label_reward_exp_";
	else
		path = "media/ui/labels/label_reward_"..(cards[1].type == 0 and "item" or "trait")..(#cards > 1 and "s" or "").."_";
	end
	status, o.tex_header = pcall(getTexture, path..language..".png");
	if not status or not o.tex_header then
		status, o.tex_header = pcall(getTexture, path.."en.png");
	end
	o.tex_w = o.tex_header:getWidth()*SSRLoader.scale;
	o.tex_h = o.tex_header:getHeight()*SSRLoader.scale;

	getSoundManager():PlaySound("itemReceived", false, 1.0);

	o.timerStart = false;
	o.done = false;

	o.callback = callback;

    return o;
end


Reward.Selection = ISPanel:derive("Reward.Selection");
Reward.Selection.instance = nil;

function Reward.Selection:initialise()
	ISPanel.initialise(self);
end

function Reward.Selection:prerender()
	self:drawTextureScaled(self.tex_title, self.width / 2 - self.tex_title_w / 2, 0, self.tex_title_w, self.tex_title_h, 1, 1, 1, 1);

	for i=1, #self.rewards do
		if self.selected == i then
			self:drawTextureScaled(self.tex_selected, self.rewards[i].x + self.rewards[i].width / 2 - self.tex_selected_w / 2, self.rewards[i].y + self.rewards[i].height + 5*SSRLoader.scale, self.tex_selected_w, self.tex_selected_h, 1, 1, 1, 1);
		elseif self.rewards[i].bonus then
			self:drawTextureScaled(self.tex_bonus, self.rewards[i].x + self.rewards[i].width / 2 - self.tex_bonus_w / 2, self.rewards[i].y + self.rewards[i].height + 5*SSRLoader.scale, self.tex_bonus_w, self.tex_bonus_h, 1, 1, 1, 1);
		end
	end
end

function Reward.Selection:confirm()
	local items = {};
	local traits = {};
	local perks = {};
	for i=1, #self.rewards do
		if self.selected == i or self.rewards[i].bonus then
			if self.rewards[i].type == 0 then
				local item = QItemFactory.createEntry(self.rewards[i].internal, self.rewards[i].amount);
				item.grade = self.rewards[i].grade;
				items[#items+1] = item;
			elseif self.rewards[i].type == 1 then
				traits[#traits+1] = self.rewards[i].internal;
			elseif self.rewards[i].type == 2 then
				perks[#perks+1] = { name = self.rewards[i].internal, amount = self.rewards[i].amount };
			end
		end
	end
	self:removeFromUIManager();
	Reward.Selection.instance = nil;
	self.callback(items, traits, perks);
end

function Reward.Selection:update()
	if self.selected then
		if not self.bAccept:isEnabled() then
			self.bAccept:setEnable(true);
		end
	elseif self.bAccept:isEnabled() then
		self.bAccept:setEnable(false);
	end
end

function Reward.Selection:createChildren()
	local function onMouseMove(o)
		if o.alpha == 1 then return end;
		o.alpha = 1;
	end

	for i=1, #self.rewards do
		local function onMouseMoveOutside(o)
			if o.bonus or self.selected == i or o.alpha == 0.9 then return end;
			o.alpha = 0.9;
		end

		local function onMouseUp(o, x, y)
			if self.selected == i then
				self.selected = nil;
			else
				self.selected = i;
			end
		end
		self.rewards[i]:setX(15*SSRLoader.scale + 260*SSRLoader.scale * (i-1));
		self.rewards[i]:setY(60*SSRLoader.scale);
		self.rewards[i].onMouseMove = onMouseMove;
		self.rewards[i].onMouseMoveOutside = onMouseMoveOutside;
		self:addChild(self.rewards[i]);
		if not self.rewards[i].bonus then
			self.rewards[i].onMouseUp = onMouseUp;
			self.rewards[i].alpha = 0.9;
		end
	end

    self.bAccept = ISButton:new((self.width / 2) - 100*SSRLoader.scale, self.height - 50*SSRLoader.scale, 200*SSRLoader.scale, 40*SSRLoader.scale, getTextOrNull("UI_QSystem_Reward_Accept") or "Accept", self, Reward.Selection.confirm);
	self.bAccept:setAnchorTop(false);
	self.bAccept:setAnchorBottom(true);
	self.bAccept:setFont(UIFont.Medium);
	self.bAccept:initialise();
	self.bAccept:instantiate();
	self.bAccept.borderColor = {r=1, g=1, b=1, a=0.2};
	self:addChild(self.bAccept);
end

function Reward.Selection:new(rewards, callback)
	rewards = rewards or {};
	local o = ISPanel:new(0, 0, 20*SSRLoader.scale + 260*SSRLoader.scale * #rewards, 480*SSRLoader.scale);
    setmetatable(o, self);
    self.__index = self;

	o.x = (getCore():getScreenWidth() / 2) - (o.width / 2);
	o.y = (getCore():getScreenHeight() / 2) - (o.height / 2);

	o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.7};
	o.background = false;

	o.rewards = rewards;
	o.selected = nil;
	o.callback = callback;

	local language, status = tostring(Translator.getLanguage());
	status, o.tex_title = pcall(getTexture, "media/ui/labels/label_select_reward_"..language..".png");
	if not status or not o.tex_title then
		o.tex_title = getTexture("media/ui/labels/label_select_reward_en.png");
	end
	o.tex_title_w, o.tex_title_h = o.tex_title:getWidth()*SSRLoader.scale, o.tex_title:getHeight()*SSRLoader.scale;

	status, o.tex_selected = pcall(getTexture, "media/ui/labels/label_selected_"..language..".png");
	if not status or not o.tex_selected then
		o.tex_selected = getTexture("media/ui/labels/label_selected_en.png");
	end
	o.tex_selected_w, o.tex_selected_h = o.tex_selected:getWidth()*SSRLoader.scale, o.tex_selected:getHeight()*SSRLoader.scale;

	status, o.tex_bonus = pcall(getTexture, "media/ui/labels/label_bonus_"..language..".png");
	if not status or not o.tex_bonus then
		o.tex_bonus = getTexture("media/ui/labels/label_bonus_en.png");
	end
	o.tex_bonus_w, o.tex_bonus_h = o.tex_bonus:getWidth()*SSRLoader.scale, o.tex_bonus:getHeight()*SSRLoader.scale;

    return o;
end


Reward.onResolutionChange = function()
	if Reward.Notification.instance then
		local x = getCore():getScreenWidth() / 2 - Reward.Notification.instance:getWidth() / 2;
		local y = getCore():getScreenHeight() / 2 - Reward.Notification.instance:getHeight() / 2  - 60;
		Reward.Notification.instance:setX(x);
		Reward.Notification.instance:setY(y);
	end

	if Reward.Selection.instance then
		local x = getCore():getScreenWidth() / 2 - Reward.Selection.instance:getWidth() / 2;
		local y = getCore():getScreenHeight() / 2 - Reward.Selection.instance:getHeight() / 2;
		Reward.Selection.instance:setX(x);
		Reward.Selection.instance:setY(y);
	end
end

Events.OnResolutionChange.Add(Reward.onResolutionChange);

Reward.onQSystemReset = function() -- TODO: reset selection on script terminated, when command is executed, from there.
	if Reward.Notification.instance then
		Reward.Notification.instance:removeFromUIManager();
		Reward.Notification.instance = nil;
	end

	if Reward.Selection.instance then
		Reward.Selection.instance:removeFromUIManager();
		Reward.Selection.instance = nil;
	end
end

Events.OnQSystemReset.Add(Reward.onQSystemReset)


Reward.Pool = {}

local pools = {}
local function getIndex(pool)
	for i=1, #pools do
		if pools[i].id == pool then
			return i;
		end
	end
end

local function validate(entry)
	local size = #entry;
	if entry[1] == "EXP" and (size == 2 or size == 3) then
		if Perks.FromString(entry[2]) then
			local status, exp;
			if size == 3 then
				exp = entry[3];
			end
			if exp then
				status, exp = pcall(tonumber, exp)
				if status and exp then
					exp = math.floor(exp);
				else
					return "Argument 3 is not a number";
				end
			end
			return { name = entry[2], amount = exp }, 3;
		else
			return "Perk "..tostring(entry[2]).." doesn't exist";
		end
	elseif size == 3 then
		if getScriptManager():FindItem(entry[1]) then
			local status;
			status, entry[2] = pcall(tonumber, entry[2])
			if status and entry[2] then
				if type(entry[3]) == "number" then
					if math.floor(entry[3]) ~= entry[3] then
						return "Item grade is a number, but not an integer";
					elseif entry[3] < 1 or entry[3] > 4 then
						return "Unknown item grade";
					end
				else
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
				end
				local item = QItemFactory.createEntry(entry[1], entry[2]);
				item.grade = entry[3];
				return item, 1;
			else
				return "Argument 2 is not a number";
			end
		else
			return "Item "..tostring(entry[1]).." doesn't exist";
		end
	elseif size == 1 then
		for i=0, TraitFactory.getTraits():size()-1 do
			local trait = TraitFactory.getTraits():get(i);
			if entry[1] == trait:getType() then
				return entry[1], 2;
			end
		end
		return "Trait "..tostring(entry[1]).." doesn't exist";
	else
		return "Invaild arguments. Must be 'item_name,amount,grade' or 'trait_name'";
	end
end

function Reward.Pool.exists(pool)
	for i=1, #pools do
		if pools[i].id == pool then
			return true;
		end
	end
end

function Reward.Pool.insert(pool, reward, weight) -- pool id, reward args, pull chance
	if type(reward) == "table" and type(weight) == "number" then
		local entry, reward_type = validate(reward);
		if type(entry) == "string" and not reward_type then
			print("[QSystem] (Error) Reward: "..entry);
		else
			if weight > 0 then
				local index = getIndex(pool);
				if not index then
					index = #pools+1;
					pools[index] = { id = pool, items = {} };
				end
				pools[index].items[#pools[index].items+1] = { reward_type, entry, weight }; -- reward type, reward args, pull chance
				return;
			else
				print("[QSystem] (Error) Reward: Weight must be greater than 0");
			end
		end
	else
		print("[QSystem] (Error) Reward: Invalid argument");
	end
	QuestLogger.error = true;
end

function Reward.Pool.pull(pool)
	local index = getIndex(pool);
	if index then
		local s = 0;
		for i=1, #pools[index].items do
			s = s + pools[index].items[i][3];
		end
		local rolled = ZombRandFloat(0, s); -- ZombRandBetween(0, s)
		for i=1, #pools[index].items do
			s = s - pools[index].items[i][3];
			if rolled >= s then
				return pools[index].items[i][1], pools[index].items[i][2];
			end
		end
	else
		error("[QSystem] (Error) Reward: Pool with id '"..tostring(pool).."' doesn't exist", 2);
	end
end