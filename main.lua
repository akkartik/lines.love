require 'keychord'
require 'button'
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
--    center, radius for mode 'circle'
--    center, radius, start_angle, end_angle for mode 'arc'
-- Unless otherwise specified, coord fields are normalized; a drawing is always 256 units wide
-- The field names are carefully chosen so that switching modes in midstream
-- remembers previously entered points where that makes sense.
--
-- Open question: how to maintain Sketchpad-style constraints? Answer for now:
-- we don't. Constraints operate only for the duration of a drawing operation.
-- We'll continue to persist them just to keep the option open to continue
-- solving for them. But for now, this is a program to create static drawings
-- once, and read them passively thereafter.
lines = {''}
cursor_line = 1
-- this is a line
-- ^cursor_pos = 1
--  ^cursor_pos = 2
--   ...
--               ^cursor_pos past end of line is 15
cursor_pos = #lines[cursor_line]+1

screenw, screenh, screenflags = 0, 0, nil

current_mode = 'line'
previous_mode = nil

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts. `drawingw` describes their width in pixels.
drawingw = nil  -- pixels
function pixels(n)  -- parts to pixels
  return n*drawingw/256
end
function coord(n)  -- pixels to parts
  return math.floor(n*256/drawingw)
end

filename = 'lines.txt'

function love.load(arg)
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  screenw, screenh, screenflags = love.window.getMode()
  -- shrink slightly to account for window decoration
  screenw = screenw-100
  screenh = screenh-100
  love.window.setMode(screenw, screenh)
  love.window.setTitle('Text with Lines')
  drawingw = math.floor(screenh/2/40)*40
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  if #arg > 0 then
    filename = arg[1]
  end
  lines = load_from_disk(filename)
  love.window.setTitle('Text with Lines - '..filename)
end

function love.filedropped(file)
  filename = file:getFilename()
  file:open('r')
  lines = load_from_file(file)
  file:close()
  love.window.setTitle('Text with Lines - '..filename)
end

function love.draw()
  button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 0, 0, screenw-1, screenh-1)
  love.graphics.setColor(0, 0, 0)
  local y = 0
  for i,line in ipairs(lines) do
    y = y+25
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
                     table.insert(lines, i, {y=y, h=256/2, points={}, shapes={}, pending={}})
                   end})
        if i == cursor_line then
          love.graphics.setColor(0,0,0)
          love.graphics.print('_', 25, y+6)  -- drop the cursor down a bit to account for the increased font size
        end
    elseif type(line) == 'table' then
      -- line drawing
      line.y = y
      y = y+pixels(line.h)

      local pmx,pmy = love.mouse.getX(), love.mouse.getY()
      if pmx < 16+drawingw and pmy > line.y and pmy < line.y+pixels(line.h) then
        love.graphics.setColor(0.75,0.75,0.75)
        love.graphics.rectangle('line', 16,line.y, drawingw,pixels(line.h))
        if icon[current_mode] then
          icon[current_mode](16+drawingw-20, line.y+4)
        else
          icon[previous_mode](16+drawingw-20, line.y+4)
        end

        if love.mouse.isDown('1') and love.keyboard.isDown('h') then
          draw_help_with_mouse_pressed(line)
          return
        end
      end

      if line.show_help then
        draw_help_without_mouse_pressed(line)
        return
      end

      local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-line.y)

      for _,shape in ipairs(line.shapes) do
        assert(shape)
        if on_shape(mx,my, line, shape) then
          love.graphics.setColor(1,0,0)
        else
          love.graphics.setColor(0,0,0)
        end
        draw_shape(16,line.y, line, shape)
      end
      for _,p in ipairs(line.points) do
        if p.deleted == nil then
          if near(p, mx,my) then
            love.graphics.setColor(1,0,0)
            love.graphics.circle('line', pixels(p.x)+16,pixels(p.y)+line.y, 4)
          else
            love.graphics.setColor(0,0,0)
            love.graphics.circle('fill', pixels(p.x)+16,pixels(p.y)+line.y, 2)
          end
        end
      end
      draw_pending_shape(16,line.y, line)
    else
      love.graphics.setColor(0,0,0)
      local text = love.graphics.newText(love.graphics.getFont(), line)
      love.graphics.draw(text, 25,y, 0, 1.5)
      if i == cursor_line then
        -- cursor
        love.graphics.print('_', 25+cursor_x(lines[cursor_line], cursor_pos)*1.5, y+6)  -- drop the cursor down a bit to account for the increased font size
      end
    end
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
          elseif drawing.pending.mode == 'move' then
            local mx,my = coord(x-16), coord(y-drawing.y)
            drawing.pending.target_point.x = mx
            drawing.pending.target_point.y = my
          end
        end
      end
    end
  elseif current_mode == 'move' then
    local drawing = lines.current
    local x, y = love.mouse.getX(), love.mouse.getY()
    if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
      local mx,my = coord(x-16), coord(y-drawing.y)
      drawing.pending.target_point.x = mx
      drawing.pending.target_point.y = my
    end
  end
