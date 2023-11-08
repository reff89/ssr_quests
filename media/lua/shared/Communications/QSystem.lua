-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
LuaEventManager.AddEvent("OnQSystemPreInit");
LuaEventManager.AddEvent("OnQSystemInit");
LuaEventManager.AddEvent("OnQSystemStart");
LuaEventManager.AddEvent("OnQSystemPostStart");
LuaEventManager.AddEvent("OnQSystemUpdate");
LuaEventManager.AddEvent("OnQSystemReset");
LuaEventManager.AddEvent("OnQSystemRestart");
LuaEventManager.AddEvent("OnEventStateChanged");
LuaEventManager.AddEvent("OnScriptExit");
LuaEventManager.AddEvent("OnAchievementUnlock");

QSystem = {}
QSystem.initialised = false;
QSystem.network = isClient() or false;
local npc_plugin = nil;
local jm_required = 1.00;

QSystem.init = function()
	if isServer() then
		if JM.require(jm_required) then
			print("[QSystem] Initializing...");
			QImport.calculateChecksums();
			if npc_plugin then
				print("[QSystem] NPC Plugin - "..tostring(npc_plugin));
			else
				print("[QSystem] NPC Plugin not selected.");
			end
			QSystem.initialised = true;
			print("[QSystem] Service initialized!");
		else
			print(string.format("[QSystem] SSROveride v%.2f or newer is required.", jm_required));
		end
	else
		NotificationManager.init();
		local init_start = getTimeInMillis();
		local function callback()
			print("[QSystem] Import took "..tostring(getTimeInMillis() - init_start).." ms")
			if not QSystem.initialised then
				if npc_plugin then
					print("[QSystem] NPC Plugin - "..tostring(npc_plugin));
				else
					print("[QSystem] NPC Plugin not selected.");
				end
				if QSystem.network then
					print("[QSystem] Multiplayer mode");
					local player = getPlayer();
					if player then
						local steamid = getCurrentUserSteamID() or player:getUsername();
						local timestamp = getTimestamp();
						sendClientCommand(player, 'QSystem', 'init', {steamid, timestamp});
					else
						print("[QSystem] Service failed to initialize!");
					end
				else
					print("[QSystem] Singleplayer mode");
					local file = tostring(getWorld():getWorld());
					local data = SaveManager.readData(file);
					QSystem.load(data);
				end
			end
		end
		QImport.init(callback); -- loads quests into script manager
	end
end

QSystem.pause = function ()
	QuestManager.pause = true;
	CharacterManager.pause = true;
end

QSystem.resume = function ()
	QuestManager.pause = false;
	CharacterManager.pause = false;
end

--- NPC Plugin ---

QSystem.validate = function(plugin_id)
	if npc_plugin then
		return npc_plugin == plugin_id;
	else
		npc_plugin = plugin_id;
		return true;
	end
end

--- COMMUNICATIONS ---

-- Client-side --

QSystem.OnServerCommand = function(module, command, args)
	if command == 'init' and not QSystem.initialised then
		print("[QSystem] Processing data received from server!");
		if type(args[2]) == "number" then SSRLoader.timezone = args[2]; end
		QSystem.load(args[1]);
	elseif command == 'callback' then
		print("[QSystem] Received callback after request. ID - "..tostring(args[1]));
		SyncClient.callback(args[1]);
	end
end

local last_update;
QSystem.update = function ()
	if SaveManager.enabled and last_update then
		local ts = getTimestamp();
		if math.abs(ts - last_update) > 600 then
			QSystem.pause(); SaveManager.enabled = false;
			sendClientCommand(getPlayer(), 'QSystem', 'kick', {0, ts, last_update});
		else
			last_update = ts;
		end
	end
end

QSystem.load = function(args)
	local serpent = require("serpent") -- lua table serialization
	local has_data = false;
	for i=1, #SaveManager.dataType do
		if args[i] then
			args[i] = serpent.load(args[i]);
			has_data = true;
		end
	end
	if has_data then -- have save data
		if pcall(SaveManager.load, args) then
			print("[QSystem] SaveManager: Data loaded successfully!")
		else
			print("[QSystem] (Error) SaveManager: Unable to load data!")
			QuestLogger.error = true;
			return;
		end

		-- HUD state restore
		local currentQuestName = getPlayer():getModData().ActiveQuestName;

		if currentQuestName ~= nil then
			local currentQuest = QuestManager.instance:getQuest(currentQuestName);
			if currentQuest then
				QTracker.track(currentQuest, false);
			end
		end
	else -- no save data
		if #QuestManager.instance.quests > 0 then
			local active_quest = QuestManager.instance:getActiveQuest();
			if active_quest then
				local function callback()
					QTracker.track(active_quest, true);
				end
				NotificationManager.add(callback, "questUnlocked", true);
			end
		end
	end
	if isClient() then
		local crc = ScriptManagerNeo.getChecksums();
		local language = tostring(Translator.getLanguage());
		sendClientCommand(getPlayer(), 'QSystem', 'verify', {crc, language});

		local accessLevel = getAccessLevel();
		if accessLevel == "" or accessLevel == "None" then
			last_update = getTimestamp();
			SSRTimer.add_m(QSystem.update, 1, true);
		end
	end
	triggerEvent("OnQSystemStart", nil);
	QSystem.initialised = true;
	print("[QSystem] Service initialized!")
	triggerEvent("OnQSystemUpdate", 4);
	SaveManager.save();
	Events.OnTick.Add(QuestManager.onTick);
	SSRTimer.add_s(CharacterManager.update, 5, true);
	QSystem.resume();
	triggerEvent("OnQSystemPostStart", nil);
