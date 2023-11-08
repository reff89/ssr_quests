-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"

QuestPanel = ISPanel:derive("QuestPanel");

local label_weekly = getTextOrNull("UI_QPanel_Label_Weekly") or "Weekly Quest";
local label_daily = getTextOrNull("UI_QPanel_Label_Daily") or "Daily Quest";
local label_event = getTextOrNull("UI_QPanel_Label_Event") or "Event Quest";
local label_track = getTextOrNull("UI_QPanel_Button_Track") or "Track";
local label_untrack = getTextOrNull("UI_QPanel_Button_Untrack") or "Untrack";
local label_abandon = getTextOrNull("UI_QPanel_Button_Abandon") or "Abandon";
local label_abandon_confirm = getTextOrNull("UI_QPanel_Label_ConfirmAbandon") or "Are you sure you want to abandon this quest?";
local label_desc = (getTextOrNull("UI_QPanel_Label_Description") or "Description")..": <LINE>";
local label_tasks = (getTextOrNull("UI_QPanel_Label_Tasks") or "Tasks")..": <LINE>";

function QuestPanel:initialise()
	ISPanel.initialise(self);
end

function QuestPanel:show()
	QuestButton.read = true;
	self:populateList();
	self:setVisible(true);
end

function QuestPanel:onTabSelect(button)
	self.page = button.internal;
	self:populateList();
end

function QuestPanel:onSelect(quest)
	if quest then
		self.questDescription.text = label_desc..self.questList.items[self.questList.selected].item:getDescription();
		self.questDescription:paginate();

		self:showTasks();

		local active = not (quest.completed or quest.failed);
		self.bTrack:setEnable(active);
		self.bAbandon:setEnable(active and (quest.weekly or quest.daily));

		local event = quest.event and CharacterManager.instance:getEvent(quest.event);
		if event then
			if event[3] then
				self.event.multiplier = nil;
			else
				self.event.multiplier = 1440 / getGameTime():getMinutesPerDay();
			end
			self.event.deadline = event[2];
			self.event.countdown = 0;
		else
			self.event.deadline = nil;
		end
	else
		self.bTrack:setEnable(false);
		self.bAbandon:setEnable(false);
		self.questDescription:setVisible(false);
		self.questTasks:setVisible(false);
	end

	for i = 3, 1, -1 do
		if i == self.page then
			self.questList.tab[i].backgroundColor = {r=0.1, g=0.1, b=0.1, a=1.0};
			self.questList.tab[i].textColor.a = 0.8;
		else
			self.questList.tab[i].backgroundColor = {r=0, g=0, b=0, a=1.0};
			self.questList.tab[i].textColor.a = 0.7;
		end
	end
end

