if onClient() then


function Factory.tradingTweaks_getProduction()
    return production
end


else -- onServer


local Azimuth = include("azimuthlib-basic")

local tradingTweaks_configOptions = {
  _version = {default = "0.1", comment = "Config version. Don't touch."},
  LogLevel = {default = 2, min = 0, max = 4, format = "floor", comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  OptionalGoodsBonus = { default = 0.1, min = 0, max = 1, comment = "How much having optional goods buffs factory production output (0.1 = 10%)." }
}
local TradingTweaksConfig, tradingTweaks_isModified = Azimuth.loadConfig("TradingTweaks", tradingTweaks_configOptions)
if tradingTweaks_isModified then
    Azimuth.saveConfig("TradingTweaks", TradingTweaksConfig, tradingTweaks_configOptions)
end


if TradingTweaksConfig.OptionalGoodsBonus > 0 then -- only if boosting production with optional goods is enabled

    local tradingTweaks_restore = Factory.restore
    function Factory.restore(data)
        Factory.tradingTweaks_optionalBoosted = data.tradingTweaks_optionalBoosted

        tradingTweaks_restore(data)
    end

    local tradingTweaks_secure = Factory.secure
    function Factory.secure()
        local data = tradingTweaks_secure()

        data.tradingTweaks_optionalBoosted = Factory.tradingTweaks_optionalBoosted
        return data
    end
    
    function Factory.onRestoredFromDisk(timeSinceLastSimulation) -- overridden
        local boughtStock, soldStock = Factory.getInitialGoods(Factory.trader.boughtGoods, Factory.trader.soldGoods)
        local entity = Entity()

        local factor = math.max(0, math.min(1, (timeSinceLastSimulation - 10 * 60) / (100 * 60)))

        -- simulate deliveries to factory
        local faction = Faction()

        if faction and faction.isAIFaction then
            for good, amount in pairs(boughtStock) do
                local curAmount = entity:getCargoAmount(good)
                local diff = math.floor((amount - curAmount) * factor)

                if diff > 0 then
                    Factory.increaseGoods(good.name, diff)
                end
            end
        end

        -- calculate production
        -- limit by time
        local maxAmountProduced = math.floor(timeSinceLastSimulation / Factory.timeToProduce) * Factory.maxNumProductions

        -- limit by goods
        for _, ingredient in pairs(production.ingredients) do
            if ingredient.optional == 0 then
                maxAmountProduced = math.min(maxAmountProduced, math.floor(Factory.getNumGoods(ingredient.name) / ingredient.amount))
            end
        end
        
        -- optional boost
        local boostAmount = 0
        for _, ingredient in pairs(production.ingredients) do
            if ingredient.optional == 1 then
                boostAmount = boostAmount + math.min(maxAmountProduced, math.floor(Factory.getNumGoods(ingredient.name) / ingredient.amount))
            end
        end
        boostAmount = boostAmount / maxAmountProduced

        -- limit by space
        local productSpace = 0
        for _, ingredient in pairs(production.ingredients) do
            if ingredient.optional == 0 then
                local size = Factory.getGoodSize(ingredient.name)
                productSpace = productSpace - ingredient.amount * size
            end
        end

        for _, garbage in pairs(production.garbages) do
            local size = Factory.getGoodSize(garbage.name)
            productSpace = productSpace + garbage.amount * size
        end

        for _, result in pairs(production.results) do
            local size = Factory.getGoodSize(result.name)
            productSpace = productSpace + result.amount * size
        end

        if productSpace > 0 then
            maxAmountProduced = math.min(maxAmountProduced, math.floor(entity.freeCargoSpace / productSpace))
        end

        -- do production
        for _, ingredient in pairs(production.ingredients) do
            Factory.decreaseGoods(ingredient.name, ingredient.amount * maxAmountProduced)
        end

        for _, garbage in pairs(production.garbages) do
            Factory.increaseGoods(garbage.name, garbage.amount * maxAmountProduced)
        end

        local bonus, chance
        for _, result in pairs(production.results) do
            if boostAmount > 0 then
                bonus = result.amount * maxAmountProduced * boostAmount * TradingTweaksConfig.OptionalGoodsBonus
                chance = bonus % 1
                if chance > 0 then
                    if math.random() > chance then
                        bonus = bonus + 1
                    end
                end
                Factory.increaseGoods(result.name, math.floor(result.amount * maxAmountProduced + bonus))
            else
                Factory.increaseGoods(result.name, result.amount * maxAmountProduced)
            end
        end

        -- simulate goods bought from the factory
        if faction and faction.isAIFaction then
            for good, amount in pairs(soldStock) do
                local curAmount = entity:getCargoAmount(good)
                local diff = math.floor((amount - curAmount) * factor)

                if diff < 0 then
                    Factory.decreaseGoods(good.name, -diff)
                end
            end
        end
    end

    function Factory.updateParallelSelf(timeStep) -- overridden
        local numProductions = 0
        for i, duration in pairs(currentProductions) do
            duration = duration + timeStep / Factory.timeToProduce
            -- print ("duration: " .. duration)

            if duration >= 1.0 then
                -- production finished
                currentProductions[i] = nil
                
                local bonus, chance
                for i, result in pairs(production.results) do
                    if Factory.tradingTweaks_optionalBoosted then -- boosted with optional goods
                        bonus = result.amount * Factory.tradingTweaks_optionalBoosted * TradingTweaksConfig.OptionalGoodsBonus
                        chance = bonus % 1
                        if chance > 0 then
                            if math.random() > chance then
                                bonus = bonus + 1
                            end
                        end
                        Factory.increaseGoods(result.name, math.floor(result.amount + bonus))
                    else -- vanilla
                        Factory.increaseGoods(result.name, result.amount)
                    end
                end

                for i, garbage in pairs(production.garbages) do
                    Factory.increaseGoods(garbage.name, garbage.amount)
                end
            else
                currentProductions[i] = duration

                numProductions = numProductions + 1
            end
        end

        Factory.updateProduction(timeStep)
    end

    function Factory.updateProduction(timeStep) -- overridden
        -- if the result isn't there yet, don't produce
        if not production then return end

        -- if not yet fully used, start producing
        local numProductions = tablelength(currentProductions)
        local canProduce = true

        if numProductions >= Factory.maxNumProductions then
            canProduce = false
            -- print("can't produce as there are no more slots free for production")
        end

        -- only start if there are actually enough ingredients for producing
        for i, ingredient in pairs(production.ingredients) do
            if ingredient.optional == 0 and Factory.getNumGoods(ingredient.name) < ingredient.amount then
                canProduce = false
                newProductionError = "Factory can't produce because ingredients are missing!"%_T
                -- print("can't produce due to missing ingredients: " .. ingredient.amount .. " " .. ingredient.name .. ", have: " .. Factory.getNumGoods(ingredient.name))
                break
            end
        end

        local station = Entity()
        for i, garbage in pairs(production.garbages) do
            local newAmount = Factory.getNumGoods(garbage.name) + garbage.amount
            local size = Factory.getGoodSize(garbage.name)

            if newAmount > Factory.getMaxStock(size) or station.freeCargoSpace < garbage.amount * size then
                canProduce = false
                newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
                -- print("can't produce due to missing room for garbage")
                break
            end
        end

        for _, result in pairs(production.results) do
            local newAmount = Factory.getNumGoods(result.name) + result.amount
            local size = Factory.getGoodSize(result.name)

            if newAmount > Factory.getMaxStock(size) or station.freeCargoSpace < result.amount * size then
                canProduce = false
                newProductionError = "Factory can't produce because there is not enough cargo space for products!"%_T
                -- print("can't produce due to missing room for result")
                break
            end
        end

        if canProduce then
            Factory.tradingTweaks_optionalBoosted = 0
            for i, ingredient in pairs(production.ingredients) do
                if ingredient.optional == 1 then
                    if Factory.getNumGoods(ingredient.name) >= ingredient.amount then -- we have enough of this optional good
                        Factory.tradingTweaks_optionalBoosted = Factory.tradingTweaks_optionalBoosted + 1
                    end
                end
                Factory.decreaseGoods(ingredient.name, ingredient.amount)
            end
            if Factory.tradingTweaks_optionalBoosted == 0 then
                Factory.tradingTweaks_optionalBoosted = nil
            end

            newProductionError = ""
            -- print("start production")

            -- start production
            Factory.startProduction(timeStep)
        end
    end

end


end