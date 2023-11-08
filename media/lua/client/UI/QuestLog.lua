-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Communications/QSystem"

QuestLog = ISPanel:derive("QuestLog");
QuestLog.notes = {};
QuestLog.notes_size = 0;

local function format(text)
    text = string.replace(text, "\\n", " <LINE> ");

    local strings = {};
    local p = 1;
    while string.len(text) > 0 do
        local tag_start = string.find(text, "${", 1, true);
        local tag_end = string.find(text, "}", 1, true);
        if tag_start and tag_end then
            strings[p] = string.sub(text, 1, tag_start-1);
            p = p + 1;
            text = string.sub(text, tag_start);
            tag_end = tag_end - tag_start;
            tag_start = 3;
            local another_tag = string.find(text, "${", 2, true);
            if another_tag and another_tag < tag_end then
                strings[p] = string.sub(text, 1, another_tag-1);
                text = string.sub(text, another_tag);
            else
                local tag = string.sub(text, tag_start, tag_end);
                local result = GetTextByTag(tag:ssplit(','));
                if result then
                    strings[p] = result;
                else
                    strings[p] = string.sub(text, 1, tag_end+1);
                end
                text = string.sub(text, tag_end+2);
            end
            p = p + 1;
        else
            strings[p] = text;
            break;
        end
    end

    return table.concat(strings);
end

function QuestLog:initialise()
    ISPanel.initialise(self);
end

function QuestLog:show()
    self:populateList();
    self:setVisible(true);
end

function QuestLog:prerender()
    ISPanel.prerender(self);
    self:drawRect(305*SSRLoader.scale, 10*SSRLoader.scale, 465*SSRLoader.scale, 430*SSRLoader.scale, 0.8, 0.1, 0.1, 0.1);
    self:drawRectBorder(305*SSRLoader.scale, 10*SSRLoader.scale, 465*SSRLoader.scale, 430*SSRLoader.scale, 0.2, 0.0, 0.0, 0.0);
    self:drawTextureScaled(self.texture, 310*SSRLoader.scale, 15*SSRLoader.scale, 455*SSRLoader.scale, 420*SSRLoader.scale, 1, 1, 1, 1);
    self:drawRectBorder(305*SSRLoader.scale, 380*SSRLoader.scale, 465*SSRLoader.scale, 60*SSRLoader.scale, 0.2, 0.0, 0.0, 0.0);
    if self.b_next.enable or self.b_prev.enable then
        self:drawTextCentre(tostring(self.page.index), self.b_next.x - 20*SSRLoader.scale, self.height - 50*SSRLoader.scale, 0.5, 0.4, 0.4, 1.0, UIFont.NewSmall);
    end
end

function QuestLog:update()

end

function QuestLog:drawDatas(y, item, alt)
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

