include("goods")

local Azimuth, TradingTweaksConfig = unpack(include("tradingtweaksinit"))
local tradingTweaks_tabbedWindow, tradingTweaks_addSoldGood, tradingTweaks_toggleSellButton, tradingTweaks_addBoughtGood, tradingTweaks_configTab, tradingTweaks_basePriceLabel, tradingTweaks_basePriceSlider, tradingTweaks_statsLabels -- UI
local tradingTweaks_allowedGoods, tradingTweaks_allowedToChange -- client
local tradingTweaks_initUI, tradingTweaks_onShowWindow, tradingTweaks_buildBuyGui, tradingTweaks_buildSellGui, tradingTweaks_refreshUI, tradingTweaks_refreshConfigUI -- extended client functions
local tradingTweaks_useUpBoughtGoods -- extended server functions


if onClient() then


include("azimuthlib-uiproportionalsplitter")

-- PREDEFINED --

tradingTweaks_initUI = TradingPost.initUI
function TradingPost.initUI(...)
    local fobidden = { ["Iron Ore"] = true, ["Titanium Ore"] = true, ["Naonite Ore"] = true, ["Trinium Ore"] = true, ["Xanion Ore"] = true, ["Ogonite Ore"] = true, ["Avorion Ore"] = true, ["Scrap Iron"] = true, ["Scrap Titanium"] = true, ["Scrap Naonite"] = true, ["Scrap Trinium"] = true, ["Scrap Xanion"] = true, ["Scrap Ogonite"] = true, ["Scrap Avorion"] = true }
    tradingTweaks_allowedGoods = {}
    for i, good in ipairs(goodsArray) do
        if not good.illegal and not fobidden[good.name] then
            tradingTweaks_allowedGoods[#tradingTweaks_allowedGoods+1] = good:good()
        end
    end
    table.sort(tradingTweaks_allowedGoods, function(a, b) return a:displayName(1) < b:displayName(1) end)

    tradingTweaks_tabbedWindow = TradingAPI.CreateTabbedWindow("Trading Post"%_t, 985)

    tradingTweaks_initUI(...)

    tradingTweaks_configTab = tradingTweaks_tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Station configuration"%_t)
    TradingPost.tradingTweaks_buildConfigUI(tradingTweaks_configTab)
end

tradingTweaks_onShowWindow = TradingPost.onShowWindow
function TradingPost.onShowWindow(...)
    tradingTweaks_onShowWindow(...)

    tradingTweaks_allowedToChange = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)

    if tradingTweaks_allowedToChange then
        tradingTweaks_addSoldGood.visible = true
        tradingTweaks_toggleSellButton.visible = true
        tradingTweaks_addBoughtGood.visible = true
        TradingPost.toggleBuyButton.visible = true
        tradingTweaks_tabbedWindow:activateTab(tradingTweaks_configTab)
    else
        tradingTweaks_addSoldGood.visible = false
        tradingTweaks_toggleSellButton.visible = false
        tradingTweaks_addBoughtGood.visible = false
        TradingPost.toggleBuyButton.visible = false
        tradingTweaks_tabbedWindow:deactivateTab(tradingTweaks_configTab)
    end
end

-- FUNCTIONS --

tradingTweaks_buildBuyGui = TradingPost.trader.buildBuyGui
function TradingPost.trader:buildBuyGui(buyTab, ...)
    tradingTweaks_buildBuyGui(self, buyTab, ...)

    TradingPost.tradingTweaks_buildModGui(buyTab, 1)

    tradingTweaks_addSoldGood = buyTab:createButton(Rect(buyTab.size.x - 65, -5, buyTab.size.x - 35, 25), "", "tradingTweaks_onAddSoldGood")
    tradingTweaks_addSoldGood.icon = "data/textures/icons/plus.png"
    tradingTweaks_addSoldGood.tooltip = "Add good"%_t

    tradingTweaks_toggleSellButton = buyTab:createButton(Rect(buyTab.size.x - 30, -5, buyTab.size.x, 25), "", "tradingTweaks_onToggleSellPressed")
    tradingTweaks_toggleSellButton.icon = "data/textures/icons/buy.png"
end

