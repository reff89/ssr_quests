-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "Communications/QSystem"

local screen, screen_width, screen_height;

VFX = {};

Dissolve = {}
local timer = 0;
local timestamp = nil

Dissolve.color = { r = 0, g = 0, b = 0 }; -- target color
Dissolve.r, Dissolve.g, Dissolve.b, Dissolve.a = 0, 0, 0, 0; -- current color
Dissolve.speed = 1;
Dissolve.fade = 0;
Dissolve.callback = nil;

local delta_r, delta_g, delta_b = 0, 0, 0;
Dissolve.setFadeOut = function (callback, color, speed)
    if Dissolve.color.r == color.r and Dissolve.color.g == color.g and Dissolve.color.b == color.b and Dissolve.a == 1 then -- already faded
        if callback then
            SSRTimer.add_s(callback, 1, false);
            return true;
        end
        return;
    elseif Dissolve.a == 0 then -- set intial color
        Dissolve.r, Dissolve.g, Dissolve.b = color.r, color.g, color.b;
    end

    if Dissolve.fade == 0 then
        timer = 0;
        Dissolve.callback = callback;
        timestamp = getTimeInMillis();
        Dissolve.color = color;
        Dissolve.speed = speed or 1;
        delta_r, delta_g, delta_b = (Dissolve.color.r - Dissolve.r) * 0.04 * Dissolve.speed, (Dissolve.color.g - Dissolve.g) * 0.04 * Dissolve.speed, (Dissolve.color.b - Dissolve.b) * 0.04 * Dissolve.speed;
        Dissolve.fade = 1;
        return true;
    else -- if still in progress
        Dissolve.r, Dissolve.g, Dissolve.b,  Dissolve.a = Dissolve.color.r, Dissolve.color.g, Dissolve.color.b, Dissolve.fade == 1 and 1 or 0;
        Dissolve.fade = 0;
        return Dissolve.setFadeOut(callback, color, speed);
    end
end

Dissolve.setFadeIn = function (callback, speed)
    if Dissolve.fade == 0 then
        if Dissolve.a ~= 0 then
            timer = 0;
            Dissolve.callback = callback;
            timestamp = getTimeInMillis();
            Dissolve.fade = 2;
            Dissolve.speed = speed or 1;
            return true;
        elseif callback then
            SSRTimer.add_s(callback, 1, false);
            return true;
        end
    else -- if still in progress
        Dissolve.r, Dissolve.g, Dissolve.b,  Dissolve.a = Dissolve.color.r, Dissolve.color.g, Dissolve.color.b, Dissolve.fade == 1 and 1 or 0;
        Dissolve.fade = 0;
        return Dissolve.setFadeIn(callback, speed);
    end
end

Dissolve.cancel = function ()
    Dissolve.fade = 0;
	Dissolve.a = 0;
	Dissolve.callback = nil;
end

Dissolve.update = function ()
    if Dissolve.fade == 0 then return end

    if timer > 0 then
        timer = timer - getDeltaTimeInMillis(timestamp)
        timestamp = getTimeInMillis();
    else
        timer = 5;
        if Dissolve.fade == 1 then
            if Dissolve.r ~= Dissolve.color.r or Dissolve.g ~= Dissolve.color.g or Dissolve.b ~= Dissolve.color.b then
                local r = delta_r + Dissolve.r;
                if (delta_r > 0 and r - Dissolve.color.r > -0.04) or (delta_r < 0 and r - Dissolve.color.r < 0.04) then
                    Dissolve.r = Dissolve.color.r;
                else
                    Dissolve.r = r;
                end
                local g = delta_g + Dissolve.g;
                if (delta_g > 0 and g - Dissolve.color.g > -0.04) or (delta_g < 0 and g - Dissolve.color.g < 0.04) then
                    Dissolve.g = Dissolve.color.g;
                else
                    Dissolve.g = g;
                end
                local b = delta_b + Dissolve.b;
                if (delta_b > 0 and b - Dissolve.color.b > -0.04) or (delta_b < 0 and b - Dissolve.color.b < 0.04) then
                    Dissolve.b = Dissolve.color.b;
                else
                    Dissolve.b = b;
                end
            elseif Dissolve.a == 1 then
                Dissolve.fade = 0;
                if Dissolve.callback then
                    Dissolve.callback();
                end
            end
        elseif Dissolve.fade == 2 then
            if Dissolve.a == 0 then
                Dissolve.fade = 0;
                if Dissolve.callback then
                    Dissolve.callback();
                end
            end
        end
        timestamp = getTimeInMillis();
    end