function QuestPanel:createChildren()
	--- Quest list ---
	self.questList = ISScrollingListBox:new(10*SSRLoader.scale, 35*SSRLoader.scale, 300*SSRLoader.scale, self.height - 45*SSRLoader.scale);
	self.questList:initialise();
	self.questList:instantiate();
	self.questList.itemheight = 22*SSRLoader.scale;
	self.questList.selected = 0;
	self.questList.joypadParent = self;
	self.questList.font = UIFont.NewSmall;
	self.questList.doDrawItem = self.drawDatas;
	self.questList:setOnMouseDownFunction(self, self.onSelect);
	self.questList.drawBorder = false;
	self.questList.backgroundColor = {r=0.1, g=0.1, b=0.1, a=1.0};
	self.questList.borderColor.a = 0;
	self.questList.tab = {}

	-- Tabs
	for i=3, 1, -1 do
		local tab = ISButton:new(0, 10*SSRLoader.scale, 60*SSRLoader.scale, 25*SSRLoader.scale, "" , self, QuestPanel.onTabSelect);
		tab:initialise();
		tab.backgroundColor = {r=0, g=0, b=0, a=1.0};
		tab.borderColor.a = 0;
		tab.textColor =  {r=1, g=1, b=1, a=0.7};
		tab:setVisible(false);
		self:addChild(tab);
		self.questList.tab[i] = tab;
		self.questList.tab[i].internal = i;
	end

	local tab_length = 0;

	local page = {};
	page.title = { getTextOrNull("UI_QPanel_Tab_Active") or "Active", getTextOrNull("UI_QPanel_Tab_Completed") or "Completed", getTextOrNull("UI_QPanel_Tab_Failed") or "Failed" };
	page.size = 3;

	local min_width = 45*SSRLoader.scale;
	for i = 1, page.size do
		self.questList.tab[i].title = page.title[i];
		local new_width = getTextManager():MeasureStringX(self.questList.tab[i].font, page.title[i]) + 10*SSRLoader.scale; -- (string.len(page.title[i]) * 8) + 10;
		self.questList.tab[i]:setWidth(new_width < min_width and min_width or new_width);
		self.questList.tab[i]:setVisible(true);
		tab_length = tab_length + self.questList.tab[i]:getWidth();
	end

	local tab_offset = (self.questList:getWidth() - tab_length) / page.size;
	if tab_offset > 3 then
		tab_offset = 3;
	end

	local prev_x = self.questList:getX() + ((self.questList:getWidth() / 2) - (tab_length / 2)) - (tab_offset * (page.size - 1));
	for i=1, page.size do
		self.questList.tab[i]:setX(prev_x);
		if i + 1 <= page.size then
			prev_x = prev_x + self.questList.tab[i]:getWidth() + tab_offset;
		end
	end

	self:addChild(self.questList);
	self.questList:bringToTop();

	local offset_x = self.questList:getWidth() + 20*SSRLoader.scale;
	--- Quest details ---
	self.questDescription = ISRichTextPanel:new(offset_x, 70*SSRLoader.scale, 450*SSRLoader.scale, 190*SSRLoader.scale);
	self.questDescription:initialise();
	self.questDescription.backgroundColor.a = 0;
	self.questDescription.borderColor.a = 0;
	self.questDescription.text = label_desc;
	self.questDescription.autosetheight = false;
	self.questDescription:setMargins(10*SSRLoader.scale, 10*SSRLoader.scale, 25*SSRLoader.scale, 0);
	self.questDescription.clip = true;
	self.questDescription:addScrollBars();
	self:addChild(self.questDescription)

	self.questTasks = ISRichTextPanel:new(offset_x, 270*SSRLoader.scale, self.questDescription.width, 130*SSRLoader.scale);
	self.questTasks:initialise();
	self.questTasks.backgroundColor.a = 0;
	self.questTasks.borderColor.a = 0;
	self.questTasks.text = label_tasks;
	self.questTasks.autosetheight = false;
	self.questTasks:setMargins(10*SSRLoader.scale, 10*SSRLoader.scale, 25*SSRLoader.scale, 0);
	self.questTasks.clip = true;
	self.questTasks:addScrollBars();
	self:addChild(self.questTasks)

	--- Buttons ---
	self.bTrack = ISButton:new(offset_x, self.height - 36*SSRLoader.scale, 70*SSRLoader.scale, 25*SSRLoader.scale, label_track, self, QuestPanel.track);
    self.bTrack:initialise();
    self.bTrack.borderColor = {r=1, g=1, b=1, a=0.4};
    self.bTrack.textColor =  {r=1, g=1, b=1, a=0.5};
	self:addChild(self.bTrack);

	self.bAbandon = ISButton:new(self.bTrack.x + self.bTrack.width + 10*SSRLoader.scale, self.bTrack.y, 70*SSRLoader.scale, 25*SSRLoader.scale, label_abandon, self, QuestPanel.abandon);
    self.bAbandon:initialise();
	self.bAbandon.borderColor = {r=1, g=1, b=1, a=0.4};
    self.bAbandon.textColor =  {r=1, g=1, b=1, a=0.5};
	self:addChild(self.bAbandon);

	self:populateList();
end

function QuestPanel:drawDatas(y, item, alt)
	local quest = item.item;
	if self.selected == item.index then
		if quest.completed then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.3, 0.73, 0.09);
		elseif quest.failed then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.81, 0.06, 0.13);
		else
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
		end
	else
		if item.index / 2 == math.floor(item.index / 2) then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.2, 0.2, 0.2, 0.15);
		end
	end

	if quest.event then
		self:drawText(item.text, 10, y + 2, 0.5, 1.0, 0.58, 0.9, self.font);
	else
		self:drawText(item.text, 10, y + 2, 1, 1, 1, 0.9, self.font);
	end

    return y + self.itemheight;
end

function QuestPanel:populateList()
    self.questList:clear();

	local active_quest = nil;
	if QTracker.ActiveQuest then
		active_quest = QTracker.ActiveQuest.internal;
	end

    for i=1, #QuestManager.instance.quests do
		local q = QuestManager.instance.quests[i];
		if q.unlocked and not q.hidden then
			if (self.page == 1 and not q.completed and not q.failed) or (self.page == 2 and q.completed) or (self.page == 3 and q.failed) then
				self.questList:addItem(q:getName(), q);
				if active_quest and active_quest == q.internal then
					self.questList.selected = self.questList:size();
				end
			end
		end
    end

	self.bTrack.title = label_track;
	if #self.questList.items > 0 then
		self:onSelect(self.questList.items[self.questList.selected].item);
	else
		self:onSelect();
	end
end

function QuestPanel:close()
	self:setVisible(false)
end

function QuestPanel:track()
	if QTracker.ActiveQuest == self.questList.items[self.questList.selected].item then
		QTracker.clear();
	elseif QTracker.ActiveQuest ~= self.questList.items[self.questList.selected].item then
		QTracker.track(self.questList.items[self.questList.selected].item, false);
		self.bTrack.title = label_untrack;
	end
end

local function abandon(self, button)
	if button.internal == "YES" then
		if self.questList.items[self.questList.selected].item == QTracker.ActiveQuest then
			QTracker.clear();
		end
		self.questList.items[self.questList.selected].item:fail();
		SaveManager.save();
		self:populateList();
	end
end

