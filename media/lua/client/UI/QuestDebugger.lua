-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISCollapsableWindow"
require "Communications/QSystem"

QuestDebugger = ISCollapsableWindow:derive("QuestDebugger");
QuestDebugger.instance = nil;
QuestDebugger.backup = nil;
local serpent = require("serpent");

function QuestDebugger:initialise()
    ISCollapsableWindow.initialise(self);
end

function QuestDebugger:render()
    ISCollapsableWindow.render(self);
end

function QuestDebugger:onTickVerbose(index, selected)
    if index == 1 then
        QuestLogger.verbose = selected;
        self.checkbox_verbose.selected[1] = QuestLogger.verbose;
    end
end

function QuestDebugger:onTickSaveProgress(index, selected)
    if index == 1 then
        SaveManager.enabled = selected;
        self.checkbox_save.selected[1] = SaveManager.enabled;
    end
end

function QuestDebugger:onTickCharProps(index, selected)
    if index == 1 then
        CharacterManager.instance.items[self.charList.selected-1]:setAlive(selected);
        self.characterPanel.cb.selected[1] = CharacterManager.instance.items[self.charList.selected-1].alive;
    elseif index == 2 then
        CharacterManager.instance.items[self.charList.selected-1].revealed = not CharacterManager.instance.items[self.charList.selected-1].revealed;
        if QInterface.instance then
            if QInterface.instance:isTab(2) then
                QInterface.instance.panel[2]:populateList();
            end
        end
        SaveManager.onCharacterDataChange();
        self.characterPanel.cb.selected[2] = CharacterManager.instance.items[self.charList.selected-1].revealed;
    end
end

local function createDialoguePanel(self)
    if self.charList.selected > 1 and not DialoguePanel.instance then
        DialoguePanel.create(CharacterManager.instance.items[self.charList.selected-1].file);
        self.bStartScript:setEnable(false);
    end
end

local function closeDialoguePanel(self)
    if DialoguePanel.instance then
        DialoguePanel.instance:close();
        self.bResetScript:setEnable(false);
    end
end

local function forceUpload()
    SaveManager.save(true, true);
end

local function saveState()
    QuestDebugger.backup = {};
    for i=1, #SaveManager.flags do
        SaveManager.flags[i] = true; -- allow saving quests, characters, etc
    end
    QuestDebugger.backup = SaveManager.data(true);
end

local function loadState()
    QSystem.pause();
    QTracker.clear(); -- clear tracker
    local progress = {};
    for i=1, #SaveManager.dataType do
        progress[i] = QuestDebugger.backup[i] and serpent.load(QuestDebugger.backup[i]) or false;
    end
    SaveManager.load(progress);
    triggerEvent("OnQSystemUpdate", 4);
    QSystem.resume();
end

local function reimport()
    QSystem.pause();
    QuestDebugger.instance:clear();
    QImport.reimport(QSystem.resume);
end

local function updateCharacterInfo(self, index)
    self.characterPanel.info.text = " <RGB:0.8,0.8,0.8> Name="..tostring(self.charList.items[index].item.displayName or self.charList.items[index].item.name).." <LINE> Cleared Quests="..tostring(self.charList.items[index].item.cleared_quests).." <LINE> File="..tostring(self.charList.items[index].item.file).." <LINE> Mod="..tostring(self.charList.items[index].item.mod);
    self.characterPanel.info:paginate();
end

local function increaseStat(self)
    local index = self.characterPanel.stats.selected;
    local stat = self.characterPanel.stats.items[index].item;
    CharacterManager.instance.items[self.charList.selected-1]:increaseStat(stat[1], 1);
    self.characterPanel.stats.items[self.characterPanel.stats.selected].text = tostring(stat[1]).."="..tostring(stat[2]);
end

local function decreaseStat(self)
    local index = self.characterPanel.stats.selected;
    local stat = self.characterPanel.stats.items[index].item;
    CharacterManager.instance.items[self.charList.selected-1]:decreaseStat(stat[1], 1);
    self.characterPanel.stats.items[self.characterPanel.stats.selected].text = tostring(stat[1]).."="..tostring(stat[2]);
end

local function removeFlag(self)
    local index = self.defaultPanel.flags.selected;
    local flag = self.defaultPanel.flags.items[index].item;
    CharacterManager.instance:removeFlag(flag);
    self:populateFlags();
    if index > self.defaultPanel.flags:size() then
        self.defaultPanel.flags.selected = self.defaultPanel.flags:size();
    else
        self.defaultPanel.flags.selected = index;
    end
end

local function removeEvent(self)
    local index = self.defaultPanel.events.selected;
    local event = tostring(CharacterManager.instance.events[index][1]);
    if self.defaultPanel.events.items[self.defaultPanel.events.selected].item[1] == event then
        CharacterManager.instance:removeEvent(index, event);
    end
    self:populateEvents();
    if index > self.defaultPanel.events:size() then
        self.defaultPanel.events.selected = self.defaultPanel.events:size();
    else
        self.defaultPanel.events.selected = index;
    end
