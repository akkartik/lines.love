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
  love.graphics.setColor(1, 1, 0)
  love.graphics.rectangle('fill', 1, 1, 400, 10*12)
  love.graphics.setColor(0, 0, 0)
  local text
  for i, line in ipairs(lines) do
    text = love.graphics.newText(love.graphics.getFont(), line)
    love.graphics.draw(text, 12, i*15)
  end
  -- cursor
  love.graphics.print('_', 12+text:getWidth(), #lines*15)
end

function love.update(dt)
end

function love.keypressed(key, scancode, isrepeat)
  if key == 'return' then
    table.insert(lines, '')
  elseif key == 'space' then
    lines[#lines] = lines[#lines]..' '
  elseif key == 'lctrl' or key == 'rctrl' then
    -- do nothing
  elseif key == 'lalt' or key == 'ralt' then
    -- do nothing
  elseif love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    lines[#lines] = lines[#lines]..' aaa'
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