end

--- Server-side ---

QSystem.OnClientCommand = function(module, command, player, args)
	local username = player:getUsername();
	if QSystem.initialised then
		if command == 'init' then
			local client_time = args[2] or 0;
			local server_time = getTimestamp();
			if math.abs(server_time - client_time) > 600 then
				print("[QSystem] Player '"..tostring(username).."' kicked from server for having incorrect date and time! (Client="..tostring(client_time).."; Server="..tostring(server_time)..")");
				jm_kick(username, "UI_QSystem_Violation3");
			else
				print("[QSystem] Sending data to client '"..tostring(username).."'...");
				local data = { SaveManager.readData(args[1]), SSRLoader.timezone };
				sendServerCommand(player, 'QSystem', 'init', data); -- отправляем данные игроку
			end
		elseif command == 'saveData' then
			if args[3] then
				local accessLevel = player:getAccessLevel();
				if accessLevel == "None" then
					print("[QSystem] Unauthorized attempt to upload progress using QDebugger from client '"..tostring(username).."'");
					jm_kick(username, "UI_QSystem_Violation2");
					return;
				else
					print("[QSystem] Client '"..tostring(username).."' uploaded progress using QDebugger");
				end
			else
				print("[QSystem] Saving progress for client '"..tostring(username).."'...");
			end
			SaveManager.writeData(args[1], args[2]);
		elseif command == "log" then
			if args[1] == 0 then
				print("[QSystem] Received EXP request from client '"..tostring(username).."'. Info: "..tostring(args[2]));
			elseif args[1] == 1 then
				print("[QSystem] Received trait request from client '"..tostring(username).."'. Info: "..tostring(args[2]));
			end
		elseif command == "kick" then
			if args[1] == 0 then
				print("[QSystem] Player '"..tostring(username).."' kicked from server for having incorrect date and time! (Last="..tostring(args[2]).."; BeforeLast="..tostring(args[3])..")");
				jm_kick(username, "UI_QSystem_Violation3");
			end
		elseif command == 'requestItem' then
			if type(args[2]) == 'table' then
				print("[QSystem] Received item request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				if QItemFactory.grant(username, args[2]) then
					if #args == 3 then
						sendServerCommand(player, 'QSystem', 'callback', {args[3]});
					end
				end
			end
		elseif command == 'createHorde' then
			if type(args[2]) == 'table' then
				print("[QSystem] Received zombie spawn request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				if QZombieFactory.createHorde(args[2][1], args[2][2], args[2][3], args[2][4], args[2][5], args[2][6]) then
					if #args == 3 then
						sendServerCommand(player, 'QSystem', 'callback', {args[3]});
					end
				else
					print("[QSystem] Can't proceed zombie spawn request from client '"..tostring(username).."'. Reason: requested more than 20 zombies. Info: "..tostring(args[1]));
				end
			end
		elseif command == 'removeZombies' then
			if type(args[2]) == 'table' then
				print("[QSystem] Received zombie despawn request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				if QZombieFactory.removeZombies(args[2][1], args[2][2], args[2][3], args[2][4], args[2][5], args[2][6]) then
					if #args == 3 then
						sendServerCommand(player, 'QSystem', 'callback', {args[3]});
					end
				else
					print("[QSystem] Can't proceed zombie despawn request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				end
			end
		elseif command == 'teleport' then
			if type(args[2]) == 'table' then
				print("[QSystem] Received teleport request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				if Kamisama.teleport(username, args[2][1], args[2][2], args[2][3]) then
					if #args == 3 then
						sendServerCommand(player, 'QSystem', 'callback', {args[3]});
					end
				else
					print("[QSystem] Can't proceed teleport request from client '"..tostring(username).."'. Info: "..tostring(args[1]));
				end
			end
		elseif command == 'verify' then
			local accessLevel = player:getAccessLevel();
			print("[QSystem] Received checksums from client '"..tostring(username).."'");
			if accessLevel == "None" then
				local checksums = args[1];
				local language = args[2];
				local entry_id = nil;
				if type(checksums) == 'table' then
					for i=1, #QImport.checksums do
						if QImport.checksums[i].language == language then
							entry_id = i;
							break;
						end
					end
					if entry_id then
						if #checksums == #QImport.checksums[entry_id].hash then
							for i=1, #QImport.checksums[entry_id].hash do
								if checksums[i] ~= QImport.checksums[entry_id].hash[i] then
									print("[QSystem] Player '"..tostring(username).."' kicked from server for checksum mismatch!");
									jm_kick(username, "UI_GameLoad_KickChecksum");
									return;
								end
							end
							print("[QSystem] Checksums match. All good!");
							return;
						end
					end
				end
				print("[QSystem] Player '"..tostring(username).."' kicked from server for file count mismatch!");
				jm_kick(username, "UI_GameLoad_KickChecksum");
			else
				print("[QSystem] Access level: "..accessLevel..". All good!");
			end
		end
	else
		print("[QSystem] Ignored '"..tostring(command).."' command from client '"..tostring(username).."' due to mod not being initialized.");
	end
end