end

function QuestDebugger:onQuestFlagsChange(index, selected)
    if index > 0 and index < 6 then
        if index == 1 then
            if selected then
                self.questPanel.flags.selected[2] = false;
                self.questList.items[self.questList.selected].item.failed = false;
                self.questList.items[self.questList.selected].item:complete();
            else
                self.questList.items[self.questList.selected].item.completed = false;
                if self.questList.items[self.questList.selected].item.unlocked then
                    QuestManager.instance.active_size = QuestManager.instance.active_size + 1; QuestManager.instance.active[QuestManager.instance.active_size] = self.questList.items[self.questList.selected].item.index;
                end
            end
        elseif index == 2 then
            self.questList.items[self.questList.selected].item.failed = selected;
            if selected then
                self.questPanel.flags.selected[1] = false;
                self.questList.items[self.questList.selected].item.completed = false;
                self.questList.items[self.questList.selected].item:fail();
            else
                self.questList.items[self.questList.selected].item.failed = false;
                if self.questList.items[self.questList.selected].item.unlocked then
                    QuestManager.instance.active_size = QuestManager.instance.active_size + 1; QuestManager.instance.active[QuestManager.instance.active_size] = self.questList.items[self.questList.selected].item.index;
                end
            end
        elseif index == 3 then
            if self.questList.items[self.questList.selected].item.unlocked then
                self.questList.items[self.questList.selected].item:reset();
            end
            if selected then
                self.questList.items[self.questList.selected].item:unlock();
            else
                self.questList.items[self.questList.selected].item:lock();
            end
        elseif index == 4 then
            self.questList.items[self.questList.selected].item.daily = selected;
        elseif index == 5 then
            self.questList.items[self.questList.selected].item.weekly = selected;
        elseif index == 7 then
            self.questList.items[self.questList.selected].item.hidden = selected;
        end
        self.questPanel.flags.selected[index] = selected;
    end
end

function QuestDebugger:onTaskFlagsChange(index, selected)
    if index > 0 and index < 5 then
        if index == 1 then
            self.taskList.items[self.taskList.selected].item.pending = selected;
        elseif index == 2 then
            if selected then
                self.taskList.items[self.taskList.selected].item:complete();
            else
                self.taskList.items[self.taskList.selected].item.completed = false;
                if self.taskList.items[self.taskList.selected].item.unlocked then
                    local quest_id = self.taskList.items[self.taskList.selected].item.quest_id;
                    QuestManager.instance.quests[quest_id].active_size = QuestManager.instance.quests[quest_id].active_size + 1; QuestManager.instance.quests[quest_id].active[QuestManager.instance.quests[quest_id].active_size] = self.taskList.items[self.taskList.selected].item.index;
                end
            end
        elseif index == 3 then
            if selected then
                self.taskList.items[self.taskList.selected].item:unlock()
            else
                self.taskList.items[self.taskList.selected].item:lock()
            end
        elseif index == 4 then
            self.taskList.items[self.taskList.selected].item.hidden = selected;
        end
        self.taskPanel.flags.selected[index] = selected;
    end
end

function QuestDebugger:onActionFlagsChange(index, selected)
    if index > 0 and index < 3 then
        if index == 1 then
            self.actionList.items[self.actionList.selected].item.pending = selected;
        elseif index == 2 then
            if not selected then
                self.actionList.items[self.actionList.selected].item.pending = selected;
                self.actionPanel.flags.selected[1] = selected;
            end
            self.actionList.items[self.actionList.selected].item.completed = selected;
        end
        self.actionPanel.flags.selected[index] = selected;
    end
end

