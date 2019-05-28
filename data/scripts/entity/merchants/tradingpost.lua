include("goods")
local Azimuth = include("azimuthlib-basic")

local configOptions = {
  _version = {default = "0.1", comment = "Config version. Don't touch."},
  LogLevel = {default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."}
}
local config, isModified = Azimuth.loadConfig("TradingTweaks", configOptions)
if isModified then
    Azimuth.saveConfig("TradingTweaks", config, configOptions)
end
local Log = Azimuth.logs("TradingTweaks", config.LogLevel)


TradingPost.trader.tax = 0
TradingPost.trader.factionPaymentFactor = 1.0 -- players pay when trading station buys goods

if onClient() then


local tradingTweaks
local tradingTweaks_configTab, tradingTweaks_allowBuyCheckBox, tradingTweaks_allowSellCheckBox, tradingTweaks_addGoodComboBox, tradingTweaks_goodConfigWindow, tradingTweaks_goodComboBox, tradingTweaks_marginLabel, tradingTweaks_marginSlider
local tradingTweaks_boughtLineByConfigBtn = {}
local tradingTweaks_soldLineByConfigBtn = {}
local tradingTweaks_boughtLineBySwapBtn = {}
local tradingTweaks_soldLineBySwapBtn = {}
local tradingTweaks_indexByGood = {}
local tradingTweaks_goodByIndex = {}
local tradingTweaks_currentGood = {}

local function tradingTweaks_getAddGoodName()
    local goodName = tradingTweaks_goodByIndex[tradingTweaks_addGoodComboBox.selectedIndex+1]
    if not goodName then
        Log.Error("onGoodChanged - good doesn't exist")
        return
    end
    -- Check if good already exists
    local found = false
    for _, good in pairs(TradingPost.trader.boughtGoods) do
        if good.name == goodName then
            found = true
            break
        end
    end
    if not found then
        for _, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == goodName then
                found = true
                break
            end
        end
    end
    if found then -- can't change, already exists
        displayChatMessage("The station already sells/buys this type of good."%_t, "", 1)
        return
    end
    return goodName
end

local tradingTweaks_receiveGoods = TradingPost.trader.receiveGoods
function TradingPost.trader:receiveGoods(buyFactor, sellFactor, boughtGoods_in, soldGoods_in, policies_in, tradingTweaks_in)
    if tradingTweaks_in then
        tradingTweaks = tradingTweaks_in
        self.buyFromOthers = tradingTweaks.buyFromOthers
        self.sellToOthers = tradingTweaks.sellToOthers
        self.goodsMargins = tradingTweaks.goodsMargins
        if tradingTweaks_allowBuyCheckBox then
            tradingTweaks_allowBuyCheckBox:setCheckedNoCallback(tradingTweaks.buyFromOthers)
            tradingTweaks_allowSellCheckBox:setCheckedNoCallback(tradingTweaks.sellToOthers)
        end
    end

    -- hide removed lines
    local endLine = math.min(15, TradingPost.trader.numBought)
    for i = #boughtGoods_in, endLine do
        TradingPost.trader.boughtLines[i]:hide()
    end
    endLine = math.min(15, TradingPost.trader.numSold)
    for i = #soldGoods_in, endLine do
        TradingPost.trader.soldLines[i]:hide()
    end

    tradingTweaks_receiveGoods(self, buyFactor, sellFactor, boughtGoods_in, soldGoods_in, policies_in)
end

function TradingPost.trader:buildGui(window, guiType) -- overridden
    local buttonCaption = ""
    local buttonCallback = ""
    local textCallback = ""
    local swapCallback = ""
    local configCallback = ""

    if guiType == 1 then
        buttonCaption = "Buy"%_t
        buttonCallback = "onBuyButtonPressed"
        textCallback = "onBuyTextEntered"
        swapCallback = "tradingTweaks_onBuySwapButtonPressed"
        configCallback = "tradingTweaks_onBuyConfigButtonPressed"
    else
        buttonCaption = "Sell"%_t
        buttonCallback = "onSellButtonPressed"
        textCallback = "onSellTextEntered"
        swapCallback = "tradingTweaks_onSellSwapButtonPressed"
        configCallback = "tradingTweaks_onSellConfigButtonPressed"
    end

    local size = window.size

    local pictureX = 270
    local nameX = 10
    local stockX = 310
    local volX = 460
    local priceX = 530
    local youX = 630
    local textBoxX = 720
    local buttonX = 790

    local buttonSize = 70

    -- header
    window:createLabel(vec2(nameX, 0), "Name"%_t, 15)
    window:createLabel(vec2(stockX, 0), "Stock"%_t, 15)
    window:createLabel(vec2(priceX, 0), "Cr"%_t, 15)
    window:createLabel(vec2(volX, 0), "Vol"%_t, 15)

    if guiType == 1 then
        window:createLabel(vec2(youX, 0), "Max"%_t, 15)
    else
        window:createLabel(vec2(youX, 0), "You"%_t, 15)
    end

    local y = 25
    for i = 1, 15 do

        local yText = y + 6

        local frame = window:createFrame(Rect(0, y, textBoxX - 10, 30 + y))

        local icon = window:createPicture(Rect(pictureX, yText - 5, 29 + pictureX, 29 + yText - 5), "")
        local nameLabel = window:createLabel(vec2(nameX, yText), "", 15)
        local stockLabel = window:createLabel(vec2(stockX, yText), "", 15)
        local priceLabel = window:createLabel(vec2(priceX, yText), "", 15)
        local sizeLabel = window:createLabel(vec2(volX, yText), "", 15)
        local youLabel = window:createLabel(vec2(youX, yText), "", 15)
        local numberTextBox = window:createTextBox(Rect(textBoxX, yText - 6, 60 + textBoxX, 30 + yText - 6), textCallback)
        local button = window:createButton(Rect(buttonX, yText - 6, window.size.x - 70, 30 + yText - 6), buttonCaption, buttonCallback)
        local swapBtn = window:createButton(Rect(window.size.x - 60, yText - 6, window.size.x - 35, 30 + yText - 6), "", swapCallback)
        local configBtn = window:createButton(Rect(window.size.x - 25, yText - 6, window.size.x, 30 + yText - 6), "", configCallback)

        button.maxTextSize = 16

        swapBtn.icon = "data/textures/icons/tradingtweaks/back-forth-mini.png"
        swapBtn.tooltip = "Moves good from sold to bought and vice versa."%_t

        configBtn.icon = "data/textures/icons/tradingtweaks/cog-mini.png"

        numberTextBox.text = "0"
        numberTextBox.allowedCharacters = "0123456789"
        numberTextBox.clearOnClick = 1

        icon.isIcon = 1

        local show = function (self)
            self.icon.visible = true
            self.frame.visible = true
            self.name.visible = true
            self.stock.visible = true
            self.price.visible = true
            self.size.visible = true
            self.number.visible = true
            self.button.visible = true
            self.swapBtn.visible = true
            self.configBtn.visible = true
            self.you.visible = true
        end
        local hide = function (self)
            self.icon.visible = false
            self.frame.visible = false
            self.name.visible = false
            self.stock.visible = false
            self.price.visible = false
            self.size.visible = false
            self.number.visible = false
            self.button.visible = false
            self.swapBtn.visible = false
            self.configBtn.visible = false
            self.you.visible = false
        end

        local line = {icon = icon, frame = frame, name = nameLabel, stock = stockLabel, price = priceLabel, you = youLabel, size = sizeLabel, number = numberTextBox, button = button, swapBtn = swapBtn, configBtn = configBtn, show = show, hide = hide}
        line:hide()

        if guiType == 1 then
            self.soldLines[#self.soldLines+1] = line
            tradingTweaks_soldLineByConfigBtn[configBtn.index] = i
            tradingTweaks_soldLineBySwapBtn[swapBtn.index] = i
        else
            self.boughtLines[#self.boughtLines+1] = line
            tradingTweaks_boughtLineByConfigBtn[configBtn.index] = i
            tradingTweaks_boughtLineBySwapBtn[swapBtn.index] = i
        end

        y = y + 35
    end
end

local tradingTweaks_initUI = TradingPost.initUI
function TradingPost.initUI()
    local tabbedWindow = TradingAPI.CreateTabbedWindow("Trading Post"%_t, 985)

    tradingTweaks_initUI()

    tradingTweaks_configTab = tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Station configuration"%_t)
    TradingPost.tradingTweaks_buildConfigUI(tradingTweaks_configTab)

    local menu = ScriptUI()
    local res = getResolution()
    local size = vec2(400, 220)
    tradingTweaks_goodConfigWindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    tradingTweaks_goodConfigWindow.caption = "Good Settings"%_t
    tradingTweaks_goodConfigWindow.showCloseButton = 1
    tradingTweaks_goodConfigWindow.moveable = 1
    tradingTweaks_goodConfigWindow.visible = false
    
    local lister = UIVerticalLister(Rect(10, 10, size.x - 10, size.y - 10), 5, 0)

    local label = tradingTweaks_goodConfigWindow:createLabel(Rect(), "Change good"%_t, 12)
    lister:placeElementTop(label)
    label.centered = true

    lister:nextRect(5)

    tradingTweaks_goodComboBox = tradingTweaks_goodConfigWindow:createComboBox(Rect(), "tradingTweaks_onGoodChanged")
    local i = 1
    for _, good in Azimuth.orderedPairs(goodsArray, function(t, a, b) return t[a].name%_t < t[b].name%_t end) do
        tradingTweaks_goodComboBox:addEntry(good.name%_t)
        i = i + 1
    end
    lister:placeElementTop(tradingTweaks_goodComboBox)

    lister:nextRect(10)
    
    tradingTweaks_marginLabel = tradingTweaks_goodConfigWindow:createLabel(Rect(), "Buy/Sell price margin %"%_t, 12)
    lister:placeElementTop(tradingTweaks_marginLabel)
    tradingTweaks_marginLabel.centered = true
    tradingTweaks_marginLabel.tooltip = "Sets the price margin of goods bought and sold by this station. Low prices attract more buyers, high prices attract more sellers."%_t

    tradingTweaks_marginSlider = tradingTweaks_goodConfigWindow:createSlider(Rect(), -50, 50, 100, "", "tradingTweaks_onGoodMarginChanged")
    lister:placeElementTop(tradingTweaks_marginSlider)
    tradingTweaks_marginSlider:setValueNoCallback(0)
    tradingTweaks_marginSlider.unit = "%"

    lister:nextRect(25)
    
    local btn = tradingTweaks_goodConfigWindow:createButton(Rect(0, 0, 200, 30), "Remove"%_t, "tradingTweaks_onGoodRemove")
    lister:placeElementTop(btn)
end

local tradingTweaks_onShowWindow = TradingPost.onShowWindow
function TradingPost.onShowWindow(optionIndex)
    tradingTweaks_onShowWindow()

    if tradingTweaks_configTab then
        local player = Player()
        local faction = Faction()
        if player.index == faction.index or player.allianceIndex == faction.index then
            TradingAPI.tabbedWindow:activateTab(tradingTweaks_configTab)
        else
            TradingAPI.tabbedWindow:deactivateTab(tradingTweaks_configTab)
        end
    end
end

local tradingTweaks_onCloseWindow = TradingPost.onCloseWindow
function TradingPost.onCloseWindow()
    if tradingTweaks_onCloseWindow then tradingTweaks_onCloseWindow() end

    tradingTweaks_goodConfigWindow.visible = false
end

function TradingPost.tradingTweaks_buildConfigUI(tab)
    local vsplit = UIVerticalSplitter(Rect(5, 5, tab.size.x - 5, tab.size.y - 5), 20, 0, 0.5)
    lister = UIVerticalLister(vsplit.left, 5, 0)

    tradingTweaks_allowBuyCheckBox = tab:createCheckBox(Rect(), "Buy goods from others"%_t, "tradingTweaks_onSettingsChanged")
    lister:placeElementTop(tradingTweaks_allowBuyCheckBox)
    tradingTweaks_allowBuyCheckBox.tooltip = "If checked, the station will buy goods from traders from other factions than you."%_t

    tradingTweaks_allowSellCheckBox = tab:createCheckBox(Rect(), "Sell goods to others"%_t, "tradingTweaks_onSettingsChanged")
    lister:placeElementTop(tradingTweaks_allowSellCheckBox)
    tradingTweaks_allowSellCheckBox.tooltip = "If checked, the station will sell goods to traders from other factions than you."%_t

    lister = UIVerticalLister(vsplit.right, 5, 0)

    tradingTweaks_addGoodComboBox = tab:createComboBox(Rect(), "")
    local i = 1
    for _, good in Azimuth.orderedPairs(goodsArray, function(t, a, b) return t[a].name%_t < t[b].name%_t end) do
        tradingTweaks_indexByGood[good.name] = i
        tradingTweaks_goodByIndex[i] = good.name
        tradingTweaks_addGoodComboBox:addEntry(good.name%_t)
        i = i + 1
    end
    lister:placeElementTop(tradingTweaks_addGoodComboBox)

    lister:nextRect(10)
    
    local btn = tab:createButton(Rect(), "Add sold good"%_t, "tradingTweaks_onAddSoldGoodButtonPressed")
    btn.maxTextSize = 16
    lister:placeElementTop(btn)
    btn = tab:createButton(Rect(), "Add bought good"%_t, "tradingTweaks_onAddBoughtGoodButtonPressed")
    btn.maxTextSize = 16
    lister:placeElementTop(btn)

    if tradingTweaks then
        tradingTweaks_allowBuyCheckBox:setCheckedNoCallback(tradingTweaks.buyFromOthers)
        tradingTweaks_allowSellCheckBox:setCheckedNoCallback(tradingTweaks.sellToOthers)
    end
end

function TradingPost.tradingTweaks_onBuySwapButtonPressed(button)
    local line = tradingTweaks_soldLineBySwapBtn[button.index]
    if not line then
        Log.Error("Sell swap button - good doesn't exist")
        return
    end
    local goodIndex = TradingPost.trader.soldGoodIndexByLine[line]
    if not goodIndex then
        Log.Error("Buy swap button - good doesn't exist")
        return
    end
    local good = TradingPost.trader.soldGoods[goodIndex]
    if not good then return end
    if TradingPost.trader.numBought == 15 then
        displayChatMessage("Reached the limits of 15 bought/sold goods."%_t, "", 1)
        return
    end

    invokeServerFunction("tradingTweaks_swapGood", true, good.name)
end

function TradingPost.tradingTweaks_onSellSwapButtonPressed(button)
    local line = tradingTweaks_boughtLineBySwapBtn[button.index]
    if not line then
        Log.Error("Sell swap button - good doesn't exist")
        return
    end
    local goodIndex = TradingPost.trader.boughtGoodIndexByLine[line]
    if not goodIndex then
        Log.Error("Sell swap button - good doesn't exist")
        return
    end
    local good = TradingPost.trader.boughtGoods[goodIndex]
    if not good then return end
    if TradingPost.trader.numSold == 15 then
        displayChatMessage("Reached the limits of 15 bought/sold goods."%_t, "", 1)
        return
    end

    invokeServerFunction("tradingTweaks_swapGood", false, good.name)
end

function TradingPost.tradingTweaks_onBuyConfigButtonPressed(button)
    local line = tradingTweaks_soldLineByConfigBtn[button.index]
    if not line then
        Log.Error("Buy config button - good doesn't exist")
        return
    end
    local goodIndex = TradingPost.trader.soldGoodIndexByLine[line]
    if not goodIndex then
        Log.Error("Buy config button - good doesn't exist")
        return
    end
    local good = TradingPost.trader.soldGoods[goodIndex]
    if not good then return end

    tradingTweaks_currentGood = { sold = true, name = good.name }

    tradingTweaks_goodComboBox:setSelectedIndexNoCallback(tradingTweaks_indexByGood[good.name]-1)

    local factor = TradingPost.trader.goodsMargins[good.name] or 1
    tradingTweaks_marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(factor * 100.0)}
    tradingTweaks_marginSlider:setValueNoCallback(round((factor - 1.0) * 100.0))

    tradingTweaks_goodConfigWindow.visible = true
end

function TradingPost.tradingTweaks_onSellConfigButtonPressed(button)
    local line = tradingTweaks_boughtLineByConfigBtn[button.index]
    if not line then
        Log.Error("Sell config button - good doesn't exist")
        return
    end
    local goodIndex = TradingPost.trader.boughtGoodIndexByLine[line]
    if not goodIndex then
        Log.Error("Sell config button - good doesn't exist")
        return
    end
    local good = TradingPost.trader.boughtGoods[goodIndex]
    if not good then return end

    tradingTweaks_currentGood = { sold = false, name = good.name }

    tradingTweaks_goodComboBox:setSelectedIndexNoCallback(tradingTweaks_indexByGood[good.name]-1)

    local factor = TradingPost.trader.goodsMargins[good.name] or 1
    tradingTweaks_marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(factor * 100.0)}
    tradingTweaks_marginSlider:setValueNoCallback(round((factor - 1.0) * 100.0))

    tradingTweaks_goodConfigWindow.visible = true
end

function TradingPost.tradingTweaks_onGoodChanged()
    local goodName = tradingTweaks_goodByIndex[tradingTweaks_goodComboBox.selectedIndex+1]
    if not goodName then
        Log.Error("onGoodChanged - good doesn't exist")
        return
    end
    if tradingTweaks_currentGood.name == goodName then return end
    -- Check if good already exists
    local found = false
    for _, good in pairs(TradingPost.trader.boughtGoods) do
        if good.name == goodName then
            found = true
            break
        end
    end
    if not found then
        for _, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == goodName then
                found = true
                break
            end
        end
    end
    if found then -- can't change, already exists
        tradingTweaks_goodComboBox:setSelectedIndexNoCallback(tradingTweaks_indexByGood[tradingTweaks_currentGood.name]-1)
        displayChatMessage("The station already sells/buys this type of good."%_t, "", 1)
        return
    end
    -- Hide window
    tradingTweaks_goodConfigWindow.visible = false
    -- Change goods
    invokeServerFunction("tradingTweaks_changeGood", tradingTweaks_currentGood.sold, tradingTweaks_currentGood.name, goodName)
end

function TradingPost.tradingTweaks_onGoodMarginChanged()
    local factor = 1.0 + tradingTweaks_marginSlider.value / 100.0
    TradingPost.trader.goodsMargins[tradingTweaks_currentGood.name] = factor
    tradingTweaks_marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(factor * 100.0)}
    TradingPost.tradingTweaks_onSettingsChanged()
