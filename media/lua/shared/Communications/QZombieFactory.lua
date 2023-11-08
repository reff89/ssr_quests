-- Copyright (c) 2022-2023 Oneline/D.Borovsky
-- All rights reserved

QZombieFactory = {}

-- Client side

QZombieFactory.requestSpawn = function (sender, x1, y1, x2, y2, z, amount, forced, callback)
    if not forced and QZombieFactory.hasZombies(x1, y1, x2, y2, z, true) then
        print("[QSystem] QZombieFactory: Unable to spawn zombies, because they already exist within the area")
        if callback then
            SSRTimer.add_ms(callback, 5, false);
        end
    else
        if isClient() then
            SyncClient.request('QSystem', 'createHorde', {x1, y1, x2, y2, z, amount}, sender, callback);
        elseif not isServer() then
            QZombieFactory.createHorde(x1, y1, x2, y2, z, amount);
            if callback then
                SSRTimer.add_ms(callback, 5, false);
            end
        end
    end
end

QZombieFactory.requestDespawn = function (sender, radius, x, y, z, reanimated, clear, callback)
    local requested = false;
    local function requestDespawn()
        if not requested then
            requested = true;
            Events.OnZombieUpdate.Remove(requestDespawn);
            if isClient() then
                SyncClient.request('QSystem', 'removeZombies', {radius, x, y, z, reanimated, clear}, sender, callback);
            elseif not isServer() then
                if clear then -- remove dead bodies
                    for _x = x - radius, x + radius do
                        for _y = y - radius, y + radius do
                            local sq = getCell():getGridSquare(_x, _y, z);
                            if sq then
                                for i = sq:getStaticMovingObjects():size(), 1, -1 do
                                    local corpse = sq:getStaticMovingObjects():get(i-1);
                                    if instanceof(corpse, "IsoDeadBody") then
                                        corpse:removeFromWorld();
                                        corpse:removeFromSquare();
                                    end
                                end
                            end
                        end
                    end
                else -- remove zombies (and reanimated players)
                    for _x = x - radius, x + radius do
                        for _y = y - radius, y + radius do
                            local sq = getCell():getGridSquare(_x, _y, z);
                            if sq then
                                for i = sq:getMovingObjects():size(), 1, -1 do
                                    local zombie = sq:getMovingObjects():get(i-1);
                                    if instanceof(zombie, "IsoZombie") then
                                        if reanimated or not zombie:isReanimatedPlayer() then
                                            zombie:removeFromWorld();
                                            zombie:removeFromSquare();
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if callback then
                    SSRTimer.add_ms(callback, 100, false);
                end
            end
        end
    end
    SSRTimer.add_ms(requestDespawn, 1000, false);
    Events.OnZombieUpdate.Add(requestDespawn);
end

QZombieFactory.hasZombies = function(x1, y1, x2, y2, level, single_level)
	local x = x1 - 2;
	while x < x2 + 2 do
		x = x + 1;
		local y = y1 - 2;
		while y < y2 + 2 do
			y = y + 1;
			local z = single_level and level or 0;
			while z <= level do
				local _square = getCell():getGridSquare(x, y, z);
				if _square then
					for i=0, _square:getMovingObjects():size()-1 do
						local o = _square:getMovingObjects():get(i);
						if instanceof(o, "IsoZombie") then
							return true;
						end
					end
				end
				z = z + 1;
			end
		end
	end
end

-- Shared

QZombieFactory.createHorde = function (x1, y1, x2, y2, z, amount)
    if amount > 100 then amount = 100 end
    spawnHorde(x1, y1, x2, y2, z, amount);
    return true;
end

QZombieFactory.removeZombies = function (radius, x, y, z, reanimated, clear)
    return jm_removeZombies(radius, x, y, z, reanimated, clear);
end