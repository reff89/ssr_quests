-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/PlayerData/ISPlayerData"
require "ISUI/ISInventoryPaneContextMenu"
require "luautils"

local counter = 0;
-- Make virtual item real to add it to player inventory
local function createRealItem(item, container, list)
    if item:getModData().virtual then
        local name = tostring(item:getModule())..'.'..tostring(item:getType());
        item:getModData().virtual = false;
        container:Remove(item);
        local exists = false;
        for i=#list,1,-1  do
            if list[i].name == name then
                list[i].amount = list[i].amount + 1;
                exists = true;
            end
        end
        if not exists then
            local entry = QItemFactory.createEntry(name, 1);
            table.insert(list, entry);
        end
        counter = counter + 1;
        if item:getModData().single then
            return true;
        end
    end
end

-- Removes virtual items from container if taken an item with single property
local function removeVirtualItems(loot, data)
    if data then
        local new_data = {};
        local index = 1;
        local items = loot.inventoryPane.inventory:getItems();
        for i=items:size()-1, 0, -1 do
            local item = items:get(i);
            if item:getModData().virtual then
                local item_type = item:getFullType();
                for j=index-#new_data, #data do
                    if data[j].type == item_type then
                        table.insert(new_data, data[j]);
                        table.remove(data, j);
                        break;
                    end
                end
                QuestLogger.print("[QSystem*] ItemSpawner: Removed single virtual item - "..tostring(item_type));
                item:getModData().virtual = false;
                items:remove(item);
                index = index + 1;
            end
        end
        if new_data[1] then
            return new_data;
        else
            return data;
        end
    else
        local items = loot.inventoryPane.inventory:getItems();
        for i=items:size()-1, 0, -1 do
            local item = items:get(i);
            if item:getModData().virtual and item:getModData().single then
                QuestLogger.print("[QSystem*] ItemSpawner: Removed single virtual item - "..tostring(item:getType()));
                item:getModData().virtual = false;
                items:remove(item);
            end
        end
    end
end

local function onGrabVirtualItems(items, player, mode)
    local loot = getPlayerLoot(player);
    local inventory = loot.inventoryPane.inventory:getParent();
    local list = {};
    if inventory then
        counter = 0;
        local container = inventory:getContainer();
        for i=1, #items do
            if items[i].items then
                local amount = 1;
                if mode == 3 then
                    amount = #items[i].items;
                elseif mode == 2 then
                    amount = math.floor((#items[i].items - 1) / 2);
                    if amount < 1 then
                        amount = 1;
                    end
                end
                for j=#items[i].items, 1, -1 do
                    if createRealItem(items[i].items[j], container, list) then
                        removeVirtualItems(loot);
                        break;
                    elseif counter >= amount then
                        break;
                    end
                end
            else
                if createRealItem(items[i], container, list) then
                    removeVirtualItems(loot);
                    break;
                end
            end
            loot:refreshBackpacks();
        end
    end
    if #list > 0 then
        if isClient() then
            for i=1, #list do
                local _item = getScriptManager():FindItem(list[i].name);
                if _item then
                    QuestLogger.report(getText("UI_QSystem_Logger_ItemGet", tostring(_item:getDisplayName()), list[i].amount))
                end
            end
        end
        QItemFactory.request("LootContainer", list);
    end
end

local function createVirtualItem(item_type, single, item_name)
    local item = InventoryItemFactory.CreateItem(item_type)
    if not item then
        return;
    end
    --[[if item_type then
        item:setType(item_type)
    end--]]
    if item_name then
        item:setName(item_name);
    end
    --[[if item_tex then
        item:getScriptItem():setIcon(item_tex)
        local status, tex = pcall(getTexture, "media/textures/Item_"..tostring(item_tex)..".png")
        if status and tex then
            item:setTexture(tex)
        end
    end--]]
    item:getModData().virtual = true;
    item:getModData().single = single or false;
    return item;
end

local function clone(obj)
    local new_data = {};
    for i=1, #obj do
        local entry = {}
        entry.type = obj[i].type;
        entry.single = obj[i].single;
        entry.name = obj[i].name;
        table.insert(new_data, entry);
    end
    return new_data;
end

function SpawnVirtualItems(_data, loot) -- TODO: Find some way to clear container on load state and reimport
    local items = {};
    local data = removeVirtualItems(loot, clone(_data));
    local inv_items = loot.inventoryPane.inventory:getItems();
    for i=1, #data do
        local item = createVirtualItem(data[i].type, data[i].single, data[i].name);
        inv_items:add(item); -- create virtual item and add it to container
        table.insert(items, item);
    end
    loot:refreshBackpacks();
    return items;
end


 -- safely override original functions
local onGrabItems = ISInventoryPaneContextMenu.onGrabItems;
ISInventoryPaneContextMenu.onGrabItems = function(items, player)
    onGrabVirtualItems(items, player, 3);
	onGrabItems(items, player);
end

local onGrabHalfItems = ISInventoryPaneContextMenu.onGrabHalfItems;
ISInventoryPaneContextMenu.onGrabHalfItems = function(items, player)
    onGrabVirtualItems(items, player, 2);
	onGrabHalfItems(items, player)
end

local onGrabOneItems = ISInventoryPaneContextMenu.onGrabOneItems;
ISInventoryPaneContextMenu.onGrabOneItems = function(items, player)
    onGrabVirtualItems(items, player, 1);
    onGrabOneItems(items, player)
end

local luautils_walkToContainer = luautils.walkToContainer;
function luautils.walkToContainer(container, playerNum)
    if container then
        return luautils_walkToContainer(container, playerNum);
    else
        return false;
    end
end