end


SpriteRenderer = {};
local bg_tex, fg_tex, bg_buf, fg_buf;

SpriteRenderer.setBackground = function (texture)
    local width, height = getCore():getScreenWidth(), getCore():getScreenHeight()
    bg_buf = { texture, (height / texture:getHeight()) * texture:getWidth(), height};
end

SpriteRenderer.setForeground = function (texture)
    local width, height = getCore():getScreenWidth(), getCore():getScreenHeight()
    fg_buf = { texture, (height / texture:getHeight()) * texture:getWidth(), height};
end

SpriteRenderer.clearBackground = function()
    bg_tex = nil; bg_buf = nil;
end

SpriteRenderer.clearForeground = function()
    fg_tex = nil; fg_buf = nil;
end

function VFX.prerender()
    if bg_buf and bg_buf ~= bg_tex then
        if bg_buf[1]:isReady() then
            bg_tex = bg_buf; bg_buf = nil;
        end
    end
    if bg_tex then
        if bg_tex[2] ~= screen_width then
            screen:drawRect(0, 0, screen_width, screen_height, 1, 0, 0, 0);
        end
        screen:drawTextureScaled(bg_tex[1], (screen_width / 2) - (bg_tex[2] / 2), 0, bg_tex[2], bg_tex[3], 1, 1, 1, 1);
    end
    if fg_buf and fg_buf ~= fg_tex then
        if fg_buf[1]:isReady() then
            fg_tex = fg_buf; fg_buf = nil;
        end
    end
    if fg_tex then
        screen:drawTextureScaled(fg_tex[1], (screen_width / 2) - (fg_tex[2] / 2), 0, fg_tex[2], fg_tex[3], 1, 1, 1, 1);
    end
    if Dissolve.fade == 1 then
        if Dissolve.a < 1 then
            local a = Dissolve.a + 0.04 * (UIManager.getMillisSinceLastRender() / 33.3) * Dissolve.speed;
            Dissolve.a = a > 1 and 1 or a;
        end
    elseif Dissolve.fade == 2 then
        if Dissolve.a > 0 then
            local a = Dissolve.a - 0.04 * (UIManager.getMillisSinceLastRender() / 33.3) * Dissolve.speed;
            Dissolve.a = a < 0 and 0 or a;
        end
    end
    if Dissolve.a > 0 then
        screen:drawRect(0, 0, screen_width, screen_height, Dissolve.a, Dissolve.r, Dissolve.g, Dissolve.b);
    end
end

function VFX.update()
    screen:setVisible(Blocker.enabled or Dissolve.a ~= 0 or bg_tex ~= nil or fg_tex ~= nil)
end

function VFX.onResolutionChange(oldw, oldh, neww, newh)
    screen_width = neww;
    screen_height = newh;

    if bg_tex then
        bg_tex[2] = (newh / bg_tex[1]:getHeight()) * bg_tex[1]:getWidth();
        bg_tex[3] = newh;
    end
    if fg_tex then
        fg_tex[2] = (newh / fg_tex[1]:getHeight()) * fg_tex[1]:getWidth();
        fg_tex[3] = newh;
    end
end

function VFX.init()
    if not screen then
        screen_width, screen_height =  getCore():getScreenWidth(), getCore():getScreenHeight();
        screen = ISUIElement:new (0, 0, screen_width, screen_height);
        screen.Type = "VFX";
        screen.onFocus = function() end
        screen.bringToTop = function() end
        screen.onMouseUp = function() return false end
        screen.onMouseDown = function() return false end
        screen:initialise();
        screen:backMost();
        screen:addToUIManager();
        Events.OnTick.Add(VFX.update)
        Events.OnTick.Add(Dissolve.update)
        Events.OnPreUIDraw.Add(VFX.prerender)
        Events.OnResolutionChange.Add(VFX.onResolutionChange);
    end
end

Events.OnQSystemInit.Add(VFX.init);


function VFX.onScriptExit()
    SpriteRenderer.clearBackground();
	SpriteRenderer.clearForeground();
	Dissolve.cancel();
end

Events.OnScriptExit.Add(VFX.onScriptExit);