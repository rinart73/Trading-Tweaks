local tradingTweaks_tabbedWindow, tradingTweaks_configTab, tradingTweaks_basePriceLabel, tradingTweaks_basePriceSlider, tradingTweaks_statsLabels -- UI
local tradingTweaks_initUI, tradingTweaks_onShowWindow, tradingTweaks_refreshUI -- extended client functions


if onClient() then


include("azimuthlib-uiproportionalsplitter")

-- PREDEFINED --

tradingTweaks_initUI = Consumer.initUI
function Consumer.initUI(...)
    tradingTweaks_tabbedWindow = TradingAPI.CreateTabbedWindow()

    tradingTweaks_initUI(...)
    
    tradingTweaks_configTab = tradingTweaks_tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Station configuration"%_t)
    Consumer.tradingTweaks_buildConfigUI(tradingTweaks_configTab)
end

tradingTweaks_onShowWindow = Consumer.onShowWindow
function Consumer.onShowWindow(...)
    tradingTweaks_onShowWindow(...)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations) then
        Consumer.toggleBuyButton.visible = true
        tradingTweaks_tabbedWindow:activateTab(tradingTweaks_configTab)
    else
        Consumer.toggleBuyButton.visible = false
        tradingTweaks_tabbedWindow:deactivateTab(tradingTweaks_configTab)
    end
end

-- FUNCTIONS --

tradingTweaks_refreshUI = Consumer.trader.refreshUI
function Consumer.trader:refreshUI(...)
    local player = Player()
    local playerCraft = player.craft
    if not playerCraft then return end

    tradingTweaks_refreshUI(self, ...)

    if not self.guiInitialized then return end

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

function Consumer.sendConfig() -- overridden
    invokeServerFunction("setConfig", {
      buyFromOthers = Consumer.trader.buyFromOthers,
      priceFactor = 1.0 + tradingTweaks_basePriceSlider.value / 100.0
    })
end

function Consumer.tradingTweaks_buildConfigUI(tab)
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

-- CALLABLE --

function Consumer.setConfig(config) -- overridden
    -- apply config to UI elements
    Consumer.trader.buyFromOthers = config.buyFromOthers
    if config.buyPriceFactor then
        Consumer.trader.buyPriceFactor = config.buyPriceFactor
        Consumer.trader.sellPriceFactor = config.sellPriceFactor
    end

    if TradingAPI.window.visible then
        Consumer.refreshConfigUI()

        if config.buyPriceFactor then -- no need for double refresh
            Consumer.trader:refreshUI()
        end
    end
end

-- CALLBACKS --

function Consumer.onToggleBuyPressed() -- overriden
    Consumer.trader.buyFromOthers = not Consumer.trader.buyFromOthers
    Consumer.sendConfig()
end


else -- onServer


-- CALLABLE --

function Consumer.sendConfig(full) -- overridden
    local config = {
      buyFromOthers = Consumer.trader.buyFromOthers
    }
    if full then
        config.buyPriceFactor = Consumer.trader.buyPriceFactor
        config.sellPriceFactor = Consumer.trader.sellPriceFactor
    end
    -- read config from factory settings
    invokeClientFunction(Player(callingPlayer), "setConfig", config)
end

function Consumer.setConfig(config) -- overridden
    if not config then return end
    local owner, station, player = checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageStations)
    if not owner then return end

    if config.buyFromOthers ~= nil then
        Consumer.trader.buyFromOthers = config.buyFromOthers
        Consumer.consumerConfigured = true
    end
    if config.priceFactor ~= nil then
        Consumer.trader.buyPriceFactor = math.min(1.1, math.max(0.9, tonumber(config.priceFactor) or 0))
        Consumer.trader.sellPriceFactor = Consumer.trader.buyPriceFactor + 0.2
    end

    Consumer.sendConfig(true)
end


end