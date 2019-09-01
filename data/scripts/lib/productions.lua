function getFactoryCost(production)
    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 then
            local good = goods[ingredient.name]
            ingredientValue = ingredientValue + good.price * ingredient.amount
        end
    end

    for _, garbage in pairs(production.garbages) do
        local good = goods[garbage.name]
        resultValue = resultValue + good.price * garbage.amount * 0.5
    end
    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = 3000000 -- 3 mio minimum for a factory
    costs = costs + diff * 4500
    return math.floor(costs)
end

function getFactoryUpgradeCost(production, size)
    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        if ingredient.optional == 0 then
            local good = goods[ingredient.name]
            ingredientValue = ingredientValue + good.price * ingredient.amount
        end
    end

    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end
    -- factor in garbage results as well
    for _, result in pairs(production.garbages) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount * 0.5
    end

    local diff = resultValue - ingredientValue

    local costs = diff * 1000 * size
    return math.floor(costs)
end