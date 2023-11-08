-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Communications/QSystem"

QTracker = {};
local label_wait = getTextOrNull("UI_QTracker_Wait") or "Wait";
local label_multiple = getTextOrNull("UI_QTracker_Multiple") or "Multiple tasks";

QTracker.ActiveQuest = nil;
QTracker.ActiveTask = nil;

QTracker.offset = 0;

local min_width = 180 * SSRLoader.scale;

local quest_title = nil;
local quest_width = 0;
local task_title = nil;
local task_lines = nil;

local T_MANAGER = getTextManager();

QTracker.update = function()
	if QTracker.ActiveQuest then
		if quest_title then -- quest name render
			local title_x = (math.floor(getCore():getScreenWidth()) - 190 - QTracker.offset);
			T_MANAGER:DrawString(UIFont.Medium, title_x + (QTracker.offset / 2) - (quest_width / 2), 5*SSRLoader.scale, quest_title, 1, 1, 1, 1);

			if QTracker.ActiveTask then -- task name render
				local task_name = QTracker.ActiveTask:getName()..QTracker.ActiveTask:getDetails();
				if QTracker.ActiveTask.pending then
					task_name = label_wait;
				else
					local active_tasks = 0;
					for i=1, QTracker.ActiveQuest.active_size do
						if not QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].hidden then
							active_tasks = active_tasks + 1;
							if active_tasks > 1 then
								task_name = label_multiple;
								break;
							end
						end
					end
				end
				if task_title ~= task_name then -- word wrap again if task_name changed
					task_title = task_name;
					task_lines = nil;
				end
				local task_width = T_MANAGER:MeasureStringX(UIFont.NewSmall, task_name);
				if task_width > QTracker.offset then -- if task name is too long, word wrap
					if task_lines then
						for i=1, #task_lines do
							local task_x = title_x + (QTracker.offset / 2) - (T_MANAGER:MeasureStringX(UIFont.NewSmall, task_lines[i]) / 2);
							T_MANAGER:DrawString(UIFont.NewSmall, task_x, (25 + ((i-1) * 15))*SSRLoader.scale, task_lines[i], 1, 1, 1, 1);
						end
					else
						local words = task_name:ssplit(" ");
						task_lines = { "" };
						local n = 1;
						for i=1, #words do
							local line = task_lines[n].." "..words[i];
							if T_MANAGER:MeasureStringX(UIFont.NewSmall, task_lines[n]) > QTracker.offset then
								n = n + 1;
								task_lines[n] = words[i];
							else
								task_lines[n] = line;
							end
						end
					end
				else -- if not, render as is
					local task_x = title_x + (QTracker.offset / 2) - (T_MANAGER:MeasureStringX(UIFont.NewSmall, task_name) / 2);
					T_MANAGER:DrawString(UIFont.NewSmall, task_x, 25*SSRLoader.scale, task_name, 1, 1, 1, 1);
				end

				if QTracker.ActiveTask.completed or not QTracker.ActiveTask.unlocked then -- reset active task if completed or locked
					QTracker.ActiveTask = nil;
				end
			else -- automatically select new active task
				for i=1, #QTracker.ActiveQuest.tasks do
					if not QTracker.ActiveQuest.tasks[i].completed and QTracker.ActiveQuest.tasks[i].unlocked and not QTracker.ActiveQuest.tasks[i].hidden then
						QTracker.ActiveTask = QTracker.ActiveQuest.tasks[i];
						task_lines = nil; -- and update text
						break;
					end
				end
			end
		else -- calculate offsets
			quest_title = QTracker.ActiveQuest:getName();
			quest_width = T_MANAGER:MeasureStringX(UIFont.Medium, quest_title)
			if quest_width < min_width then
				QTracker.offset = min_width;
			else
				QTracker.offset = quest_width;
			end
		end

		if QTracker.ActiveQuest.completed or QTracker.ActiveQuest.failed or QTracker.ActiveQuest.hidden or not QTracker.ActiveQuest.unlocked then -- reset active quest if completed, failed or locked
			QTracker.ActiveQuest = nil;
		end
	end
end

QTracker.track = function (quest, notify)
	if QTracker.ActiveQuest == quest then return end
	QTracker.clear();
	if quest.unlocked and not quest.hidden and not quest.failed and not quest.completed then
		QTracker.ActiveQuest = quest;
		local player = getPlayer()
		player:getModData().ActiveQuestName = QTracker.ActiveQuest.internal;

		if notify then
			QuestButton.read = false;
		end
	end
end

QTracker.clear = function()
	local player = getPlayer();
	if player:getModData().ActiveQuestName then
		player:getModData().ActiveQuestName = nil;
	end
	QTracker.ActiveQuest = nil;
	quest_title = nil;
	QTracker.ActiveTask = nil;
end

Events.OnQSystemStart.Add(function() Events.OnPreUIDraw.Add(QTracker.update); end)

QTracker.onResolutionChange = function()
	quest_title = nil;
	task_lines = nil;
end

Events.OnResolutionChange.Add(QTracker.onResolutionChange);