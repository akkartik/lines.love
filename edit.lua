-- some constants people might like to tweak
Text_color = {r=0, g=0, b=0}
Cursor_color = {r=1, g=0, b=0}
Stroke_color = {r=0, g=0, b=0}
Current_stroke_color = {r=0.7, g=0.7, b=0.7}  -- in process of being drawn
Current_name_background_color = {r=1, g=0, b=0, a=0.1}  -- name currently being edited
Focus_stroke_color = {r=1, g=0, b=0}  -- what mouse is hovering over
Highlight_color = {r=0.7, g=0.7, b=0.9}  -- selected text
Icon_color = {r=0.7, g=0.7, b=0.7}  -- color of current mode icon in drawings
Help_color = {r=0, g=0.5, b=0}
Help_background_color = {r=0, g=0.5, b=0, a=0.1}

utf8 = require 'utf8'

require 'file'
require 'text'
require 'drawing'
require 'geom'
require 'help'
require 'icons'

edit = {}

-- run in both tests and a real run
function edit.initialize_state()
  local result = {
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
    lines = {{mode='text', data=''}},

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
    screen_top1 = {line=1, pos=1},  -- position of start of screen line at top of screen
    cursor1 = {line=1, pos=1},  -- position of cursor
    screen_bottom1 = {line=1, pos=1},  -- position of start of screen line at bottom of screen

    selection1 = {},
    -- some extra state to compute selection between mouse press and release
    old_cursor1 = nil,
    old_selection1 = nil,
    mousepress_shift = nil,
    -- when selecting text, avoid recomputing some state on every single frame
    recent_mouse = {},

    -- cursor coordinates in pixels
    cursor_x = 0,
    cursor_y = 0,

    current_drawing_mode = 'line',
    previous_drawing_mode = nil,  -- extra state for some ephemeral modes like moving/deleting/naming points

    -- these default values are important for tests
    font_height = 14,
    line_height = 15,
    -- widest possible character width
    em = App.newText(love.graphics.getFont(), 'm'),

    margin_top = 15,
    margin_left = 25,
    margin_right = 0,
    margin_width = nil,

    drawing_padding_top = 10,
    drawing_padding_bottom = 10,
    drawing_padding_height = nil,

    filename = love.filesystem.getUserDirectory()..'/lines.txt',
    next_save = nil,

    -- undo
    history = {},
    next_history = 1,

    -- search
    search_term = nil,
    search_text = nil,
    search_backup = nil,  -- stuff to restore when cancelling search
  }
  result.margin_width = result.margin_left + result.margin_right
  result.drawing_padding_height = result.drawing_padding_top + result.drawing_padding_bottom
  return result
end  -- App.initialize_state

function edit.draw(State)
  App.color(Text_color)
--?   print(State.screen_top1.line, State.screen_top1.pos, State.cursor1.line, State.cursor1.pos)
  assert(Text.le1(State.screen_top1, State.cursor1))
  State.cursor_y = -1
  local y = State.margin_top
--?   print('== draw')
  for line_index = State.screen_top1.line,#State.lines do
    local line = State.lines[line_index]
--?     print('draw:', y, line_index, line)
    if y + State.line_height > App.screen.height then break end
    State.screen_bottom1.line = line_index
    if line.mode == 'text' and line.data == '' then
      line.starty = y
      line.startpos = 1
      -- insert new drawing
      button('draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
        icon = icon.insert_drawing,
        onpress1 = function()
                     Drawing.before = snapshot(line_index-1, line_index)
                     table.insert(State.lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                     if State.cursor1.line >= line_index then
                       State.cursor1.line = State.cursor1.line+1
                     end
                     schedule_save()
                     record_undo_event({before=Drawing.before, after=snapshot(line_index-1, line_index+1)})
                   end
      })
      if State.search_term == nil then
        if line_index == State.cursor1.line then
          Text.draw_cursor(State, State.margin_left, y)
        end
      end
      State.screen_bottom1.pos = State.screen_top1.pos
      y = y + State.line_height
    elseif line.mode == 'drawing' then
      y = y+State.drawing_padding_top
      line.y = y
      Drawing.draw(line)
      y = y + Drawing.pixels(line.h) + State.drawing_padding_bottom
    else
      line.starty = y
      line.startpos = 1
      if line_index == State.screen_top1.line then
        line.startpos = State.screen_top1.pos
      end
--?       print('text.draw', y, line_index)
      y, State.screen_bottom1.pos = Text.draw(State, line, line_index, line.starty, State.margin_left, App.screen.width-State.margin_right)
      y = y + State.line_height
--?       print('=> y', y)
    end
  end
  if State.cursor_y == -1 then
    State.cursor_y = App.screen.height
  end
