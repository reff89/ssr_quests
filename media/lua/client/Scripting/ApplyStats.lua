-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

local function addHalo(label, value, _inverseCols)
    local currentPlayer = getPlayer();
    if not currentPlayer then
        return;
    end

    local color = HaloTextHelper.getColorGreen();
    local direction = 0;

    if value and (type(value) == "number") then
        if value < 0 then
            color = _inverseCols and HaloTextHelper.getColorRed() or HaloTextHelper.getColorGreen();
            direction = -1;
        elseif value > 0 then
            color = _inverseCols and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed();
            direction = 1;
        end
    end

    if direction ~= 0 then
        HaloTextHelper.addTextWithArrow(currentPlayer, label, direction == 1 and true or false, color);
    else
        HaloTextHelper.addText(currentPlayer, label, color);
    end
end

function ApplyStats(player, _stats)
    local bodyDamage = player:getBodyDamage();

    for i=1, #_stats do
        if _stats[i][1] == "Unhappiness" then
            local value = bodyDamage:getUnhappynessLevel() + _stats[i][2];
            if value > 100 then
                value = 100;
            elseif value < 0 then
                value = 0;
            end

            bodyDamage:setUnhappynessLevel(value);
            addHalo(getText("IGUI_HaloNote_Unhappiness"), _stats[i][2])
            return true;
        elseif _stats[i][1] == "Boredom" then
            local value = bodyDamage:getBoredomLevel() + _stats[i][2];
            if value > 100 then
                value = 100;
            elseif value < 0 then
                value = 0;
            end

            bodyDamage:setBoredomLevel(value);
            addHalo(getText("IGUI_HaloNote_Boredom"), _stats[i][2])
            return true;
        else
            local stats = player:getStats();
            if stats["get".._stats[i][1]] then
                local value = stats["get".._stats[i][1]](stats);

                local range100 = false;
                if _stats[i][1] == "Panic" then
                    range100 = true;
                end

                if range100 then
                    value = value + _stats[i][2];
                else
                    value = value + _stats[i][2] * 0.01;
                end

                if value < 0 then
                    value = 0;
                elseif range100 and value > 100 then
                    value = 100;
                elseif not range100 and value > 1 then
                    value = 1;
                end

                stats["set".._stats[i][1]](stats,value);
                addHalo(getText("IGUI_HaloNote_".._stats[i][1]), _stats[i][2])
                return true;
            end
        end
    end
end