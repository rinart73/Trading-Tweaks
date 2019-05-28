if onServer() then


local tradingTweaks_setConfig = Factory.setConfig
function Factory.setConfig(config) -- fix price margin exploit
    if not config then return end

    config.priceFactor = math.max(0.5, math.min(1.5, config.priceFactor))

    tradingTweaks_setConfig(config)
end


end