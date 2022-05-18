local utf8 = require 'utf8'
require 'keychord'
require 'button'
local Text = require 'text'
local Drawing = require 'drawing'

-- a line is either text or a drawing
-- a text is a table with:
--    mode = 'text'
--    string data
-- a drawing is a table with:
--    mode = 'drawing'
--    a (y) coord in pixels (updated while painting screen),
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
Lines = {{mode='text', data=''}}
Cursor_line = 1
-- this is a line
-- ^cursor_pos = 1
--  ^cursor_pos = 2
--   ...
--               ^cursor_pos past end of line is 15
Cursor_pos = #Lines[Cursor_line].data+1

Screen_width, Screen_height, Screen_flags = 0, 0, nil

Current_mode = 'line'
Previous_mode = nil

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts. `Drawing_width` describes their width in pixels.
Drawing_width = nil  -- pixels
function pixels(n)  -- parts to pixels
  return n*Drawing_width/256
end
function coord(n)  -- pixels to parts
  return math.floor(n*256/Drawing_width)
end

Zoom = 1.5

Filename = 'lines.txt'

function love.load(arg)
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  Screen_width, Screen_height, Screen_flags = love.window.getMode()
  -- shrink slightly to account for window decoration
  Screen_width = Screen_width-100
  Screen_height = Screen_height-100
  love.window.setMode(Screen_width, Screen_height)
  love.window.setTitle('Text with Lines')
  Drawing_width = math.floor(Screen_width/2/40)*40
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  if #arg > 0 then
    Filename = arg[1]
  end
  Lines = load_from_disk(Filename)
  for i,line in ipairs(Lines) do
    if line.mode == 'text' then
      Cursor_line = i
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)
end

function love.filedropped(file)
  Filename = file:getFilename()
  file:open('r')
  Lines = load_from_file(file)
  file:close()
  for i,line in ipairs(Lines) do
    if line.mode == 'text' then
      Cursor_line = i
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)
end

function love.draw()
  button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 0, 0, Screen_width-1, Screen_height-1)
  love.graphics.setColor(0, 0, 0)
  local y = 0
  for line_index,line in ipairs(Lines) do
    y = y+15*Zoom
    line.y = y
    if line.mode == 'text' and line.data == '' then
      button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
        icon = icon.insert_drawing,
        onpress1 = function()
                     table.insert(Lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                     if Cursor_line >= line_index then
                       Cursor_line = Cursor_line+1
                     end
                   end})
        if line_index == Cursor_line then
          love.graphics.setColor(0,0,0)
          love.graphics.print('_', 25, y+6)  -- drop the cursor down a bit to account for the increased font size
        end
    elseif line.mode == 'drawing' then
      y = y+pixels(line.h)
      Drawing.draw(line, y)
    else
      Text.draw(line, line_index, Cursor_line, y, Cursor_pos)
    end
  end
end

function love.update(dt)
  if love.mouse.isDown('1') then
    if Lines.current then
      if Lines.current.mode == 'drawing' then
        local drawing = Lines.current
        local x, y = love.mouse.getX(), love.mouse.getY()
        if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
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
  elseif Current_mode == 'move' then
    local drawing = Lines.current
    local x, y = love.mouse.getX(), love.mouse.getY()
    if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
      local mx,my = coord(x-16), coord(y-drawing.y)
      drawing.pending.target_point.x = mx
      drawing.pending.target_point.y = my
    end
  end
end

function love.mousepressed(x,y, button)
  propagate_to_button_handlers(x,y, button)

  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      -- move cursor
      if x >= 16 and y >= line.y and y < y+15*Zoom then
        Cursor_line = line_index
        Cursor_pos = Text.nearest_cursor_pos(line.data, x, 1)
      end
    elseif line.mode == 'drawing' then
      local drawing = line
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
        if Current_mode == 'freehand' then
          drawing.pending = {mode=Current_mode, points={{x=coord(x-16), y=coord(y-drawing.y)}}}
        elseif Current_mode == 'line' or Current_mode == 'manhattan' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=Current_mode, p1=j}
        elseif Current_mode == 'polygon' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=Current_mode, vertices={j}}
        elseif Current_mode == 'circle' then
          local j = insert_point(drawing.points, coord(x-16), coord(y-drawing.y))
          drawing.pending = {mode=Current_mode, center=j}
        end
        Lines.current = drawing
      end
    end
  end
end

