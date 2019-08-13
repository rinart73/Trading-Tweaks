if onServer() then


include("utility")

function Traders.update(timeStep) -- overridden
    local sector = Sector()
    if sector:getValue("war_zone") then return end

    -- find all stations that buy or sell goods
    local scripts = TradingUtility.getTradeableScripts()

    local tradingStations = {}

    local stations = {sector:getEntitiesByType(EntityType.Station)}

    for _, station in pairs(stations) do

        if not TradingUtility.hasTraders(station) then

            for _, script in pairs(scripts) do

                local tradingStation = nil

                if TradingUtility.getSellsToOthers(station, script) then
                    local results = {station:invokeFunction(script, "getSoldGoods")}
                    local callResult = results[1]

                    if callResult == 0 then -- call was successful, the station sells goods
                        tradingStation = {station = station, script = script, bought = {}, sold = {}}
                        tradingStation.sold = {}

                        for i = 2, tablelength(results) do
                            tradingStation.sold[#tradingStation.sold+1] = results[i]
                        end
                    end
                end

                if TradingUtility.getBuysFromOthers(station, script) then
                    local results = {station:invokeFunction(script, "getBoughtGoods")}
                    local callResult = results[1]
                    if callResult == 0 then -- call was successful, the station buys goods

                        if tradingStation == nil then
                            tradingStation = {station = station, script = script, bought = {}, sold = {}}
                        end

                        for i = 2, tablelength(results) do
                            tradingStation.bought[#tradingStation.bought+1] = results[i]
                        end

                    end
                end

                if tradingStation then
                    tradingStations[#tradingStations+1] = tradingStation
                end
            end
        end
    end

    -- find stations that need goods or would sell goods
    local tradingPossibilities = {}
    local tradingWeights = {}

    local x, y = sector:getCoordinates()

    for _, v in pairs(tradingStations) do
        local station = v.station
        local bought = v.bought
        local sold = v.sold
        local script = v.script

        -- these are all possibilities for goods to be bought from stations
        for _, name in pairs(sold) do
            local err, amount, maxAmount, sellPriceFactor = station:invokeFunction(script, "getStock", name)
            if err == 0 and maxAmount > 0 and amount / maxAmount > 0.6 then
                tradingPossibilities[#tradingPossibilities+1] = { tradeType = TradingUtility.TradeType.BuyFromStation, station = station, script = script, name = name }
                tradingWeights[#tradingWeights+1] = lerp(sellPriceFactor, 0.5, 1.5, 1.0, 0.3)
            end
        end

        -- these are all possibilities for goods to be sold to stations
        for _, name in pairs(bought) do
            local err, amount, maxAmount, _, buyPriceFactor = station:invokeFunction(script, "getStock", name)
            if err == 0 and maxAmount > 0 and amount / maxAmount < 0.4 then
            
                local amountTraded = maxAmount - amount
                if TradingUtility.isScriptAConsumer(script) then
                    if station.playerOwned or station.allianceOwned then
                        local g = goods[name]
                        if not g then
                            print ("invalid good: '" .. name .. "'")
                            return
                        end

                        local maxValue = Balancing_GetSectorRichnessFactor(x, y, 1500000)
                        amountTraded = math.min(amountTraded, math.max(2, math.ceil(maxValue / g.price)))
                    end
                end
            
                tradingPossibilities[#tradingPossibilities+1] = { tradeType = TradingUtility.TradeType.SellToStation, station = station, script = script, name = name, amount = amountTraded }
                tradingWeights[#tradingWeights+1] = lerp(buyPriceFactor, 0.5, 1.5, 0.3, 1.0)
            end
        end
    end

    -- if there is no way for trade, exit
    if #tradingPossibilities == 0 then return end

    -- choose one at random according to weights
    local trade = tradingPossibilities[selectByWeight(random(), tradingWeights)]

    -- create a trader ship that will fly to this station to trade
    -- don't create traders when there are no players in the sector to witness it. instead, do the trade transaction immediately
    TradingUtility.spawnTrader(trade, Traders, sector.numPlayers == 0)
end


end