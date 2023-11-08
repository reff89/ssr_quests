-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Communications/QSystem"

ItemFetcher = {}

ItemFetcher.rulesets = {};
ItemFetcher.has_ruleset = function(id)
	for i=1, #ItemFetcher.rulesets do
		if ItemFetcher.rulesets[i].id == id then
			return true;
		end
	end
end

ItemFetcher.add_ruleset = function(id, delegate)
	if not id or not delegate then
		QuestLogger.error = true;
		print("[QSystem] (Error) ItemFetcher: Unable to add ruleset, because one of the arguments is null.");
		return false;
	end
	for i=1, #ItemFetcher.rulesets do
		if ItemFetcher.rulesets[i].id == id then
			QuestLogger.error = true;
			print("[QSystem] (Error) ItemFetcher: Unable to add ruleset, because ID already exists - "..tostring(id));
			return false;
		end
	end
	ItemFetcher.rulesets[#ItemFetcher.rulesets+1] = { id = id, validate = delegate };
	return true;
end

ItemFetcher.validate = function(item, ruleset_id)
	for i=1, #ItemFetcher.rulesets do
		if ItemFetcher.rulesets[i].id == ruleset_id then
			if ItemFetcher.rulesets[i].validate(item) then
				return true;
			else
				return false;
			end
		end
	end
end

ItemFetcher.getNumberOfItem = function(item_id, maximum, ruleset_id)
	local inventory = getPlayer():getInventory();
	if ruleset_id then
		if ruleset_id == "any" and item_id then
			ruleset_id = false;
		elseif not ItemFetcher.has_ruleset(ruleset_id) then
			return "Attempt to use non-existent ruleset '"..tostring(ruleset_id).."'";
		end
	else
		ruleset_id = "default";
	end

	if item_id then
		if not getScriptManager():FindItem(item_id) then
			return "Attempt to check non-existent item '"..tostring(item_id).."'";
		end
	end

	local amount = 0;
	if item_id then
		if ruleset_id then
			local items = inventory:FindAll(item_id);
			if items then
				for j=items:size()-1, 0, -1 do
					local item = items:get(j);
					if ItemFetcher.validate(item, ruleset_id) then
						amount = amount + 1;
						if maximum and amount >= maximum then break end
					end
				end
			end
		else
			amount = inventory:getNumberOfItem(item_id);
		end
	else
		local items = inventory:getItems();
		if items then
			for j=items:size()-1, 0, -1 do
				local item_id = items:get(j);
				if ItemFetcher.validate(item_id, ruleset_id) then
					amount = amount + 1;
					if maximum and amount >= maximum then break end
				end
			end
		end
	end

	return amount;
end

ItemFetcher.UI = ISPanel:derive("ItemFetcher_UI");
ItemFetcher.UI.instance = nil;

local function validate(item) -- TODO: check if item still follows rule set?
	if not ItemFetcher.UI.instance.inventory:contains(item) then
		return false;
	elseif getPlayer():isEquipped(item) or getPlayer():isEquippedClothing(item) then
		return false;
	elseif item:isFavorite() then
		return false;
	end
	return true;
end

function ItemFetcher.UI.OnRefreshInventoryWindowContainers()
	if ItemFetcher.UI.instance then
		for i=#ItemFetcher.UI.instance.offerings.items, 1, -1 do
			if not validate(ItemFetcher.UI.instance.offerings.items[i].item) then
				ItemFetcher.UI.instance:removeItem(i);
			end
		end
	end
end

Events.OnRefreshInventoryWindowContainers.Add(ItemFetcher.UI.OnRefreshInventoryWindowContainers)

function ItemFetcher.UI:initialise()
	ISPanel.initialise(self);
end

function ItemFetcher.UI:createChildren()
	local label = getTextOrNull("UI_ItemFetcher_Label_Title") or "Complete delivery";
	self.label = ISLabelMod:new((self.width / 2) - (getTextManager():MeasureStringX(UIFont.Medium, label) / 2), 5*SSRLoader.scale, self.width, 20*SSRLoader.scale, label, 1, 1, 1, 1, UIFont.Medium);
	self.label:initialise();
	self:addChild(self.label);

	self.offerings = ISScrollingListBox:new(10*SSRLoader.scale, 35*SSRLoader.scale, 185*SSRLoader.scale, 220*SSRLoader.scale);
    self.offerings:initialise();
    self.offerings:instantiate();
    self.offerings.itemheight = 22*SSRLoader.scale;
    self.offerings.selected = 0;
    self.offerings.joypadParent = self;
    self.offerings.font = UIFont.NewSmall;
    self.offerings.doDrawItem = self.drawOffer;
    self.offerings.onMouseUp = self.offeringMouseUp;
    self.offerings.drawBorder = true;
    self:addChild(self.offerings);

	self.requirements = ISScrollingListBox:new(205*SSRLoader.scale, 35*SSRLoader.scale, 285*SSRLoader.scale, 220*SSRLoader.scale);
    self.requirements:initialise();
    self.requirements:instantiate();
    self.requirements.itemheight = 22*SSRLoader.scale;
    self.requirements.selected = 0;
    self.requirements.joypadParent = self;
    self.requirements.font = UIFont.NewSmall;
    self.requirements.doDrawItem = self.drawRequired;
    self.requirements.onMouseUp = function () end
    self.requirements.onMouseDown = function () end
	self.requirements.backgroundColor.a = 0.5;
    self.requirements.drawBorder = true;
    self:addChild(self.requirements);

	local function createButton(i, text)
		local button = ISButton:new(10*SSRLoader.scale, self.offerings.y + self.offerings.height + 10*SSRLoader.scale, getTextManager():MeasureStringX(UIFont.Medium, text) + 20*SSRLoader.scale, 25*SSRLoader.scale, text, self, ItemFetcher.UI.onButtonPressed);
		button.font = UIFont.Medium;
		button:initialise();
		button:instantiate();
		button.internal = i;
		button.borderColor = {r=1, g=1, b=1, a=0.3};
		button.textColor =  {r=1, g=1, b=1, a=0.5};
		return button;
	end

	self.remove = createButton(0, getTextOrNull("UI_ItemFetcher_Button_Remove") or "Remove");
    self:addChild(self.remove);

	self.cancel = createButton(2, getTextOrNull("UI_ItemFetcher_Button_Cancel") or "Cancel");
	self.cancel:setX(self.width - self.cancel.width - 10*SSRLoader.scale);
    self:addChild(self.cancel);

	self.confirm = createButton(1, getTextOrNull("UI_ItemFetcher_Button_Confirm") or "Confirm");
	self.confirm:setX(self.cancel.x - self.confirm.width - 10*SSRLoader.scale);
    self:addChild(self.confirm);

	self:populateList();
	self:updateButtons();
end

function ItemFetcher.UI:populateList()
	self.requirements:clear();
	for item_id=1, #self.task.items do
		if self.task.items[item_id].item then
			local item = getScriptManager():FindItem(tostring(self.task.items[item_id].item))
			self.requirements:addItem(tostring(item:getDisplayName()), self.task.items[item_id]);
		else
			local ruleset = self.task.items[item_id].ruleset;
			self.requirements:addItem(getText("UI_RuleSet_"..tostring(ruleset)), self.task.items[item_id]);
		end
		self.requirements.items[#self.requirements.items].collected = 0;
	end
end

local tooltip = getTextOrNull("UI_ItemFetcher_Tooltip_Drag") or "Drop items here";
function ItemFetcher.UI:render()
	ISPanel.render(self);
	if not self.offerings.items[1] then
		self:drawTextCentre(tooltip, self.offerings.x + (self.offerings.width / 2), self.offerings.y + (self.offerings.height / 2) - 20*SSRLoader.scale, 0.5, 0.5, 0.5, 1, UIFont.NewSmall);
	end
end

function ItemFetcher.UI:onButtonPressed(button)
	if button.internal == 0 then -- remove
		self:removeItem(self.offerings.selected);
	elseif button.internal == 1 then -- confirm
		ItemFetcher.UI.OnRefreshInventoryWindowContainers();
		if button.enable then
			for i=1, #self.offerings.items do
				self.inventory:Remove(self.offerings.items[i].item);
			end
			if self.onConfirm then
				self.onConfirm();
			end
			self.task:setPending(true);
			self:close();
		end
	elseif button.internal == 2 then -- cancel
		if self.onCancel then
			self.onCancel();
		end
		self:close();
	end
end

function ItemFetcher.UI:updateButtons()
	if self.offerings.items[1] and self.offerings.selected > 0 then
		self.remove:setEnable(true);
	else
		self.remove:setEnable(false);
	end

	local fetched = true;
	for i=1, #self.requirements.items do
		if self.requirements.items[i].collected < self.requirements.items[i].item.amount then
			fetched = false;
			break;
		end
	end
	self.confirm:setEnable(fetched);
end

function ItemFetcher.UI:addItem(item)
	if luautils.haveToBeTransfered(self.player, item) then
		return;
	elseif not validate(item) then
		return;
	end

	for i=1, #self.offerings.items do
		if self.offerings.items[i].item == item then
			return;
		end
	end

	local allow = false;
	for i=1, #self.requirements.items do
		if item:getFullType() == self.requirements.items[i].item.item then
			local valid = true;
			if self.requirements.items[i].item.ruleset then
				valid = ItemFetcher.validate(item, self.requirements.items[i].item.ruleset);
			end
			if valid and self.requirements.items[i].collected < self.requirements.items[i].item.amount then
				self.requirements.items[i].collected = self.requirements.items[i].collected + 1;
				allow = true;
				break;
			end
		elseif not self.requirements.items[i].item.item then
			if ItemFetcher.validate(item, self.requirements.items[i].item.ruleset) then
				if self.requirements.items[i].collected < self.requirements.items[i].item.amount then
					self.requirements.items[i].collected = self.requirements.items[i].collected + 1;
					allow = true;
					break;
				end
			end
		end
	end
	if not allow then return end

	self.offerings:addItem(item:getName(), item);
	self:updateButtons();
end

function ItemFetcher.UI:removeItem(index)
	index = index or self.offerings.selected;
	for i=#self.requirements.items, 1, -1 do
		if self.offerings.items[index].item:getFullType() == self.requirements.items[i].item.item then
			local valid = true;
			if self.requirements.items[i].item.ruleset then
				valid = ItemFetcher.validate(self.offerings.items[index].item, self.requirements.items[i].item.ruleset);
			end
			if valid and self.requirements.items[i].collected > 0 then
				self.requirements.items[i].collected = self.requirements.items[i].collected - 1;
				break;
			end
		elseif not self.requirements.items[i].item.item then
			if ItemFetcher.validate(self.offerings.items[index].item, self.requirements.items[i].item.ruleset) then
				if self.requirements.items[i].collected > 0 then
					self.requirements.items[i].collected = self.requirements.items[i].collected - 1;
					break;
				end
			end
		end
	end
    table.remove(self.offerings.items, index);
	self.offerings.selected = 0;
	self:updateButtons();
end

function ItemFetcher.UI:drawOffer(y, item, alt)
    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.9, self.borderColor.r, self.borderColor.g, self.borderColor.b);

    if self.selected == item.index then
		self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15);
    end

	self:drawText(item.text, 25, y + 2, 1, 1, 1, 0.9, self.font);

    self:drawTextureScaledAspect(item.item:getTex(), 5, y + 2, 18, 18, 1, item.item:getR(), item.item:getG(), item.item:getB());

    return y + self.itemheight;
