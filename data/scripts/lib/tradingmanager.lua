local tradingTweaks_CreateTabbedWindow -- extended client functions


if onClient() then


tradingTweaks_CreateTabbedWindow = PublicNamespace.CreateTabbedWindow
function PublicNamespace.CreateTabbedWindow(caption, width)
    if width and not PublicNamespace.tabbedWindow then
        local menu = ScriptUI()
        local res = getResolution()
        local size = vec2(width, 650)

        local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));

        window.caption = caption or ""
        window.showCloseButton = 1
        window.moveable = 1

        -- create a tabbed window inside the main window
        PublicNamespace.tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
        PublicNamespace.window = window
    end

    return tradingTweaks_CreateTabbedWindow(caption)
end


end