function QuestDebugger:update()
    if DialoguePanel.instance then
        if self.bStartScript.enable then
            self.bStartScript:setEnable(false);
        end
        if not self.bResetScript.enable then
            self.bResetScript:setEnable(true);
        end
        if self.bLoadState.enable or self.bReloadAll.enable then
            self.bLoadState:setEnable(false);
            self.bReloadAll:setEnable(false);
        end
    elseif not DialoguePanel.instance then
        if not self.bStartScript.enable and self.charList.selected > 1 then
            self.bStartScript:setEnable(true);
        elseif self.bStartScript.enable and self.charList.selected < 2 then
            self.bStartScript:setEnable(false);
        end
        if self.bResetScript.enable then
            self.bResetScript:setEnable(false);
        end
        if QuestDebugger.backup and not QuestManager.pause then
            if not self.bLoadState.enable or not self.bReloadAll.enable then
                self.bLoadState:setEnable(true);
                self.bReloadAll:setEnable(true);
            end
        elseif self.bLoadState.enable or self.bReloadAll.enable then
            self.bLoadState:setEnable(false);
            self.bReloadAll:setEnable(false);
        end
    end

    if QuestManager.pause then
        if self.bSaveState.enable or self.bForceUpload.enable then
            self.bSaveState:setEnable(false);
            self.bForceUpload:setEnable(false);
        end
    elseif not self.bSaveState.enable or not self.bForceUpload.enable then
        self.bSaveState:setEnable(true);
        self.bForceUpload:setEnable(true);
    end

    if self.defaultPanel:isVisible() then
        if self.defaultPanel.flags:size() > 0 then
            self.defaultPanel.deleteFlag:setEnable(true);
        else
            self.defaultPanel.deleteFlag:setEnable(false);
        end
        if self.defaultPanel.events:size() > 0 then
            self.defaultPanel.deleteEvent:setEnable(true);
        else
            self.defaultPanel.deleteEvent:setEnable(false);
        end
    end

    if self.characterPanel:isVisible() then
        if self.characterPanel.stats:size() > 0 then
            if self.characterPanel.stats.items[self.characterPanel.stats.selected].item[2] < CharacterManager.r_max then
                self.characterPanel.increaseStat:setEnable(true);
            else
                self.characterPanel.increaseStat:setEnable(false);
            end
            if self.characterPanel.stats.items[self.characterPanel.stats.selected].item[2] > CharacterManager.r_min then
                self.characterPanel.decreaseStat:setEnable(true);
            else
                self.characterPanel.decreaseStat:setEnable(false);
            end
        else
            self.characterPanel.increaseStat:setEnable(false);
            self.characterPanel.decreaseStat:setEnable(false);
        end
    end
end

function QuestDebugger:drawDatas(y, item, alt)
	if self.selected_id == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
	else
		if item.index / 2 == math.floor(item.index / 2) then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.2, 0.2, 0.2, 0.15);
		end
	end

    if item.text == "n/a" then
        self:drawText(item.text, 10, y + 2, 0.7, 0.7, 0.8, 0.9, self.font);
    else
        self:drawText(item.text, 10, y + 2, 1, 1, 1, 0.9, self.font);
    end

    return y + self.itemheight;
end

local function drawDatas(self, y, item, alt)
    self:setStencilRect(0, 0, self:isVScrollBarVisible() and (self.vscroll.x + 3) or self.width, self.height)
	if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
	else
		if item.index / 2 == math.floor(item.index / 2) then
			self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.2, 0.2, 0.2, 0.15);
		end
	end

	self:drawText(item.text, 10, y + 2, 1, 1, 1, 0.9, self.font);

    self:clearStencilRect();
    return y + self.itemheight;
end

local function showPanel(self, n)
    if n == 0 then
        self.defaultPanel:setVisible(true);
        self.defaultPanel.active = true;
    else
        self.defaultPanel:setVisible(false);
        self.defaultPanel.active = false;
    end
    if n == 1 then
        self.characterPanel:setVisible(true);
    else
        self.characterPanel:setVisible(false);
    end
    if n == 2 then
        self.questPanel:setVisible(true);
    else
        self.questPanel:setVisible(false);
    end
    if n == 3 then
        self.taskPanel:setVisible(true);
    else
        self.taskPanel:setVisible(false);
    end
    if n == 4 then
        self.actionPanel:setVisible(true);
    else
        self.actionPanel:setVisible(false);
    end
end

function QuestDebugger:clear()
    self.charList.selected_id = -1;
    self.questList.selected_id = -1;
    self.taskList.selected_id = -1;
    self.actionList.selected_id = -1;
    self.charList:clear();
    self.questList:clear();
    self.taskList:clear();
    self.actionList:clear();
    showPanel(self, -1)
end

function QuestDebugger:populateList_C()
    self.charList.selected_id = -1;
    self.questList.selected_id = -1;
    self.taskList.selected_id = -1;
    self.actionList.selected_id = -1;
    self.charList:clear();
    self.questList:clear();
    self.taskList:clear();
    self.actionList:clear();

    self.charList:addItem("n/a", {});
    for i=1, #CharacterManager.instance.items do
		local c = CharacterManager.instance.items[i];
		self.charList:addItem(c.name, c);
    end
    self.charList.selected = 1;
    self:onSelectC();
end

