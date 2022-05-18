local utf8 = require 'utf8'
require 'keychord'
require 'file'
require 'button'
local Text = require 'text'
local Drawing = require 'drawing'
local geom = require 'geom'
require 'help'
require 'icons'

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
Cursor_pos = #Lines[Cursor_line].data+1  -- in Unicode codepoints

Screen_width, Screen_height, Screen_flags = 0, 0, nil

Current_drawing_mode = 'line'
Previous_drawing_mode = nil

-- All drawings span 100% of some conceptual 'page width' and divide it up
-- into 256 parts. `Drawing_width` describes their width in pixels.
Drawing_width = nil  -- pixels

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
  love.keyboard.setKeyRepeat(true)
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
      y = y+Drawing.pixels(line.h)
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
        if y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
          if drawing.pending.mode == 'freehand' then
            table.insert(drawing.pending.points, {x=Drawing.coord(love.mouse.getX()-16), y=Drawing.coord(love.mouse.getY()-drawing.y)})
          elseif drawing.pending.mode == 'move' then
            local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
            drawing.pending.target_point.x = mx
            drawing.pending.target_point.y = my
          end
        end
      end
    end
  elseif Current_drawing_mode == 'move' then
    local drawing = Lines.current
    local x, y = love.mouse.getX(), love.mouse.getY()
    if y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
      local mx,my = Drawing.coord(x-16), Drawing.coord(y-drawing.y)
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
      if x >= 16 and y >= line.y and y < line.y+15*Zoom then
        Cursor_line = line_index
        Cursor_pos = Text.nearest_cursor_pos(line.data, x, 1)
      end
    elseif line.mode == 'drawing' then
      local drawing = line
      local x, y = love.mouse.getX(), love.mouse.getY()
      if y >= drawing.y and y < drawing.y + Drawing.pixels(drawing.h) and x >= 16 and x < 16+Drawing_width then
        if Current_drawing_mode == 'freehand' then
          drawing.pending = {mode=Current_drawing_mode, points={{x=Drawing.coord(x-16), y=Drawing.coord(y-drawing.y)}}}
        elseif Current_drawing_mode == 'line' or Current_drawing_mode == 'manhattan' then
          local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
          drawing.pending = {mode=Current_drawing_mode, p1=j}
        elseif Current_drawing_mode == 'polygon' then
          local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
          drawing.pending = {mode=Current_drawing_mode, vertices={j}}
        elseif Current_drawing_mode == 'circle' then
          local j = Drawing.insert_point(drawing.points, Drawing.coord(x-16), Drawing.coord(y-drawing.y))
          drawing.pending = {mode=Current_drawing_mode, center=j}
        end
        Lines.current = drawing
      end
    end
  end
end

function love.mousereleased(x,y, button)
  if Current_drawing_mode == 'move' then
    Current_drawing_mode = Previous_drawing_mode
    Previous_drawing_mode = nil
  elseif Lines.current then
    if Lines.current.pending then
      if Lines.current.pending.mode == 'freehand' then
        -- the last point added during update is good enough
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'line' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = Drawing.insert_point(Lines.current.points, mx,my)
          Lines.current.pending.p2 = j
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'manhattan' then
        local p1 = Lines.current.points[Lines.current.pending.p1]
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          if math.abs(mx-p1.x) > math.abs(my-p1.y) then
            local j = Drawing.insert_point(Lines.current.points, mx, p1.y)
            Lines.current.pending.p2 = j
          else
            local j = Drawing.insert_point(Lines.current.points, p1.x, my)
            Lines.current.pending.p2 = j
          end
          local p2 = Lines.current.points[Lines.current.pending.p2]
          love.mouse.setPosition(16+Drawing.pixels(p2.x), Lines.current.y+Drawing.pixels(p2.y))
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'polygon' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local j = Drawing.insert_point(Lines.current.points, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
        table.insert(Lines.current.shapes, Lines.current.pending)
      elseif Lines.current.pending.mode == 'circle' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.radius = math.dist(center.x,center.y, mx,my)
          table.insert(Lines.current.shapes, Lines.current.pending)
        end
      elseif Lines.current.pending.mode == 'arc' then
        local mx,my = Drawing.coord(x-16), Drawing.coord(y-Lines.current.y)
        if mx >= 0 and mx < 256 and my >= 0 and my < Lines.current.h then
          local center = Lines.current.points[Lines.current.pending.center]
          Lines.current.pending.end_angle = geom.angle_with_hint(center.x,center.y, mx,my, Lines.current.pending.end_angle)
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

function love.textinput(t)
  if love.mouse.isDown('1') then return end
  if Lines[Cursor_line].mode == 'drawing' then return end
  local byte_offset
  if Cursor_pos > 1 then
    byte_offset = utf8.offset(Lines[Cursor_line].data, Cursor_pos-1)
  else
    byte_offset = 0
  end
  Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_offset)..t..string.sub(Lines[Cursor_line].data, byte_offset+1)
  Cursor_pos = Cursor_pos+1
  if Filename then
    save_to_disk(Lines, Filename)
  end