function QuestLog:onSelect(note_id, n)
    self.page.index = n or 1;
    if note_id then
        local lines = {};
        local line_count = 0;
        for i=#self.notes[note_id].lines, 1, -1 do -- формируем список id записей (порядок инвертирован)
            lines[#lines+1] = i;
        end

        local next_button = false;
        self.page.text = " <RGB:0.4,0.3,0.3> <SIZE:medium> "..tostring(self.notes[note_id].title).." <RGB:0.0,0.0,0.0> <SIZE:small> <LINE> <LINE> ";
        for flag_id=(CharacterManager.instance.flags_size > 0 and 1 or 0), CharacterManager.instance.flags_size do -- в порядке разблокировки флагов
            for line_id=#lines, 1, -1 do -- проверяем какие строки можно вывести с текущим набором (от 1 до flag_id)
                local unlocked = 0;
                if self.notes[note_id].lines[lines[line_id]].flags_size ~= 0 then
                    for i=1, self.notes[note_id].lines[lines[line_id]].flags_size do
                        for j=tonumber(flag_id), 1, -1 do
                            if self.notes[note_id].lines[lines[line_id]].flags[i] == CharacterManager.instance.flags[j] then
                                unlocked = unlocked+1;
                                break;
                            end
                        end

                        if unlocked < i then
                            break;
                        end
                    end
                end

                if unlocked >= self.notes[note_id].lines[lines[line_id]].flags_size then -- если строка проходит по требованиям, мы исключаем её из списка для проверки
                    if line_count < 5*(self.page.index) then
                        local page_start = 5*(self.page.index-1);
                        if line_count == page_start then
                            self.page.text = self.page.text..format(self.notes[note_id].lines[lines[line_id]].text);
                        elseif line_count > page_start then
                            self.page.text = self.page.text.." <LINE>  <LINE> "..format(self.notes[note_id].lines[lines[line_id]].text);
                        end
                        table.remove(lines, line_id);
                        line_count = line_count + 1;
                    else
                        next_button = true;
                        break;
                    end
                end
            end
        end
        self.b_next:setEnable(next_button);
        self.b_prev:setEnable(self.page.index > 1);
    else
        self.page.text = "";
        self.b_next:setEnable(false);
        self.b_prev:setEnable(false);
    end
    self.page:paginate();
end

function QuestLog:populateList()
    self.list:clear();
    for note_id=1, self.notes_size do
        local unlocked = false;
        for line_id=1, self.notes[note_id].lines_size do
            if self.notes[note_id].lines[line_id].flags_size == 0 then
                unlocked = true;
            else
                for flag_id=1, self.notes[note_id].lines[line_id].flags_size do
                    if CharacterManager.instance:isFlag(self.notes[note_id].lines[line_id].flags[flag_id]) then
                        unlocked = true;
                    else
                        unlocked = false;
                        break;
                    end
                end
            end

            if unlocked then
                self.list:addItem(self.notes[note_id].title, note_id);
                break;
            end
        end
    end
    local note_id;
    if self.list.items[1] then note_id = self.list.items[self.list.selected].item; end
    self:onSelect(note_id, 1);
end

function QuestLog:createChildren()
    self.list = ISScrollingListBox:new(10*SSRLoader.scale, 10*SSRLoader.scale, 285*SSRLoader.scale, self.height - 20*SSRLoader.scale);
    self.list:initialise();
    self.list:instantiate();
    self.list.itemheight = 22*SSRLoader.scale;
    self.list.selected = 1;
    self.list.joypadParent = self;
    self.list.font = UIFont.NewSmall;
    self.list.drawBorder = false;
	self.list.borderColor = {r=0, g=0, b=0, a=0.2};
	self.list.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8};
    self.list.doDrawItem = self.drawDatas;
	self.list:setOnMouseDownFunction(self, self.onSelect);
	self:addChild(self.list);

    self.page = ISRichTextPanel:new(self.list.width + 20*SSRLoader.scale, 10*SSRLoader.scale, self.width - self.list.width - 30*SSRLoader.scale, self.list.height - 60*SSRLoader.scale);
	self.page.backgroundColor.a = 0;
	self.page.borderColor.a = 0;
	self.page:setAnchorTop(false);
	self.page:setAnchorBottom(true);
	self.page.autosetheight = false;
	self.page:setMargins(10*SSRLoader.scale, 10*SSRLoader.scale, 10*SSRLoader.scale, 5*SSRLoader.scale);
    self.page.clip = true;
	self:addChild(self.page);
    self.page:addScrollBars();
    self.page.vscroll:setX(self.page.vscroll.x + 10*SSRLoader.scale);
    self.page.index = 1;

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
        local note_id;
        if self.list.items[1] then note_id = self.list.items[self.list.selected].item; end
        self:onSelect(note_id, self.page.index + value);
    end

    local centre = self.page.x + self.page.width / 2;
    self.b_prev = createButton(centre - 45*SSRLoader.scale, self.height - 55*SSRLoader.scale, 25*SSRLoader.scale, 25*SSRLoader.scale, "<", -1, flip_page);
	self:addChild(self.b_prev);

    self.b_next = createButton(centre + 20*SSRLoader.scale, self.height - 55*SSRLoader.scale, 25*SSRLoader.scale, 25*SSRLoader.scale, ">", 1, flip_page);
	self:addChild(self.b_next);

    self:populateList();
end

function QuestLog:close()
    self:setVisible(false);
end

function QuestLog:new(x, y)
    local o = ISPanel:new(x*SSRLoader.scale, y*SSRLoader.scale, 780*SSRLoader.scale, 450*SSRLoader.scale);
    setmetatable(o, self)
    self.__index = self
    --o.noBackground = true;
    o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=1};
    o.borderColor.a = 0;

    o.texture = getTexture("media/ui/questLog_b.png")

    return o
end

function QuestLog.import()
    QuestLog.notes = {};
    QuestLog.notes_size = 0;
    local language = tostring(QImport.language);
    local list = getActivatedMods();
	for mod_id=0, list:size()-1 do
		local mod = tostring(list:get(mod_id));
        if language and not isServer() then
            local reader = getModFileReader(mod, "media/data/"..language.."/questlog.txt", false);
            if not reader then
                reader = getModFileReader(mod, "media/data/default/questlog.txt", false);
            end

            if reader then
                print("[QSystem] QuestLog: Found 'questlog.txt' in the directory of mod '"..mod.."'. Language: "..language)
                local line = reader:readLine();

                if line then
                    local entry = nil;
                    local i = 1;
                    while line ~= nil do
                        line = line:trim()
                        if line:starts_with("#entry ") then
                            if entry then
                                QuestLog.notes_size = QuestLog.notes_size + 1; QuestLog.notes[QuestLog.notes_size] = entry;
                            end
                            entry = {};
                            entry.title = string.sub(line, 8):trim();
                            entry.lines = {};
                            entry.lines_size = 0;
                        elseif line:starts_with("#line ") and entry then
                            local args = string.sub(line, 7):trim():ssplit("|")
                            if #args == 2 then
                                entry.lines_size = entry.lines_size + 1;
                                if args[1]:trim() == "" then
                                    entry.lines[entry.lines_size] = {flags = {},flags_size = 0,text = tostring(args[2])};
                                else
                                    local flags = args[1]:ssplit(',');
                                    entry.lines[entry.lines_size] = {flags = flags,flags_size = #flags,text = tostring(args[2])};
                                end
                            elseif #args == 1 then
                                entry.lines_size = entry.lines_size + 1; entry.lines[entry.lines_size] = {flags = {},flags_size = 0,text = tostring(args[1])};
                            end
                        end

                        line = reader:readLine();
                        i = i + 1;
                    end
                    if entry then
                        if entry.lines[1] then
                            QuestLog.notes_size = QuestLog.notes_size + 1; QuestLog.notes[QuestLog.notes_size] = entry;
                        end
                    end
                end
                reader:close();
            end
        end
    end
end

Events.OnQSystemInit.Add(QuestLog.import);
Events.OnQSystemRestart.Add(QuestLog.import);