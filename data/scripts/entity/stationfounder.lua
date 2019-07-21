local SectorGenerator -- includes
local tradingTweaks_generator -- server
local tradingTweaks_transformToStation -- overridden functions

if onServer() then


SectorGenerator = include("SectorGenerator")
tradingTweaks_generator = SectorGenerator(Sector():getCoordinates())

tradingTweaks_transformToStation = StationFounder.transformToStation
function StationFounder.transformToStation(buyer)
    local station = tradingTweaks_transformToStation(buyer)
    if station then
        tradingTweaks_generator:addAmbientEvents() -- add traders, passing ships etc.
    end
    return station
end


end