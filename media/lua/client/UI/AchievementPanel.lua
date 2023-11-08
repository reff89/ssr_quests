-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Scripting/AchievementManager"

AchievementPanel = ISPanel:derive("AchievementPanel");

local label_unlocked = getTextOrNull("UI_Achievement_Unlocked") or "Achievement unlocked!"
local label_hidden = getTextOrNull("UI_Achievement_Hidden") or "%i hidden achievements remaining|Details for each achievement will be revealed once unlocked"

function AchievementPanel:show()
    self:paginate();
	self:setVisible(true);
end

function AchievementPanel:close()
	self:setVisible(false);
end

local t_index = 1;
local offset_y = 0;
function AchievementPanel:prerender()
    ISPanel.prerender(self);
    self:drawRect(10*SSRLoader.scale, 10*SSRLoader.scale, self.width - 20*SSRLoader.scale, self.height - 20*SSRLoader.scale, 0.8, 0.1, 0.1, 0.1);
    if self.achievements_size > 0 then
        local m = 5 * (self.page.index-1);
        t_index = 1;
        while t_index <= 5 do
            offset_y = 74*SSRLoader.scale * (t_index-1);
            if t_index + m <= self.achievements_size then
                if self.achievements[t_index+m][2] then
                    if AchievementManager.list[self.achievements[t_index+m][1]].texture then
                        self:drawTextureScaled(AchievementManager.list[self.achievements[t_index+m][1]].texture, 30*SSRLoader.scale, 20*SSRLoader.scale + offset_y, 64*SSRLoader.scale, 64*SSRLoader.scale, 1, 1, 1, 1);
                    else
                        self:drawTextureScaled(self.tex_unlocked, 30*SSRLoader.scale, 20*SSRLoader.scale + offset_y, 64*SSRLoader.scale, 64*SSRLoader.scale, 1, 1, 1, 1);
                    end
                else
                    self:drawTextureScaled(self.tex_locked, 30*SSRLoader.scale, 20*SSRLoader.scale + offset_y, 64*SSRLoader.scale, 64*SSRLoader.scale, 0.5, 1, 1, 1);
                end
                self:drawText(AchievementManager.list[self.achievements[t_index+m][1]].name, 104*SSRLoader.scale, 30*SSRLoader.scale + offset_y, 1.0, 1.0, 1.0, 1.0, UIFont.Medium);
                self:drawText(AchievementManager.list[self.achievements[t_index+m][1]].description, 104*SSRLoader.scale, 55*SSRLoader.scale + offset_y, 0.9, 0.9, 0.9, 1.0, UIFont.NewSmall);
            else
                if self.hidden then
                    self:drawTextureScaled(self.tex_locked, 30*SSRLoader.scale, 20*SSRLoader.scale + offset_y, 64*SSRLoader.scale, 64*SSRLoader.scale, 0.5, 1, 1, 1);
                    self:drawText(self.hidden[1], 104*SSRLoader.scale, 30*SSRLoader.scale + offset_y, 1.0, 1.0, 1.0, 1.0, UIFont.Medium);
                    self:drawText(self.hidden[2], 104*SSRLoader.scale, 55*SSRLoader.scale + offset_y, 0.9, 0.9, 0.9, 1.0, UIFont.NewSmall);
                end
                break;
            end
            t_index = t_index + 1;
        end
    elseif self.hidden then
        self:drawTextureScaled(self.tex_locked, 30*SSRLoader.scale, 20*SSRLoader.scale, 64*SSRLoader.scale, 64*SSRLoader.scale, 0.5, 1, 1, 1);
        self:drawText(self.hidden[1], 104*SSRLoader.scale, 30*SSRLoader.scale, 1.0, 1.0, 1.0, 0.5, UIFont.Medium);
        self:drawText(self.hidden[2], 104*SSRLoader.scale, 55*SSRLoader.scale, 0.9, 0.9, 0.9, 1.0, UIFont.NewSmall);
    end
    if self.b_next.enable or self.b_prev.enable then
        self:drawTextCentre(tostring(self.page.index), self.b_next.x - 20*SSRLoader.scale, self.height - 50*SSRLoader.scale, 1.0, 1.0, 1.0, 1.0, UIFont.NewSmall);
    end
end

function AchievementPanel:paginate()
    self.page.index = 1;
    self.achievements = {};
    self.achievements_size = 0;
    local hidden = 0;
    if AchievementManager.list_size > 0 then
        local id = {};
        for i=1, AchievementManager.list_size do -- формируем список id записей
            id[i] = i;
        end

        for i=1, CharacterManager.instance.achievements_size do
            for index=1, #id do
                if CharacterManager.instance.achievements[i] == AchievementManager.list[id[index]].internal then
                    self.achievements_size = self.achievements_size + 1; self.achievements[self.achievements_size] = { id[index], true };
                    table.remove(id, index);
                    break;
                end
            end
        end

        for i=1, #id do
            if AchievementManager.list[id[i]].hidden then
                hidden = hidden + 1;
            else
                self.achievements_size = self.achievements_size + 1; self.achievements[self.achievements_size] = { id[i], false };
            end
        end
        self.b_next:setEnable(self.achievements_size + (hidden > 0 and 1 or 0) > 5);
        self.b_prev:setEnable(self.page.index > 1);

        if hidden > 0 then
            self.hidden = string.format(label_hidden, hidden):ssplit("|");
            self.hidden[2] = tostring(self.hidden[2]);
        else
            self.hidden = false;
        end
    else
        self.b_next:setEnable(false);
        self.b_prev:setEnable(false);
    end
end