--?   print('screen bottom: '..tostring(State.screen_bottom1.pos)..' in '..tostring(State.lines[State.screen_bottom1.line].data))
  if State.search_term then
    Text.draw_search_bar(State)
  end
end

function edit.update(State, dt)
  Drawing.update(dt)
  if State.next_save and State.next_save < App.getTime() then
    save_to_disk(State.lines, State.filename)
    State.next_save = nil
  end
end

function schedule_save()
  if Editor_state.next_save == nil then
    Editor_state.next_save = App.getTime() + 3  -- short enough that you're likely to still remember what you did
  end
end

function edit.quit(State)
  -- make sure to save before quitting
  if State.next_save then
    save_to_disk(State.lines, State.filename)
  end
end

function edit.mouse_pressed(State, x,y, mouse_button)
  if State.search_term then return end
--?   print('press', State.selection1.line, State.selection1.pos)
  propagate_to_button_handlers(x,y, mouse_button)

  for line_index,line in ipairs(State.lines) do
    if line.mode == 'text' then
      if Text.in_line(line, x,y, State.margin_left, App.screen.width-State.margin_right) then
        -- delicate dance between cursor, selection and old cursor/selection
        -- scenarios:
        --  regular press+release: sets cursor, clears selection
        --  shift press+release:
        --    sets selection to old cursor if not set otherwise leaves it untouched
        --    sets cursor
        --  press and hold to start a selection: sets selection on press, cursor on release
        --  press and hold, then press shift: ignore shift
        --    i.e. mousereleased should never look at shift state
        State.old_cursor1 = State.cursor1
        State.old_selection1 = State.selection1
        State.mousepress_shift = App.shift_down()
        State.selection1 = {
            line=line_index,
            pos=Text.to_pos_on_line(line, x, y, State.margin_left, App.screen.width-State.margin_right),
        }
--?         print('selection', State.selection1.line, State.selection1.pos)
        break
      end
    elseif line.mode == 'drawing' then
      if Drawing.in_drawing(line, x, y) then
        State.lines.current_drawing_index = line_index
        State.lines.current_drawing = line
        Drawing.before = snapshot(line_index)
        Drawing.mouse_pressed(line, x,y, mouse_button)
        break
      end
    end
  end
end

function edit.mouse_released(State, x,y, mouse_button)
  if State.search_term then return end
--?   print('release')
  if State.lines.current_drawing then
    Drawing.mouse_released(x,y, mouse_button)
    schedule_save()
    if Drawing.before then
      record_undo_event({before=Drawing.before, after=snapshot(State.lines.current_drawing_index)})
      Drawing.before = nil
    end
  else
    for line_index,line in ipairs(State.lines) do
      if line.mode == 'text' then
        if Text.in_line(line, x,y, State.margin_left, App.screen.width-State.margin_right) then
--?           print('reset selection')
          State.cursor1 = {
              line=line_index,
              pos=Text.to_pos_on_line(line, x, y, State.margin_left, App.screen.width-State.margin_right),
          }
--?           print('cursor', State.cursor1.line, State.cursor1.pos)
          if State.mousepress_shift then
            if State.old_selection1.line == nil then
              State.selection1 = State.old_cursor1
            else
              State.selection1 = State.old_selection1
            end
          end
          State.old_cursor1, State.old_selection1, State.mousepress_shift = nil
          if eq(State.cursor1, State.selection1) then
            State.selection1 = {}
          end
          break
        end
      end
    end
--?     print('selection:', State.selection1.line, State.selection1.pos)
  end
end

function edit.textinput(State, t)
  for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
  if State.search_term then
    State.search_term = State.search_term..t
    State.search_text = nil
    Text.search_next()
  elseif State.current_drawing_mode == 'name' then
    local before = snapshot(State.lines.current_drawing_index)
    local drawing = State.lines.current_drawing
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
    record_undo_event({before=before, after=snapshot(State.lines.current_drawing_index)})
  else
    Text.textinput(t)
  end
  schedule_save()
end

