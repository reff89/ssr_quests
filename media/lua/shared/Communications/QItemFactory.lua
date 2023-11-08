-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

QItemFactory = {}

-- Client side

QItemFactory.createEntry = function (name, amount)
    local item = {}
    item.name = name;
    item.amount = amount;
    return item;
end

QItemFactory.request = function (sender, items, callback)
    if type(items) == "table" then
        if #items > 0 then
            if isClient() then
                SyncClient.request('QSystem', 'requestItem', items, sender, callback);
            elseif not isServer() then
                local inventory = getPlayer():getInventory();
                for i=1, #items do
                    local added = 0;
                    while added < items[i].amount do
                        inventory:AddItem(items[i].name);
                        added = added + 1;
                    end
                end
                if callback then
                    SSRTimer.add_ms(callback, 100, false);
                end
            end
        end
    end
end

local function loadTexture(id, icons)
    if id > -1 and id < icons:size() then
        return getTexture("Item_"..tostring(icons:get(id)));
    end
end

QItemFactory.getTextureFromItem = function(item)
	local texture = item:getNormalTexture();
	if not texture or texture:getName() == "Question_On" then
		local obj = item:InstanceItem(nil);
		if obj then
			local icons = item:getIconsForTexture();
			if icons and icons:size() > 0 then
				texture = loadTexture(obj:getVisual():getBaseTexture(), icons) or loadTexture(obj:getVisual():getTextureChoice(), icons);
			else
				texture = obj:getTexture();
			end
		end
	end
	return texture;
end

QItemFactory.getWorldSpriteFromItem = function(item)
    if item:getTypeString() == "Moveable" then
        local obj = item:InstanceItem(nil);
        if obj then
            local sprite = obj:getWorldSprite();
            if sprite and sprite ~= "" then
                return getTexture(sprite);
            end
        end
    end
end

-- Server side

QItemFactory.grant = function (username, items)
    local done = false;
    if type(items) == "table" then
        for i=1, #items do
            items[i].amount = tonumber(items[i].amount)
            if items[i].name and items[i].amount then
                local result = jm_addItem(username, items[i].name, items[i].amount);
                print(tostring(result));
                done = true;
            end
        end
    end

    if done then
        return true;
    end
end