end

function ItemFetcher.UI:drawRequired(y, item, alt)
	self:drawText(item.text.." ("..item.collected.."/"..item.item.amount..")", 5, y + 2, 1, 1, 1, 0.9, self.font);

	if item.collected == item.item.amount then
		self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.3, 0.73, 0.09);
	end

    return y + self.itemheight;
end

function ItemFetcher.UI:offeringMouseUp(x, y)
	self.parent:updateButtons();
    if self.vscroll then
        self.vscroll.scrolling = false;
    end
    local count = 1;
    if ISMouseDrag.dragging then
        for i=1, #ISMouseDrag.dragging do
           count = 1;
           if instanceof(ISMouseDrag.dragging[i], "InventoryItem") then
                self.parent:addItem(ISMouseDrag.dragging[i]);
           else
               if ISMouseDrag.dragging[i].invPanel.collapsed[ISMouseDrag.dragging[i].name] then
                   count = 1;
                   for j=1, #ISMouseDrag.dragging[i].items do
                       if count > 1 then
                           self.parent:addItem(ISMouseDrag.dragging[i].items[j]);
                       end
                       count = count + 1;
                   end
               end
           end
        end
    end
end

function ItemFetcher.UI.close()
	if ItemFetcher.UI.instance then
		ItemFetcher.UI.instance:removeFromUIManager();
		ItemFetcher.UI.instance = nil;
	end