function QuestDebugger:populateList_Q(file, mod)
    self.questList.selected_id = -1;
    self.taskList.selected_id = -1;
    self.actionList.selected_id = -1;
    self.questList:clear();
    self.taskList:clear();
    self.actionList:clear();

    if file and mod then
        for i=1, #QuestManager.instance.quests do
            local q = QuestManager.instance.quests[i];
            if q.file == file and q.mod == mod then
                self.questList:addItem(q.internal, q);
            end
        end
    else
        local dependent = {}
        for i=1, #CharacterManager.instance.items do
            dependent[i] = {CharacterManager.instance.items[i].file, CharacterManager.instance.items[i].mod};
        end
        for i=1, #QuestManager.instance.quests do
            local q = QuestManager.instance.quests[i];
            local valid = true;
            for j=1, #dependent do
                if q.file == dependent[j][1] and q.mod == dependent[j][2] then
                    valid = false;
                    break;
                end
            end
            if valid then
                self.questList:addItem(q.internal, q);
            end
        end
    end
end

function QuestDebugger:populateList_T(q)
    self.taskList.selected_id = -1;
    self.actionList.selected_id = -1;
    self.taskList:clear();
    self.actionList:clear();

    for i=1, #q.tasks do
		local t = q.tasks[i];
		self.taskList:addItem(t.internal, t);
    end
    --self.taskList.selected = 1;
end

function QuestDebugger:populateList_A(t)
    self.actionList.selected_id = -1;
    self.actionList:clear();

    for i=1, #t.actions do
		local a = t.actions[i];
		self.actionList:addItem(a.type, a);
    end
    --self.actionList.selected = 1;
end

function QuestDebugger:populateFlags()
    self.defaultPanel.flags:clear();
    for i=1, #CharacterManager.instance.flags do
		local flag = CharacterManager.instance.flags[i];
        self.defaultPanel.flags:addItem(flag, flag);
    end
end

function QuestDebugger:onSelectE()
    if self.defaultPanel.events:size() > 0 then
        local eta = GetCurrentTime(self.defaultPanel.events.items[self.defaultPanel.events.selected].item[3] == false and 0, self.defaultPanel.events.items[self.defaultPanel.events.selected].item[2]);
        self.defaultPanel.info.text = string.format(" <RGB:0.8,0.8,0.8> %s <LINE> %04d/%02d/%02d %02d:%02d", self.defaultPanel.events.items[self.defaultPanel.events.selected].item[3] and (getTextOrNull("UI_QDebugger_Label_RT") or "Real Time") or (getTextOrNull("UI_QDebugger_Label_GT") or "Game Time"), eta.tm_year, eta.tm_mon, eta.tm_mday, eta.tm_hour, eta.tm_min);
    else
        self.defaultPanel.info.text = "";
    end
    self.defaultPanel.info:paginate();
end

function QuestDebugger:populateEvents()
    self.defaultPanel.events:clear();
    for i=1, #CharacterManager.instance.events do
		local event = CharacterManager.instance.events[i];
        self.defaultPanel.events:addItem(event[1], event);
    end
    self:onSelectE();
end

function QuestDebugger:populateStats(index)
    self.characterPanel.stats:clear();
    if self.charList.items[index].item.stats then
        for i=1, #self.charList.items[index].item.stats do
			local stat = self.charList.items[index].item.stats[i];
            self.characterPanel.stats:addItem(tostring(stat[1]).."="..tostring(stat[2]), stat);
        end
    end
end

function QuestDebugger:onSelectC()
    local index = self.charList.selected;
    self.charList.selected_id = index;
    if index == 1 then
        self:populateFlags();
        self:populateEvents();
        showPanel(self, 0);
        self:populateList_Q();
    elseif index > 1 and self.charList:size() > 1 then
        updateCharacterInfo(self, index);
        self.characterPanel.cb.selected[1] = self.charList.items[index].item.alive;
        self.characterPanel.cb.selected[2] = self.charList.items[index].item.revealed;
        self:populateStats(index);
        showPanel(self, 1);
        self:populateList_Q(self.charList.items[index].item.file, self.charList.items[index].item.mod);
    end
end

function QuestDebugger:onSelectQ()
    local index = self.questList.selected;
    self.questList.selected_id = index;
    if self.questList:size() > 0 then
        self.questPanel.info.text = " <RGB:0.7,0.7,1> "..tostring(self.questList.items[index].item.internal).." <LINE>  <RGB:1,1,1> <LINE> "..tostring(self.questList.items[index].item.name or "No name").." <LINE> <LINE> "..tostring(self.questList.items[index].item.description or "No description");
        self.questPanel.info:paginate();
        self.questPanel.flags.selected[1] = self.questList.items[index].item.completed;
        self.questPanel.flags.selected[2] = self.questList.items[index].item.failed;
        self.questPanel.flags.selected[3] = self.questList.items[index].item.unlocked;
        self.questPanel.flags.selected[4] = self.questList.items[index].item.daily;
        self.questPanel.flags.selected[5] = self.questList.items[index].item.weekly;
        self.questPanel.flags.selected[6] = self.questList.items[index].item.event ~= nil;
        self.questPanel.flags.selected[7] = self.questList.items[index].item.hidden;
        if self.questList.items[index].item.event then
            self.questPanel.flags:disableOption("Unlocked", true);
        else
            self.questPanel.flags:disableOption("Unlocked", false);
        end
        showPanel(self, 2);
        self:populateList_T(self.questList.items[index].item);
    end
