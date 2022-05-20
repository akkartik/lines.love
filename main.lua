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
Screen_top_line = 1
Screen_bottom_line = 1
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
      break
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
      break
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)
end

function love.draw()
  Button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 0, 0, Screen_width-1, Screen_height-1)
  love.graphics.setColor(0, 0, 0)
  for line_index,line in ipairs(Lines) do
    line.y = nil
  end
  local y = 15
  for line_index,line in ipairs(Lines) do
    if y > Screen_height then break end
    if line_index >= Screen_top_line then
      Screen_bottom_line = line_index
      if line.mode == 'text' and line.data == '' then
        line.y = y
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
        y = y + math.floor(15*Zoom)  -- text height
      elseif line.mode == 'drawing' then
        y = y+10 -- padding
        line.y = y
        Drawing.draw(line)
        y = y + Drawing.pixels(line.h) + 10 -- padding
      else
        line.y = y
        y = Text.draw(line, 100, line_index, Cursor_line, Cursor_pos)
--?         y = Text.draw(line, Drawing_width, line_index, Cursor_line, Cursor_pos)
        y = y + math.floor(15*Zoom)  -- text height
      end
    end
  end
--?   os.exit(1)
end

function love.update(dt)
  Drawing.update(dt)
end

function love.mousepressed(x,y, mouse_button)
  propagate_to_button_handlers(x,y, mouse_button)

  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y) then
        Text.move_cursor(line_index, line, x)
      end
    elseif line.mode == 'drawing' then
      if Drawing.in_drawing(line, x, y) then
        Drawing.mouse_pressed(line, x,y, button)
      end
    end
  end
end

function love.mousereleased(x,y, button)
  Drawing.mouse_released(x,y, button)
end

function keychord_pressed(chord)
  if love.mouse.isDown('1') or chord:sub(1,2) == 'C-' then
    Drawing.keychord_pressed(chord)
  elseif chord == 'escape' and love.mouse.isDown('1') then
    local drawing = Drawing.current_drawing()
    if drawing then
      drawing.pending = {}
    end
  elseif chord == 'pagedown' then
    Screen_top_line = Screen_bottom_line
    Cursor_line = Screen_top_line
    Cursor_pos = 1
    Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  elseif chord == 'pageup' then
    -- duplicate some logic from love.draw
    local y = Screen_height
    while y >= 0 do
      if Screen_top_line == 1 then break end
      y = y - math.floor(15*Zoom)
      if Lines[Screen_top_line].mode == 'drawing' then
        y = y - Drawing.pixels(Lines[Screen_top_line].h)
      end
      Screen_top_line = Screen_top_line - 1
    end
    if Cursor_line ~= Screen_top_line then
      Cursor_pos = 1
    end
    Cursor_line = Screen_top_line
    Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  else
    Text.keychord_pressed(chord)
  end
end

function love.keyreleased(key, scancode)
end
