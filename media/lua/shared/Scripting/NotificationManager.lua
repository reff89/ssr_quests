-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

NotificationManager = {};
NotificationManager.initialized = false;
local ui_emitter, audio;
local queue = {};

NotificationManager.init = function ()
    if not NotificationManager.initialized and not isServer() then
        ui_emitter = FMODSoundEmitter.new();
        SSRTimer.add_ms(NotificationManager.update, 50, true);
        NotificationManager.initialized = true;
    end
end

NotificationManager.add = function(f, sound, sync)
    local size = #queue;
    if size > 0 then
        if queue[size] == sound then -- play sound only once, if we have multiple identical notifications in queue
            sound = nil;
            sync = false;
        end
    end
    queue[size+1] = { callback = f, sound = sound, sync = sync };
end

NotificationManager.update = function()
    ui_emitter:tick();
    if #queue > 0 then
        if audio then
            if ui_emitter:isPlaying(audio) then
                if queue[1].sync then return end
            else
                audio = nil;
                return;
            end
        elseif queue[1].sound then
            audio = ui_emitter:playSoundImpl(queue[1].sound, false, nil);
            ui_emitter:tick();
        end
        if queue[1].callback then
            queue[1].callback();
        end
        table.remove(queue, 1);
    end
end