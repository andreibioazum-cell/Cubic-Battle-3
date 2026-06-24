function love.conf(t)
    t.identity = "cubicbattle"
    t.version = "12.0"
    t.window.title = "Cubic Battle"
    t.window.fullscreen = true
    t.window.borderless = true
    t.window.vsync = 1
    t.window.msaa = 4
    t.window.resizable = true
    t.modules.physics = false
    t.modules.video = false
end
