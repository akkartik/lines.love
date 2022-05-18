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
  save_to_disk(Lines, Filename)
end

function keychord_pressed(chord)
  if love.mouse.isDown('1') or chord:sub(1,2) == 'C-' then
    Drawing.keychord_pressed(chord)
  else
    Text.keychord_pressed(chord)
  end
end

function love.keyreleased(key, scancode)
end
