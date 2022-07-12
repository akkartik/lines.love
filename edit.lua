utf8 = require 'utf8'

require 'file'
require 'button'
require 'text'
require 'drawing'
require 'geom'
require 'help'
require 'icons'

edit = {}

-- run in both tests and a real run
function edit.initialize_globals()
-- a line is either text or a drawing
-- a text is a table with:
--    mode = 'text',
--    string data,
--    startpos, the index of data the line starts rendering from (if currently on screen), can only be >1 for topmost line on screen
--    starty, the y coord in pixels
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
--
-- Make sure these coordinates are never aliased, so that changing one causes
-- action at a distance.
Screen_top1 = {line=1, pos=1}  -- position of start of screen line at top of screen
Cursor1 = {line=1, pos=1}  -- position of cursor
Screen_bottom1 = {line=1, pos=1}  -- position of start of screen line at bottom of screen

Selection1 = {}
Old_cursor1, Old_selection1, Mousepress_shift = nil  -- some extra state to compute selection between mouse press and release
Recent_mouse = {}  -- when selecting text, avoid recomputing some state on every single frame

Cursor_x, Cursor_y = 0, 0  -- in pixels

Current_drawing_mode = 'line'
Previous_drawing_mode = nil

-- values for tests
Font_height = 14
Line_height = 15
-- widest possible character width
Em = App.newText(love.graphics.getFont(), 'm')

Margin_top = 15
Margin_left = 25
Margin_right = 25
Margin_width = Margin_left + Margin_right

Drawing_padding_top = 10
Drawing_padding_bottom = 10
Drawing_padding_height = Drawing_padding_top + Drawing_padding_bottom

Filename = love.filesystem.getUserDirectory()..'/lines.txt'
Next_save = nil

-- undo
History = {}
Next_history = 1

-- search
Search_term = nil
Search_text = nil
Search_backup = nil  -- stuff to restore when cancelling search

-- resize
Last_resize_time = nil

-- blinking cursor
Cursor_time = 0

end  -- App.initialize_globals

function edit.draw()
  Button_handlers = {}

  love.graphics.setColor(0, 0, 0)
--?   print(Screen_top1.line, Screen_top1.pos, Cursor1.line, Cursor1.pos)
  assert(Text.le1(Screen_top1, Cursor1))
  Cursor_y = -1
  local y = Margin_top
--?   print('== draw')
  for line_index = Screen_top1.line,#Lines do
    local line = Lines[line_index]
--?     print('draw:', y, line_index, line)
    if y + Line_height > App.screen.height then break end
    Screen_bottom1.line = line_index
    if line.mode == 'text' and line.data == '' then
      line.starty = y
      line.startpos = 1
      -- insert new drawing
      button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
        icon = icon.insert_drawing,
        onpress1 = function()
                     Drawing.before = snapshot(line_index-1, line_index)
                     table.insert(Lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                     if Cursor1.line >= line_index then
                       Cursor1.line = Cursor1.line+1
                     end
                     schedule_save()
                     record_undo_event({before=Drawing.before, after=snapshot(line_index-1, line_index+1)})
                   end
      })
      if Search_term == nil then
        if line_index == Cursor1.line then
          Text.draw_cursor(Margin_left, y)
        end
      end
      Screen_bottom1.pos = Screen_top1.pos
      y = y + Line_height
    elseif line.mode == 'drawing' then
      y = y+Drawing_padding_top
      line.y = y
      Drawing.draw(line)
      y = y + Drawing.pixels(line.h) + Drawing_padding_bottom
    else
      line.starty = y
      line.startpos = 1
      if line_index == Screen_top1.line then
        line.startpos = Screen_top1.pos
      end
--?       print('text.draw', y, line_index)
      y, Screen_bottom1.pos = Text.draw(line, line_index, line.starty, Margin_left, App.screen.width-Margin_right)
      y = y + Line_height
--?       print('=> y', y)
    end
  end
  if Cursor_y == -1 then
    Cursor_y = App.screen.height
  end
--?   print('screen bottom: '..tostring(Screen_bottom1.pos)..' in '..tostring(Lines[Screen_bottom1.line].data))
  if Search_term then
    Text.draw_search_bar()
  end
end