tradingTweaks_buildSellGui = TradingPost.trader.buildSellGui
function TradingPost.trader:buildSellGui(sellTab, ...)
    tradingTweaks_buildSellGui(self, sellTab, ...)

    TradingPost.tradingTweaks_buildModGui(sellTab, 0)

    tradingTweaks_addBoughtGood = sellTab:createButton(Rect(sellTab.size.x - 65, -5, sellTab.size.x - 35, 25), "", "tradingTweaks_onAddBoughtGood")
    tradingTweaks_addBoughtGood.icon = "data/textures/icons/plus.png"
    tradingTweaks_addBoughtGood.tooltip = "Add good"%_t
end

tradingTweaks_refreshUI = TradingPost.trader.refreshUI
function TradingPost.trader:refreshUI(...)
    local player = Player()
    local playerCraft = player.craft
    if not playerCraft then return end

    tradingTweaks_refreshUI(self, ...)

    if not self.guiInitialized then return end

    for i, line in ipairs(self.soldLines) do
        local good = self.soldGoods[i]
        if good then
            line.tradingTweaks_selectGood:setSelectedValueNoCallback(good.name)
        else
            line:hide()
        end
    end
    for i, line in ipairs(self.boughtLines) do
        local good = self.boughtGoods[i]
        if good then
            line.tradingTweaks_selectGood:setSelectedValueNoCallback(good.name)
        else
            line:hide()
        end
    end

    tradingTweaks_addSoldGood.active = #self.soldGoods < 15
    tradingTweaks_addBoughtGood.active = #self.boughtGoods < 15

    tradingTweaks_basePriceSlider:setValueNoCallback(round((self.buyPriceFactor - 1.0) * 100.0))
    tradingTweaks_basePriceLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(self.buyPriceFactor * 100.0)}

    -- stats
    tradingTweaks_statsLabels[1].left.caption = "Money spent"%_t
    tradingTweaks_statsLabels[1].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(self.stats.moneySpentOnGoods)}
    tradingTweaks_statsLabels[1].left.tooltip = "Amount of money spent on purchasing goods"%_t

    tradingTweaks_statsLabels[2].left.caption = "Money gained"%_t
    tradingTweaks_statsLabels[2].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(self.stats.moneyGainedFromGoods)}
    tradingTweaks_statsLabels[2].left.tooltip = "Amount of money gained by selling products."%_t

    tradingTweaks_statsLabels[4].left.caption = "Profit"%_t
    tradingTweaks_statsLabels[4].right.caption = "${c}${money}"%_t % {c = credits(), money = createMonetaryString(self.stats.moneyGainedFromGoods + self.stats.moneyGainedFromTax - self.stats.moneySpentOnGoods)}
    tradingTweaks_statsLabels[4].left.tooltip = "Total profit of the station; (sales - purchases)."%_t
end

tradingTweaks_refreshConfigUI = TradingPost.refreshConfigUI
function TradingPost.refreshConfigUI(...)
    tradingTweaks_refreshConfigUI(...)

    if TradingPost.trader.sellToOthers then
        tradingTweaks_toggleSellButton.icon = "data/textures/icons/tradingtweaks/buy-enabled.png"
        tradingTweaks_toggleSellButton.tooltip = "This station resells bought goods to traders."%_t
    else
        tradingTweaks_toggleSellButton.icon = "data/textures/icons/tradingtweaks/buy-disabled.png"
        tradingTweaks_toggleSellButton.tooltip = "This station doesn't resell bought goods to traders."%_t
    end
end

function TradingPost.sendConfig() -- overridden
    invokeServerFunction("setConfig", {
      buyFromOthers = TradingPost.trader.buyFromOthers,
      sellToOthers = TradingPost.trader.sellToOthers,
      priceFactor = 1.0 + tradingTweaks_basePriceSlider.value / 100.0
    })
end