function love.mousereleased(x,y, button)
  if Current_mode == 'move' then
    Current_mode = Previous_mode
    Previous_mode = nil
  elseif Lines.current then
    if Lines.current.pending then
      if Lines.current.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'line' then
        local mx,my = coord(x-16), coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = insert_point(Lines.current.points, mx,my)
          Lines.current.pending.p2 = j
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'manhattan' then
        local p1 = Lines.current.points[Lines.current.pending.p1]
        local mx,my = coord(x-16), coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            local j = insert_point(Lines.current.points, mx, p1.y)
            Lines.current.pending.p2 = j
          else
            local j = insert_point(Lines.current.points, p1.x, my)
            Lines.current.pending.p2 = j
          end
          local p2 = Lines.current.points[Lines.current.pending.p2]
          love.mouse.setPosition(16+pixels(p2.x), Lines.current.y+pixels(p2.y))
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'polygon' then
        local mx,my = coord(x-16), coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = insert_point(Lines.current.points, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'circle' then
        local mx,my = coord(x-16), coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.radius = math.dist(center.x,center.y, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'arc' then
        local mx,my = coord(x-16), coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.end_angle = angle_with_hint(center.x,center.y, mx,my, Lines.current.pending.end_angle)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      end
      Lines.current.pending = {}
      Lines.current = nil
    end
  end
  if Filename then
    save_to_disk(Lines, Filename)
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
  if Lines[Cursor_line].mode == 'drawing' then return end
  local byteoffset
  if Cursor_pos > 1 then
    byteoffset = utf8.offset(Lines[Cursor_line].data, Cursor_pos-1)
  else
    byteoffset = 0
  end
  Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byteoffset)..t..string.sub(Lines[Cursor_line].data, byteoffset+1)
  Cursor_pos = Cursor_pos+1
  if Filename then
    save_to_disk(Lines, Filename)
  end
end

function keychord_pressed(chord)
  -- Don't handle any keys here that would trigger love.textinput above.
  -- shortcuts for text
  if chord == 'return' then
    table.insert(Lines, Cursor_line+1, {mode='text', data=''})
    Cursor_line = Cursor_line+1
    Cursor_pos = 1
  elseif chord == 'backspace' then
    if Cursor_pos > 1 then
      local byte_start = utf8.offset(Lines[Cursor_line].data, Cursor_pos-1)
      local byte_end = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
      if byte_start then
        if byte_end then
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)..string.sub(Lines[Cursor_line].data, byte_end)
        else
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)
        end
        Cursor_pos = Cursor_pos-1
      end
    elseif Cursor_line > 1 then
      if Lines[Cursor_line-1].mode == 'drawing' then
        table.remove(Lines, Cursor_line-1)
      else
        -- join Lines
        Cursor_pos = utf8.len(Lines[Cursor_line-1].data)+1
        Lines[Cursor_line-1].data = Lines[Cursor_line-1].data..Lines[Cursor_line].data
        table.remove(Lines, Cursor_line)
      end
      Cursor_line = Cursor_line-1
    end
  elseif chord == 'left' then
    if Cursor_pos > 1 then
      Cursor_pos = Cursor_pos-1
    end
  elseif chord == 'right' then
    if Cursor_pos <= #Lines[Cursor_line].data then
      Cursor_pos = Cursor_pos+1
    end
  elseif chord == 'home' then
    Cursor_pos = 1
  elseif chord == 'end' then
    Cursor_pos = #Lines[Cursor_line].data+1
  elseif chord == 'delete' then
    if Cursor_pos <= #Lines[Cursor_line].data then
      local byte_start = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
      local byte_end = utf8.offset(Lines[Cursor_line].data, Cursor_pos+1)
      if byte_start then
        if byte_end then
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)..string.sub(Lines[Cursor_line].data, byte_end)
        else
          Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_start-1)
        end
        -- no change to Cursor_pos
      end
    end
  -- transitioning between drawings and text
  elseif chord == 'up' then
    assert(Lines[Cursor_line].mode == 'text')
    local new_cursor_line = Cursor_line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
        local old_x = Text.cursor_x(Lines[new_cursor_line].data, Cursor_pos)
        Cursor_line = new_cursor_line
        Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, old_x, Cursor_pos)
        break
      end
    end
  elseif chord == 'down' then
    assert(Lines[Cursor_line].mode == 'text')
    local new_cursor_line = Cursor_line
    while new_cursor_line < #Lines do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        local old_x = Text.cursor_x(Lines[new_cursor_line].data, Cursor_pos)
        Cursor_line = new_cursor_line
        Cursor_pos = Text.nearest_cursor_pos(Lines[Cursor_line].data, old_x, Cursor_pos)
        break
      end
    end
  elseif chord == 'C-=' then
    Drawing_width = Drawing_width/Zoom
    Zoom = Zoom+0.5
    Drawing_width = Drawing_width*Zoom
  elseif chord == 'C--' then
    Drawing_width = Drawing_width/Zoom
    Zoom = Zoom-0.5
    Drawing_width = Drawing_width*Zoom
  elseif chord == 'C-0' then
    Drawing_width = Drawing_width/Zoom
    Zoom = 1.5
    Drawing_width = Drawing_width*Zoom
  -- shortcuts for drawings
  elseif chord == 'escape' and love.mouse.isDown('1') then
    local drawing = current_drawing()
    drawing.pending = {}
  elseif chord == 'C-f' and not love.mouse.isDown('1') then
    Current_mode = 'freehand'
  elseif chord == 'C-g' and not love.mouse.isDown('1') then
    Current_mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'g' then
    Current_mode = 'polygon'
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
  elseif love.mouse.isDown('1') and chord == 'p' and Current_mode == 'polygon' then
    local drawing = current_drawing()
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    local j = insert_point(drawing.points, mx,my)
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-c' and not love.mouse.isDown('1') then
    Current_mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'a' and Current_mode == 'circle' then
    local drawing = current_drawing()
    drawing.pending.mode = 'arc'
    local mx,my = coord(love.mouse.getX()-16), coord(love.mouse.getY()-drawing.y)
    local j = insert_point(drawing.points, mx,my)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = math.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = math.angle(center.x,center.y, mx,my)
  elseif love.mouse.isDown('1') and chord == 'c' then
    Current_mode = 'circle'
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
    Current_mode = 'line'
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
    Current_mode = 'line'
    local drawing,_,shape = select_shape_at_mouse()
    if drawing then
      convert_line(drawing, shape)
    end
  elseif love.mouse.isDown('1') and chord == 'm' then
    Current_mode = 'manhattan'
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
    Current_mode = 'manhattan'
    local drawing,_,shape = select_shape_at_mouse()
    if drawing then
      convert_horvert(drawing, shape)
    end
  elseif chord == 'C-s' and not love.mouse.isDown('1') then
    local drawing,_,shape = select_shape_at_mouse()
    if drawing then
      smoothen(shape)
    end
  elseif chord == 'C-v' and not love.mouse.isDown('1') then
    local drawing,_,p = select_point_at_mouse()
    if drawing then
      Previous_mode = Current_mode
      Current_mode = 'move'
      drawing.pending = {mode=Current_mode, target_point=p}
      Lines.current = drawing
    end
  elseif love.mouse.isDown('1') and chord == 'v' then
    local drawing,_,p = select_point_at_mouse()
    if drawing then
      Previous_mode = Current_mode
      Current_mode = 'move'
      drawing.pending = {mode=Current_mode, target_point=p}
      Lines.current = drawing
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
    local drawing,_,shape = select_shape_at_mouse()
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not love.mouse.isDown('1') then
    local drawing = select_drawing_at_mouse()
    if drawing then
      drawing.show_help = true
    end
  elseif chord == 'escape' and not love.mouse.isDown('1') then
    for _,line in ipairs(Lines) do
      if line.mode == 'drawing' then
        line.show_help = false
      end
    end
  end
