-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "OptionScreens/MainScreen"
require "Communications/QSystem"

local MainScreen_instantiate = MainScreen.instantiate;
function MainScreen:instantiate()
    MainScreen_instantiate(self);
    if self.inGame and self.modListDetail then
        local info = "SSR: Quest System";
        local translator = getTextOrNull("UI_QSystem_Translator");
        if translator and translator ~= "" then
            info = string.format("%s (%s TL by %s)", info, tostring(Translator.getLanguage()), translator);
        end
        self.questSystemInfo = ISLabel:new(-12*SSRLoader.scale, 1*SSRLoader.scale, getTextManager():getFontHeight(UIFont.Small), info, 1, 1, 1, 0.7, UIFont.Small);
        self.questSystemInfo:initialise();
        self.modListDetail:addChild(self.questSystemInfo);
    end
end

local function getDayOfWeek(i)
    if i == 1 then
        return "Monday";
    elseif i == 2 then
        return "Tuesday";
    elseif i == 3 then
        return "Wednesday";
    elseif i == 4 then
        return "Thursday";
    elseif i == 5 then
        return "Friday";
    elseif i == 6 then
        return "Saturday";
    elseif i == 0 then
        return "Sunday";
    else
        return "N/A";
    end
end

function DrawQSystemDebugInfo()
    local player = getPlayer();
    if player then
        local text = string.format("SSR: Quest System\r\nX=%i Y=%i Z=%i\r\n", math.floor(player:getX()), math.floor(player:getY()),  math.floor(player:getZ()));
        local time = GetCurrentTime();
        if time then
            text = text..string.format("%04d-%02d-%02d %02d:%02d:%02d\r\n%s\r\n", time.tm_year, time.tm_mon, time.tm_mday, time.tm_hour, time.tm_min, time.tm_sec, getDayOfWeek(time.tm_wday));
        end
        local area = QuestArea.current();
        if area then
            local bgm = QuestArea.isPlayingMusic();
            if bgm then
                if bgm == "m" then
                    text = text..string.format("QuestArea='%s'\r\nBGM=none\r\n", area);
                else
                    text = text..string.format("QuestArea='%s'\r\nBGM='%s'\r\n", area, bgm);
                end
            else
                text = text..string.format("QuestArea='%s'\r\n", area);
            end
        end
        local square = player:getSquare();
        if square then
            local obj = square:getObjects();
            if obj then
                local containers = {};
                for i = 0, obj:size()-1 do
                    local o = obj:get(i);
                    local container = o:getContainer();
                    if container then
                        containers[#containers+1] = "container="..tostring(container:getType());
                    end
                end
                if #containers > 0 then
                    text = text..table.concat(containers, "\r\n");
                end
            end
        end
        getTextManager():DrawString(UIFont.NewSmall, 90, 5*SSRLoader.scale, text, 1.0, 1.0, 1.0, 1.0);
    end
end

function DrawQSystemErrorMsg()
    if QuestLogger.error then
        getTextManager():DrawString(UIFont.NewSmall, 10, getCore():getScreenHeight() - 35*SSRLoader.scale, "One or multiple lua scripts in your quest pack(s) were loaded with errors.", 1.0, 0.0, 0.0, 1.0);
        getTextManager():DrawString(UIFont.NewSmall, 10, getCore():getScreenHeight() - 20*SSRLoader.scale, "Please check the logs to identify the issue, and once you have made the necessary fixes, restart the game.", 1.0, 0.0, 0.0, 1.0);
    end
end

Events.OnQSystemPostStart.Add(function ()
    if QuestLogger.error == false then
        Events.OnPostUIDraw.Remove(DrawQSystemErrorMsg);
    end
end)

Events.OnQSystemInit.Add(function ()
    Events.OnPostUIDraw.Add(DrawQSystemErrorMsg);
    if isClient() then
        local accessLevel = getAccessLevel();
        if accessLevel and accessLevel ~= "" and accessLevel ~= "None" then
            Events.OnPreUIDraw.Add(DrawQSystemDebugInfo);
        end
    elseif isDebugEnabled() then
        Events.OnPreUIDraw.Add(DrawQSystemDebugInfo);
    end
end)