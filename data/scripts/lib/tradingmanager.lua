function TradingManager:getStock(name) -- overridden
    local sellPriceFactor = self.sellPriceFactor or 1
    local buyPriceFactor = self.buyPriceFactor or 1
    if self.goodsMargins then
        local factor = self.goodsMargins[name]
        if factor then
            sellPriceFactor = factor
            buyPriceFactor = factor
        end
    end
    return self:getNumGoods(name), self:getMaxGoods(name), sellPriceFactor, buyPriceFactor
end

-- price for which goods are bought by this from others
function TradingManager:getBuyPrice(goodName, sellingFactionIndex) -- overridden
    local good = self:getBoughtGoodByName(goodName)
    if not good then return 0 end

    if self.factionPaymentFactor == 0 then
        local stationFaction = Faction()

        if not stationFaction or stationFaction.index == sellingFactionIndex then return 0 end

        if stationFaction.isAlliance then
            -- is selling player member of the station alliance?
            local seller = Player(sellingFactionIndex)
            if seller and seller.allianceIndex == stationFaction.index then return 0 end
        end

        if stationFaction.isPlayer then
            -- does the station belong to a player that is a member of the ship's alliance?
            local stationPlayer = Player(stationFaction.index)
            if stationPlayer and stationPlayer.allianceIndex == sellingFactionIndex then return 0 end
        end
    end

    -- empty stock -> higher price
    local maxStock = self:getMaxStock(good.size)
    local factor = 1

    if maxStock > 0 then
        factor = math.min(maxStock, self:getNumGoods(goodName)) / maxStock -- 0 to 1 where 1 is 'full stock'
        factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
        factor = factor * 0.2 -- 0.2 to 0
        factor = factor + 0.9 -- 1.1 to 0.9; 'no goods' to 'full'
    end

    local relationFactor = 1
    if sellingFactionIndex then
        local sellerIndex = nil
        if type(sellingFactionIndex) == "number" then
            sellerIndex = sellingFactionIndex
        else
            sellerIndex = sellingFactionIndex.index
        end

        if sellerIndex then
            local relations = Faction():getRelations(sellerIndex)

            if relations < -10000 then
                -- bad relations: faction pays less for the goods
                -- 10% to 100% from -100.000 to -10.000
                relationFactor = lerp(relations, -100000, -10000, 0.1, 1.0)
            elseif relations >= 50000 then
                -- very good relations: factions pays MORE for the goods
                -- 100% to 120% from 80.000 to 100.000
                relationFactor = lerp(relations, 80000, 100000, 1.0, 1.15)
            end

            if Faction().index == sellerIndex then relationFactor = 0 end
        end
    end
    
    local tradingStationFactor = 1
    if self.goodsMargins then
        tradingStationFactor = self.goodsMargins[goodName] or 1
    end

    local basePrice = round(good.price * self.buyPriceFactor * tradingStationFactor)
    local price = round(good.price * relationFactor * factor * self.buyPriceFactor * tradingStationFactor)

    return price, basePrice
end

-- price for which goods are sold from this to others
function TradingManager:getSellPrice(goodName, buyingFaction) -- overridden
    local good = self:getSoldGoodByName(goodName)
    if not good then return 0 end

    -- empty stock -> higher price
    local maxStock = self:getMaxStock(good.size)
    local factor = 1

    if maxStock > 0 then
        factor = math.min(maxStock, self:getNumGoods(goodName)) / maxStock -- 0 to 1 where 1 is 'full stock'
        factor = 1 - factor -- 1 to 0 where 0 is 'full stock'
        factor = factor * 0.2 -- 0.2 to 0
        factor = factor + 0.9 -- 1.1 to 0.9; 'no goods' to 'full'
    end

    local relationFactor = 1
    if buyingFaction then
        local sellerIndex = nil
        if type(buyingFaction) == "number" then
            sellerIndex = buyingFaction
        else
            sellerIndex = buyingFaction.index
        end

        if sellerIndex then
            local faction = Faction()
            if faction then
                local relations = faction:getRelations(sellerIndex)

                if relations < -10000 then
                    -- bad relations: faction wants more for the goods
                    -- 200% to 100% from -100.000 to -10.000
                    relationFactor = lerp(relations, -100000, -10000, 2.0, 1.0)
                elseif relations > 30000 then
                    -- good relations: factions start giving player better prices
                    -- 100% to 80% from 30.000 to 90.000
                    relationFactor = lerp(relations, 30000, 90000, 1.0, 0.8)
                end

                if faction.index == sellerIndex then relationFactor = 0 end
            end
        end
    end

    local tradingStationFactor = 1
    if self.goodsMargins then
        tradingStationFactor = self.goodsMargins[goodName] or 1
    end

    local price = round(good.price * relationFactor * factor * self.sellPriceFactor * tradingStationFactor)
    local basePrice = round(good.price * self.sellPriceFactor * tradingStationFactor)

    return price, basePrice
