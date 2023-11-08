-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"

CharacterPanel = ISPanel:derive("CharacterPanel");

function CharacterPanel:initialise()
	ISPanel.initialise(self);
end

function CharacterPanel:clear()
	self.panel.profile.text = "";
	self.panel.profile:paginate();
end

function CharacterPanel:show()
	self:populateList();
	if self.charList:size() > 0 then
		self:onSelect(self.charList.items[self.charList.selected].item);
	else
		self:clear();
	end
	self:setVisible(true);
end

function CharacterPanel:drawDatas(y, item, alt)
	if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
	else
		if item.index / 2 == math.floor(item.index / 2) then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.2, 0.2, 0.2, 0.15);
		end
	end

	self:drawText(item.text, 10, y + 2, 1, 1, 1, 0.9, self.font);

    return y + self.itemheight;
end

function CharacterPanel:populateList()
    self.charList:clear();

    for i=1, #CharacterManager.instance.items do
		local char = CharacterManager.instance.items[i];
		if char:isRevealed() then
			self.charList:addItem(char.displayName, char);
		end
    end
end

function CharacterPanel:onSelect(item)
	self.character_id = CharacterManager.instance:indexOf(tostring(item.name));
	if self.character_id then
		local file = CharacterManager.instance.items[self.character_id].file;
		local mod = CharacterManager.instance.items[self.character_id].mod;
		self.script = CharacterManager.instance:load_script(file, mod);
		if self.script then
			while true do
				local result = self.script:play(self);
				if result == -1 then
					break;
				elseif result then
					self.panel.profile.text = "<RED>"..tostring(result);
					break;
				end
			end
		end
	else
		self.panel.profile.text = "";
	end
	self.panel.profile:paginate();
end

function CharacterPanel:createChildren()
	local offset_y = 10*SSRLoader.scale;
	self.charList = ISScrollingListBox:new(10*SSRLoader.scale, offset_y, 150*SSRLoader.scale, self.height - offset_y - 10*SSRLoader.scale);
	self.charList:initialise();
	self.charList:instantiate();
	self.charList.itemheight = 22*SSRLoader.scale;
	self.charList.selected = 1;
	self.charList.joypadParent = self;
	self.charList.font = UIFont.NewSmall;
	self.charList.doDrawItem = self.drawDatas;
	self.charList:setOnMouseDownFunction(self, self.onSelect);
	self.charList.drawBorder = true;
	self.charList.borderColor = {r=0, g=0, b=0, a=0.2};
	self.charList.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8};
	self.charList.tab = {};
	self:addChild(self.charList);

    self.panel = ISPanel:new(self.charList.width + 20*SSRLoader.scale, offset_y, self.width - self.charList.width - 30*SSRLoader.scale, self.charList.height);
	self.panel:initialise();
	self.panel.borderColor = {r=0, g=0, b=0, a=0.0};
	self.panel.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8};
	self:addChild(self.panel);

	self.panel.profile = ISRichTextPanel:new(0, 0, self.panel.width, self.panel.height);
	self.panel.profile:initialise();
	self.panel.profile.backgroundColor = {r=1, g=1, b=1, a=0.01};
	self.panel.profile.borderColor = {r=1, g=1, b=1, a=0.0};
	self.panel.profile.text = "";
	self.panel.profile.autosetheight = false;
	self.panel.profile:setMargins(10*SSRLoader.scale, 10*SSRLoader.scale, 25*SSRLoader.scale, 0);
	self.panel.profile.clip = true;
	self.panel.profile:addScrollBars();
	self.panel:addChild(self.panel.profile);

    self:populateList();
	if self.charList:size() > 0 then
		self:onSelect(self.charList.items[self.charList.selected].item)
	end
end

function CharacterPanel:close()
	self:setVisible(false);
end

function CharacterPanel:new(x, y)
	local o = ISPanel:new(x*SSRLoader.scale, y*SSRLoader.scale, 780*SSRLoader.scale, 450*SSRLoader.scale);
	setmetatable(o, self);
    self.__index = self;

	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=1.0};
	o.borderColor.a = 0;

	o.autosetheight = true;

	o.window = nil;

	o.script = nil -- last script
	o.character_id = nil -- last character

	o.dragging = true;
	o.strict = true;
   return o
end