function TradingPost.tradingTweaks_buildConfigUI(tab)
    local splitter = UIVerticalProportionalSplitter(Rect(tab.size), 30, 0, {0.5, 270})

    local lister = UIVerticalLister(splitter[1], 10, 0)
    local vSplitter = UIVerticalSplitter(lister:placeCenter(vec2(lister.inner.width, 40)), 10, 0, 0.30)
    tradingTweaks_basePriceLabel = tab:createLabel(vSplitter.left, "Base Price %"%_t, 13)
    tradingTweaks_basePriceLabel:setCenterAligned()
    tradingTweaks_basePriceSlider = tab:createSlider(vSplitter.right, -10, 10, 20, "", "sendConfig")
    tradingTweaks_basePriceSlider:setValueNoCallback(0)
    tradingTweaks_basePriceSlider.unit = "%"
    tradingTweaks_basePriceSlider.tooltip = "Sets the base price of goods bought and sold by this station. A low base price attracts more buyers and a high base price attracts more sellers."%_t

    -- stats
    local rect = splitter[2]
    rect.upper = vec2(rect.upper.x, rect.lower.y + 74)
    tab:createFrame(rect)
    local lister = UIVerticalLister(splitter[2], 4, 10)
    tradingTweaks_statsLabels = {}
    for i = 1, 4 do
        local rect = lister:nextRect(10)
        if i ~= 3 then
            local left = tab:createLabel(rect, "", 11)
            left:setLeftAligned()
            left.font = FontType.Normal

            local right = tab:createLabel(rect, "", 11)
            right:setRightAligned()
            right.font = FontType.Normal

            tradingTweaks_statsLabels[i] = {left = left, right = right}
        end
    end
end

function TradingPost.tradingTweaks_buildModGui(tab, guiType)
    local goodLines, selectGoodCallback, removeGoodCallback
    if guiType == 1 then
        goodLines = TradingPost.trader.soldLines
        selectGoodCallback = "tradingTweaks_onChangeSoldGood"
        removeGoodCallback = "tradingTweaks_onRemoveSoldGood"
    else
        goodLines = TradingPost.trader.boughtLines
        selectGoodCallback = "tradingTweaks_onChangeBoughtGood"
        removeGoodCallback = "tradingTweaks_onRemoveBoughtGood"
    end

    for i, line in ipairs(goodLines) do
        line.tradingTweaks_selectGood = tab:createValueComboBox(Rect(), selectGoodCallback)
        line.tradingTweaks_selectGood.rect = Rect(line.name.position - vec2(10, 6), line.name.position + vec2(250, 24))
        for _, good in ipairs(tradingTweaks_allowedGoods) do
            line.tradingTweaks_selectGood:addEntry(good.name, good:displayName(100), good.color)
        end

        line.tradingTweaks_removeGoodBtn = tab:createButton(Rect(), "", removeGoodCallback)
        line.tradingTweaks_removeGoodBtn.rect = Rect(line.button.upper - vec2(30, 30), line.button.upper)
        line.tradingTweaks_removeGoodBtn.icon = "data/textures/icons/minus.png"
        line.tradingTweaks_removeGoodBtn.tooltip = "Remove good"%_t

        line.tradingTweaks_hide = line.hide
        line.hide = function(self)
            self:tradingTweaks_hide()
            self.tradingTweaks_selectGood.visible = false
            self.tradingTweaks_removeGoodBtn.visible = false
        end

        line.tradingTweaks_show = line.show
        line.show = function(self)
            self:tradingTweaks_show()

            if tradingTweaks_allowedToChange then
                self.name.visible = false
                self.tradingTweaks_selectGood.visible = true
                self.button.upper = self.tradingTweaks_removeGoodBtn.upper - vec2(35, 0)
                self.tradingTweaks_removeGoodBtn.visible = true
            else
                self.name.visible = true
                self.tradingTweaks_selectGood.visible = false
                self.button.upper = self.tradingTweaks_removeGoodBtn.upper
                self.tradingTweaks_removeGoodBtn.visible = false
            end
        end

        line:hide()
    end
end

