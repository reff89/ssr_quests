-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Communications/QSystem"
require "OptionScreens/MainOptions"

AudioManager = {};
AudioManager.loop = false;
AudioManager.initialized = false;
local music_volume, ambient_volume;
local sfx_emitter, bgm_emitter, voice_emitter;
local current_sfx, current_bgm, current_voice;

local last_bgm;
local wait_bgm = false;

local update_areas = true; -- allows quest area bgm overwrite

AudioManager.init = function ()
    if not AudioManager.initialized and not isServer() then
        sfx_emitter = FMODSoundEmitter.new();
        bgm_emitter = FMODSoundEmitter.new();
        voice_emitter = FMODSoundEmitter.new();
        Events.OnTick.Add(AudioManager.update);
        AudioManager.initialized = true;

        local apply_options = MainOptions.apply;
        function MainOptions:apply(closeAfter)
            apply_options(self, closeAfter);
            AudioManager.syncVolume();
        end

        local return_to_game = MainScreen.onReturnToGame;
        function MainScreen:onReturnToGame()
            return_to_game(self);
            if AudioManager.isMusicMuted() or AudioManager.isPlayingMusic(last_bgm) then
                if getSoundManager():getMusicVolume() ~= 0 then
                    AudioManager.setVolume(0, 0);
                end
            end
        end
    end
end

AudioManager.update = function ()
    sfx_emitter:tick();
    bgm_emitter:tick();
    voice_emitter:tick();

    if current_bgm then
        if not bgm_emitter:isPlaying(current_bgm) then
            if AudioManager.loop then
                if last_bgm then
                    AudioManager.playBGM(last_bgm, true, wait_bgm); -- restart bgm
                end
            elseif wait_bgm then
                wait_bgm = false;
                AudioManager.stop(1);
                if not DialoguePanel.instance then
                    AudioManager.restoreVolume();
                end
            end
        end
    end
end

AudioManager.syncVolume = function ()
    if AudioManager.initialized then
        local sm = getSoundManager();
        sfx_emitter:setVolumeAll(sm:getSoundVolume());
        bgm_emitter:setVolumeAll(sm:getMusicVolume());
        voice_emitter:setVolumeAll(sm:getSoundVolume());
        if current_bgm then -- mute music if custom bgm is playing
            music_volume = sm:getMusicVolume();
            sm:setMusicVolume(0);
        end
    end
end

AudioManager.onQSystemUpdate = function(code)
    if code == 4 then
        wait_bgm = false;
        if not QuestArea.isPlayingMusic() then
            AudioManager.stopAll();
            AudioManager.restoreVolume();
        end
    end
end

Events.OnQSystemInit.Add(AudioManager.init);
Events.OnQSystemUpdate.Add(AudioManager.onQSystemUpdate);


AudioManager.playSound = function(file)
    if sfx_emitter then
        if current_sfx then
            if sfx_emitter:isPlaying(current_sfx) then
                sfx_emitter:stopSoundLocal(current_sfx)
            end
        end
        current_sfx = sfx_emitter:playSoundImpl(file, false, nil);
        if current_sfx then
            sfx_emitter:setVolume(current_sfx, getSoundManager():getSoundVolume());
        end
        return true;
    else
        print("[QSystem] (Error) AudioManager: Unable to access sfx emitter.")
    end
end

AudioManager.playBGM = function(file, loop, fully)
    if bgm_emitter then
        if current_bgm then
            if bgm_emitter:isPlaying(current_bgm) then
                if QuestArea.isPlayingMusic() and last_bgm == file then return true end
                bgm_emitter:stopSoundLocal(current_bgm)
            end
        end
        last_bgm = file;
        AudioManager.setVolume(0, 0);
        current_bgm = bgm_emitter:playSoundImpl(file, false, nil);
        AudioManager.loop = loop;
        wait_bgm = fully; -- play audio to the end after dialogue ends
        if current_bgm and music_volume then
            bgm_emitter:setVolume(current_bgm, music_volume);
        end
        if update_areas then
            QuestArea.bgm(file); -- changes bgm for current quest area
        end
        return true;
    else
        print("[QSystem] (Error) AudioManager: Unable to access bgm emitter.")
    end
end

AudioManager.playVoice = function(file)
    if voice_emitter then
        if current_voice then
            if voice_emitter:isPlaying(current_voice) then
                voice_emitter:stopSoundLocal(current_voice)
            end
        end
        current_voice = voice_emitter:playSoundImpl(file, false, nil);
        if current_voice then
            voice_emitter:setVolume(current_voice, getSoundManager():getSoundVolume());
        end
        return true;
    else
        print("[QSystem] (Error) AudioManager: Unable to access voice emitter.")
    end
end

AudioManager.isMusicMuted = function()
    return music_volume and not current_bgm;
end

AudioManager.isPlayingMusic = function(file)
    if current_bgm then
        return last_bgm == file and bgm_emitter:isPlaying(current_bgm);
    end
    return false;
end


AudioManager.stop = function(master)
    if master == 0 then
        if current_sfx and sfx_emitter then
            sfx_emitter:stopSoundLocal(current_sfx);
            current_sfx = nil;
        end
    elseif master == 1 then
        AudioManager.setVolume(0, 0);
        if current_bgm and bgm_emitter then
            AudioManager.loop = false;
            bgm_emitter:stopSoundLocal(current_bgm);
            current_bgm = nil;
            last_bgm = nil;
        end
        if update_areas then
            QuestArea.bgm("m"); -- changes bgm for current quest area
        end
    elseif master == 2 then
        if current_voice and voice_emitter then
            voice_emitter:stopSoundLocal(current_voice);
            current_voice = nil;
        end
    end
end

AudioManager.stopAll = function()
    AudioManager.stop(0);
    if wait_bgm then
        AudioManager.loop = false;
    else
        AudioManager.stop(1);
    end
    AudioManager.stop(2);
end


AudioManager.setVolume = function (master, value)
    local sm = getSoundManager();
    if master == 0 then -- music
        if not music_volume then
            music_volume = sm:getMusicVolume()
        end
        sm:setMusicVolume(value);
    elseif master == 1 then -- ambient
        if not ambient_volume then
            ambient_volume = sm:getAmbientVolume();
        end
        sm:setAmbientVolume(value);
    end
end

AudioManager.restoreVolume = function ()
    local sm = getSoundManager();
    if music_volume and not wait_bgm then
		sm:setMusicVolume(music_volume);
		music_volume = nil;
	end
    if ambient_volume then
		sm:setAmbientVolume(ambient_volume);
		ambient_volume = nil;
	end
end


AudioManager.onScriptExit = function ()
    if not QuestArea.isPlayingMusic() then
        update_areas = false;
        AudioManager.stopAll();
        AudioManager.restoreVolume();
        update_areas = true;
    end
end

Events.OnScriptExit.Add(AudioManager.onScriptExit);