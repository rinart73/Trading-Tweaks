Consumer.trader.factionPaymentFactor = 1.0 -- players pay when consumer station buys goods
Consumer.trader.minTradingRelations = -20000

if onClient() then


local tradingTweaks
local tradingTweaks_configTab, tradingTweaks_marginLabel, tradingTweaks_marginSlider, tradingTweaks_allowBuyCheckBox

local tradingTweaks_receiveGoods = Consumer.trader.receiveGoods
function Consumer.trader:receiveGoods(buyFactor, sellFactor, boughtGoods_in, soldGoods_in, policies_in, tradingTweaks_in)
    if tradingTweaks_in then
        tradingTweaks = tradingTweaks_in
        self.buyFromOthers = tradingTweaks.buyFromOthers
        if tradingTweaks_marginLabel then
            tradingTweaks_marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(self.buyPriceFactor * 100.0)}
            tradingTweaks_marginSlider:setValueNoCallback(round((self.buyPriceFactor - 1.0) * 100.0))
            tradingTweaks_allowBuyCheckBox:setCheckedNoCallback(tradingTweaks.buyFromOthers)
        end
    end

    tradingTweaks_receiveGoods(self, buyFactor, sellFactor, boughtGoods_in, soldGoods_in, policies_in)
end

local tradingTweaks_initUI = Consumer.initUI
function Consumer.initUI()
    tradingTweaks_initUI()

    tradingTweaks_configTab = TradingAPI.tabbedWindow:createTab("Configure"%_t, "data/textures/icons/cog.png", "Station configuration"%_t)
    Consumer.tradingTweaks_buildConfigUI(tradingTweaks_configTab)
end

local tradingTweaks_onShowWindow = Consumer.onShowWindow
function Consumer.onShowWindow()
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

function Consumer.tradingTweaks_buildConfigUI(tab)
    local lister = UIVerticalLister(Rect(5, 5, tab.size.x - 5, tab.size.y - 5), 5, 0)

    tradingTweaks_marginLabel = tab:createLabel(Rect(), "Buy/Sell price margin %"%_t, 12)
    lister:placeElementTop(tradingTweaks_marginLabel)
    tradingTweaks_marginLabel.centered = true

    tradingTweaks_marginSlider = tab:createSlider(Rect(), -50, 50, 100, "", "tradingTweaks_onSettingsChanged")
    lister:placeElementTop(tradingTweaks_marginSlider)
    tradingTweaks_marginSlider.unit = "%"
    if tradingTweaks then
        tradingTweaks_marginLabel.tooltip = "This station will buy and sell its goods for ${percentage}% of the normal price."%_t % {percentage = round(Consumer.trader.buyPriceFactor * 100.0)}
        tradingTweaks_marginSlider:setValueNoCallback(round((Consumer.trader.buyPriceFactor - 1.0) * 100.0))
    else
        tradingTweaks_marginLabel.tooltip = "Sets the price margin of goods bought and sold by this station. Low prices attract more buyers, high prices attract more sellers."%_t
        tradingTweaks_marginSlider:setValueNoCallback(0)
    end

    lister:nextRect(15)
    
    tradingTweaks_allowBuyCheckBox = tab:createCheckBox(Rect(), "Buy goods from others"%_t, "tradingTweaks_onSettingsChanged")
    lister:placeElementTop(tradingTweaks_allowBuyCheckBox)
    tradingTweaks_allowBuyCheckBox:setCheckedNoCallback(tradingTweaks and tradingTweaks.buyFromOthers or true)
    tradingTweaks_allowBuyCheckBox.tooltip = "If checked, the station will buy goods from traders from other factions than you."%_t
end

function Consumer.tradingTweaks_onSettingsChanged()
    local config = {
      buyFromOthers = tradingTweaks_allowBuyCheckBox.checked,
      priceFactor = 1.0 + tradingTweaks_marginSlider.value / 100.0
    }
    invokeServerFunction("tradingTweaks_setSettings", config)
end


else -- onServer


function Consumer.trader:sendGoods(playerIndex) -- overridden
    local player = Player(playerIndex)
    local tradingTweaks = {
      buyFromOthers = self.buyFromOthers
    }
    invokeClientFunction(player, "receiveGoods", self.buyPriceFactor, self.sellPriceFactor, self.boughtGoods, self.soldGoods, self.policies, tradingTweaks)
end

local tradingTweaks_restore = Consumer.restore
function Consumer.restore(values)
    tradingTweaks_restore(values)
    -- if player/alliance owns a consumer, turn off buying at first, so people will not lose money
    local entity = Entity()
    if not entity.aiOwned and not entity:getValue("TradingTweaks") then
        entity:setValue("TradingTweaks", true)
        Consumer.trader.buyFromOthers = false
    end
end

local tradingTweaks_initialize = Consumer.initialize
function Consumer.initialize(name_in, ...)
    local entity = Entity()
    local goodsGenerated = entity:getValue("goods_generated")

    tradingTweaks_initialize(name_in, ...)
    -- if player/alliance owns a consumer, turn off buying at first, so people will not lose money
    if not entity.aiOwned then
        if not goodsGenerated and not entity:getValue("TradingTweaks") then -- consumer was just created
            entity:setValue("TradingTweaks", true)
            Consumer.trader.buyFromOthers = false
        end
    end
end

function Consumer.tradingTweaks_setSettings(config)
    local player = Player(callingPlayer)
    local faction = Faction()

    if player.index == faction.index or player.allianceIndex == faction.index then
        Consumer.trader.buyFromOthers = config.buyFromOthers
        Consumer.trader.buyPriceFactor = math.max(0.5, math.min(1.5, config.priceFactor))
        Consumer.sendGoods(callingPlayer)
    end
end
callable(Consumer, "tradingTweaks_setSettings")


end