function edit.update(dt)
  Cursor_time = Cursor_time + dt
  -- some hysteresis while resizing
  if Last_resize_time then
    if App.getTime() - Last_resize_time < 0.1 then
      return
    else
      Last_resize_time = nil
    end
  end
  Drawing.update(dt)
  if Next_save and Next_save < App.getTime() then
    save_to_disk(Lines, Filename)
    Next_save = nil
  end
end

function schedule_save()
  if Next_save == nil then
    Next_save = App.getTime() + 3  -- short enough that you're likely to still remember what you did
  end
end

function edit.quit()
  -- make sure to save before quitting
  if Next_save then
    save_to_disk(Lines, Filename)
  end
end

function edit.mouse_pressed(x,y, mouse_button)
  if Search_term then return end
  -- ensure cursor is visible immediately after it moves
  Cursor_time = 0
--?   print('press', Selection1.line, Selection1.pos)
  propagate_to_button_handlers(x,y, mouse_button)

  for line_index,line in ipairs(Lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y, Margin_left, App.screen.width-Margin_right) then
        -- delicate dance between cursor, selection and old cursor/selection
        -- scenarios:
        --  regular press+release: sets cursor, clears selection
        --  shift press+release:
        --    sets selection to old cursor if not set otherwise leaves it untouched
        --    sets cursor
        --  press and hold to start a selection: sets selection on press, cursor on release
        --  press and hold, then press shift: ignore shift
        --    i.e. mousereleased should never look at shift state
        Old_cursor1 = Cursor1
        Old_selection1 = Selection1
        Mousepress_shift = App.shift_down()
        Selection1 = {
            line=line_index,
            pos=Text.to_pos_on_line(line, x, y, Margin_left, App.screen.width-Margin_right),
        }
--?         print('selection', Selection1.line, Selection1.pos)
        break
      end
    elseif line.mode == 'drawing' then
      if Drawing.in_drawing(line, x, y) then
        Lines.current_drawing_index = line_index
        Lines.current_drawing = line
        Drawing.before = snapshot(line_index)
        Drawing.mouse_pressed(line, x,y, mouse_button)
        break
      end
    end
  end
end

function edit.mouse_released(x,y, mouse_button)
  if Search_term then return end
--?   print('release')
  -- ensure cursor is visible immediately after it moves
  Cursor_time = 0
  if Lines.current_drawing then
    Drawing.mouse_released(x,y, mouse_button)
    schedule_save()
    if Drawing.before then
      record_undo_event({before=Drawing.before, after=snapshot(Lines.current_drawing_index)})
      Drawing.before = nil
    end
  else
    for line_index,line in ipairs(Lines) do
      if line.mode == 'text' then
        if Text.in_line(line, x,y, Margin_left, App.screen.width-Margin_right) then
--?           print('reset selection')
          Cursor1 = {
              line=line_index,
              pos=Text.to_pos_on_line(line, x, y, Margin_left, App.screen.width-Margin_right),
          }
--?           print('cursor', Cursor1.line, Cursor1.pos)
          if Mousepress_shift then
            if Old_selection1.line == nil then
              Selection1 = Old_cursor1
            else
              Selection1 = Old_selection1
            end
          end
          Old_cursor1, Old_selection1, Mousepress_shift = nil
          if eq(Cursor1, Selection1) then
            Selection1 = {}
          end
          break
        end
      end
    end
--?     print('selection:', Selection1.line, Selection1.pos)
  end
end

function edit.textinput(t)
  -- ensure cursor is visible immediately after it moves
  Cursor_time = 0
  for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
  if Search_term then
    Search_term = Search_term..t
    Search_text = nil
    Text.search_next()
  elseif Current_drawing_mode == 'name' then
    local before = snapshot(Lines.current_drawing_index)
    local drawing = Lines.current_drawing
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
    record_undo_event({before=before, after=snapshot(Lines.current_drawing_index)})
  else
    Text.textinput(t)
  end
  schedule_save()
end