function QuestPanel:abandon()
	if QInterface.instance then
		local modal = ISModalDialog:new(QInterface.instance:getX() + (QInterface.instance:getWidth() / 2) - 175*SSRLoader.scale, QInterface.instance:getY() + (QInterface.instance:getHeight() / 2) - 75*SSRLoader.scale, 350*SSRLoader.scale, 150*SSRLoader.scale, label_abandon_confirm, true, self, abandon);
		modal.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.8};
    	modal.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
		modal:initialise()
		modal:addToUIManager()
		modal:setCapture(true);
	end
end

function QuestPanel:showTasks()
	if self.questList.items[1] then
		local text = "";
		local counter = 0;
		for i=1, #self.questList.items[self.questList.selected].item.tasks do
			local t = self.questList.items[self.questList.selected].item.tasks[i];
			if t.unlocked and not t.hidden and not t.completed then
				text = text.."- "..t:getName()..t:getDetails();
				text = text.." <LINE> ";
				counter = counter + 1;
			end
		end

		if counter > 0 then
			text = label_tasks..text;
			self.questTasks:setVisible(true);
		else
			self.questTasks:setVisible(false);
		end

		if text ~= self.questTasks.text then
			self.questTasks.text = text;
			self.questTasks:paginate();
		end
	end
end

function QuestPanel:prerender()
	ISPanel.prerender(self);
	self:drawRect(320*SSRLoader.scale, 10*SSRLoader.scale, 450*SSRLoader.scale, 50*SSRLoader.scale, 1.0, 0.1, 0.1, 0.1);
	self:drawRect(320*SSRLoader.scale, 70*SSRLoader.scale, 450*SSRLoader.scale, 190*SSRLoader.scale, 1.0, 0.1, 0.1, 0.1);
	self:drawRect(320*SSRLoader.scale, 270*SSRLoader.scale, 450*SSRLoader.scale, 130*SSRLoader.scale, 1.0, 0.1, 0.1, 0.1);
	if self.questList.items[1] then
		self:setStencilRect(320*SSRLoader.scale, 10*SSRLoader.scale, 450*SSRLoader.scale, 50*SSRLoader.scale);
		self:drawText(self.questList.items[self.questList.selected].text, 330*SSRLoader.scale, 15*SSRLoader.scale, 1.0, 1.0, 1.0, 1.0, UIFont.Medium);
		if self.questList.items[self.questList.selected].item.event then
			local text = self.questList.items[self.questList.selected].item.daily and (label_daily.." / "..label_event) or self.questList.items[self.questList.selected].item.weekly and (label_weekly.." / "..label_event) or label_event;
			if self.event.deadline then
				if self.event.countdown > 0 then
					local minutes = self.event.countdown / 60;
					if minutes > 60 then
						self:drawText(text..string.format(" (~%ih)", minutes / 60), 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 0.58, 1.0, UIFont.NewSmall);
					elseif minutes > 1 then
						self:drawText(text..string.format(" (~%im)", minutes), 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 0.58, 1.0, UIFont.NewSmall);
					else
						self:drawText(text..string.format(" (%is)", self.event.countdown), 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 0.58, 1.0, UIFont.NewSmall);
					end
				else
					self:drawText(text, 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 0.58, 1.0, UIFont.NewSmall);
				end
			else
				self:drawText(text, 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 0.58, 1.0, UIFont.NewSmall);
			end
		elseif self.questList.items[self.questList.selected].item.weekly then
			self:drawText(label_weekly, 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 1.0, 1.0, UIFont.NewSmall);
		elseif self.questList.items[self.questList.selected].item.daily then
			self:drawText(label_daily, 330*SSRLoader.scale, 35*SSRLoader.scale, 0.5, 1.0, 1.0, 1.0, UIFont.NewSmall);
		end
		self:clearStencilRect();
	end
end

function QuestPanel:update()
	if self:isVisible() then
		if self.questList.items[1] then
			if self.event.deadline then
				if self.event.multiplier then
					self.event.countdown = math.floor((self.event.deadline - GetWorldAgeSeconds()) / self.event.multiplier);
				else
					self.event.countdown = math.floor(self.event.deadline - getTimestamp());
					self.event.countdown = self.event.countdown < 0 and 0 or self.event.countdown;
				end
			end

			self.bTrack.title = QTracker.ActiveQuest == self.questList.items[self.questList.selected].item and label_untrack or label_track;
			self.questDescription:setVisible(true);
		end
	end
end

function QuestPanel:new(x, y)
	local o = ISPanel:new(x*SSRLoader.scale, y*SSRLoader.scale, 780*SSRLoader.scale, 450*SSRLoader.scale);
	setmetatable(o, self)
    self.__index = self

	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=1.0};
	o.borderColor.a = 0;

	o.autosetheight = true;
	--o.window = nil;

	o.page = 1; -- (1 - active), (2 - completed), (3 - failed)

	o.event = {};
	o.event.multiplier = 1440 / getGameTime():getMinutesPerDay();

	o:setAlwaysOnTop(true);
	return o
end