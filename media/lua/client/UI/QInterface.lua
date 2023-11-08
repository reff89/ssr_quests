-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISCollapsableWindow"
require "Communications/QSystem"

QInterface = ISCollapsableWindow:derive("QuestPanel");
QInterface.instance = nil;

function QInterface:show(tab)
    if self:isVisible() then
        self:setVisible(false);
    else
        self:setVisible(true);
        if type(tab) == "number" then
            if tab > 0 and tab <= self.tabs_size then
                return self:OnTabSelect({internal = tab});
            end
        end
        self.panel[self.tabs.selected]:show();
    end
end

function QInterface:OnTabSelect(button)
    if self.tabs.selected ~= button.internal then
        self.tabs.items[self.tabs.selected].backgroundColor = {r=0.1, g=0.1, b=0.1, a=1.0};
        self.tabs.items[self.tabs.selected].textColor.a = 0.7;
        self.panel[self.tabs.selected]:setVisible(false);
        self.tabs.selected = button.internal;
    end
    self.tabs.items[self.tabs.selected].textColor.a = 1;
    self.tabs.items[self.tabs.selected].backgroundColor = {r=0.2, g=0.2, b=0.2, a=1.0};
    self.panel[self.tabs.selected]:show();
end

function QInterface:realign()
    local max_width = 200*SSRLoader.scale;
    local i, w = 1, 0;
    while i <= self.tabs_size do
        local _w = getTextManager():MeasureStringX(UIFont.Medium, self.tabs.items[i].title) + 20*SSRLoader.scale;
        if _w > w then
            w = _w > max_width and max_width or _w;
        end
        i = i + 1;
    end
    w = w + (self.width - 30 * (self.tabs_size+1) - w * self.tabs_size) / self.tabs_size;
    if w > max_width then w = max_width; end
    i = 1;
    while i <= self.tabs_size do
        self.tabs.items[i]:setWidth(w);
        local x = (self.width / self.tabs_size) * i - ((self.width / self.tabs_size) / 2) - (w / 2);
        if self.tabs_size % 2 ~= 0 then
            local middle = math.ceil(self.tabs_size / 2);
            local offset = ((self.width / self.tabs_size) - ((self.width / self.tabs_size) / 2) - (w / 2)) / 2;
            if i < middle then
                x = x + offset;
            elseif i > middle then
                x = x - offset;
            end
        end
        self.tabs.items[i]:setX(x);
        i = i + 1;
    end
end

function QInterface:createChildren()
    ISCollapsableWindow.createChildren(self);

    local function createTab(i, count, text, selected)
        local w = 200*SSRLoader.scale;
        local x = (self.width / count) * i - ((self.width / count) / 2) - (w / 2);
        if count % 2 ~= 0 then
            local middle = math.ceil(count / 2);
            local offset = ((self.width / count) - ((self.width / count) / 2) - (w / 2)) / 2;
            if i < middle then
                x = x + offset;
            elseif i > middle then
                x = x - offset;
            end
        end
        local button = ISButton:new(x, math.ceil(24 * SSRLoader.scale), w, math.ceil(26 * SSRLoader.scale), text, self, QInterface.OnTabSelect);
        button:initialise();
        if selected then
            button.textColor.a = 1;
            button.backgroundColor = {r=0.2, g=0.2, b=0.2, a=1.0};
        else
            button.backgroundColor = {r=0.1, g=0.1, b=0.1, a=1.0};
            button.textColor.a = 0.7;
        end
        button.borderColor.a = 0;
        button.internal = i;
        button.font = UIFont.Medium;
        self:addChild(button);
        return button;
    end

    self.tabs_size = 3;
    local achievements = false;
    if AchievementManager.list_size > 0 then
        achievements = true;
        self.tabs_size = self.tabs_size + 1;
    end
    self.tabs.items[1] = createTab(1, self.tabs_size, getTextOrNull("UI_QSystem_Panel_Quests") or "Quests", true);
    self.tabs.items[2] = createTab(2, self.tabs_size, getTextOrNull("UI_QSystem_Panel_Characters") or "Characters", false);
    self.tabs.items[3] = createTab(3, self.tabs_size, getTextOrNull("UI_QSystem_Panel_Journal") or "Journal", false);
    if achievements then self.tabs.items[4] = createTab(4, self.tabs_size, getTextOrNull("UI_QSystem_Panel_Achievements") or "Achievements", false); end
    self.tabs.selected = 1;

    self.panel = {};
    self.panel[1] = QuestPanel:new(0, 50);
    self.panel[1]:initialise();
    self.panel[1]:setVisible(true);
    self:addChild(self.panel[1]);

    self.panel[2] = CharacterPanel:new(0, 50);
    self.panel[2]:initialise();
    self.panel[2]:setVisible(false);
    self:addChild(self.panel[2]);

    self.panel[3] = QuestLog:new(0, 50);
    self.panel[3]:initialise();
    self.panel[3]:setVisible(false);
    self:addChild(self.panel[3]);

    if achievements then
        self.panel[4] = AchievementPanel:new(0, 50);
        self.panel[4]:initialise();
        self.panel[4]:setVisible(false);
        self:addChild(self.panel[4]);
    end
    self:realign();
