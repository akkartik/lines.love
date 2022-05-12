require 'keychord'
require 'button'
require 'repl'
local utf8 = require 'utf8'

lines = {}
width, height, flags = 0, 0, nil
exec_payload = nil

function love.load()
  table.insert(lines, '')
  love.window.setMode(0, 0)  -- maximize
  width, height, flags = love.window.getMode()
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
end

function love.draw()
  button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 1, 1, width-1, height-1)
  love.graphics.setColor(0, 0, 0)
  local text
  local y = 0
  for i,line in ipairs(lines) do
    y = y+25
    text = love.graphics.newText(love.graphics.getFont(), line)
    if line == '' then
      button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
        icon = function(x,y)
                 love.graphics.setColor(0.7,0.7,0.7)
                 love.graphics.rectangle('line', x,y, 12,12)
                 love.graphics.line(4,y+6, 16,y+6)
                 love.graphics.line(10,y, 10,y+12)
                 love.graphics.setColor(0, 0, 0)
               end,
        onpress1 = function()
                     table.insert(lines, i, {y=y, w=400, h=200, pending={}, shapes={}})
                   end})
    elseif type(line) == 'table' then
      -- line drawing
      love.graphics.setColor(0.75,0.75,0.75)
      line.y = y
      love.graphics.rectangle('line', 12,y, line.w,line.h)
      y = y+line.h

      for _,shape in ipairs(line.shapes) do
        if on_freehand(love.mouse.getX(),love.mouse.getY(), shape) then
          love.graphics.setColor(1,0,0)
        else
          love.graphics.setColor(0,0,0)
        end
        prev = nil
        for _,point in ipairs(shape) do
          if prev then
            love.graphics.line(prev.x,prev.y, point.x,point.y)
          end
          prev = point
        end
      end
      prev = nil
      for _,point in ipairs(line.pending) do
        if prev then
          love.graphics.line(prev.x,prev.y, point.x,point.y)
        end
        prev = point
      end
    else
      love.graphics.draw(text, 25,y, 0, 1.5)
    end
  end
  -- cursor
  love.graphics.print('_', 25+text:getWidth()*1.5, y)

  -- display side effect
  if exec_payload then
    run(exec_payload)
  end
end

function love.update(dt)
  if love.mouse.isDown('1') then
    if lines.current then
      local drawing = lines.current
      if type(drawing) == 'table' then
        local x, y = love.mouse.getX(), love.mouse.getY()
        if y >= drawing.y and y < drawing.y + drawing.h and x >= 12 and x < 12+drawing.w then
          table.insert(drawing.pending, {x=love.mouse.getX(), y=love.mouse.getY()})
        end
      end
    end
  end
end

function love.mousepressed(x,y, button)
  propagate_to_button_handers(x,y, button)
  propagate_to_drawings(x,y, button)
end

function propagate_to_drawings(x,y, button)
  for i,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + drawing.h and x >= 12 and x < 12+drawing.w then
        lines.current = drawing
      end
    end
  end
end

function on_freehand(x,y, shape)
  local prev
  for _,p in ipairs(shape) do
    if prev then
      if on_line(x,y, {x1=prev.x,y1=prev.y, x2=p.x,y2=p.y}) then
        return true
      end
    end
    prev = p
  end
  return false
end

function on_line(x,y, shape)
  if shape.x1 == shape.x2 then
    if math.abs(shape.x1-x) > 5 then
      return false
    end
    local y1,y2 = shape.y1,shape.y2
    if y1 > y2 then
      y1,y2 = y2,y1
    end
    return y >= y1 and y <= y2
  end
  -- has the right slope and intercept
  local m = (shape.y2 - shape.y1) / (shape.x2 - shape.x1)
  local yp = shape.y1 + m*(x-shape.x1)
  if yp < 0.95*y or yp > 1.05*y then
    return false
  end
  -- between endpoints
  local k = (x-shape.x1) / (shape.x2-shape.x1)
  return k > -0.05 and k < 1.05
end

function love.mousereleased(x,y, button)
  if lines.current then
    if lines.current.pending then
      table.insert(lines.current.shapes, lines.current.pending)
      lines.current.pending = {}
      lines.current = nil
    end
  end
end

function love.textinput(t)
  lines[#lines] = lines[#lines]..t
end

function keychord_pressed(chord)
  -- Don't handle any keys here that would trigger love.textinput above.
  if chord == 'return' then
    table.insert(lines, '')
  elseif chord == 'backspace' then
    if #lines > 1 and lines[#lines] == '' then
      table.remove(lines)
    else
      local byteoffset = utf8.offset(lines[#lines], -1)
      if byteoffset then
        lines[#lines] = string.sub(lines[#lines], 1, byteoffset-1)
      end
    end
  elseif chord == 'C-r' then
    lines[#lines+1] = eval(lines[#lines])[1]
    lines[#lines+1] = ''
  elseif chord == 'C-d' then
    parse_into_exec_payload(lines[#lines])
  elseif chord == 'C-l' then
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_line(drawing,i,shape)
    end
  elseif chord == 'C-m' then
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_horvert(drawing,i,shape)
    end
  end
end

function select_shape_at_mouse()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + drawing.h and x >= 12 and x < 12+drawing.w then
        for i,shape in ipairs(drawing.shapes) do
          if on_freehand(love.mouse.getX(),love.mouse.getY(), shape) then
            return drawing,i,shape
          end
        end
      end
    end
  end
end

function convert_line(drawing, i, shape)
  -- Perhaps we should do a more sophisticated "simple linear regression"
  -- here:
  --   https://en.wikipedia.org/wiki/Linear_regression#Simple_and_multiple_linear_regression
  -- But this works well enough for close-to-linear strokes.
  drawing.shapes[i] = {shape[1], shape[#shape]}
end

-- turn a stroke into either a horizontal or vertical line
function convert_horvert(drawing, i, shape)
  local x1,y1 = shape[1].x, shape[1].y
  local x2,y2 = shape[#shape].x, shape[#shape].y
  if math.abs(x1-x2) > math.abs(y1-y2) then
    drawing.shapes[i] = {{x=x1, y=y1}, {x=x2, y=y1}}
  else
    drawing.shapes[i] = {{x=x1, y=y1}, {x=x1, y=y2}}
  end
end

function love.keyreleased(key, scancode)
end