function edit.keychord_pressed(State, chord, key)
  if State.selection1.line and
      not State.lines.current_drawing and
      -- printable character created using shift key => delete selection
      -- (we're not creating any ctrl-shift- or alt-shift- combinations using regular/printable keys)
      (not App.shift_down() or utf8.len(key) == 1) and
      chord ~= 'C-c' and chord ~= 'C-x' and chord ~= 'backspace' and backspace ~= 'delete' and not App.is_cursor_movement(chord) then
    Text.delete_selection(State.margin_left, App.screen.width-State.margin_right)
  end
  if State.search_term then
    if chord == 'escape' then
      State.search_term = nil
      State.search_text = nil
      State.cursor1 = State.search_backup.cursor
      State.screen_top1 = State.search_backup.screen_top
      State.search_backup = nil
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
    elseif chord == 'return' then
      State.search_term = nil
      State.search_text = nil
      State.search_backup = nil
    elseif chord == 'backspace' then
      local len = utf8.len(State.search_term)
      local byte_offset = Text.offset(State.search_term, len)
      State.search_term = string.sub(State.search_term, 1, byte_offset-1)
      State.search_text = nil
    elseif chord == 'down' then
      State.cursor1.pos = State.cursor1.pos+1
      Text.search_next()
    elseif chord == 'up' then
      Text.search_previous()
    end
    return
  elseif chord == 'C-f' then
    State.search_term = ''
    State.search_backup = {cursor={line=State.cursor1.line, pos=State.cursor1.pos}, screen_top={line=State.screen_top1.line, pos=State.screen_top1.pos}}
    assert(State.search_text == nil)
  elseif chord == 'C-=' then
    initialize_font_settings(State.font_height+2)
    Text.redraw_all()
  elseif chord == 'C--' then
    initialize_font_settings(State.font_height-2)
    Text.redraw_all()
  elseif chord == 'C-0' then
    initialize_font_settings(20)
    Text.redraw_all()
  elseif chord == 'C-z' then
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    local event = undo_event()
    if event then
      local src = event.before
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.after, event.before)
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
      schedule_save()
    end
  elseif chord == 'C-y' then
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    local event = redo_event()
    if event then
      local src = event.after
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.before, event.after)
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
      schedule_save()
    end
  -- clipboard
  elseif chord == 'C-c' then
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    local s = Text.selection()
    if s then
      App.setClipboardText(s)
    end
  elseif chord == 'C-x' then
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    local s = Text.cut_selection(State.margin_left, App.screen.width-State.margin_right)
    if s then
      App.setClipboardText(s)
    end
    schedule_save()
  elseif chord == 'C-v' then
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    -- We don't have a good sense of when to scroll, so we'll be conservative
    -- and sometimes scroll when we didn't quite need to.
    local before_line = State.cursor1.line
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
      Text.snap_cursor_to_bottom_of_screen(State.margin_left, App.screen.height-State.margin_right)
    end
    schedule_save()
    record_undo_event({before=before, after=snapshot(before_line, State.cursor1.line)})
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
    for _,line in ipairs(State.lines) do
      if line.mode == 'drawing' then
        line.show_help = false
      end
    end
  elseif State.current_drawing_mode == 'name' then
    if chord == 'return' then
      State.current_drawing_mode = State.previous_drawing_mode
      State.previous_drawing_mode = nil
    else
      local before = snapshot(State.lines.current_drawing_index)
      local drawing = State.lines.current_drawing
      local p = drawing.points[drawing.pending.target_point]
      if chord == 'escape' then
        p.name = nil
        record_undo_event({before=before, after=snapshot(State.lines.current_drawing_index)})
      elseif chord == 'backspace' then
        local len = utf8.len(p.name)
        local byte_offset = Text.offset(p.name, len-1)
        if len == 1 then byte_offset = 0 end
        p.name = string.sub(p.name, 1, byte_offset)
        record_undo_event({before=before, after=snapshot(State.lines.current_drawing_index)})
      end
    end
    schedule_save()
  else
    for _,line in ipairs(State.lines) do line.y = nil end  -- just in case we scroll
    Text.keychord_pressed(chord)
  end
end

function edit.key_released(State, key, scancode)
end

--== copy some App methods for tests

-- all textinput events are also keypresses
-- TODO: handle chords of multiple keys
function edit.run_after_textinput(State, t)
  edit.keychord_pressed(State, t)
  edit.textinput(State, t)
  edit.key_released(State, t)
  App.screen.contents = {}
  edit.draw(State)
end

-- not all keys are textinput
function edit.run_after_keychord(State, chord)
  edit.keychord_pressed(State, chord)
  edit.key_released(State, chord)
  App.screen.contents = {}
  edit.draw(State)
end

function edit.run_after_mouse_click(State, x,y, button)
  App.fake_mouse_press(x,y, button)
  edit.mouse_pressed(State, x,y, button)
  App.fake_mouse_release(x,y, button)
  edit.mouse_released(State, x,y, button)
  App.screen.contents = {}
  edit.draw(State)
end

function edit.run_after_mouse_press(State, x,y, button)
  App.fake_mouse_press(x,y, button)
  edit.mouse_pressed(State, x,y, button)
  App.screen.contents = {}
  edit.draw(State)
end

function edit.run_after_mouse_release(State, x,y, button)
  App.fake_mouse_release(x,y, button)
  edit.mouse_released(State, x,y, button)
  App.screen.contents = {}
  edit.draw(State)
end
