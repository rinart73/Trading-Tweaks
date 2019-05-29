function getFactoryUpgradeCost(production, size)
    -- calculate the difference between the value of ingredients and results
    local ingredientValue = 0
    local resultValue = 0

    for _, ingredient in pairs(production.ingredients) do
        local good = goods[ingredient.name]
        ingredientValue = ingredientValue + good.price * ingredient.amount
    end

    for _, garbage in pairs(production.garbages) do
        local good = goods[garbage.name]
        resultValue = resultValue + good.price * garbage.amount
    end
    for _, result in pairs(production.results) do
        local good = goods[result.name]
        resultValue = resultValue + good.price * result.amount
    end

    local diff = resultValue - ingredientValue

    local costs = diff * 1000 * size
    return costs
end