end

function love.mousepressed(x,y, button)
  propagate_to_button_handlers(x,y, button)
  propagate_to_drawings(x,y, button)
end

function love.mousereleased(x,y, button)
  if current_mode == 'move' then
    current_mode = previous_mode
    previous_mode = nil
  elseif lines.current then
    if lines.current.pending then
      if lines.current.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        table.insert(lines.current.shapes, lines.current.pending)
      elseif lines.current.pending.mode == 'line' then
        local mx,my = coord(x-16), coord(y-lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < lines.current.h then
          local j = insert_point(lines.current.points, mx,my)
          lines.current.pending.p2 = j
          table.insert(lines.current.shapes, lines.current.pending)
        end
      elseif lines.current.pending.mode == 'manhattan' then
        local p1 = lines.current.points[lines.current.pending.p1]
        local mx,my = coord(x-16), coord(y-lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < lines.current.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            local j = insert_point(lines.current.points, mx, p1.y)
            lines.current.pending.p2 = j
          else
            local j = insert_point(lines.current.points, p1.x, my)
            lines.current.pending.p2 = j
          end
          local p2 = lines.current.points[lines.current.pending.p2]
          love.mouse.setPosition(16+pixels(p2.x), lines.current.y+pixels(p2.y))
          table.insert(lines.current.shapes, lines.current.pending)
        end
      elseif lines.current.pending.mode == 'polygon' then
        local mx,my = coord(x-16), coord(y-lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < lines.current.h then
          local j = insert_point(lines.current.points, mx,my)
          table.insert(lines.current.shapes, lines.current.pending)
        end
        table.insert(lines.current.shapes, lines.current.pending)
      elseif lines.current.pending.mode == 'circle' then
        local mx,my = coord(x-16), coord(y-lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < lines.current.h then
          local center = lines.current.points[lines.current.pending.center]
          lines.current.pending.radius = math.dist(center.x,center.y, mx,my)
          table.insert(lines.current.shapes, lines.current.pending)
        end
      elseif lines.current.pending.mode == 'arc' then
        local mx,my = coord(x-16), coord(y-lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < lines.current.h then
          local center = lines.current.points[lines.current.pending.center]
          lines.current.pending.end_angle = angle_with_hint(center.x,center.y, mx,my, lines.current.pending.end_angle)
          table.insert(lines.current.shapes, lines.current.pending)
        end
      end
      lines.current.pending = {}
      lines.current = nil
    end
  end
  if filename then
    save_to_disk(lines, filename)
  end
end

function propagate_to_drawings(x,y, button)
  for i,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        if current_mode == 'freehand' then
          drawing.pending = {mode=current_mode, points={{x=coord(x-16), y=coord(y-drawing.y)}}}
        elseif current_mode == 'line' or current_mode == 'manhattan' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=current_mode, p1=j}
        elseif current_mode == 'polygon' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=current_mode, vertices={j}}
        elseif current_mode == 'circle' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=current_mode, center=j}
        end
        lines.current = drawing
      end
    end
  end
end

function insert_point(points, x,y)
  for i,point in ipairs(points) do
    if near(point, x,y) then
      return i
    end
  end
  table.insert(points, {x=x, y=y})
  return #points
end

function near(point, x,y)
  local px,py = pixels(x),pixels(y)
  local cx,cy = pixels(point.x), pixels(point.y)
  return (cx-px)*(cx-px) + (cy-py)*(cy-py) < 16
end

function draw_shape(left,top, drawing, shape)
  if shape.mode == 'freehand' then
    local prev = nil
    for _,point in ipairs(shape.points) do
      if prev then
        love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, pixels(point.x)+left,pixels(point.y)+top)
      end
      prev = point
    end
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local p2 = drawing.points[shape.p2]
    love.graphics.line(pixels(p1.x)+left,pixels(p1.y)+top, pixels(p2.x)+left,pixels(p2.y)+top)
  elseif shape.mode == 'polygon' then
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, pixels(curr.x)+left,pixels(curr.y)+top)
      end
      prev = curr
    end
    -- close the loop
    local curr = drawing.points[shape.vertices[1]]
    love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, pixels(curr.x)+left,pixels(curr.y)+top)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    love.graphics.circle('line', pixels(center.x)+left,pixels(center.y)+top, pixels(shape.radius))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    love.graphics.arc('line', 'open', pixels(center.x)+left,pixels(center.y)+top, pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  elseif shape.mode == 'deleted' then
  else
    print(shape.mode)
    assert(false)
  end
end

function draw_pending_shape(left,top, drawing)
  local shape = drawing.pending
  if shape.mode == 'freehand' then
    draw_shape(left,top, drawing, shape)
  elseif shape.mode == 'line' then
    local p1 = drawing.points[shape.p1]
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    love.graphics.line(pixels(p1.x)+left,pixels(p1.y)+top, pixels(mx)+left,pixels(my)+top)
  elseif shape.mode == 'manhattan' then
    local p1 = drawing.points[shape.p1]
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    if math.abs(mx-p1.x) > math.abs(my-p1.y) then
      love.graphics.line(pixels(p1.x)+left,pixels(p1.y)+top, pixels(mx)+left,pixels(p1.y)+top)
    else
      love.graphics.line(pixels(p1.x)+left,pixels(p1.y)+top, pixels(p1.x)+left,pixels(my)+top)
    end
  elseif shape.mode == 'polygon' then
    -- don't close the loop on a pending polygon
    local prev = nil
    for _,point in ipairs(shape.vertices) do
      local curr = drawing.points[point]
      if prev then
        love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, pixels(curr.x)+left,pixels(curr.y)+top)
      end
      prev = curr
    end
    love.graphics.line(pixels(prev.x)+left,pixels(prev.y)+top, love.mouse.getX(),love.mouse.getY())
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    local cx,cy = pixels(center.x)+left, pixels(center.y)+top
    love.graphics.circle('line', cx,cy, math.dist(cx,cy, love.mouse.getX(),love.mouse.getY()))
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    if mx < 0 or mx >= 256 or my < 0 or my >= drawing.h then
      return
    end
    shape.end_angle = angle_with_hint(center.x,center.y, mx,my, shape.end_angle)
    local cx,cy = pixels(center.x)+left, pixels(center.y)+top
    love.graphics.arc('line', 'open', cx,cy, pixels(shape.radius), shape.start_angle, shape.end_angle, 360)
  end
