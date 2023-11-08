-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/Maps/ISWorldMap"
require "ISUI/Maps/ISMiniMap"
require "QTracker"

WMM = {}
WMM.texture = getTexture("media/ui/map/target.png");

if not WMM.texture then return end

function WMM.render(self, _x, _y)
    local api = self.javaObject:getAPI();
    if api then
        local x = api:worldToUIX(_x, _y);
        local y = api:worldToUIY(_x, _y);
        local scale = math.max(1, api:getWorldScale());
        local w, _w = 20*scale, 10*scale;
        self:setStencilRect(0, 0, self.width, self.height)
        self:drawTextureScaled(WMM.texture, x - _w, y - _w, w, w, 1, 1, 1, 1);
        self:clearStencilRect();
    end
end

local ISWorldMap_render = ISWorldMap.render;
function ISWorldMap:render()
    ISWorldMap_render(self);
    if QTracker.ActiveQuest then
        for i=1, QTracker.ActiveQuest.active_size do
            if QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].type == "GotoLocation" then
                if QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].showOnMap then
                    WMM.render(self, QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].x, QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].y)
                end
            end
        end
    end
end

local ISMiniMapInner_render = ISMiniMapInner.render;
function ISMiniMapInner:render()
    ISMiniMapInner_render(self);
    if QTracker.ActiveQuest then
        for i=1, QTracker.ActiveQuest.active_size do
            if QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].type == "GotoLocation" then
                if QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].showOnMap then
                    WMM.render(self, QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].x, QTracker.ActiveQuest.tasks[QTracker.ActiveQuest.active[i]].y)
                end
            end
        end
    end
end