function AchievementPanel:createChildren()
    self.page = {}
    self.page.index = 1;
    self.page.max = 5;

    local function createButton(x, y, w, h, text, arg, onClick)
        local button = ISButton:new(x, y, w, h, text, arg, onClick);
        button:initialise();
        button.borderColor = {r=0.3, g=0.3, b=0.3, a=1};
        button.backgroundColorMouseOver = {r=1.0, g=1.0, b=0.4, a=0.5};
        button.backgroundColor = {r=1.0, g=1.0, b=0.4, a=0.0};
        button.textColor = {r=0.3, g=0.3, b=0.3, a=1};
        return button;
    end

    local function flip_page(value)
        self.page.index = self.page.index + value;
        self.b_next:setEnable(5 * self.page.index < self.achievements_size + (self.hidden == false and 0 or 1));
        self.b_prev:setEnable(self.page.index > 1);
    end

    local centre = self.x + self.width / 2;
    self.b_prev = createButton(centre - 45*SSRLoader.scale, self.height - 55*SSRLoader.scale, 25*SSRLoader.scale, 25*SSRLoader.scale, "<", -1, flip_page);
	self:addChild(self.b_prev);

    self.b_next = createButton(centre + 20*SSRLoader.scale, self.height - 55*SSRLoader.scale, 25*SSRLoader.scale, 25*SSRLoader.scale, ">", 1, flip_page);
	self:addChild(self.b_next);

    self:paginate();
end

function AchievementPanel:new(x, y)
    local o = ISPanel:new(x*SSRLoader.scale, y*SSRLoader.scale, 780*SSRLoader.scale, 450*SSRLoader.scale);
	setmetatable(o, self);
    self.__index = self;

	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=1.0};
	o.borderColor.a = 0;

    o.achievements = {};
    o.achievements_size = 0;

    o.tex_locked = getTexture("media/ui/achievement_locked.png");
    o.tex_unlocked = getTexture("media/ui/achievement_unlocked.png");

	o:setAlwaysOnTop(true);
    return o;
end




AchievementNotification = ISPanel:derive("AchievementNotification");

function AchievementNotification:initialise()
	ISPanel.initialise(self);
end

function AchievementNotification:createChildren()
    self.panel = ISRichTextPanel:new(84*SSRLoader.scale, 48*SSRLoader.scale, self.width - 84*SSRLoader.scale, self.height - 58*SSRLoader.scale);
    self.panel:initialise();
	self.panel.backgroundColor = {r=0, g=0, b=0, a=0.0};
    self.panel.borderColor = {r=0, g=0, b=0, a=0.0};
    self.panel:setMargins(0, 0, 0, 0);
	self.panel.text = " <SIZE:medium> <RGB:0.8,0.8,0.8> "..AchievementManager.list[self.achievement_id].name;
	self.panel.autosetheight = false;
	self.panel.clip = true;
    self:addChild(self.panel)
    self.panel:paginate();

	local function callback()
        self.timerStart = true;
    end

    SSRTimer.add_s(callback, 4, false)
end

function AchievementNotification:prerender()
    self:drawRect(0, 0, self.width, self.height, self.alpha, 0.2, 0.2, 0.2);
    if AchievementManager.list[self.achievement_id].texture then
        self:drawTextureScaled(AchievementManager.list[self.achievement_id].texture, 10*SSRLoader.scale, 20*SSRLoader.scale, 64*SSRLoader.scale, 64*SSRLoader.scale, self.alpha, 1, 1, 1);
    else
        self:drawTextureScaled(self.tex_unlocked, 10*SSRLoader.scale, 20*SSRLoader.scale, 64*SSRLoader.scale, 64*SSRLoader.scale, self.alpha, 1, 1, 1);
    end
    self:drawText(label_unlocked, 84*SSRLoader.scale, 22*SSRLoader.scale, 1.0, 1.0, 1.0, self.alpha, UIFont.Medium);
end

function AchievementNotification:render()
    if self.timerStart then
        if self.alpha > 0 then
            local delta = (UIManager.getMillisSinceLastRender() / 33.3) * 0.08;
            local value = self.alpha - delta;
            if value > 0 then
                self.alpha = value;
            else
                self.alpha = 0;
            end
            self.panel.contentTransparency = self.alpha;
        else
            self.done = true;
        end
	end
end

function AchievementNotification:update()
    if self.done then
        self:removeFromUIManager();
        if self.callback then
            self.callback();
        end
    end
end

function AchievementNotification:new(achievement_id, callback)
    local o = ISPanel:new(0, 0, 300*SSRLoader.scale, 100*SSRLoader.scale);
    setmetatable(o, self)
    self.__index = self

	o.achievement_id = achievement_id;

	o.x = getCore():getScreenWidth() - o.width - 10*SSRLoader.scale;
	o.y = getCore():getScreenHeight() - o.height - 10*SSRLoader.scale;

    o.anchorLeft = true;
    o.anchorRight = true;
    o.anchorTop = true;
    o.anchorBottom = true;

    o.alpha = 1;
    o.tex_unlocked = getTexture("media/ui/achievement_unlocked.png");

	o.timerStart = false;
	o.done = false;

	o.callback = callback;

    return o;
end

local last_notification = nil;
local function resetLast() last_notification = nil; end

Events.OnAchievementUnlock.Add(function (achievement_id)
    if AchievementManager.list[achievement_id] then
        local notification = AchievementNotification:new(achievement_id, resetLast);
        notification:initialise();
        if last_notification then
            last_notification.callback = function()
                notification:addToUIManager();
            end
            last_notification = notification;
        else
            notification:addToUIManager();
            last_notification = notification;
        end
    end
end)