function TradingPost.tradingTweaks_changeGood(tabType, comboBox, value)
    local goodLines, stationGoods
    if tabType == 1 then
        goodLines = TradingPost.trader.soldLines
        stationGoods = TradingPost.trader.soldGoods
    else
        goodLines = TradingPost.trader.boughtLines
        stationGoods = TradingPost.trader.boughtGoods
    end

    local curName, invalid
    for i, line in ipairs(goodLines) do
        local good = stationGoods[i]
        if good then
            if line.tradingTweaks_selectGood.index == comboBox.index then
                if good.name == value then return end -- no change
                curName = good.name
            elseif value == good.name then
                invalid = true -- can't have the same good on multiple lines
            end 
        end
    end
    if curName then
        if invalid then
            comboBox:setSelectedValueNoCallback(curName) -- restore current good
        else -- send request
            invokeServerFunction("tradingTweaks_changeGood", tabType, curName, value)
        end
    end
end

function TradingPost.tradingTweaks_removeGood(tabType, btn)
    local goodLines, stationGoods
    if tabType == 1 then
        goodLines = TradingPost.trader.soldLines
        stationGoods = TradingPost.trader.soldGoods
    else
        goodLines = TradingPost.trader.boughtLines
        stationGoods = TradingPost.trader.boughtGoods
    end

    for i, line in ipairs(goodLines) do
        if line.tradingTweaks_removeGoodBtn.index == btn.index then
            local good = stationGoods[i]
            if good then
                invokeServerFunction("tradingTweaks_removeGood", tabType, good.name)
                return
            end
        end
    end
end

-- CALLABLE --

function TradingPost.setConfig(config) -- overridden
    -- apply config to UI elements
    TradingPost.trader.buyFromOthers = config.buyFromOthers
    TradingPost.trader.sellToOthers = config.sellToOthers
    if config.buyPriceFactor then
        TradingPost.trader.buyPriceFactor = config.buyPriceFactor
        TradingPost.trader.sellPriceFactor = config.sellPriceFactor
    end

    if TradingAPI.window.visible then
        TradingPost.refreshConfigUI()

        if config.buyPriceFactor then -- no need for double refresh
            TradingPost.trader:refreshUI()
        end
    end
end

-- CALLBACKS --

function TradingPost.onToggleBuyPressed() -- overriden
    TradingPost.trader.buyFromOthers = not TradingPost.trader.buyFromOthers
    TradingPost.sendConfig()
end

function TradingPost.tradingTweaks_onChangeSoldGood(comboBox, value, selectedIndex)
    TradingPost.tradingTweaks_changeGood(1, comboBox, value)
end

function TradingPost.tradingTweaks_onChangeBoughtGood(comboBox, value, selectedIndex)
    TradingPost.tradingTweaks_changeGood(0, comboBox, value)
end

function TradingPost.tradingTweaks_onRemoveSoldGood(btn)
    TradingPost.tradingTweaks_removeGood(1, btn)
end

function TradingPost.tradingTweaks_onRemoveBoughtGood(btn)
    TradingPost.tradingTweaks_removeGood(0, btn)
end

function TradingPost.tradingTweaks_onAddSoldGood()
    invokeServerFunction("tradingTweaks_addGood", 1)
end

function TradingPost.tradingTweaks_onAddBoughtGood()
    invokeServerFunction("tradingTweaks_addGood", 0)
end

function TradingPost.tradingTweaks_onToggleSellPressed()
    TradingPost.trader.sellToOthers = not TradingPost.trader.sellToOthers
    TradingPost.sendConfig()
end


else -- onServer


-- FUNCTIONS --

tradingTweaks_useUpBoughtGoods = TradingPost.trader.useUpBoughtGoods
function TradingPost.trader:useUpBoughtGoods(...)
    if not Entity().aiOwned and not TradingTweaksConfig.PlayerTradingPostsUseUpGoods then return end

    tradingTweaks_useUpBoughtGoods(self, ...)
end

if GameVersion() < Version(1, 3, 5) then

function TradingPost.trader:updateOrganizeGoodsBulletins() -- overridden
    -- don't create Resource Shortage bulletins for Trading Posts
end

end

-- CALLABLE --

function TradingPost.sendConfig(full) -- overridden
    local config = {
      buyFromOthers = TradingPost.trader.buyFromOthers,
      sellToOthers = TradingPost.trader.sellToOthers
    }
    if full then
        config.buyPriceFactor = TradingPost.trader.buyPriceFactor
        config.sellPriceFactor = TradingPost.trader.sellPriceFactor
    end
    -- read config from factory settings
    invokeClientFunction(Player(callingPlayer), "setConfig", config)