function edit.keychord_pressed(chord, key)
  -- ensure cursor is visible immediately after it moves
  Cursor_time = 0
  if Selection1.line and
      not Lines.current_drawing and
      -- printable character created using shift key => delete selection
      -- (we're not creating any ctrl-shift- or alt-shift- combinations using regular/printable keys)
      (not App.shift_down() or utf8.len(key) == 1) and
      chord ~= 'C-c' and chord ~= 'C-x' and chord ~= 'backspace' and backspace ~= 'delete' and not App.is_cursor_movement(chord) then
    Text.delete_selection(Margin_left, App.screen.width-Margin_right)
  end
  if Search_term then
    if chord == 'escape' then
      Search_term = nil
      Search_text = nil
      Cursor1 = Search_backup.cursor
      Screen_top1 = Search_backup.screen_top
      Search_backup = nil
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
    elseif chord == 'return' then
      Search_term = nil
      Search_text = nil
      Search_backup = nil
    elseif chord == 'backspace' then
      local len = utf8.len(Search_term)
      local byte_offset = Text.offset(Search_term, len)
      Search_term = string.sub(Search_term, 1, byte_offset-1)
      Search_text = nil
    elseif chord == 'down' then
      Cursor1.pos = Cursor1.pos+1
      Text.search_next()
    elseif chord == 'up' then
      Text.search_previous()
    end
    return
  elseif chord == 'C-f' then
    Search_term = ''
    Search_backup = {cursor={line=Cursor1.line, pos=Cursor1.pos}, screen_top={line=Screen_top1.line, pos=Screen_top1.pos}}
    assert(Search_text == nil)
  elseif chord == 'C-=' then
    initialize_font_settings(Font_height+2)
    Text.redraw_all()
  elseif chord == 'C--' then
    initialize_font_settings(Font_height-2)
    Text.redraw_all()
  elseif chord == 'C-0' then
    initialize_font_settings(20)
    Text.redraw_all()
  elseif chord == 'C-z' then
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    local event = undo_event()
    if event then
      local src = event.before
      Screen_top1 = deepcopy(src.screen_top)
      Cursor1 = deepcopy(src.cursor)
      Selection1 = deepcopy(src.selection)
      patch(Lines, event.after, event.before)
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
      schedule_save()
    end
  elseif chord == 'C-y' then
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    local event = redo_event()
    if event then
      local src = event.after
      Screen_top1 = deepcopy(src.screen_top)
      Cursor1 = deepcopy(src.cursor)
      Selection1 = deepcopy(src.selection)
      patch(Lines, event.before, event.after)
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
      schedule_save()
    end
  -- clipboard
  elseif chord == 'C-c' then
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    local s = Text.selection()
    if s then
      App.setClipboardText(s)
    end
  elseif chord == 'C-x' then
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    local s = Text.cut_selection(Margin_left, App.screen.width-Margin_right)
    if s then
      App.setClipboardText(s)
    end
    schedule_save()
  elseif chord == 'C-v' then
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    -- We don't have a good sense of when to scroll, so we'll be conservative
    -- and sometimes scroll when we didn't quite need to.
    local before_line = Cursor1.line
    local before = snapshot(before_line)
    local clipboard_data = App.getClipboardText()
    for _,code in utf8.codes(clipboard_data) do
      local c = utf8.char(code)
      if c == '\n' then
        Text.insert_return()
      else
        Text.insert_at_cursor(c)
      end
    end
    if Text.cursor_past_screen_bottom() then
      Text.snap_cursor_to_bottom_of_screen(Margin_left, App.screen.height-Margin_right)
    end
    schedule_save()
    record_undo_event({before=before, after=snapshot(before_line, Cursor1.line)})
  -- dispatch to drawing or text
  elseif App.mouse_down(1) or chord:sub(1,2) == 'C-' then
    -- DON'T reset line.y here
    local drawing_index, drawing = Drawing.current_drawing()
    if drawing_index then
      local before = snapshot(drawing_index)
      Drawing.keychord_pressed(chord)
      record_undo_event({before=before, after=snapshot(drawing_index)})
      schedule_save()
    end
  elseif chord == 'escape' and not App.mouse_down(1) then
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
      local before = snapshot(Lines.current_drawing_index)
      local drawing = Lines.current_drawing
      local p = drawing.points[drawing.pending.target_point]
      if chord == 'escape' then
        p.name = nil
        record_undo_event({before=before, after=snapshot(Lines.current_drawing_index)})
      elseif chord == 'backspace' then
        local len = utf8.len(p.name)
        local byte_offset = Text.offset(p.name, len-1)
        if len == 1 then byte_offset = 0 end
        p.name = string.sub(p.name, 1, byte_offset)
        record_undo_event({before=before, after=snapshot(Lines.current_drawing_index)})
      end
    end
    schedule_save()
  else
    for _,line in ipairs(Lines) do line.y = nil end  -- just in case we scroll
    Text.keychord_pressed(chord)
  end
end

function edit.key_released(key, scancode)
end