end

function TradingPost.tradingTweaks_onGoodRemove()
    tradingTweaks_goodConfigWindow.visible = false
    invokeServerFunction("tradingTweaks_removeGood", tradingTweaks_currentGood.sold, tradingTweaks_currentGood.name)
end

function TradingPost.tradingTweaks_onAddBoughtGoodButtonPressed()
    local goodName = tradingTweaks_getAddGoodName()
    if goodName then
        if TradingPost.trader.numBought == 15 then
            displayChatMessage("Reached the limits of 15 bought/sold goods."%_t, "", 1)
            return
        end
        invokeServerFunction("tradingTweaks_addGood", true, goodName)
    end
end

function TradingPost.tradingTweaks_onAddSoldGoodButtonPressed()
    local goodName = tradingTweaks_getAddGoodName()
    if goodName then
        if TradingPost.trader.numSold == 15 then
            displayChatMessage("Reached the limits of 15 bought/sold goods."%_t, "", 1)
            return
        end
        invokeServerFunction("tradingTweaks_addGood", false, goodName)
    end
end

function TradingPost.tradingTweaks_onSettingsChanged()
    local config = {
      buyFromOthers = tradingTweaks_allowBuyCheckBox.checked,
      sellToOthers = tradingTweaks_allowSellCheckBox.checked,
      goodsMargins = TradingPost.trader.goodsMargins
    }
    invokeServerFunction("tradingTweaks_setSettings", config)