end

function on_shape(x,y, drawing, shape)
  if shape.mode == 'freehand' then
    return on_freehand(x,y, drawing, shape)
  elseif shape.mode == 'line' then
    return on_line(x,y, drawing, shape)
  elseif shape.mode == 'manhattan' then
    return x == drawing.points[shape.p1].x or y == drawing.points[shape.p1].y
  elseif shape.mode == 'polygon' then
    return on_polygon(x,y, drawing, shape)
  elseif shape.mode == 'circle' then
    local center = drawing.points[shape.center]
    return math.dist(center.x,center.y, x,y) == shape.radius
  elseif shape.mode == 'arc' then
    local center = drawing.points[shape.center]
    local dist = math.dist(center.x,center.y, x,y)
    if dist < shape.radius*0.95 or dist > shape.radius*1.05 then
      return false
    end
    return angle_between(center.x,center.y, x,y, shape.start_angle,shape.end_angle)
  elseif shape.mode == 'deleted' then
  else
    print(shape.mode)
    assert(false)
  end
end

function on_freehand(x,y, drawing, shape)
  local prev
  for _,p in ipairs(shape.points) do
    if prev then
      if on_line(x,y, drawing, {p1=prev, p2=p}) then
        return true
      end
    end
    prev = p
  end
  return false