end

function QuestDebugger:onSelectT()
    local index = self.taskList.selected;
    self.taskList.selected_id = index;
    if self.taskList:size() > 0 then
        self.taskPanel.info.text = " <RGB:0.7,0.7,1> "..tostring(self.taskList.items[index].item.type).." <LINE>  <RGB:1,1,1> <LINE> "..tostring(self.taskList.items[index].item.name or "No name");
        self.taskPanel.info:paginate();
        self.taskPanel.flags.selected[1] = self.taskList.items[index].item.pending;
        self.taskPanel.flags.selected[2] = self.taskList.items[index].item.completed;
        self.taskPanel.flags.selected[3] = self.taskList.items[index].item.unlocked;
        self.taskPanel.flags.selected[4] = self.taskList.items[index].item.hidden;
        showPanel(self, 3);
        self:populateList_A(self.taskList.items[index].item)
    end
end

function QuestDebugger:onSelectA()
    local index = self.actionList.selected;
    self.actionList.selected_id = index;
    if self.actionList:size() > 0 then
        self.actionPanel.flags.selected[1] = self.actionList.items[index].item.pending;
        self.actionPanel.flags.selected[2] = self.actionList.items[index].item.completed;
        showPanel(self, 4);
    end
end

function QuestDebugger.onQSystemUpdate(code)
    if QuestDebugger.instance then
        if code == 4 then
            QuestDebugger.instance:populateList_C();
        elseif QuestDebugger.instance.actionList.selected_id ~= -1 then
            QuestDebugger.instance:onSelectA();
        elseif QuestDebugger.instance.taskList.selected_id ~= -1 then
            QuestDebugger.instance:onSelectT();
        elseif QuestDebugger.instance.questList.selected_id ~= -1 then
            QuestDebugger.instance:onSelectQ();
        elseif code == 0 and QuestDebugger.instance.charList.selected_id ~= -1 then
            QuestDebugger.instance:onSelectC();
        end
    end
end

Events.OnQSystemUpdate.Add(QuestDebugger.onQSystemUpdate);