end


if onClient() then


local Azimuth = include("azimuthlib-basic")

function TradingManager:refreshUI() -- overridden
    local player = Player()
    local playerCraft = player.craft
    if not playerCraft then return end

    if playerCraft.factionIndex == player.allianceIndex then
        player = player.alliance
    end
    
    self.boughtGoodIndexByLine = {}
    self.boughtGoodLineByIndex = {}
    self.soldGoodIndexByLine = {}
    self.soldGoodLineByIndex = {}

    local i = 1
    for j, good in Azimuth.orderedPairs(self.boughtGoods, function(t, a, b) return t[a].name%_t < t[b].name%_t end) do
        self:updateBoughtGoodGui(i, good, self:getBuyPrice(good.name, player.index))
        self.boughtGoodIndexByLine[i] = j
        self.boughtGoodLineByIndex[j] = i
        i = i + 1
    end

    i = 1
    for j, good in Azimuth.orderedPairs(self.soldGoods, function(t, a, b) return t[a].name%_t < t[b].name%_t end) do
        self:updateSoldGoodGui(i, good, self:getSellPrice(good.name, player.index))
        self.soldGoodIndexByLine[i] = j
        self.soldGoodLineByIndex[j] = i
        i = i + 1
    end
end

local tradingTweaks_updateBoughtGoodGui = TradingManager.updateBoughtGoodGui
function TradingManager:updateBoughtGoodGui(index, good, price)
    if not self.guiInitialized then return end
    local line = self.boughtLines[index]
    if not line then return end

    tradingTweaks_updateBoughtGoodGui(self, index, good, price)

    local player = Player()
    local entity = Entity()
    if player.index == entity.factionIndex or player.allianceIndex == entity.factionIndex then
        line.button.active = true
        if line.configBtn then
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x - 70, line.button.upper.y)
        end
    else
        line.button.active = self.buyFromOthers
        if line.configBtn then
            line.swapBtn.visible = false
            line.configBtn.visible = false
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x, line.button.upper.y)
        end
    end
end

local tradingTweaks_updateSoldGoodGui = TradingManager.updateSoldGoodGui
function TradingManager:updateSoldGoodGui(index, good, price)
    if not self.guiInitialized then return end
    local line = self.soldLines[index]
    if not line then return end

    tradingTweaks_updateSoldGoodGui(self, index, good, price)

    local player = Player()
    local entity = Entity()
    if player.index == entity.factionIndex or player.allianceIndex == entity.factionIndex then
        line.button.active = true
        if line.configBtn then
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x - 70, line.button.upper.y)
        end
    else
        line.button.active = self.sellToOthers
        if line.configBtn then
            line.swapBtn.visible = false
            line.configBtn.visible = false
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x, line.button.upper.y)
        end
    end
end