end

function QInterface:isTab(id)
    if self:isVisible() then
        if self.tabs.selected == id then
            return true;
        end
    end
    return false;
end

function QInterface:new()
    local width = 780 * SSRLoader.scale;
	local height = 500 * SSRLoader.scale;
	local x, y = (getCore():getScreenWidth() / 2) - (width / 2), (getCore():getScreenHeight() / 2) - (height / 2);
    local o = ISCollapsableWindow:new(x, y, width, height);
    setmetatable(o, self)
    self.__index = self
    o.player = getPlayer();
    o.playerNum = o.player:getPlayerNum();
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1.0};
    o.backgroundColor = {r=0, g=0, b=0, a=1.0};
    o.greyCol = { r=0.4,g=0.4,b=0.4,a=1};
    o.anchorLeft = true;
    o.anchorRight = false;
    o.anchorTop = true;
    o.anchorBottom = false;
    o.pin = true;
    o.isCollapsed = false;
    o.collapseCounter = 0;
    o.title = "";
    o.resizable = false;
    o.drawFrame = true;

    o.tabs = {};
    o.tabs.items = {};
    o.tabs_size = 0;

    o.currentTile = nil;
    o.richtext = nil;
    o.overrideBPrompt = true;
    o.subFocus = nil;
    o.hotKeyPanels = {};
    o.isJoypadWindow = false;
    return o
end

function QInterface.OnQSystemUpdate(code) -- 0 (character data), 1 (quest data), 2 (task data), 3 (action data), 4 (forced update)
	if QInterface.instance then
        if QInterface.instance:isVisible() then
            if QInterface.instance.tabs.selected == 1 then -- Quests
                if code == 1 or code == 4 then
                    QInterface.instance.panel[1]:populateList();
                elseif code == 2 then
                    QInterface.instance.panel[1]:showTasks();
                end
            elseif QInterface.instance.tabs.selected == 2 then -- Characters
                if code == 0 or code == 4 then
                    if code == 4 then
                        QInterface.instance.panel[2]:populateList();
                    end
                    if QInterface.instance.panel[2].charList:size() > 0 then
                        QInterface.instance.panel[2]:onSelect(QInterface.instance.panel[2].charList.items[QInterface.instance.panel[2].charList.selected].item)
                    else
                        QInterface.instance.panel[2]:clear();
                    end
                end
            elseif QInterface.instance.tabs.selected == 3 then -- Journal
                if code == 0 or code == 4 then
                    QInterface.instance.panel[3]:populateList();
                end
            elseif QInterface.instance.tabs.selected == 4 then -- Achievements
                if AchievementManager.list_size > 0 then
                    if code == 0 or code == 4 then
                        QInterface.instance.panel[4]:paginate();
                    end
                end
            end
        end
	end
end

Events.OnQSystemUpdate.Add(QInterface.OnQSystemUpdate);