function QuestDebugger:createChildren()
    ISCollapsableWindow.createChildren(self);

    local offset_y = 22*SSRLoader.scale;
    self.checkbox_verbose = ISTickBox:new(10*SSRLoader.scale, offset_y, 200*SSRLoader.scale, 20*SSRLoader.scale, "", self, QuestDebugger.onTickVerbose);
	self.checkbox_verbose:initialise();
	self:addChild(self.checkbox_verbose);
	self.checkbox_verbose:addOption(getTextOrNull("UI_QDebugger_Checkbox_Verbose") or "Verbose");
	self.checkbox_verbose.selected[1] = QuestLogger.verbose;
    self.checkbox_verbose.tooltip = getTextOrNull("UI_QDebugger_Tooltip_Verbose") or "Detailed output in log";

    self.checkbox_save = ISTickBox:new(10*SSRLoader.scale, offset_y + 20*SSRLoader.scale, 200*SSRLoader.scale, 20*SSRLoader.scale, "", self, QuestDebugger.onTickSaveProgress);
	self.checkbox_save:initialise()
    self:addChild(self.checkbox_save)
    self.checkbox_save:addOption(getTextOrNull("UI_QDebugger_Checkbox_SaveProgress") or "AutoSave");
    self.checkbox_save.selected[1] = SaveManager.enabled;
    self.checkbox_save.tooltip = getTextOrNull("UI_QDebugger_Tooltip_SaveProgress") or "Enable/disable quest progress saving";

    local function createButton(x, y, w, text, func)
        local button = ISButton:new(x, y, w, 20*SSRLoader.scale, text, self, func);
        button:setAnchorTop(false);
        button:setAnchorBottom(true);
        button:initialise();
        button:instantiate();
        button.borderColor = {r=1, g=1, b=1, a=0.2};
        return button;
    end

    local offset_x = 155*SSRLoader.scale;
    self.bForceUpload = createButton(offset_x, offset_y, 100*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_ForceUpload") or "Force Upload", forceUpload)
	self:addChild(self.bForceUpload);
    self.bForceUpload:setTooltip(getTextOrNull("UI_QDebugger_Tooltip_ForceUpload") or "Sends progress to the server");

    self.bStartScript = createButton(offset_x, offset_y+25*SSRLoader.scale, 212.5*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_StartDialogue") or "Start dialogue", createDialoguePanel)
	self:addChild(self.bStartScript);
    offset_x = offset_x + self.bForceUpload.width + 11*SSRLoader.scale;

    self.bSaveState = createButton(offset_x, offset_y, 100*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_SaveState") or "Save state", saveState)
	self:addChild(self.bSaveState);
    self.bSaveState:setTooltip(getTextOrNull("UI_QDebugger_Tooltip_SaveState"))
    offset_x = offset_x + self.bSaveState.width + 12*SSRLoader.scale;

    self.bResetScript = createButton(offset_x, offset_y+25*SSRLoader.scale, 212.5*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_EndDialogue") or "End dialogue", closeDialoguePanel)
	self:addChild(self.bResetScript);

    self.bLoadState = createButton(offset_x, offset_y, 100*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_LoadState") or "Load state", loadState)
	self:addChild(self.bLoadState);
    self.bLoadState:setTooltip(getTextOrNull("UI_QDebugger_Tooltip_LoadState"))
    offset_x = offset_x + self.bLoadState.width + 12*SSRLoader.scale;

    self.bReloadAll = createButton(offset_x, offset_y, 100*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_Reimport") or "Reimport", reimport)
	self:addChild(self.bReloadAll);
    self.bReloadAll:setTooltip(getTextOrNull("UI_QDebugger_Tooltip_Reimport") or "Quest and character data will be reset and reloaded from disk");

	offset_y=offset_y+self.checkbox_verbose:getHeight()+self.checkbox_save:getHeight()+15*SSRLoader.scale;

    local function createScrollingListBox(x, y, w, h)
        local list = ISScrollingListBox:new(x, y, w, h);
	    list:initialise();
        list:instantiate();
        list.itemheight = 20*SSRLoader.scale;
        list.selected = 1;
        list.selected_id = -1;
        list.joypadParent = self;
        list.font = UIFont.NewSmall;
        list.drawBorder = true;
        list.borderColor = {r=1, g=1, b=1, a=0.2};
        list.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.5};
        return list;
    end

	self.charList = createScrollingListBox(10*SSRLoader.scale, offset_y, 140*SSRLoader.scale, self.height - offset_y - 10*SSRLoader.scale);
    self.charList.doDrawItem = self.drawDatas;
	self.charList:setOnMouseDownFunction(self, QuestDebugger.onSelectC);
	self:addChild(self.charList);

    self.questList = createScrollingListBox(self.charList.x + self.charList.width + 5*SSRLoader.scale, offset_y, 140*SSRLoader.scale, 200*SSRLoader.scale);
    self.questList.doDrawItem = self.drawDatas;
	self.questList:setOnMouseDownFunction(self, QuestDebugger.onSelectQ);
	self:addChild(self.questList);

    self.taskList = createScrollingListBox(self.questList.x + self.questList.width + 5*SSRLoader.scale, offset_y, 140*SSRLoader.scale, 200*SSRLoader.scale);
    self.taskList.doDrawItem = self.drawDatas;
	self.taskList:setOnMouseDownFunction(self, QuestDebugger.onSelectT);
	self:addChild(self.taskList);

    self.actionList = createScrollingListBox(self.taskList.x + self.taskList.width + 5*SSRLoader.scale, offset_y, 145*SSRLoader.scale, 200*SSRLoader.scale);
    self.actionList.doDrawItem = self.drawDatas;
	self.actionList:setOnMouseDownFunction(self, QuestDebugger.onSelectA);
	self:addChild(self.actionList);

    local function createPanel(x, y, w, h)
        local panel = ISPanel:new(x, y, w, h);
        panel:initialise();
        panel.borderColor = {r=1, g=1, b=1, a=0.2};
        panel.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.5};
        panel:setVisible(false);
        return panel;
    end

    local textHeight = getTextManager():getFontHeight(UIFont.NewSmall)
    local x, y = self.charList.x + self.charList.width + 5*SSRLoader.scale, offset_y + self.questList.height + 5*SSRLoader.scale;
    local w, h = self.width - x - 10*SSRLoader.scale, self.height - y - 10*SSRLoader.scale;

    self.defaultPanel = createPanel(x, y, w, h);
    self:addChild(self.defaultPanel);

    self.defaultPanel.flags = createScrollingListBox(10*SSRLoader.scale, 10*SSRLoader.scale, 210*SSRLoader.scale, self.height - y - 60*SSRLoader.scale);
    self.defaultPanel.flags.doDrawItem = drawDatas;
	self.defaultPanel:addChild(self.defaultPanel.flags);

    self.defaultPanel.deleteFlag = ISButton:new(10*SSRLoader.scale, self.defaultPanel.flags.height + 20*SSRLoader.scale, 210*SSRLoader.scale, 20*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_RemoveFlag") or "Remove Flag", self, removeFlag);
	self.defaultPanel.deleteFlag:setAnchorTop(false);
	self.defaultPanel.deleteFlag:setAnchorBottom(true);
	self.defaultPanel.deleteFlag:initialise();
	self.defaultPanel.deleteFlag:instantiate();
	self.defaultPanel.deleteFlag.borderColor = {r=1, g=1, b=1, a=0.1};
	self.defaultPanel:addChild(self.defaultPanel.deleteFlag);

    self.defaultPanel.info = ISRichTextPanel:new(230*SSRLoader.scale, 10*SSRLoader.scale, 190*SSRLoader.scale, 35*SSRLoader.scale);
	self.defaultPanel.info.backgroundColor.a = 0;
	self.defaultPanel.info.borderColor.a = 0;
	self.defaultPanel.info:setAnchorTop(false);
	self.defaultPanel.info:setAnchorBottom(true);
	self.defaultPanel.info.autosetheight = false;
	self.defaultPanel.info:setMargins(5*SSRLoader.scale, 2*SSRLoader.scale, 2*SSRLoader.scale, 5*SSRLoader.scale);
	self.defaultPanel:addChild(self.defaultPanel.info);

    self.defaultPanel.events = createScrollingListBox(230*SSRLoader.scale, 50*SSRLoader.scale, 190*SSRLoader.scale, self.height - y - 100*SSRLoader.scale);
    self.defaultPanel.events.doDrawItem = drawDatas;
    self.defaultPanel.events:setOnMouseDownFunction(self, QuestDebugger.onSelectE);
	self.defaultPanel:addChild(self.defaultPanel.events);

    self.defaultPanel.deleteEvent = ISButton:new(230*SSRLoader.scale, self.defaultPanel.events.y + self.defaultPanel.events.height + 10*SSRLoader.scale, 190*SSRLoader.scale, 20*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_RemoveEvent") or "Remove Event", self, removeEvent);
	self.defaultPanel.deleteEvent:setAnchorTop(false);
	self.defaultPanel.deleteEvent:setAnchorBottom(true);
	self.defaultPanel.deleteEvent:initialise();
	self.defaultPanel.deleteEvent:instantiate();
	self.defaultPanel.deleteEvent.borderColor = {r=1, g=1, b=1, a=0.1};
	self.defaultPanel:addChild(self.defaultPanel.deleteEvent);

    self.characterPanel = createPanel(x, y, w, h);
    self:addChild(self.characterPanel);

    self.characterPanel.info = ISRichTextPanel:new(10*SSRLoader.scale, 10*SSRLoader.scale, 210*SSRLoader.scale, textHeight*4);
	self.characterPanel.info.backgroundColor.a = 0;
	self.characterPanel.info.borderColor.a = 0;
	self.characterPanel.info:setAnchorTop(false);
	self.characterPanel.info:setAnchorBottom(true);
	self.characterPanel.info.autosetheight = false;
	self.characterPanel.info:setMargins(0, 0, 0, 0);
	self.characterPanel:addChild(self.characterPanel.info);

    self.characterPanel.cb = ISTickBox:new(10*SSRLoader.scale, self.characterPanel.info.y+self.characterPanel.info.height+5*SSRLoader.scale, 210*SSRLoader.scale, 40*SSRLoader.scale, "", self, QuestDebugger.onTickCharProps);
	self.characterPanel.cb:initialise()
	self.characterPanel:addChild(self.characterPanel.cb)
	self.characterPanel.cb:addOption("Character is alive");
	self.characterPanel.cb:addOption("Character is revealed");

    self.characterPanel.stats = createScrollingListBox(230*SSRLoader.scale, 10*SSRLoader.scale, 190*SSRLoader.scale, self.height - y - 60*SSRLoader.scale);
    self.characterPanel.stats.doDrawItem = drawDatas;
	self.characterPanel:addChild(self.characterPanel.stats);

    local stat_button_y = self.characterPanel.stats.y+self.characterPanel.stats.height + 10*SSRLoader.scale;
    self.characterPanel.decreaseStat = ISButton:new(230*SSRLoader.scale, stat_button_y, 90*SSRLoader.scale, 20*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_DecreaseStat") or "Decrease", self, decreaseStat);
	self.characterPanel.decreaseStat:setAnchorTop(false);
	self.characterPanel.decreaseStat:setAnchorBottom(true);
	self.characterPanel.decreaseStat:initialise();
	self.characterPanel.decreaseStat:instantiate();
	self.characterPanel.decreaseStat.borderColor = {r=1, g=1, b=1, a=0.1};
	self.characterPanel:addChild(self.characterPanel.decreaseStat);

    self.characterPanel.increaseStat = ISButton:new(330*SSRLoader.scale, stat_button_y, 90*SSRLoader.scale, 20*SSRLoader.scale, getTextOrNull("UI_QDebugger_Button_IncreaseStat") or "Increase", self, increaseStat);
	self.characterPanel.increaseStat:setAnchorTop(false);
	self.characterPanel.increaseStat:setAnchorBottom(true);
	self.characterPanel.increaseStat:initialise();
	self.characterPanel.increaseStat:instantiate();
	self.characterPanel.increaseStat.borderColor = {r=1, g=1, b=1, a=0.1};
	self.characterPanel:addChild(self.characterPanel.increaseStat);

    -- quest panel

    self.questPanel = createPanel(x, y, w, h);
    self:addChild(self.questPanel);

    self.questPanel.info = ISRichTextPanel:new(5*SSRLoader.scale, 10*SSRLoader.scale, 335*SSRLoader.scale, self.questPanel.height - 20*SSRLoader.scale);
	self.questPanel.info:initialise();
	self.questPanel.info.backgroundColor = {r=1, g=1, b=1, a=0.01};
	self.questPanel.info.borderColor = {r=1, g=1, b=1, a=0.05};
	self.questPanel.info.autosetheight = false;
	self.questPanel:addChild(self.questPanel.info);

    self.questPanel.flags = ISTickBox:new(345*SSRLoader.scale, 10*SSRLoader.scale, 130*SSRLoader.scale, 20*SSRLoader.scale, "", self, QuestDebugger.onQuestFlagsChange);
	self.questPanel.flags:initialise()
	self.questPanel:addChild(self.questPanel.flags)
	self.questPanel.flags:addOption("Completed");
	self.questPanel.flags:addOption("Failed");
	self.questPanel.flags:addOption("Unlocked");
	self.questPanel.flags:addOption("Daily");
	self.questPanel.flags:addOption("Weekly");
	self.questPanel.flags:addOption("Event");
	self.questPanel.flags:addOption("Hidden");
    self.questPanel.flags:disableOption("Daily", true);
	self.questPanel.flags:disableOption("Weekly", true);
	self.questPanel.flags:disableOption("Event", true);
	self.questPanel.flags:disableOption("Hidden", true);

    self.taskPanel = createPanel(x, y, w, h);
    self:addChild(self.taskPanel);

    self.taskPanel.info = ISRichTextPanel:new(5*SSRLoader.scale, 10*SSRLoader.scale, 335*SSRLoader.scale, self.taskPanel.height - 20*SSRLoader.scale);
	self.taskPanel.info:initialise();
	self.taskPanel.info.backgroundColor = {r=1, g=1, b=1, a=0.01};
	self.taskPanel.info.borderColor = {r=1, g=1, b=1, a=0.05};
	self.taskPanel.info.autosetheight = false;
	self.taskPanel:addChild(self.taskPanel.info);

    self.taskPanel.flags = ISTickBox:new(345*SSRLoader.scale, 10*SSRLoader.scale, 130*SSRLoader.scale, 20*SSRLoader.scale, "", self, QuestDebugger.onTaskFlagsChange);
	self.taskPanel.flags:initialise()
	self.taskPanel:addChild(self.taskPanel.flags)
	self.taskPanel.flags:addOption("Pending");
	self.taskPanel.flags:addOption("Completed");
	self.taskPanel.flags:addOption("Unlocked");
	self.taskPanel.flags:addOption("Hidden");
	self.taskPanel.flags:disableOption("Hidden", true);

    self.actionPanel = createPanel(x, y, w, h);
    self:addChild(self.actionPanel);

    self.actionPanel.flags = ISTickBox:new(345*SSRLoader.scale, 10*SSRLoader.scale, 130*SSRLoader.scale, 20*SSRLoader.scale, "", self, QuestDebugger.onActionFlagsChange);
	self.actionPanel.flags:initialise()
	self.actionPanel:addChild(self.actionPanel.flags)
	self.actionPanel.flags:addOption("Pending");
	self.actionPanel.flags:addOption("Completed");

    self:populateList_C();
end

function QuestDebugger:new()
    local w, h = 600*SSRLoader.scale, 520*SSRLoader.scale;
    local o = ISCollapsableWindow:new((getCore():getScreenWidth() / 2) - (w / 2), (getCore():getScreenHeight() / 2) - (h / 2), w, h);
    setmetatable(o, self)
    self.__index = self
    o.player = getPlayer();
    o.playerNum = o.player:getPlayerNum();
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    o.backgroundColor = {r=0, g=0, b=0, a=0.7};
    o.greyCol = { r=0.4,g=0.4,b=0.4,a=1};
    o.anchorLeft = true;
    o.anchorRight = false;
    o.anchorTop = true;
    o.anchorBottom = false;
    o.pin = true;
    o.isCollapsed = false;
    o.collapseCounter = 0;
    o.title = getTextOrNull("UI_QDebugger_Title") or "Quest System Debugger";
    o.resizable = false;
    o.drawFrame = true;

    o.currentTile = nil;
    o.richtext = nil;
    o.overrideBPrompt = true;
    o.subFocus = nil;
    o.hotKeyPanels = {};
    o.isJoypadWindow = false;
    return o
end