function TradingManager:onBuyTextEntered(textBox) -- overridden
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(self.soldLines) do
        if line.number.index == textBox.index then
            goodIndex = self.soldGoodIndexByLine[i]
            break
        end
    end

    if goodIndex == nil then return end

    local good = self.soldGoods[goodIndex]

    if not good then
        -- no error reporting necessary, it's possible the goods got reset while waiting for sync
        -- self:reportError("Good with index " .. goodIndex .. " isn't sold.")
        return
    end

    -- make sure the player can't buy more than the station has in stock
    local stock = self:getNumGoods(good.name)

    if stock < newNumber then
        newNumber = stock
    end

    local player = Player()
    local ship = player.craft
    local shipFaction
    if ship.factionIndex == player.allianceIndex then
        shipFaction = player.alliance
    end
    if shipFaction == nil then
        shipFaction = player
    end
    if ship.freeCargoSpace == nil then return end --> no cargo bay

    -- make sure the player does not buy more than he can have in his cargo bay
    local maxShipHold = math.floor(ship.freeCargoSpace / good.size)
    local msg

    if maxShipHold < newNumber then
        newNumber = maxShipHold
        if newNumber == 0 then
            msg = "Not enough space in your cargo bay!"%_t
        else
            msg = "You can only store ${amount} of this good!"%_t % {amount = newNumber}
        end
    end

    -- make sure the player does not buy more than he can afford (if this isn't his station)
    if Faction().index ~= shipFaction.index then
        local maxAffordable = math.floor(shipFaction.money / self:getSellPrice(good.name, shipFaction.index))
        if shipFaction.infiniteResources then maxAffordable = math.huge end

        if maxAffordable < newNumber then
            newNumber = maxAffordable

            if newNumber == 0 then
                msg = "You can't afford any of this good!"%_t
            else
                msg = "You can only afford ${amount} of this good!"%_t % {amount = newNumber}
            end
        end
    end

    if msg then
        self:sendError(nil, msg)
    end

    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TradingManager:onSellTextEntered(textBox) -- overridden
    local enteredNumber = tonumber(textBox.text)
    if enteredNumber == nil then
        enteredNumber = 0
    end

    local newNumber = enteredNumber

    local goodIndex = nil
    for i, line in pairs(self.boughtLines) do
        if line.number.index == textBox.index then
            goodIndex = self.boughtGoodIndexByLine[i]
            break
        end
    end
    if goodIndex == nil then return end

    local good = self.boughtGoods[goodIndex]
    if not good then
        -- no error reporting necessary, it's possible the goods got reset while waiting for sync
        -- self:reportError("Good with index " .. goodIndex .. " isn't bought");
        return
    end

    local stock = self:getNumGoods(good.name)

    local maxAmountPlaceable = self:getMaxStock(good.size) - stock;
    if maxAmountPlaceable < newNumber then
        newNumber = maxAmountPlaceable
    end


    local ship = Player().craft

    local msg

    -- make sure the player does not sell more than he has in his cargo bay
    local amountOnPlayerShip = ship:getCargoAmount(good)
    if amountOnPlayerShip == nil then return end --> no cargo bay

    if amountOnPlayerShip < newNumber then
        newNumber = amountOnPlayerShip
        if newNumber == 0 then
            msg = "You don't have any of this!"%_t
        end
    end

    if msg then
        self:sendError(nil, msg)
    end

    -- maximum number of sellable things is the amount the player has on his ship
    if newNumber ~= enteredNumber then
        textBox.text = newNumber
    end
end

function TradingManager:onBuyButtonPressed(button) -- overridden
    local shipIndex = Player().craftIndex
    local lineIndex = nil
    local goodIndex = nil

    for i, line in ipairs(self.soldLines) do
        if line.button.index == button.index then
            lineIndex = i
            goodIndex = self.soldGoodIndexByLine[i]
            break
        end
    end

    if goodIndex == nil then
        return
    end

    local amount = self.soldLines[lineIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    local good = self.soldGoods[goodIndex]
    if not good then
        -- no error reporting necessary, it's possible the goods got reset while waiting for sync
        -- self:reportError("Good with index " .. goodIndex .. " of buy button not found.")
        return
    end

    invokeServerFunction("sellToShip", shipIndex, good.name, amount)
end

function TradingManager:onSellButtonPressed(button) -- overridden
    local shipIndex = Player().craftIndex
    local lineIndex = nil
    local goodIndex = nil

    for i, line in ipairs(self.boughtLines) do
        if line.button.index == button.index then
            lineIndex = i
            goodIndex = self.boughtGoodIndexByLine[i]
            break
        end
    end

    if goodIndex == nil then
        return
    end

    local amount = self.boughtLines[lineIndex].number.text
    if amount == "" then
        amount = 0
    else
        amount = tonumber(amount)
    end

    local good = self.boughtGoods[goodIndex]
    if not good then
        -- no error reporting necessary, it's possible the goods got reset while waiting for sync
        -- self:reportError("Good with index " .. goodIndex .. " of sell button not found.")
        return
    end

    invokeServerFunction("buyFromShip", shipIndex, good.name, amount)
end

function TradingManager:updateBoughtGoodAmount(index) -- overridden
    local good = self.boughtGoods[index]

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local player = Player()
        local playerCraft = player.craft
        if playerCraft and playerCraft.factionIndex == player.allianceIndex then
            player = player.alliance
        end

        if self.boughtGoodLineByIndex then
            local line = self.boughtGoodLineByIndex[index]
            self:updateBoughtGoodGui(line, good, self:getBuyPrice(good.name, player.index))
        end
    end
end

function TradingManager:updateSoldGoodAmount(index) -- overridden
    local good = self.soldGoods[index]

    if good ~= nil then -- it's possible that the production may start before the initialization of the client version of the factory
        local player = Player()
        local playerCraft = player.craft
        if playerCraft and playerCraft.factionIndex == player.allianceIndex then
            player = player.alliance
        end

        if self.soldGoodLineByIndex then
            local line = self.soldGoodLineByIndex[index]
            self:updateSoldGoodGui(line, good, self:getSellPrice(good.name, player.index))
        end
    end
end

function PublicNamespace.CreateTabbedWindow(caption, width)
    local menu = ScriptUI()

    if not PublicNamespace.tabbedWindow then
        local res = getResolution()
        local size = vec2(width or 950, 650)

        local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));

        window.caption = caption or ""
        window.showCloseButton = 1
        window.moveable = 1

        -- create a tabbed window inside the main window
        PublicNamespace.tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
        PublicNamespace.window = window
    end

    -- registers the window for this script, enabling the default window interaction calls like onShowWindow(), renderUI(), etc.
    -- if the same window is registered more than once, an interaction option will only be shown for the first registration
    menu:registerWindow(PublicNamespace.window, "Trade Goods"%_t);

    return PublicNamespace.tabbedWindow