end

function on_line(x,y, drawing, shape)
  local p1,p2
  if type(shape.p1) == 'number' then
    p1 = drawing.points[shape.p1]
    p2 = drawing.points[shape.p2]
  else
    p1 = shape.p1
    p2 = shape.p2
  end
  if p1.x == p2.x then
    if math.abs(p1.x-x) > 5 then
      return false
    end
    local y1,y2 = p1.y,p2.y
    if y1 > y2 then
      y1,y2 = y2,y1
    end
    return y >= y1 and y <= y2
  end
  -- has the right slope and intercept
  local m = (p2.y - p1.y) / (p2.x - p1.x)
  local yp = p1.y + m*(x-p1.x)
  if yp < 0.95*y or yp > 1.05*y then
    return false
  end
  -- between endpoints
  local k = (x-p1.x) / (p2.x-p1.x)
  return k > -0.05 and k < 1.05
end

function on_polygon(x,y, drawing, shape)
  local prev
  for _,p in ipairs(shape.vertices) do
    if prev then
      if on_line(x,y, drawing, {p1=prev, p2=p}) then
        return true
      end
    end
    prev = p
  end
  return on_line(x,y, drawing, {p1=shape.vertices[1], p2=shape.vertices[#shape.vertices]})
end

function angle_between(x1,y1, x2,y2, s,e)
  local angle = math.angle(x1,y1, x2,y2)
--?   print(s,e, angle-math.pi*2, angle, angle+math.pi*2)
  if s > e then
    s,e = e,s
  end
  -- I'm not sure this is right or ideal..
  angle = angle-math.pi*2
  if s <= angle and angle <= e then
    return true
  end
  angle = angle+math.pi*2
  if s <= angle and angle <= e then
    return true
  end
  angle = angle+math.pi*2
  return s <= angle and angle <= e
end

function love.textinput(t)
  if love.mouse.isDown('1') then return end
  if in_drawing() then return end
  local byteoffset
  if cursor_pos > 1 then
    byteoffset = utf8.offset(lines[cursor_line], cursor_pos-1)
  else
    byteoffset = 0
  end
  lines[cursor_line] = string.sub(lines[cursor_line], 1, byteoffset)..t..string.sub(lines[cursor_line], byteoffset+1)
  cursor_pos = cursor_pos+1
  if filename then
    save_to_disk(lines, filename)
  end
end

function keychord_pressed(chord)
  -- Don't handle any keys here that would trigger love.textinput above.
  if chord == 'return' then
    table.insert(lines, cursor_line+1, '')
    cursor_line = cursor_line+1
    cursor_pos = 1
  elseif chord == 'backspace' then
    if #lines > 1 and lines[#lines] == '' then
      table.remove(lines)
    elseif type(lines[#lines]) == 'table' then
      table.remove(lines)  -- we'll add undo soon
    else
      if cursor_pos > 1 then
        local byte_start = utf8.offset(lines[cursor_line], cursor_pos-1)
        local byte_end = utf8.offset(lines[cursor_line], cursor_pos)
        if byte_start then
          if byte_end then
            lines[cursor_line] = string.sub(lines[cursor_line], 1, byte_start-1)..string.sub(lines[cursor_line], byte_end)
          else
            lines[cursor_line] = string.sub(lines[cursor_line], 1, byte_start-1)
          end
          cursor_pos = cursor_pos-1
        end
      end
    end
  elseif chord == 'left' then
    if cursor_pos > 1 then
      cursor_pos = cursor_pos - 1
    end
  elseif chord == 'right' then
    if cursor_pos <= #lines[cursor_line] then
      cursor_pos = cursor_pos + 1
    end
  elseif chord == 'home' then
    cursor_pos = 1
  elseif chord == 'end' then
    cursor_pos = #lines[cursor_line]+1
  elseif chord == 'up' then
    if cursor_line > 1 then
      local old_x = cursor_x(lines[cursor_line], cursor_pos)
      cursor_line = cursor_line-1
      cursor_pos = nearest_cursor_pos(lines[cursor_line], old_x, cursor_pos)
    end
  elseif chord == 'down' then
    if cursor_line < #lines then
      local old_x = cursor_x(lines[cursor_line], cursor_pos)
      cursor_line = cursor_line+1
      cursor_pos = nearest_cursor_pos(lines[cursor_line], old_x, cursor_pos)
    end
  elseif chord == 'delete' then
    if cursor_pos <= #lines[cursor_line] then
      local byte_start = utf8.offset(lines[cursor_line], cursor_pos)
      local byte_end = utf8.offset(lines[cursor_line], cursor_pos+1)
      if byte_start then
        if byte_end then
          lines[cursor_line] = string.sub(lines[cursor_line], 1, byte_start-1)..string.sub(lines[cursor_line], byte_end)
        else
          lines[cursor_line] = string.sub(lines[cursor_line], 1, byte_start-1)
        end
        -- no change to cursor_pos
      end
    end
  elseif chord == 'escape' and love.mouse.isDown('1') then
    local drawing = current_drawing()
    drawing.pending = {}
  elseif chord == 'C-f' and not love.mouse.isDown('1') then
    current_mode = 'freehand'
  elseif chord == 'C-g' and not love.mouse.isDown('1') then
    current_mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'g' then
    current_mode = 'polygon'
    local drawing = current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'p' and current_mode == 'polygon' then
    local drawing = current_drawing()
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    local j = insert_point(drawing.points, mx,my)
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-c' and not love.mouse.isDown('1') then
    current_mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'a' and current_mode == 'circle' then
    local drawing = current_drawing()
    drawing.pending.mode = 'arc'
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    local j = insert_point(drawing.points, mx,my)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = math.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = math.angle(center.x,center.y, mx,my)
  elseif love.mouse.isDown('1') and chord == 'c' then
    current_mode = 'circle'
    local drawing = current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'l' then
    current_mode = 'line'
    local drawing = current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-l' then
    current_mode = 'line'
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_line(drawing, shape)
    end
  elseif love.mouse.isDown('1') and chord == 'm' then
    current_mode = 'manhattan'
    local drawing = select_drawing_at_mouse()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not love.mouse.isDown('1') then
    current_mode = 'manhattan'
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      convert_horvert(drawing, shape)
    end
  elseif chord == 'C-s' and not love.mouse.isDown('1') then
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      smoothen(shape)
    end
  elseif chord == 'C-v' and not love.mouse.isDown('1') then
    local drawing,_,p = select_point_at_mouse()
    if drawing then
      previous_mode = current_mode
      current_mode = 'move'
      drawing.pending = {mode=current_mode, target_point=p}
      lines.current = drawing
    end
  elseif love.mouse.isDown('1') and chord == 'v' then
    local drawing,_,p = select_point_at_mouse()
    if drawing then
      previous_mode = current_mode
      current_mode = 'move'
      drawing.pending = {mode=current_mode, target_point=p}
      lines.current = drawing
    end
  elseif chord == 'C-d' and not love.mouse.isDown('1') then
    local drawing,i,p = select_point_at_mouse()
    if drawing then
      for _,shape in ipairs(drawing.shapes) do
        if contains_point(shape, i) then
          if shape.mode == 'polygon' then
            local idx = table.find(shape.vertices, i)
            assert(idx)
            table.remove(shape.vertices, idx)
            if #shape.vertices < 3 then
              shape.mode = 'deleted'
            end
          else
            shape.mode = 'deleted'
          end
        end
      end
      drawing.points[i].deleted = true
    end
    local drawing,i,shape = select_shape_at_mouse()
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not love.mouse.isDown('1') then
    local drawing = select_drawing_at_mouse()
    if drawing then
      drawing.show_help = true
    end
  elseif chord == 'escape' and not love.mouse.isDown('1') then
    local drawing = select_drawing_at_mouse()
    if drawing then
      drawing.show_help = false
    end
  end
end

function cursor_x(line, cursor_pos)
  if type(line) == 'table' then return 0 end
  local line_before_cursor = line:sub(1, cursor_pos-1)
  local text_before_cursor = love.graphics.newText(love.graphics.getFont(), line_before_cursor)
  return text_before_cursor:getWidth()
end

function nearest_cursor_pos(line, x, hint)
  if type(line) == 'table' then return hint end
  if x == 0 then
    return 1
  end
  local max_x = cursor_x(line, #line+1)
  if x > max_x then
    return #line+1
  end
  local currx = cursor_x(line, hint)
  if currx > x-2 and currx < x+2 then
    return hint
  end
  local left, right = 1, #line+1
  if currx > x then
    right = hint
  else
    left = hint
  end
  while left < right-1 do
    local curr = math.floor((left+right)/2)
    local currx = cursor_x(line, curr)
    if currx > x-2 and currx < x+2 then
      return curr
    end
    if currx > x then
      right = curr
    else
      left = curr
    end
  end
  return right
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
          assert(shape)
          if on_shape(mx,my, drawing, shape) then
            return drawing,i,shape
          end
        end
      end
    end
  end
end

function select_point_at_mouse()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
        for i,point in ipairs(drawing.points) do
          assert(point)
          if near(point, mx,my) then
            return drawing,i,point
          end
        end
      end
    end
  end
end

function select_drawing_at_mouse()
  for _,drawing in ipairs(lines) do
    if type(drawing) == 'table' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+drawingw then
        return drawing
      end
    end
  end
end

function contains_point(shape, p)
  if shape.mode == 'freehand' then
    -- not supported
  elseif shape.mode == 'line' or shape.mode == 'manhattan' then
    return shape.p1 == p or shape.p2 == p
  elseif shape.mode == 'polygon' then
    return table.find(shape.vertices, p)
  elseif shape.mode == 'circle' then
    return shape.center == p
  elseif shape.mode == 'arc' then
    return shape.center == p
    -- ugh, how to support angles
  elseif shape.mode == 'deleted' then
    -- already done
  else
    print(shape.mode)
    assert(false)
  end
end

function convert_line(drawing, shape)
  -- Perhaps we should do a more sophisticated "simple linear regression"
  -- here:
  --   https://en.wikipedia.org/wiki/Linear_regression#Simple_and_multiple_linear_regression
  -- But this works well enough for close-to-linear strokes.
  assert(shape.mode == 'freehand')
  shape.mode = 'line'
  shape.p1 = insert_point(drawing.points, shape.points[1].x, shape.points[1].y)
  local n = #shape.points
  shape.p2 = insert_point(drawing.points, shape.points[n].x, shape.points[n].y)
end

-- turn a line either horizontal or vertical
function convert_horvert(drawing, shape)
  if shape.mode == 'freehand' then
    convert_line(shape)
  end
  assert(shape.mode == 'line')
  local p1 = drawing.points[shape.p1]
  local p2 = drawing.points[shape.p2]
  if math.abs(p1.x-p2.x) > math.abs(p1.y-p2.y) then
    p2.y = p1.y
  else
    p2.x = p1.x
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

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end

function angle_with_hint(x1, y1, x2, y2, hint)
  local result = math.angle(x1,y1, x2,y2)
  if hint then
    -- Smooth the discontinuity where angle goes from positive to negative.
    -- The hint is a memory of which way we drew it last time.
    while result > hint+math.pi/10 do
      result = result-math.pi*2
    end
    while result < hint-math.pi/10 do
      result = result+math.pi*2
    end
  end
  return result
end

-- result is from -π/2 to 3π/2, approximately adding math.atan2 from Lua 5.3
-- (LÖVE is Lua 5.1)
function math.angle(x1,y1, x2,y2)
  local result = math.atan((y2-y1)/(x2-x1))
  if x2 < x1 then
    result = result+math.pi
  end
  return result
end

function math.dist(x1,y1, x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end

function load_from_disk(filename)
  local infile = io.open(filename)
  local result = load_from_file(infile)
  if infile then infile:close() end
  return result
end

function load_from_file(infile)
  local result = {}
  if infile then
    local infile_next_line = infile:lines()  -- works with both Lua files and LÖVE Files (https://www.love2d.org/wiki/File)
    while true do
      local line = infile_next_line()
      if line == nil then break end
      if line == '```lines' then  -- inflexible with whitespace since these files are always autogenerated
        table.insert(result, load_drawing(infile_next_line))
      else
        table.insert(result, line)
      end
    end
  end
  if #result == 0 then
    table.insert(result, '')
  end
  return result
end

function save_to_disk(lines, filename)
  local outfile = io.open(filename, 'w')
  for _,line in ipairs(lines) do
    if type(line) == 'table' then
      store_drawing(outfile, line)
    else
      outfile:write(line..'\n')
    end
  end
  outfile:close()
end

json = require 'json'
function load_drawing(infile_next_line)
  local drawing = {h=256/2, points={}, shapes={}, pending={}}
  while true do
    local line = infile_next_line()
    assert(line)
    if line == '```' then break end
    local shape = json.decode(line)
    if shape.mode == 'line' or shape.mode == 'manhattan' then
      shape.p1 = insert_point(drawing.points, shape.p1.x, shape.p1.y)
      shape.p2 = insert_point(drawing.points, shape.p2.x, shape.p2.y)
    elseif shape.mode == 'polygon' then
      for i,p in ipairs(shape.vertices) do
        shape.vertices[i] = insert_point(drawing.points, p.x,p.y)
      end
    elseif shape.mode == 'circle' or shape.mode == 'arc' then
      shape.center = insert_point(drawing.points, shape.center.x,shape.center.y)
    end
    table.insert(drawing.shapes, shape)
  end
  return drawing
end

function store_drawing(outfile, drawing)
  outfile:write('```lines\n')
  for _,shape in ipairs(drawing.shapes) do
    if shape.mode == 'freehand' then
      outfile:write(json.encode(shape)..'\n')
    elseif shape.mode == 'line' or shape.mode == 'manhattan' then
      local line = json.encode({mode=shape.mode, p1=drawing.points[shape.p1], p2=drawing.points[shape.p2]})
      outfile:write(line..'\n')
    elseif shape.mode == 'polygon' then
      local obj = {mode=shape.mode, vertices={}}
      for _,p in ipairs(shape.vertices) do
        table.insert(obj.vertices, drawing.points[p])
      end
      local line = json.encode(obj)
      outfile:write(line..'\n')
    elseif shape.mode == 'circle' then
      outfile:write(json.encode({mode=shape.mode, center=drawing.points[shape.center], radius=shape.radius})..'\n')
    elseif shape.mode == 'arc' then
      outfile:write(json.encode({mode=shape.mode, center=drawing.points[shape.center], radius=shape.radius, start_angle=shape.start_angle, end_angle=shape.end_angle})..'\n')
    end
  end
  outfile:write('```\n')
end

icon = {}

function icon.freehand(x, y)
  love.graphics.line(x+4,y+7,x+5,y+5)
  love.graphics.line(x+5,y+5,x+7,y+4)
  love.graphics.line(x+7,y+4,x+9,y+3)
  love.graphics.line(x+9,y+3,x+10,y+5)
  love.graphics.line(x+10,y+5,x+12,y+6)
  love.graphics.line(x+12,y+6,x+13,y+8)
  love.graphics.line(x+13,y+8,x+13,y+10)
  love.graphics.line(x+13,y+10,x+14,y+12)
  love.graphics.line(x+14,y+12,x+15,y+14)
  love.graphics.line(x+15,y+14,x+15,y+16)
end

function icon.line(x, y)
  love.graphics.line(x+4,y+2, x+16,y+18)
end

function icon.manhattan(x, y)
  love.graphics.line(x+4,y+20, x+4,y+2)
  love.graphics.line(x+4,y+2, x+10,y+2)
  love.graphics.line(x+10,y+2, x+10,y+10)
  love.graphics.line(x+10,y+10, x+18,y+10)
end

function icon.polygon(x, y)
  love.graphics.line(x+8,y+2, x+14,y+2)
  love.graphics.line(x+14,y+2, x+18,y+10)
  love.graphics.line(x+18,y+10, x+10,y+18)
  love.graphics.line(x+10,y+18, x+4,y+12)
  love.graphics.line(x+4,y+12, x+8,y+2)
end

function icon.circle(x, y)
  love.graphics.circle('line', x+10,y+10, 8)
end

function draw_help_without_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  love.graphics.rectangle('line', 16,drawing.y, drawingw,pixels(drawing.h))
  local y = drawing.y+10
  love.graphics.print("Things you can do:", 16+30,y)
  y = y+15
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape_singular(), 16+30,y)
  y = y+15
  love.graphics.print("* Hover on a point and press 'ctrl+v' to start moving it,", 16+30,y)
  y = y+15
  love.graphics.print("then press the mouse button to finish", 16+30+bullet_indent(),y)
  y = y+15
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", 16+30,y)
  y = y+15
  y = y+15
  if current_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+f' to switch to drawing freehand strokes", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+l' to switch to drawing lines", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+c' to switch to drawing circles/arcs", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+g' to switch to drawing polygons", 16+30,y)
    y = y+15
  end
end

function draw_help_with_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  love.graphics.rectangle('line', 16,drawing.y, drawingw,pixels(drawing.h))
  local y = drawing.y+10
  love.graphics.print("You're currently drawing "..current_shape_pluralized(), 16+30,y)
  y = y+15
  love.graphics.print('Things you can do now:', 16+30,y)
  y = y+15
  if current_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing a freehand stroke', 16+30,y)
    y = y+15
  elseif current_mode == 'line' or current_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing a line', 16+30,y)
    y = y+15
  elseif current_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing a full circle', 16+30,y)
      y = y+15
      love.graphics.print("* Press 'a' to draw just an arc of a circle", 16+30,y)
    else
      love.graphics.print('* Release the mouse button to finish drawing an arc', 16+30,y)
    end
    y = y+15
  elseif current_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing a polygon', 16+30,y)
    y = y+15
    love.graphics.print("* Press 'p' to add a vertex to the polygon", 16+30,y)
    y = y+15
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", 16+30,y)
  y = y+15
  y = y+15
  if current_mode ~= 'line' then
    love.graphics.print("* Press 'l' to switch to drawing lines", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'circle' then
    love.graphics.print("* Press 'c' to switch to drawing circles/arcs", 16+30,y)
    y = y+15
  end
  if current_mode ~= 'polygon' then
    love.graphics.print("* Press 'g' to switch to drawing polygons", 16+30,y)
    y = y+15
  end
end

function current_shape_singular()
  if current_mode == 'freehand' then
    return 'freehand stroke'
  elseif current_mode == 'line' then
    return 'straight line'
  elseif current_mode == 'manhattan' then
    return 'horizontal/vertical line'
  else
    return current_mode
  end
end

function current_shape_pluralized()
  return current_shape_singular()..'s'
end

_bullet_indent = nil
function bullet_indent()
  if _bullet_indent == nil then
    local text = love.graphics.newText(love.graphics.getFont(), '* ')
    _bullet_indent = text:getWidth()
  end
  return _bullet_indent
end
