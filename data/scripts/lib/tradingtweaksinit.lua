local Azimuth = include("azimuthlib-basic")
local Config, Log

if onServer() then

local configOptions = {
  _version = {"0.3", comment = "Config version. Don't touch."},
  LogLevel = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  FileLogLevel = {2, round = -1, min = 0, max = 4, comment = "0 - Disable, 1 - Errors, 2 - Warnings, 3 - Info, 4 - Debug."},
  PlayerTradingPostsUseUpGoods = {true, comment = "If false, player/alliance-owned Trading Posts will not use up good passively."}
}
local isModified
Config, isModified = Azimuth.loadConfig("TradingTweaks", configOptions)
if Config._version == "0.1" then
    isModified = true
    Config._version = "0.3"
    Config.OptionalGoodsBonus = nil
    Config.FileLogLevel = Config.LogLevel
end
if isModified then
    Azimuth.saveConfig("TradingTweaks", Config, configOptions)
end

Log = Azimuth.logs("TradingTweaks", Config.LogLevel, Config.FileLogLevel)

end

return {Azimuth, Config, Log}