end

function current_drawing()
  local x, y = love.mouse.getX(), love.mouse.getY()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
        return drawing
      end
    end
  end
  return nil
end

function select_shape_at_mouse()
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
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
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
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
  for _,drawing in ipairs(Lines) do
    if drawing.mode == 'drawing' then
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
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
        table.insert(result, {mode='text', data=line})
      end
    end
  end
  if #result == 0 then
    table.insert(result, {mode='text', data=''})
  end
  return result
end

function save_to_disk(lines, filename)
  local outfile = io.open(filename, 'w')
  for _,line in ipairs(lines) do
    if line.mode == 'drawing' then
      store_drawing(outfile, line)
    else
      outfile:write(line.data..'\n')
    end
  end
  outfile:close()
end

json = require 'json'
function load_drawing(infile_next_line)
  local drawing = {mode='drawing', h=256/2, points={}, shapes={}, pending={}}
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

function icon.insert_drawing(x, y)
  love.graphics.setColor(0.7,0.7,0.7)
  love.graphics.rectangle('line', x,y, 12,12)
  love.graphics.line(4,y+6, 16,y+6)
  love.graphics.line(10,y, 10,y+12)
  love.graphics.setColor(0, 0, 0)
end

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
  local y = drawing.y+10
  love.graphics.print("Things you can do:", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print("* Press the mouse button to start drawing a "..current_shape(), 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print("* Hover on a point and press 'ctrl+v' to start moving it,", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print("then press the mouse button to finish", 16+30+bullet_indent(),y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print("* Hover on a point or shape and press 'ctrl+d' to delete it", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  y = y+15*Zoom
  if Current_mode ~= 'freehand' then
    love.graphics.print("* Press 'ctrl+f' to switch to drawing freehand strokes", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'line' then
    love.graphics.print("* Press 'ctrl+l' to switch to drawing lines", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'manhattan' then
    love.graphics.print("* Press 'ctrl+m' to switch to drawing horizontal/vertical lines", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'circle' then
    love.graphics.print("* Press 'ctrl+c' to switch to drawing circles/arcs", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'polygon' then
    love.graphics.print("* Press 'ctrl+g' to switch to drawing polygons", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  love.graphics.print("* Press 'ctrl+=' or 'ctrl+-' to Zoom in or out", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print("* Press 'ctrl+0' to reset Zoom", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  y = y+15*Zoom
  love.graphics.print("Hit 'esc' now to hide this message", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', 16,drawing.y, Drawing_width, math.max(pixels(drawing.h),y-drawing.y))
end

function draw_help_with_mouse_pressed(drawing)
  love.graphics.setColor(0,0.5,0)
  local y = drawing.y+10
  love.graphics.print("You're currently drawing a "..current_shape(drawing.pending), 16+30,y, 0, Zoom)
  y = y+15*Zoom
  love.graphics.print('Things you can do now:', 16+30,y, 0, Zoom)
  y = y+15*Zoom
  if Current_mode == 'freehand' then
    love.graphics.print('* Release the mouse button to finish drawing the stroke', 16+30,y, 0, Zoom)
    y = y+15*Zoom
  elseif Current_mode == 'line' or Current_mode == 'manhattan' then
    love.graphics.print('* Release the mouse button to finish drawing the line', 16+30,y, 0, Zoom)
    y = y+15*Zoom
  elseif Current_mode == 'circle' then
    if drawing.pending.mode == 'circle' then
      love.graphics.print('* Release the mouse button to finish drawing the circle', 16+30,y, 0, Zoom)
      y = y+15*Zoom
      love.graphics.print("* Press 'a' to draw just an arc of a circle", 16+30,y, 0, Zoom)
    else
      love.graphics.print('* Release the mouse button to finish drawing the arc', 16+30,y, 0, Zoom)
    end
    y = y+15*Zoom
  elseif Current_mode == 'polygon' then
    love.graphics.print('* Release the mouse button to finish drawing the polygon', 16+30,y, 0, Zoom)
    y = y+15*Zoom
    love.graphics.print("* Press 'p' to add a vertex to the polygon", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  love.graphics.print("* Press 'esc' then release the mouse button to cancel the current shape", 16+30,y, 0, Zoom)
  y = y+15*Zoom
  y = y+15*Zoom
  if Current_mode ~= 'line' then
    love.graphics.print("* Press 'l' to switch to drawing lines", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'manhattan' then
    love.graphics.print("* Press 'm' to switch to drawing horizontal/vertical lines", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'circle' then
    love.graphics.print("* Press 'c' to switch to drawing circles/arcs", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  if Current_mode ~= 'polygon' then
    love.graphics.print("* Press 'g' to switch to drawing polygons", 16+30,y, 0, Zoom)
    y = y+15*Zoom
  end
  love.graphics.setColor(0,0.5,0, 0.1)
  love.graphics.rectangle('fill', 16,drawing.y, Drawing_width, math.max(pixels(drawing.h),y-drawing.y))
end

function current_shape(shape)
  if Current_mode == 'freehand' then
    return 'freehand stroke'
  elseif Current_mode == 'line' then
    return 'straight line'
  elseif Current_mode == 'manhattan' then
    return 'horizontal/vertical line'
  elseif Current_mode == 'circle' and shape and shape.start_angle then
    return 'arc'
  else
    return Current_mode
  end
end

_bullet_indent = nil
function bullet_indent()
  if _bullet_indent == nil then
    local text = love.graphics.newText(love.graphics.getFont(), '* ')
    _bullet_indent = text:getWidth()
  end
  return _bullet_indent
end
