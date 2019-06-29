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

local tradingTweaks_getBuyPrice = TradingManager.getBuyPrice
function TradingManager:getBuyPrice(goodName, sellingFactionIndex)
    local price, basePrice = tradingTweaks_getBuyPrice(self, goodName, sellingFactionIndex)
    if not basePrice then return price end

    local tradingStationFactor = 1
    if self.goodsMargins then
        tradingStationFactor = self.goodsMargins[goodName] or 1
    end

    return round(price * tradingStationFactor), round(basePrice * tradingStationFactor)
end

local tradingTweaks_getSellPrice = TradingManager.getSellPrice
function TradingManager:getSellPrice(goodName, buyingFaction)
    local price, basePrice = tradingTweaks_getSellPrice(self, goodName, buyingFaction)
    if not basePrice then return price end

    local tradingStationFactor = 1
    if self.goodsMargins then
        tradingStationFactor = self.goodsMargins[goodName] or 1
    end

    return round(price * tradingStationFactor), round(basePrice * tradingStationFactor)
end

local tradingTweaks_CreateNamespace = PublicNamespace.CreateNamespace
function PublicNamespace.CreateNamespace()
    local result = tradingTweaks_CreateNamespace()

    result.trader.namespace = result -- so trader could call current namespace functions
    return result
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

    self.factoryOptionalGoods = {}
    if self.namespace and self.namespace.tradingTweaks_getProduction then -- it's factory
        local production = self.namespace.tradingTweaks_getProduction()
        if production and production.ingredients then
            for _, ingredient in pairs(production.ingredients) do
                if ingredient.optional == 1 then
                    self.factoryOptionalGoods[ingredient.name] = true
                end
            end
        end
    end
    
    local i = 1
    local price, basePrice
    for j, good in Azimuth.orderedPairs(self.boughtGoods, function(t, a, b) return t[a].name%_t < t[b].name%_t end) do
        price, basePrice = self:getBuyPrice(good.name, player.index)
        self:updateBoughtGoodGui(i, good, price, basePrice, self.factoryOptionalGoods[good.name])
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

function TradingManager:updateBoughtGoodGui(index, good, price, _, isOptional) -- overridden
    if not self.guiInitialized then return end

    local line = self.boughtLines[index]
    if not line then return end

    local maxAmount = self:getMaxStock(good.size)
    local amount = self:getNumGoods(good.name)

    if isOptional then
        line.name.caption = good:displayName(100) .. " (Optional)"%_t
    else
        line.name.caption = good:displayName(100)
    end
    line.stock.caption = amount .. "/" .. maxAmount
    line.price.caption = createMonetaryString(price)
    line.size.caption = round(good.size, 2)
    line.icon.picture = good.icon

    local ownCargo = 0
    local player = Player()
    local ship = Entity(player.craftIndex)
    if ship then
        ownCargo = ship:getCargoAmount(good) or 0
    end
    if ownCargo == 0 then ownCargo = "-" end
    line.you.caption = tostring(ownCargo)

    line:show()

    local entity = Entity()
    if player.index == entity.factionIndex or player.allianceIndex == entity.factionIndex then
        if line.configBtn then
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x - 70, line.button.upper.y)
        end
    else
        if line.configBtn then
            line.swapBtn.visible = false
            line.configBtn.visible = false
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x, line.button.upper.y)
        end
    end
    line.button.active = self.buyFromOthers
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
        if line.configBtn then
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x - 70, line.button.upper.y)
        end
    else
        if line.configBtn then
            line.swapBtn.visible = false
            line.configBtn.visible = false
            line.button.upper = vec2(PublicNamespace.tabbedWindow.upper.x, line.button.upper.y)
        end
    end
    line.button.active = self.sellToOthers
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
            local isOptional = false
            local price, basePrice = self:getBuyPrice(good.name, player.index)
            if self.factoryOptionalGoods then
                isOptional = self.factoryOptionalGoods[good.name]
            end
            self:updateBoughtGoodGui(line, good, price, basePrice, isOptional)
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


end