if onServer() then


local SectorGenerator = include("SectorGenerator")
local tradingTweaks_generator = SectorGenerator(Sector():getCoordinates())

local tradingTweaks_transformToStation = StationFounder.transformToStation
function StationFounder.transformToStation(buyer)
    local station = tradingTweaks_transformToStation(buyer)
    if station then
        tradingTweaks_generator:addAmbientEvents() -- add traders, passing ships etc.
    end
    return station
end


end