end


else -- onServer


local tradingTweaks_sellToShip = TradingManager.sellToShip
function TradingManager:sellToShip(shipIndex, goodName, amount, noDockCheck)
    if not self.sellToOthers then
        local shipFaction = getInteractingFactionByShip(shipIndex, callingPlayer, AlliancePrivilege.SpendResources)
        if not shipFaction then return end

        local entity = Entity()
        if callingPlayer then
            local player = Player(callingPlayer)
            if player.index ~= entity.factionIndex and player.allianceIndex ~= entity.factionIndex then
                player:sendChatMessage("", 1, "The station doesn't sell goods right now."%_t)
                return
            end
        elseif shipFaction.index ~= entity.factionIndex then
            return
        end
    end
    if callingPlayer then
        noDockCheck = false -- no cheating
        -- no trading if faction relations are lower than certain threshold
        local status, msg = CheckFactionInteraction(callingPlayer, self.minTradingRelations and self.minTradingRelations or -10000)
        if not status then
            Player(callingPlayer):sendChatMessage("", 1, msg)
            return
        end
    end
    

    tradingTweaks_sellToShip(self, shipIndex, goodName, amount, noDockCheck)
end

local tradingTweaks_buyFromShip = TradingManager.buyFromShip
function TradingManager:buyFromShip(shipIndex, goodName, amount, noDockCheck)
    if not self.buyFromOthers then
        local shipFaction = getInteractingFactionByShip(shipIndex, callingPlayer, AlliancePrivilege.SpendResources)
        if not shipFaction then return end

        local entity = Entity()
        if callingPlayer then
            local player = Player(callingPlayer)
            if player.index ~= entity.factionIndex and player.allianceIndex ~= entity.factionIndex then
                player:sendChatMessage("", 1, "The station doesn't buy goods right now."%_t)
                return
            end
        elseif shipFaction.index ~= entity.factionIndex then
            return
        end
    end
    if callingPlayer then
        noDockCheck = false -- no cheating
        -- no trading if faction relations are lower than certain threshold
        local status, msg = CheckFactionInteraction(callingPlayer, self.minTradingRelations and self.minTradingRelations or -10000)
        if not status then
            Player(callingPlayer):sendChatMessage("", 1, msg)
            return
        end
    end

    tradingTweaks_buyFromShip(self, shipIndex, goodName, amount, noDockCheck)
end


end