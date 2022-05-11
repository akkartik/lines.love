require 'keychord'
require 'button'
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
  for i, line in ipairs(lines) do
    y = y+25
    text = love.graphics.newText(love.graphics.getFont(), line)
    if line == '' then
      button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
        icon = function(x, y)
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
      love.graphics.setColor(0,0,0)
      line.y = y
      love.graphics.rectangle('line', 12,y, line.w,line.h)
      y = y+line.h

      for _,shape in ipairs(line.shapes) do
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

  if exec_payload then
    call_gather(exec_payload)
  end
end

function love.update(dt)
  if love.mouse.isDown('1') then
    for i, line in ipairs(lines) do
      if type(line) == 'table' then
        local y = love.mouse.getY()
        if y >= line.y and y < line.y + line.h then
          lines.current = line
          process_drag(line,love.mouse.getX(),love.mouse.getY())
        end
      end
    end
  end
end

function process_drag(drawing, x,y)
  table.insert(drawing.pending, {x=x, y=y})
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
    eval(lines[#lines])
--?     lines[#lines+1] = eval(lines[#lines])[1]
--?     lines[#lines+1] = ''
  end
end

function love.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button)
  propagate_to_button_handers(x, y, button)
end

function eval(buf)
  local f = load('return '..buf, 'REPL')
  if f then
    exec_payload = f
    return
--?     return call_gather(f)
  end
  local f, err = load(buf, 'REPL')
  if f then
    exec_payload = f
    return
--?     return call_gather(f)
  else
    return {err}
  end
end

-- based on https://github.com/hoelzro/lua-repl
function call_gather(f)
  local success, results = gather_results(xpcall(f, function(...) return debug.traceback() end))
  return results
end

function gather_results(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end
