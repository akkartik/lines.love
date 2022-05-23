local utf8 = require 'utf8'

require 'app'
require 'test'

require 'keychord'
require 'file'
require 'button'
local Text = require 'text'
local Drawing = require 'drawing'
local geom = require 'geom'
require 'help'
require 'icons'

function App.initialize(arg)
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

-- globals

-- a line is either text or a drawing
-- a text is a table with:
--    mode = 'text'
--    string data
--    screen_line_starting_pos: optional array of grapheme indices if it wraps over more than one screen line
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

-- Lines can be too long to fit on screen, in which case they _wrap_ into
-- multiple _screen lines_.
--
-- Therefore, any potential location for the cursor can be described in two ways:
-- * schema 1: As a combination of line index and position within a line (in utf8 codepoint units)
-- * schema 2: As a combination of line index, screen line index within the line, and a position within the screen line.
--
-- Most of the time we'll only persist positions in schema 1, translating to
-- schema 2 when that's convenient.
Cursor1 = {line=1, pos=1}  -- position of cursor
Screen_top1 = {line=1, pos=1}  -- position of start of screen line at top of screen
Screen_bottom1 = {line=1, pos=1}  -- position of start of screen line at bottom of screen

-- maximize window
love.window.setMode(0, 0)  -- maximize
App.screen.width, App.screen.height = love.window.getMode()
-- shrink slightly to account for window decoration
App.screen.width = App.screen.width-100
App.screen.height = App.screen.height-100
love.window.setMode(App.screen.width, App.screen.height)

Cursor_x, Cursor_y = 0, 0  -- in pixels

Current_drawing_mode = 'line'
Previous_drawing_mode = nil

-- maximum width available to either text or drawings, in pixels
Line_width = math.floor(App.screen.width/2/40)*40

Zoom = 1.5

Filename = love.filesystem.getUserDirectory()..'/lines.txt'

Debug_main = false

  if #arg > 0 then
    Filename = arg[1]
  end
  Lines = load_from_disk(Filename)
  for i,line in ipairs(Lines) do
    if line.mode == 'text' then
      Cursor1.line = i
      break
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)

end

function App.filedropped(file)
  Filename = file:getFilename()
  file:open('r')
  Lines = load_from_file(file)
  file:close()
  for i,line in ipairs(Lines) do
    if line.mode == 'text' then
      Cursor1.line = i
      break
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)
end

function App.draw()
  Button_handlers = {}
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle('fill', 0, 0, App.screen.width-1, App.screen.height-1)
  love.graphics.setColor(0, 0, 0)
  for line_index,line in ipairs(Lines) do
    line.y = nil
  end
  local y = 15
  if Debug_main then print('== draw') end
  for line_index,line in ipairs(Lines) do
    print(y, line_index, line)
    if Debug_main then print('draw:', line_index, y) end
    if y + math.floor(15*Zoom) > App.screen.height then break end
    print('a')
    if line_index >= Screen_top1.line then
      Screen_bottom1.line = line_index
      if line.mode == 'text' and line.data == '' then
        line.y = y
        button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
          icon = icon.insert_drawing,
          onpress1 = function()
                       table.insert(Lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                       if Cursor1.line >= line_index then
                         Cursor1.line = Cursor1.line+1
                       end
                     end})
          if line_index == Cursor1.line then
            Text.draw_cursor(25, y)
          end
        y = y + math.floor(15*Zoom)  -- text height
      elseif line.mode == 'drawing' then
        y = y+10 -- padding
        line.y = y
        Drawing.draw(line)
        y = y + Drawing.pixels(line.h) + 10 -- padding
      else
        if Debug_main then print('text') end
        line.y = y
        y, Screen_bottom1.pos = Text.draw(line, Line_width, line_index)
        y = y + math.floor(15*Zoom)  -- text height
        if Debug_main then print('aa', y) end
      end
    end
  end
  Debug_main = false
--?   print('screen bottom: '..tostring(Screen_bottom1.pos)..' in '..tostring(Lines[Screen_bottom1.line].data))
--?   os.exit(1)
end

function App.update(dt)
  Drawing.update(dt)
end

function App.mousepressed(x,y, mouse_button)
  propagate_to_button_handlers(x,y, mouse_button)

  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y) then
        Text.move_cursor(line_index, line, x, y)
      end
    elseif line.mode == 'drawing' then
      if Drawing.in_drawing(line, x, y) then
        Drawing.mouse_pressed(line, x,y, button)
      end
    end
  end
end

function App.mousereleased(x,y, button)
  Drawing.mouse_released(x,y, button)
end

function App.textinput(t)
  if Current_drawing_mode == 'name' then
    local drawing = Lines.current
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
  else
    Text.textinput(t)
  end
  save_to_disk(Lines, Filename)
end

function App.keychord_pressed(chord)
--?   Debug_main = true
  if love.mouse.isDown('1') or chord:sub(1,2) == 'C-' then
    Drawing.keychord_pressed(chord)
  elseif chord == 'escape' and love.mouse.isDown('1') then
    local drawing = Drawing.current_drawing()
    if drawing then
      drawing.pending = {}
    end
  elseif chord == 'escape' and not love.mouse.isDown('1') then
    for _,line in ipairs(Lines) do
      if line.mode == 'drawing' then
        line.show_help = false
      end
    end
  elseif Current_drawing_mode == 'name' then
    if chord == 'return' then
      Current_drawing_mode = Previous_drawing_mode
      Previous_drawing_mode = nil
    else
      local drawing = Lines.current
      local p = drawing.points[drawing.pending.target_point]
      if chord == 'escape' then
        p.name = nil
      elseif chord == 'backspace' then
        local len = utf8.len(p.name)
        local byte_offset = utf8.offset(p.name, len-1)
        p.name = string.sub(p.name, 1, byte_offset)
      end
    end
    save_to_disk(Lines, Filename)
  elseif chord == 'pagedown' then
    Screen_top1.line = Screen_bottom1.line
    Screen_top1.pos = Screen_bottom1.pos
    print('setting top to', Screen_top1.line)
    Cursor1.line = Screen_top1.line
    Cursor1.pos = Screen_top1.pos
    Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
    print('top now', Screen_top1.line)
  elseif chord == 'pageup' then
    -- duplicate some logic from love.draw
    local y = App.screen.height
    while y >= 0 do
      if Screen_top1.line == 1 then break end
      y = y - math.floor(15*Zoom)
      if Lines[Screen_top1.line].mode == 'drawing' then
        y = y - Drawing.pixels(Lines[Screen_top1.line].h)
      end
      Screen_top1.line = Screen_top1.line - 1
    end
    if Cursor1.line ~= Screen_top1.line then
      Cursor1.pos = 1
    end
    Cursor1.line = Screen_top1.line
    Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  else
    Text.keychord_pressed(chord)
  end
end

function App.keyreleased(key, scancode)
end
