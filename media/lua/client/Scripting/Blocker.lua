require "ISUI/ISUIHandler"
require "Vehicles/ISUI/ISVehicleMenu"

Blocker = {}
Blocker.enabled = false;
Blocker.cutscene = false;

function Blocker.setBlockMovement(value)
    Blocker.enabled = value;
    local player = getPlayer();
    if player then
        if player:isAiming() then
            player:nullifyAiming();
        end
        player:setBlockMovement(value);
    end
end

function Blocker.setEnabled(value)
    Blocker.cutscene = value;
    Blocker.setBlockMovement(value);
    if QuestDebugger.instance then
        if QuestDebugger.instance:isVisible() then return end
    end
    if (ISUIHandler.allUIVisible and value) or (not ISUIHandler.allUIVisible and not value) then
        ISUIHandler.toggleUI();
    end
end

ISUIHandler.setVisibleAllUI = function(visible) -- UNSAFE
	local ui = UIManager.getUI();
	if not visible then
		for i=0,ui:size()-1 do
			if ui:get(i):isVisible() then
                local _table = ui:get(i):getTable();
                local _type;
                if _table then
                    _type = _table.Type
                end
                if _type ~= "DialoguePanel" then
                    table.insert(ISUIHandler.visibleUI, ui:get(i):toString());
				    ui:get(i):setVisible(false);
                end
			end
		end
	else
		for i,v in ipairs(ISUIHandler.visibleUI) do
			for i=0,ui:size()-1 do
				if v == ui:get(i):toString() then
					ui:get(i):setVisible(true);
					break;
				end
			end
		end
		table.wipe(ISUIHandler.visibleUI);
	end
    ISUIHandler.allUIVisible = visible;
	UIManager.setVisibleAllUI(visible)
end

-- forbid entering vehicles during dialogue
local ISVehicleMenu_onEnterAux = ISVehicleMenu.onEnterAux;
function ISVehicleMenu.onEnterAux(playerObj, vehicle, seat)
    if not DialoguePanel.instance then
        ISVehicleMenu_onEnterAux(playerObj, vehicle, seat);
    end
end