end

Events.OnScriptExit.Add(ItemFetcher.UI.close);
Events.OnQSystemReset.Add(ItemFetcher.UI.close);
Events.OnQSystemUpdate.Add(function (code) if code == 4 then ItemFetcher.UI.close() end end);

function ItemFetcher.UI:new(task, onConfirm, onCancel)
	local w, h = 500*SSRLoader.scale, 300*SSRLoader.scale;
    local o = ISPanel:new((getCore():getScreenWidth() / 2) - (w / 2), (getCore():getScreenHeight() / 2) - (h / 2), w, h);
    setmetatable(o, self);
    self.__index = self;
	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.95};
	o.player = getPlayer();
	o.inventory = o.player:getInventory();
	o.task = task;
	o.onConfirm = onConfirm;
	o.onCancel = onCancel;
	if ItemFetcher.UI.instance then
		ItemFetcher.UI.instance:removeFromUIManager();
	end
	ItemFetcher.UI.instance = o;
	return o;
end

ItemFetcher.onResolutionChange = function()
	if ItemFetcher.UI.instance then
		local x = getCore():getScreenWidth() / 2 - ItemFetcher.UI.instance:getWidth() / 2;
		local y = getCore():getScreenHeight() / 2 - ItemFetcher.UI.instance:getHeight() / 2;
		ItemFetcher.UI.instance:setX(x);
		ItemFetcher.UI.instance:setY(y);
	end
end

Events.OnResolutionChange.Add(ItemFetcher.onResolutionChange);

-- default rulesets (applied to has_item and remove_item)
local function isRemovableItem(item)
    local player = getPlayer();
    if player then
        if player:isEquipped(item) or player:isEquippedClothing(item) or item:isFavorite() then
            return false;
        end
    else
        return false;
    end

    return true;
end

local function anyItem(item)
    return true;
end

ItemFetcher.add_ruleset("default", isRemovableItem);
ItemFetcher.add_ruleset("any", anyItem);