local sim = require('sim')
local util = require('util')

local s, o

function love.draw()
    o.image:replacePixels(o.data)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(o.image)
    love.graphics.setColor(0, 0, 0, 1)
    --love.graphics.rectangle("line", 100, 50, 200, 150)
    love.graphics.print(string.format("%d FPS", love.timer.getFPS()))
end

function love.update(dt)
    s:step(1e3)
end

function love.load()
    love.window.setTitle('Jamba juice')
    love.window.setFullscreen(true, "desktop")
    love.graphics.setBackgroundColor(1, 1, 1)
    s, o = sim.level0()
end

