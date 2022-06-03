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

-- run in both tests and a real run
function App.initialize_globals()
-- a line is either text or a drawing
-- a text is a table with:
--    mode = 'text',
--    string data,
--    a (y) coord in pixels (updated while painting screen),
--    some cached data that's blown away and recomputed when data changes:
--      fragments: snippets of rendered love.graphics.Text, guaranteed to not wrap
--      screen_line_starting_pos: optional array of grapheme indices if it wraps over more than one screen line
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
Screen_top1 = {line=1, pos=1}  -- position of start of screen line at top of screen
Cursor1 = {line=1, pos=1}  -- position of cursor
Screen_bottom1 = {line=1, pos=1}  -- position of start of screen line at bottom of screen

Selection1 = {}

Cursor_x, Cursor_y = 0, 0  -- in pixels

Current_drawing_mode = 'line'
Previous_drawing_mode = nil

Font_height = 14
Line_height = 15
Margin_top = 15

Filename = love.filesystem.getUserDirectory()..'/lines.txt'

-- undo
History = {}
Next_history = 1

-- search
Search_term = nil
Search_text = nil
Search_backup_cursor1 = nil  -- where to position the cursor if search term was not found

end  -- App.initialize_globals

function App.initialize(arg)
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  App.screen.width, App.screen.height = love.window.getMode()
  -- shrink slightly to account for window decoration
  App.screen.width = App.screen.width-100
  App.screen.height = App.screen.height-100
  love.window.setMode(App.screen.width, App.screen.height)
--?   App.screen.width = 120
--?   App.screen.height = 200
--?   love.window.setMode(App.screen.width, App.screen.height)

  -- maximum width available to either text or drawings, in pixels
  Line_width = math.floor(App.screen.width/2/40)*40
--?   Line_width = 100

  -- still in App.initialize
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

end  -- App.initialize

function App.filedropped(file)
  App.initialize_globals()  -- in particular, forget all undo history
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
  assert(Text.le1(Screen_top1, Cursor1))
  local y = Margin_top
--?   print('== draw')
  for line_index,line in ipairs(Lines) do
--?     print('draw:', y, line_index, line)
    if y + Line_height > App.screen.height then break end
--?     print('a')
    if line_index >= Screen_top1.line then
      Screen_bottom1.line = line_index
      if line.mode == 'text' and line.data == '' then
        line.y = y
        button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
          icon = icon.insert_drawing,
          onpress1 = function()
                       Drawing.before = snapshot()
                       table.insert(Lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                       if Cursor1.line >= line_index then
                         Cursor1.line = Cursor1.line+1
                       end
                     end})
          if Search_term == nil then
            if line_index == Cursor1.line then
              Text.draw_cursor(25, y)
            end
          end
        y = y + Line_height
      elseif line.mode == 'drawing' then
        y = y+10 -- padding
        line.y = y
        Drawing.draw(line)
        y = y + Drawing.pixels(line.h) + 10 -- padding
      else
--?         print('text')
        line.y = y
        y, Screen_bottom1.pos = Text.draw(line, Line_width, line_index)
        y = y + Line_height
--?         print('=> y', y)
      end
    end
  end
--?   print('screen bottom: '..tostring(Screen_bottom1.pos)..' in '..tostring(Lines[Screen_bottom1.line].data))
  if Search_term then
    Text.draw_search_bar()
  end
end

function App.update(dt)
  Drawing.update(dt)
end

function App.mousepressed(x,y, mouse_button)
  if Search_term then return end
  propagate_to_button_handlers(x,y, mouse_button)

  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y) then
        if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
          if Selection1.line == nil then
            Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
          end
        else
          if Selection1.line then
            Selection1 = {}
          end
        end
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
  if Search_term then return end
  Drawing.mouse_released(x,y, button)
end

function App.textinput(t)
  if Search_term then
    Search_term = Search_term..t
    Search_text = nil
    Text.search_next()
  elseif Current_drawing_mode == 'name' then
    local drawing = Lines.current
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
  else
    Text.textinput(t)
  end
  save_to_disk(Lines, Filename)
end

function App.keychord_pressed(chord)
  if Search_term then
    if chord == 'escape' then
      Search_term = nil
      Search_text = nil
      Cursor1 = Search_backup_cursor1
      Search_backup_cursor1 = nil
    elseif chord == 'return' then
      Search_term = nil
      Search_text = nil
    elseif chord == 'backspace' then
      local len = utf8.len(Search_term)
      local byte_offset = utf8.offset(Search_term, len)
      Search_term = string.sub(Search_term, 1, byte_offset-1)
      Search_text = nil
    elseif chord == 'down' then
      Cursor1.pos = Cursor1.pos+1
      Text.search_next()
    end
    return
  elseif chord == 'C-f' then
    Search_term = ''
    Search_backup_cursor1 = {line=Cursor1.line, pos=Cursor1.pos}
    assert(Search_text == nil)
  elseif chord == 'C-=' then
    Font_height = Font_height+2
    love.graphics.setFont(love.graphics.newFont(Font_height))
    Line_height = math.floor(Font_height*1.1)
    Text.redraw_all()
  elseif chord == 'C--' then
    Font_height = Font_height-2
    love.graphics.setFont(love.graphics.newFont(Font_height))
    Text.redraw_all()
    Line_height = math.floor(Font_height*1.1)
  elseif chord == 'C-0' then
    Font_height = 14
    love.graphics.setFont(love.graphics.newFont(Font_height))
    Text.redraw_all()
    Line_height = 15
  elseif love.mouse.isDown('1') or chord:sub(1,2) == 'C-' then
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
  else
    Text.keychord_pressed(chord)
  end
end

function App.keyreleased(key, scancode)
end