end

function keychord_pressed(chord)
  -- Don't handle any keys here that would trigger love.textinput above.
  -- shortcuts for text
  if chord == 'return' then
    local byte_offset = utf8.offset(Lines[Cursor_line].data, Cursor_pos)
    if byte_offset then
      table.insert(Lines, Cursor_line+1, {mode='text', data=string.sub(Lines[Cursor_line].data, byte_offset)})
      Lines[Cursor_line].data = string.sub(Lines[Cursor_line].data, 1, byte_offset)
      Cursor_line = Cursor_line+1
      Cursor_pos = 1
    end
  elseif chord == 'left' then
    assert(Lines[Cursor_line].mode == 'text')
    if Cursor_pos > 1 then
      Cursor_pos = Cursor_pos-1
    else
      local new_cursor_line = Cursor_line
      while new_cursor_line > 1 do
        new_cursor_line = new_cursor_line-1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          Cursor_pos = #Lines[Cursor_line].data+1
          break
        end
      end
    end
  elseif chord == 'right' then
    assert(Lines[Cursor_line].mode == 'text')
    if Cursor_pos <= #Lines[Cursor_line].data then
      Cursor_pos = Cursor_pos+1
    else
      local new_cursor_line = Cursor_line
      while new_cursor_line <= #Lines-1 do
        new_cursor_line = new_cursor_line+1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor_line = new_cursor_line
          Cursor_pos = 1
          break
        end
      end
    end
  elseif chord == 'home' then
    Cursor_pos = 1
  elseif chord == 'end' then
    Cursor_pos = #Lines[Cursor_line].data+1
  -- transitioning between drawings and text
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
        -- join lines
        Cursor_pos = utf8.len(Lines[Cursor_line-1].data)+1
        Lines[Cursor_line-1].data = Lines[Cursor_line-1].data..Lines[Cursor_line].data
        table.remove(Lines, Cursor_line)
      end
      Cursor_line = Cursor_line-1
    end
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
    elseif Cursor_line < #Lines then
      if Lines[Cursor_line+1].mode == 'drawing' then
        table.remove(Lines, Cursor_line+1)
      else
        -- join lines
        Lines[Cursor_line].data = Lines[Cursor_line].data..Lines[Cursor_line+1].data
        table.remove(Lines, Cursor_line+1)
      end
    end
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
    local drawing = Drawing.current_drawing()
    drawing.pending = {}
  elseif chord == 'C-f' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'freehand'
  elseif chord == 'C-g' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'g' then
    Current_drawing_mode = 'polygon'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.vertices = {Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)}
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      if drawing.pending.vertices == nil then
        drawing.pending.vertices = {drawing.pending.p1}
      end
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.vertices = {drawing.pending.center}
    end
    drawing.pending.mode = 'polygon'
  elseif love.mouse.isDown('1') and chord == 'p' and Current_drawing_mode == 'polygon' then
    local drawing = Drawing.current_drawing()
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    local j = Drawing.insert_point(drawing.points, mx,my)
    table.insert(drawing.pending.vertices, j)
  elseif chord == 'C-c' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'a' and Current_drawing_mode == 'circle' then
    local drawing = Drawing.current_drawing()
    drawing.pending.mode = 'arc'
    local mx,my = Drawing.coord(love.mouse.getX()-16), Drawing.coord(love.mouse.getY()-drawing.y)
    local j = Drawing.insert_point(drawing.points, mx,my)
    local center = drawing.points[drawing.pending.center]
    drawing.pending.radius = math.dist(center.x,center.y, mx,my)
    drawing.pending.start_angle = geom.angle(center.x,center.y, mx,my)
  elseif love.mouse.isDown('1') and chord == 'c' then
    Current_drawing_mode = 'circle'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.center = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' or drawing.pending.mode == 'manhattan' then
      drawing.pending.center = drawing.pending.p1
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.center = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'circle'
  elseif love.mouse.isDown('1') and chord == 'l' then
    Current_drawing_mode = 'line'
    local drawing = Drawing.current_drawing()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    end
    drawing.pending.mode = 'line'
  elseif chord == 'C-l' then
    Current_drawing_mode = 'line'
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      convert_line(drawing, shape)
    end
  elseif love.mouse.isDown('1') and chord == 'm' then
    Current_drawing_mode = 'manhattan'
    local drawing = Drawing.select_drawing_at_mouse()
    if drawing.pending.mode == 'freehand' then
      drawing.pending.p1 = Drawing.insert_point(drawing.points, drawing.pending.points[1].x, drawing.pending.points[1].y)
    elseif drawing.pending.mode == 'line' then
      -- do nothing
    elseif drawing.pending.mode == 'polygon' then
      drawing.pending.p1 = drawing.pending.vertices[1]
    elseif drawing.pending.mode == 'circle' or drawing.pending.mode == 'arc' then
      drawing.pending.p1 = drawing.pending.center
    end
    drawing.pending.mode = 'manhattan'
  elseif chord == 'C-m' and not love.mouse.isDown('1') then
    Current_drawing_mode = 'manhattan'
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      convert_horvert(drawing, shape)
    end
  elseif chord == 'C-s' and not love.mouse.isDown('1') then
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      smoothen(shape)
    end
  elseif chord == 'C-v' and not love.mouse.isDown('1') then
    local drawing,_,p = Drawing.select_point_at_mouse()
    if drawing then
      Previous_drawing_mode = Current_drawing_mode
      Current_drawing_mode = 'move'
      drawing.pending = {mode=Current_drawing_mode, target_point=p}
      Lines.current = drawing
    end
  elseif love.mouse.isDown('1') and chord == 'v' then
    local drawing,_,p = Drawing.select_point_at_mouse()
    if drawing then
      Previous_drawing_mode = Current_drawing_mode
      Current_drawing_mode = 'move'
      drawing.pending = {mode=Current_drawing_mode, target_point=p}
      Lines.current = drawing
    end
  elseif chord == 'C-d' and not love.mouse.isDown('1') then
    local drawing,i,p = Drawing.select_point_at_mouse()
    if drawing then
      for _,shape in ipairs(drawing.shapes) do
        if Drawing.contains_point(shape, i) then
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
    local drawing,_,shape = Drawing.select_shape_at_mouse()
    if drawing then
      shape.mode = 'deleted'
    end
  elseif chord == 'C-h' and not love.mouse.isDown('1') then
    local drawing = Drawing.select_drawing_at_mouse()
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

function love.keyreleased(key, scancode)
end

function table.find(h, x)
  for k,v in pairs(h) do
    if v == x then
      return k
    end
  end
end