end


else -- onServer


function TradingPost.trader:sendGoods(playerIndex) -- overridden
    if playerIndex then
        local player = Player(playerIndex)
        local tradingTweaks = { -- sync with client
          buyFromOthers = self.buyFromOthers,
          sellToOthers = self.sellToOthers,
          goodsMargins = self.goodsMargins
        }
        invokeClientFunction(player, "receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, tradingTweaks)
    else
        broadcastInvokeClientFunction("receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, tradingTweaks)
    end
end

local tradingTweaks_secureTradingGoods = TradingPost.trader.secureTradingGoods
function TradingPost.trader:secureTradingGoods()
    local data = tradingTweaks_secureTradingGoods(self)

    data.goodsMargins = self.goodsMargins
    return data
end

local tradingTweaks_restoreTradingGoods = TradingPost.trader.restoreTradingGoods
function TradingPost.trader:restoreTradingGoods(data)
    self.goodsMargins = data.goodsMargins or {}
    if not Entity().aiOwned then
        -- reset to normal
        data.buyPriceFactor = 1
        data.sellPriceFactor = 1
        -- if player/alliance owns a trading station, turn off buying at first, so people will not lose money
        local entity = Entity()
        if entity:getValue("TradingTweaks") then
            entity:setValue("TradingTweaks", true)
            TradingPost.trader.buyFromOthers = false
        end
    end

    tradingTweaks_restoreTradingGoods(self, data)
end

local tradingTweaks_initialize = TradingPost.initialize
function TradingPost.initialize()
    local entity = Entity()
    local goodsGenerated = entity:getValue("goods_generated")

    tradingTweaks_initialize()

    if not entity.aiOwned then 
        TradingPost.trader.useUpGoodsEnabled = false -- don't consume goods
        -- reset to normal
        TradingPost.trader.buyPriceFactor = 1
        TradingPost.trader.sellPriceFactor = 1
        -- disable buying so people will not lose their money
        if not goodsGenerated and not entity:getValue("TradingTweaks") then -- trading station was just created
            entity:setValue("TradingTweaks", true)
            TradingPost.trader.buyFromOthers = false
            -- add margin tables for goods
            if not TradingPost.trader.goodsMargins then TradingPost.trader.goodsMargins = {} end
        end
    end
end

function TradingPost.tradingTweaks_setSettings(config)
    local player = Player(callingPlayer)
    local faction = Faction()
    if player.index ~= faction.index and player.allianceIndex ~= faction.index then return end
    
    TradingPost.trader.buyFromOthers = config.buyFromOthers
    TradingPost.trader.sellToOthers = config.sellToOthers
    if config.goodsMargins then
        TradingPost.trader.goodsMargins = {}
        for name, factor in pairs(config.goodsMargins) do
            TradingPost.trader.goodsMargins[name] = math.max(0.5, math.min(1.5, factor))
        end
    end
    TradingPost.sendGoods() -- broadcast
end
callable(TradingPost, "tradingTweaks_setSettings")

function TradingPost.tradingTweaks_addGood(isSold, goodName)
    local player = Player(callingPlayer)
    local faction = Faction()
    if player.index ~= faction.index and player.allianceIndex ~= faction.index then return end

    local newGood = goods[goodName]
    if not newGood then
        Log.Error("addGood - incorrect good name")
        return
    end
    local found = false
    for _, good in pairs(TradingPost.trader.boughtGoods) do
        if good.name == goodName then
            found = true
            break
        end
    end
    if not found then
        for _, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == goodName then
                found = true
                break
            end
        end
    end
    if found then
        player:sendChatMessage("", 1, "The station already sells/buys this type of good."%_t)
        return
    end
    player:sendChatMessage("", 3, "Added new good '%s' to trading station."%_t, goodName)
    if isSold then
        if TradingPost.trader.numBought == 15 then
            player:sendChatMessage("", 1, "Reached the limits of 15 bought/sold goods."%_t)
            return
        end
        TradingPost.trader.boughtGoods[#TradingPost.trader.boughtGoods+1] = newGood:good()
        TradingPost.trader.numBought = #TradingPost.trader.boughtGoods
    else
        if TradingPost.trader.numSold == 15 then
            player:sendChatMessage("", 1, "Reached the limits of 15 bought/sold goods."%_t)
            return
        end
        TradingPost.trader.soldGoods[#TradingPost.trader.soldGoods+1] = newGood:good()
        TradingPost.trader.numSold = #TradingPost.trader.soldGoods
    end
    TradingPost.sendGoods() -- broadcast
end
callable(TradingPost, "tradingTweaks_addGood")

function TradingPost.tradingTweaks_changeGood(isSold, prevName, newName)
    local player = Player(callingPlayer)
    local faction = Faction()
    if player.index ~= faction.index and player.allianceIndex ~= faction.index then return end
    
    local newGood = goods[newName]
    if not newGood then
        Log.Error("changeGood - incorrect good name")
        return
    end
    local found = false
    for _, good in pairs(TradingPost.trader.boughtGoods) do
        if good.name == newName then
            found = true
            break
        end
    end
    if not found then
        for _, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == newName then
                found = true
                break
            end
        end
    end
    if found then
        player:sendChatMessage("", 1, "The station already sells/buys this type of good."%_t)
        return
    end
    found = false
    if isSold then
        for index, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == prevName then
                TradingPost.trader.soldGoods[index] = newGood:good()
                found = true
                break
            end
        end
    else
        for index, good in pairs(TradingPost.trader.boughtGoods) do
            if good.name == prevName then
                TradingPost.trader.boughtGoods[index] = newGood:good()
                found = true
                break
            end
        end
    end
    if not found then
        Log.Error("changeGood - couldn't find the old good")
        return
    end
    TradingPost.trader.goodsMargins[prevName] = nil
    TradingPost.sendGoods() -- broadcast
end
callable(TradingPost, "tradingTweaks_changeGood")

function TradingPost.tradingTweaks_swapGood(isSold, goodName)
    local player = Player(callingPlayer)
    local faction = Faction()
    if player.index ~= faction.index and player.allianceIndex ~= faction.index then return end

    local newGood = goods[goodName]
    if not newGood then
        Log.Error("swapGood - incorrect good name")
        return
    end
    local found = false
    if isSold then
        if TradingPost.trader.numBought == 15 then
            player:sendChatMessage("", 1, "Reached the limits of 15 bought/sold goods."%_t)
            return
        end
        for index, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == goodName then
                table.remove(TradingPost.trader.soldGoods, index)
                found = true
                break
            end
        end
        if not found then
            Log.Error("swapGood - couldn't find good")
            return
        end
        TradingPost.trader.boughtGoods[#TradingPost.trader.boughtGoods+1] = newGood:good()
    else
        if TradingPost.trader.numSold == 15 then
            player:sendChatMessage("", 1, "Reached the limits of 15 bought/sold goods."%_t)
            return
        end
        for index, good in pairs(TradingPost.trader.boughtGoods) do
            if good.name == goodName then
                table.remove(TradingPost.trader.boughtGoods, index)
                found = true
                break
            end
        end
        if not found then
            Log.Error("swapGood - couldn't find good")
            return
        end
        TradingPost.trader.soldGoods[#TradingPost.trader.soldGoods+1] = newGood:good()
    end
    TradingPost.trader.numSold = #TradingPost.trader.soldGoods
    TradingPost.trader.numBought = #TradingPost.trader.boughtGoods
    TradingPost.sendGoods() -- broadcast
end
callable(TradingPost, "tradingTweaks_swapGood")

function TradingPost.tradingTweaks_removeGood(isSold, prevName)
    local player = Player(callingPlayer)
    local faction = Faction()
    if player.index ~= faction.index and player.allianceIndex ~= faction.index then return end

    local found = false
    if isSold then
        for index, good in pairs(TradingPost.trader.soldGoods) do
            if good.name == prevName then
                table.remove(TradingPost.trader.soldGoods, index)
                found = true
                break
            end
        end
        TradingPost.trader.numSold = #TradingPost.trader.soldGoods
    else
        for index, good in pairs(TradingPost.trader.boughtGoods) do
            if good.name == prevName then
                table.remove(TradingPost.trader.boughtGoods, index)
                found = true
                break
            end
        end
        TradingPost.trader.numBought = #TradingPost.trader.boughtGoods
    end
    if not found then
        Log.Error("removeGood - couldn't find good")
        return
    end
    TradingPost.trader.goodsMargins[prevName] = nil
    TradingPost.sendGoods() -- broadcast
end
callable(TradingPost, "tradingTweaks_removeGood")


end