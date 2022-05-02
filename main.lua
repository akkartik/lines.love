lines = {}
width, height, flags = 0, 0, nil

function love.load()
  table.insert(lines, '')
  love.window.setMode(0, 0)  -- maximize
  width, height, flags = love.window.getMode()
end

function love.draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 1, 1, width-1, height-1)
  love.graphics.setColor(0, 0, 0)
  for i, line in ipairs(lines) do
    love.graphics.print(line, 12, i*12)
  end
end

function love.update(dt)
end

function love.keypressed(key, scancode, isrepeat)
  if key == 'return' then
    table.insert(lines, '')
  else
    lines[#lines] = lines[#lines]..key
  end
end

function love.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
end
