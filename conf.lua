---@diagnostic disable: undefined-global

function love.conf(t)
    t.modules.audio = false
    t.window.title = ":)"
    t.window.width = 480
    t.window.height = 320
    t.window.msaa = 2
    t.window.vsync = 1
    t.window.console = true
    t.window.cursor = false
    t.window.icon = "games/override/icon.png"
end