end

function TradingPost.setConfig(config) -- overridden
    if not config then return end
    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    if config.buyFromOthers ~= nil then
        TradingPost.trader.buyFromOthers = config.buyFromOthers
        TradingPost.buyingConfigured = true
    end
    if config.sellToOthers ~= nil then
        TradingPost.trader.sellToOthers = config.sellToOthers
    end
    if config.priceFactor ~= nil then
        TradingPost.trader.buyPriceFactor = math.min(1.1, math.max(0.9, tonumber(config.priceFactor) or 0))
        TradingPost.trader.sellPriceFactor = TradingPost.trader.buyPriceFactor + 0.2
    end

    TradingPost.sendConfig(true)
end

function TradingPost.tradingTweaks_changeGood(tabType, prevName, newName)
    if anynils(tabType, prevName, newName) or prevName == newName then return end
    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    local fobidden = { ["Iron Ore"] = true, ["Titanium Ore"] = true, ["Naonite Ore"] = true, ["Trinium Ore"] = true, ["Xanion Ore"] = true, ["Ogonite Ore"] = true, ["Avorion Ore"] = true, ["Scrap Iron"] = true, ["Scrap Titanium"] = true, ["Scrap Naonite"] = true, ["Scrap Trinium"] = true, ["Scrap Xanion"] = true, ["Scrap Ogonite"] = true, ["Scrap Avorion"] = true }
    local good = goods[newName]
    if not good or good.illegal or fobidden[newName] then return end

    local self = TradingPost.trader
    local stationGoods = tabType == 1 and self.soldGoods or self.boughtGoods
    local index
    for i, good in ipairs(stationGoods) do
        if good.name == prevName then
            index = i
        elseif good.name == newName then -- good already exists on another line
            return
        end
    end
    if index then
        stationGoods[index] = good:good()
        broadcastInvokeClientFunction("receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, self.stats, self.ownSupplyTypes, self.supplyDemandInfluence, self.stockInfluence)
    end
end
callable(TradingPost, "tradingTweaks_changeGood")

function TradingPost.tradingTweaks_removeGood(tabType, name)
    if anynils(tabType, name) then return end
    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    local self = TradingPost.trader
    local stationGoods = tabType == 1 and self.soldGoods or self.boughtGoods
    for i, good in ipairs(stationGoods) do
        if good.name == name then
            table.remove(stationGoods, i)
            broadcastInvokeClientFunction("receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, self.stats, self.ownSupplyTypes, self.supplyDemandInfluence, self.stockInfluence)
            return
        end
    end
end
callable(TradingPost, "tradingTweaks_removeGood")

function TradingPost.tradingTweaks_addGood(tabType)
    if anynils(tabType) then return end
    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    local self = TradingPost.trader
    local stationGoods = tabType == 1 and self.soldGoods or self.boughtGoods
    local count = #stationGoods
    if count >= 15 then return end -- can't have more than 15 goods

    local fobidden = { ["Iron Ore"] = true, ["Titanium Ore"] = true, ["Naonite Ore"] = true, ["Trinium Ore"] = true, ["Xanion Ore"] = true, ["Ogonite Ore"] = true, ["Avorion Ore"] = true, ["Scrap Iron"] = true, ["Scrap Titanium"] = true, ["Scrap Naonite"] = true, ["Scrap Trinium"] = true, ["Scrap Xanion"] = true, ["Scrap Ogonite"] = true, ["Scrap Avorion"] = true }
    for i, good in ipairs(stationGoods) do
        fobidden[good.name] = true
    end
    for _, good in ipairs(goodsArray) do
        if not good.illegal and not fobidden[good.name] then
            stationGoods[count+1] = good:good()
            player:sendChatMessage(Entity(), 3, "Good '%1%' was added to the list. Feel free to change it."%_T, good.name)
            broadcastInvokeClientFunction("receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, self.stats, self.ownSupplyTypes, self.supplyDemandInfluence, self.stockInfluence)
            return
        end
    end
end
callable(TradingPost, "tradingTweaks_addGood")


end