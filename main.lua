require 'keychord'
require 'button'
require 'repl'
local utf8 = require 'utf8'

-- lines is an array of lines
-- a line is either:
--    a string containing text
--    or a drawing
-- a drawing is a table with:
--    a (y) coord in pixels,
--    a (h)eight,
--    an array of points, and
--    an array of shapes
-- a shape is a table containing:
--    a mode
--    an array points for mode 'freehand' (raw x,y coords; freehand drawings don't pollute the points array of a drawing)
--    an array vertices for mode 'polygon', 'rectangle', 'square'
--    p1, p2 for mode 'line'
--    p1, p2, arrow-mode for mode 'arrow-line'
--    cx,cy, r for mode 'circle'
--    pc, r for mode 'circle'
--    pc, r, s, e for mode 'arc'
-- Unless otherwise specified, coord fields are normalized; a drawing is always 256 units wide
-- The field names are carefully chosen so that switching modes in midstream
-- remembers previously entered points where that makes sense.
--
-- Open question: how to maintain Sketchpad-style constraints? Answer for now:
-- we don't. Constraints operate only for the duration of a drawing operation.
-- We'll continue to persist them just to keep the option open to continue
-- solving for them. But for now, this is a program to create static drawings
-- once, and read them passively thereafter.
lines = {}

screenw, screenh, screenflags = 0, 0, nil

current_mode = 'freehand'

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts. `drawingw` describes their width in pixels.
drawingw = 400  -- pixels
function pixels(n)  -- parts to pixels
  return n*drawingw/256
end
function coord(n)  -- pixels to parts
  return math.floor(n*256/drawingw)
end

exec_payload = nil

function love.load()
  table.insert(lines, '')
  love.window.setMode(0, 0)  -- maximize
  screenw, screenh, screenflags = love.window.getMode()
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
end

function love.draw()
  button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 1, 1, screenw-1, screenh-1)
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
                     table.insert(lines, i, {y=y, h=256/2, pending={}, shapes={}})
                   end})
    elseif type(line) == 'table' then
      -- line drawing
      line.y = y
      y = y+pixels(line.h)
      love.graphics.setColor(0.75,0.75,0.75)
      love.graphics.rectangle('line', 16,line.y, drawingw,pixels(line.h))

      local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-line.y)

      for _,shape in ipairs(line.shapes) do
        if on_shape(mx,my, shape) then
          love.graphics.setColor(1,0,0)
        else
          love.graphics.setColor(0,0,0)
        end
        draw_shape(16,line.y, shape)
      end
      draw_pending_shape(16,line.y, line.pending)
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
        if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
          if drawing.pending.mode == 'freehand' then
            table.insert(drawing.pending.points, {x=coord(love.mouse.getX()-16), y=coord(love.mouse.getY()-drawing.y)})
          end
        end
      end
    end
  end
end

function love.mousepressed(x,y, button)
  propagate_to_button_handlers(x,y, button)
  propagate_to_drawings(x,y, button)
end

function love.mousereleased(x,y, button)
  if lines.current then
    if lines.current.pending then
      if lines.current.pending.mode == 'freehand' then
        -- the last point added during update is good enough
      elseif lines.current.pending.mode == 'line' then
        lines.current.pending.x2 = coord(x-16)
        lines.current.pending.y2 = coord(y-lines.current.y)
      end
      table.insert(lines.current.shapes, lines.current.pending)
      lines.current.pending = {}
      lines.current = nil
    end
  end
end

function propagate_to_drawings(x,y, button)
  for i,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        if current_mode == 'freehand' then
          drawing.pending = {mode='freehand', points={x=coord(x-16), y=coord(y-drawing.y)}}
        elseif current_mode == 'line' then
          drawing.pending = {mode='line', x1=coord(x-16), y1=coord(y-drawing.y)}
        end
        lines.current = drawing
      end
    end
  end
end

function draw_shape(left,top, shape)
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, pixels(point.x)+left,pixels(point.y)+top)
      end
      prev = point
    end
  elseif shape.mode == 'line' then
    love.graphics.line(pixels(shape.x1)+left,pixels(shape.y1)+top, pixels(shape.x2)+left,pixels(shape.y2)+top)
  end
end

function draw_pending_shape(left,top, shape)
  if shape.mode == 'freehand' then
    draw_shape(left,top, shape)
  elseif shape.mode == 'line' then
    love.graphics.line(pixels(shape.x1)+left,pixels(shape.y1)+top, love.mouse.getX(),love.mouse.getY())
  end
end

function on_shape(x,y, shape)
  if shape.mode == 'freehand' then
    return on_freehand(x,y, shape)
  elseif shape.mode == 'line' then
    return on_line(x,y, shape)
  else
    assert(false)
  end
end

function on_freehand(x,y, shape)
  local prev
  for _,p in ipairs(shape.points) do
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

function love.textinput(t)
  if love.mouse.isDown('1') then return end
  if in_drawing() then return end
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
  elseif chord == 'C-f' then
    current_mode = 'freehand'
  elseif love.mouse.isDown('1') and chord == 'l' then
    current_mode = 'line'
    local drawing = current_drawing()
    assert(drawing.pending.mode == 'freehand')
    drawing.pending.mode = 'line'
    drawing.pending.x1 = drawing.pending.points[1].x
    drawing.pending.y1 = drawing.pending.points[1].y
  elseif chord == 'C-l' then
    current_mode = 'line'
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_line(shape)
    end
  elseif chord == 'C-m' then
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_horvert(shape)
    end
  elseif chord == 'C-s' then
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      smoothen(shape)
    end
  end
end

function in_drawing()
  local x, y = love.mouse.getX(), love.mouse.getY()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        return true
      end
    end
  end
  return false
end

function current_drawing()
  local x, y = love.mouse.getX(), love.mouse.getY()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        return drawing
      end
    end
  end
  return nil
end

function select_shape_at_mouse()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
        for i,shape in ipairs(drawing.shapes) do
          if on_shape(mx,my, shape) then
            return drawing,i,shape
          end
        end
      end
    end
  end
end

function convert_line(shape)
  -- Perhaps we should do a more sophisticated "simple linear regression"
  -- here:
  --   https://en.wikipedia.org/wiki/Linear_regression#Simple_and_multiple_linear_regression
  -- But this works well enough for close-to-linear strokes.
  assert(shape.mode == 'freehand')
  shape.mode = 'line'
  shape.x1 = shape.points[1].x
  shape.y1 = shape.points[1].y
  shape.x2 = shape.points[#shape.points].x
  shape.y2 = shape.points[#shape.points].y
end

-- turn a line either horizontal or vertical
function convert_horvert(shape)
  if shape.mode == 'freehand' then
    convert_line(shape)
  end
  assert(shape.mode == 'line')
  if math.abs(shape.x1-shape.x2) > math.abs(shape.y1-shape.y2) then
    shape.y2 = shape.y1
  else
    shape.x2 = shape.x1
  end
end

function smoothen(shape)
  assert(shape.mode == 'freehand')
  for _=1,7 do
    for i=2,#shape.points-1 do
      local a = shape.points[i-1]
      local b = shape.points[i]
      local c = shape.points[i+1]
      b.x = (a.x + b.x + c.x)/3
      b.y = (a.y + b.y + c.y)/3
    end
  end
end

function love.keyreleased(key, scancode)
end
