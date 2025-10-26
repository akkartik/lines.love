-- some constants people might like to tweak
Text_color = {r=0, g=0, b=0}
Cursor_color = {r=1, g=0, b=0}
Hyperlink_decoration_color = {r=0.4, g=0.4, b=1}
Stroke_color = {r=0, g=0, b=0}
Current_stroke_color = {r=0.7, g=0.7, b=0.7}  -- in process of being drawn
Current_name_background_color = {r=1, g=0, b=0, a=0.1}  -- name currently being edited
Focus_stroke_color = {r=1, g=0, b=0}  -- what mouse is hovering over
Highlight_color = {r=0.7, g=0.7, b=0.9}  -- selected text
Line_number_color = {r=0.6, g=0.6, b=0.6}
Icon_color = {r=0.7, g=0.7, b=0.7}  -- color of current mode icon in drawings
Help_color = {r=0, g=0.5, b=0}
Help_background_color = {r=0, g=0.5, b=0, a=0.1}

Margin_top = 15
Margin_left = 25
Margin_right = 25

Drawing_padding_top = 10
Drawing_padding_bottom = 10
Drawing_padding_height = Drawing_padding_top + Drawing_padding_bottom

Same_point_distance = 4  -- pixel distance at which two points are considered the same

Hand_icon = love.mouse.getSystemCursor('hand')
Arrow_icon = love.mouse.getSystemCursor('arrow')

edit = {}

-- run in both tests and a real run
function edit.initialize_state(top, left, right, font, font_height, line_height)  -- currently always draws to bottom of screen
  local result = {
    -- a line is either text or a drawing
    -- a text is a table with:
    --    mode = 'text',
    --    string data,
    -- a drawing is a table with:
    --    mode = 'drawing'
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
    lines = {{mode='text', data=''}},  -- array of lines

    -- Lines can be too long to fit on screen, in which case they _wrap_ into
    -- multiple _screen lines_.

    -- rendering wrapped text lines needs some additional short-lived data per line:
    --   startpos, the index of data the line starts rendering from, can only be >1 for topmost line on screen
    --   screen_line_starting_pos: optional array of codepoint indices if it wraps over more than one screen line
    line_cache = {},

    -- Given wrapping, any potential location for the text cursor can be described in two ways:
    -- * schema 1: As a combination of line index and position within a line (in utf8 codepoint units)
    -- * schema 2: As a combination of line index, screen line index within the line, and a position within the screen line.
    --
    -- Most of the time we'll only persist positions in schema 1, translating to
    -- schema 2 when that's convenient.
    --
    -- Make sure these coordinates are never aliased, so that changing one causes
    -- action at a distance.
    --
    -- On lines that are drawings, pos will be nil.
    screen_top1 = {line=1, pos=1},  -- position of start of screen line at top of screen
    cursor1 = {line=1, pos=1},  -- position of cursor; must be on a text line

    selection1 = {},
    -- some extra state to compute selection between mouse press and release
    old_cursor1 = nil,
    old_selection1 = nil,
    mousepress_shift = nil,

    -- cursor coordinates in pixels
    cursor_x = 0,
    cursor_y = 0,

    current_drawing_mode = 'line',
    previous_drawing_mode = nil,  -- extra state for some ephemeral modes like moving/deleting/naming points

    font = font,
    font_height = font_height,
    line_height = line_height,

    top = top,
    left = math.floor(left),  -- left margin for text; line numbers go to the left of this
    right = math.floor(right),
    width = right-left,

    filename = 'run.lua',
    next_save = nil,

    -- undo
    history = {},
    next_history = 1,

    -- search
    search_term = nil,
    search_backup = nil,  -- stuff to restore when cancelling search

    button_handlers = {},
  }
  return result
end  -- edit.initialize_state

function edit.check_locs(State)
  -- if State is inconsistent (i.e. file changed by some other program),
  --   throw away all cursor state entirely
  if edit.invalid1(State, State.screen_top1)
      or edit.invalid_cursor1(State)
      or not edit.cursor_on_text(State)
      or not Text.le1(State.screen_top1, State.cursor1) then
    State.screen_top1 = {line=1, pos=1}
    State.cursor1 = {line=1, pos=1}
    edit.put_cursor_on_next_text_line(State)
  end
end

function edit.invalid1(State, loc1)
  if loc1.line > #State.lines then return true end
  local l = State.lines[loc1.line]
  if l.mode ~= 'text' then return false end  -- pos is irrelevant to validity for a drawing line
  return loc1.pos > #State.lines[loc1.line].data
end

-- cursor loc in particular differs from other locs in one way:
-- pos might occur just after end of line
function edit.invalid_cursor1(State)
  local cursor1 = State.cursor1
  if cursor1.line > #State.lines then return true end
  local l = State.lines[cursor1.line]
  if l.mode ~= 'text' then return false end  -- pos is irrelevant to validity for a drawing line
  return cursor1.pos > #State.lines[cursor1.line].data + 1
end

function edit.cursor_on_text(State)
  return State.cursor1.line <= #State.lines
      and State.lines[State.cursor1.line].mode == 'text'
end

function edit.put_cursor_on_next_text_line(State)
  local line = State.cursor1.line
  if State.lines[line].mode == 'text' then return end
  while line <= #State.lines and State.lines[line].mode ~= 'text' do
    line = line+1
  end
  if line <= #State.lines and State.lines[line].mode == 'text' then
    State.cursor1.line = line
    State.cursor1.pos = 1
  end
end

function edit.draw(State, hide_cursor, show_line_numbers)
  State.button_handlers = {}
  love.graphics.setFont(State.font)
  App.color(Text_color)
  assert(#State.lines == #State.line_cache, ('line_cache is out of date; %d elements when it should be %d'):format(#State.line_cache, #State.lines))
  assert(Text.le1(State.screen_top1, State.cursor1), ('screen_top (line=%d,pos=%d) is below cursor (line=%d,pos=%d)'):format(State.screen_top1.line, State.screen_top1.pos, State.cursor1.line, State.cursor1.pos))
  State.cursor_x = nil
  State.cursor_y = nil
  local y = State.top
--?   print('== draw')
  for line_index = State.screen_top1.line,#State.lines do
    local line = State.lines[line_index]
--?     print('draw:', y, line_index, line)
    if y + State.line_height > App.screen.height then break end
    if line.mode == 'text' then
--?       print('text.draw', y, line_index)
      local startpos = 1
      if line_index == State.screen_top1.line then
        startpos = State.screen_top1.pos
      end
      if line.data == '' then
        -- button to insert new drawing
        local buttonx = State.left-Margin_left+4
        if show_line_numbers then
          buttonx = 4  -- HACK: position draw buttons at a fixed x on screen
        end
        button(State, 'draw', {x=buttonx, y=y+4, w=12,h=12, bg={r=1,g=1,b=0},
          icon = icon.insert_drawing,
          onpress1 = function()
                       Drawing.before = snapshot(State, line_index-1, line_index)
                       table.insert(State.lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                       table.insert(State.line_cache, line_index, {})
                       if State.cursor1.line >= line_index then
                         State.cursor1.line = State.cursor1.line+1
                       end
                       record_undo_event(State, {before=Drawing.before, after=snapshot(State, line_index-1, line_index+1)})
                       Drawing.before = nil
                       schedule_save(State)
                     end,
        })
      end
      y = Text.draw(State, line_index, y, startpos, hide_cursor, show_line_numbers)
--?       print('=> y', y)
    elseif line.mode == 'drawing' then
      y = y+Drawing_padding_top
      Drawing.draw(State, line_index, y)
      y = y + Drawing.pixels(line.h, State.width) + Drawing_padding_bottom
    else
      assert(false, ('unknown line mode %s'):format(line.mode))
    end
  end
  if State.search_term then
    Text.draw_search_bar(State)
  end
end

function edit.update(State, dt)
  local x, y = love.mouse.getPosition()
  if mouse_hover_on_any_button(State, x,y) then
    love.mouse.setCursor(Hand_icon)
  else
    love.mouse.setCursor(Arrow_icon)
  end
  Drawing.update(State, dt)
  if State.next_save and State.next_save < Current_time then
    save_to_disk(State)
    State.next_save = nil
  end
end

function schedule_save(State)
  if State.next_save == nil then
    State.next_save = Current_time + 3  -- short enough that you're likely to still remember what you did
  end
end

function edit.quit(State)
  -- make sure to save before quitting
  if State.next_save then
    save_to_disk(State)
    -- give some time for the OS to flush everything to disk
    love.timer.sleep(0.1)
  end
end

function edit.mouse_press(State, x,y, mouse_button, is_touch, presses)
  if State.search_term then return end
  State.mouse_down = mouse_button
--?   print_and_log(('edit.mouse_press: cursor at %d,%d'):format(State.cursor1.line, State.cursor1.pos))
  if mouse_press_consumed_by_any_button(State, x,y, mouse_button) then
    -- press on a button and it returned 'true' to short-circuit
    return
  end

  if y < State.top then
    State.old_cursor1 = State.cursor1
    State.old_selection1 = State.selection1
    State.mousepress_shift = App.shift_down()
    State.selection1 = {
        line=State.screen_top1.line,
        pos=State.screen_top1.pos,
    }
    return
  end

  for line_index,line in ipairs(State.lines) do
    if line.mode == 'text' then
      if Text.in_line(State, line_index, x,y) then
        -- delicate dance between cursor, selection and old cursor/selection
        -- scenarios:
        --  regular press+release: sets cursor, clears selection
        --  shift press+release:
        --    sets selection to old cursor if not set otherwise leaves it untouched
        --    sets cursor
        --  press and hold to start a selection: sets selection on press, cursor on release
        --  press and hold, then press shift: ignore shift
        --    i.e. mouse_release should never look at shift state
--?         print_and_log(('edit.mouse_press: in line %d'):format(line_index))
        State.old_cursor1 = State.cursor1
        State.old_selection1 = State.selection1
        State.mousepress_shift = App.shift_down()
        State.selection1 = {
            line=line_index,
            pos=Text.to_pos_on_line(State, line_index, x, y),
        }
        return
      end
    elseif line.mode == 'drawing' then
      if Drawing.in_drawing(State, line_index, x, y, State.left,State.right) then
        State.lines.current_drawing_index = line_index
        State.lines.current_drawing = line
        Drawing.before = snapshot(State, line_index)
        Drawing.mouse_press(State, line_index, x,y, mouse_button, is_touch, presses)
        return
      end
    end
  end

  -- still here? mouse press is below all screen lines
  State.old_cursor1 = State.cursor1
  State.old_selection1 = State.selection1
  State.mousepress_shift = App.shift_down()
  State.selection1 = Text.final_text_loc_on_screen(State)
end

function edit.mouse_release(State, x,y, mouse_button, is_touch, presses)
  if State.search_term then return end
--?   print_and_log(('edit.mouse_release: cursor at %d,%d'):format(State.cursor1.line, State.cursor1.pos))
  State.mouse_down = nil
  if State.lines.current_drawing then
    Drawing.mouse_release(State, x,y, mouse_button, is_touch, presses)
    if Drawing.before then
      record_undo_event(State, {before=Drawing.before, after=snapshot(State, State.lines.current_drawing_index)})
      Drawing.before = nil
    end
    schedule_save(State)
  else
--?     print_and_log('edit.mouse_release: no current drawing')
    if y < State.top then
      State.cursor1 = deepcopy(State.screen_top1)
      edit.clean_up_mouse_press(State)
      return
    end

    for line_index,line in ipairs(State.lines) do
      if line.mode == 'text' then
        if Text.in_line(State, line_index, x,y) then
--?           print_and_log(('edit.mouse_release: in line %d'):format(line_index))
          State.cursor1 = {
              line=line_index,
              pos=Text.to_pos_on_line(State, line_index, x, y),
          }
--?           print_and_log(('edit.mouse_release: cursor now %d,%d'):format(State.cursor1.line, State.cursor1.pos))
          edit.clean_up_mouse_press(State)
          return
        end
      end
    end

    -- still here? mouse release is below all screen lines
    State.cursor1 = Text.final_text_loc_on_screen(State)
    edit.clean_up_mouse_press(State)
--?     print_and_log(('edit.mouse_release: finally selection %s,%s cursor %d,%d'):format(tostring(State.selection1.line), tostring(State.selection1.pos), State.cursor1.line, State.cursor1.pos))
  end
end

function edit.clean_up_mouse_press(State)
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
end

function edit.mouse_wheel_move(State, dx,dy)
  if dy > 0 then
    State.cursor1 = deepcopy(State.screen_top1)
    edit.put_cursor_on_next_text_line(State)
    for i=1,math.floor(dy) do
      Text.up(State)
    end
  elseif dy < 0 then
    State.cursor1 = Text.screen_bottom1(State)
    edit.put_cursor_on_next_text_line(State)
    for i=1,math.floor(-dy) do
      Text.down(State)
    end
  end
end

function edit.text_input(State, t)
--?   print('text input', t)
  if State.search_term then
    State.search_term = State.search_term..t
    Text.search_next(State)
  elseif State.lines.current_drawing and State.current_drawing_mode == 'name' then
    local before = snapshot(State, State.lines.current_drawing_index)
    local drawing = State.lines.current_drawing
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
    record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
  else
    local drawing_index, drawing = Drawing.current_drawing(State)
    if drawing_index == nil then
      Text.text_input(State, t)
    end
  end
  schedule_save(State)
end

function edit.keychord_press(State, chord, key, scancode, is_repeat)
  if State.selection1.line and
      not State.lines.current_drawing and
      -- printable character created using shift key => delete selection
      -- (we're not creating any ctrl-shift- or alt-shift- combinations using regular/printable keys)
      (not App.shift_down() or utf8.len(key) == 1) and
      chord ~= 'C-a' and chord ~= 'C-c' and chord ~= 'C-x' and chord ~= 'backspace' and chord ~= 'delete' and chord ~= 'C-z' and chord ~= 'C-y' and not App.is_cursor_movement(key) then
    Text.delete_selection_and_record_undo_event(State)
  end
  if State.search_term then
    if chord == 'escape' then
      State.search_term = nil
      State.cursor1 = State.search_backup.cursor
      State.screen_top1 = State.search_backup.screen_top
      State.search_backup = nil
      Text.redraw_all(State)  -- if we're scrolling, reclaim all line caches to avoid memory leaks
    elseif chord == 'return' then
      State.search_term = nil
      State.search_backup = nil
    elseif chord == 'backspace' then
      local len = utf8.len(State.search_term)
      local byte_offset = Text.offset(State.search_term, len)
      State.search_term = string.sub(State.search_term, 1, byte_offset-1)
      State.cursor = deepcopy(State.search_backup.cursor)
      State.screen_top = deepcopy(State.search_backup.screen_top)
      Text.search_next(State)
    elseif chord == 'down' then
      if #State.search_term > 0 then
        Text.right(State)
        Text.search_next(State)
      end
    elseif chord == 'up' then
      Text.search_previous(State)
    end
    return
  elseif chord == 'C-f' then
    State.search_term = ''
    State.search_backup = {
      cursor={line=State.cursor1.line, pos=State.cursor1.pos},
      screen_top={line=State.screen_top1.line, pos=State.screen_top1.pos},
    }
  -- zoom
  elseif chord == 'C-=' then
    edit.update_font_settings(State, State.font_height+2)
    Text.redraw_all(State)
  elseif chord == 'C--' then
    if State.font_height > 2 then
      edit.update_font_settings(State, State.font_height-2)
      Text.redraw_all(State)
    end
  elseif chord == 'C-0' then
    edit.update_font_settings(State, 20)
    Text.redraw_all(State)
  -- undo
  elseif chord == 'C-z' then
    local event = undo_event(State)
    if event then
      local src = event.before
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.after, event.before)
      -- invalidate various cached bits of lines
      State.lines.current_drawing = nil
      Text.redraw_all(State)  -- if we're scrolling, reclaim all line caches to avoid memory leaks
      schedule_save(State)
    end
  elseif chord == 'C-y' then
    local event = redo_event(State)
    if event then
      local src = event.after
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.before, event.after)
      -- invalidate various cached bits of lines
      State.lines.current_drawing = nil
      Text.redraw_all(State)  -- if we're scrolling, reclaim all line caches to avoid memory leaks
      schedule_save(State)
    end
  -- clipboard
  elseif chord == 'C-a' then
    State.selection1 = {line=1, pos=1}
    State.cursor1 = {line=#State.lines, pos=utf8.len(State.lines[#State.lines].data)+1}
  elseif chord == 'C-c' then
    local s = Text.selection(State)
    if s then
      App.set_clipboard(s)
    end
  elseif chord == 'C-x' then
    local s = Text.cut_selection_and_record_undo_event(State)
    if s then
      App.set_clipboard(s)
    end
    schedule_save(State)
  elseif chord == 'C-v' then
    -- We don't have a good sense of when to scroll, so we'll be conservative
    -- and sometimes scroll when we didn't quite need to.
    local before_line = State.cursor1.line
    local before = snapshot(State, before_line)
    local clipboard_data = App.get_clipboard()
    for _,code in utf8.codes(clipboard_data) do
      local c = utf8.char(code)
      if c == '\n' then
        Text.insert_return(State)
      else
        Text.insert_at_cursor(State, c)
      end
    end
    if Text.cursor_out_of_screen(State) then
      Text.snap_cursor_to_bottom_of_screen(State, State.left, State.right)
    end
    record_undo_event(State, {before=before, after=snapshot(State, before_line, State.cursor1.line)})
    schedule_save(State)
  -- dispatch to drawing or text
  elseif App.mouse_down(1) or chord:sub(1,2) == 'C-' then
    local drawing_index, drawing = Drawing.current_drawing(State)
    if drawing_index then
      local before = snapshot(State, drawing_index)
      Drawing.keychord_press(State, chord, key, scancode, is_repeat)
      record_undo_event(State, {before=before, after=snapshot(State, drawing_index)})
      schedule_save(State)
    end
  elseif chord == 'escape' and not App.mouse_down(1) then
    for _,line in ipairs(State.lines) do
      if line.mode == 'drawing' then
        line.show_help = false
      end
    end
  elseif State.lines.current_drawing and State.current_drawing_mode == 'name' then
    if chord == 'return' then
      State.current_drawing_mode = State.previous_drawing_mode
      State.previous_drawing_mode = nil
    else
      local before = snapshot(State, State.lines.current_drawing_index)
      local drawing = State.lines.current_drawing
      local p = drawing.points[drawing.pending.target_point]
      if chord == 'escape' then
        p.name = nil
        record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
      elseif chord == 'backspace' then
        local len = utf8.len(p.name)
        if len > 0 then
          local byte_offset = Text.offset(p.name, len-1)
          if len == 1 then byte_offset = 0 end
          p.name = string.sub(p.name, 1, byte_offset)
          record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
        end
      end
    end
    schedule_save(State)
  else
    Text.keychord_press(State, chord, key, scancode, is_repeat)
  end
end

function edit.key_release(State, key, scancode)
end

function edit.update_font_settings(State, font_height, font)
  State.font_height = font_height
  State.font = font or love.graphics.newFont(State.font_height)
  State.line_height = math.floor(font_height*1.3)
end

--== some methods for tests

-- Insulate tests from some key globals so I don't have to change the vast
-- majority of tests when they're modified for the real app.
Test_margin_left = 25
Test_margin_right = 0

function edit.initialize_test_state()
  -- if you change these values, tests will start failing
  return edit.initialize_state(
      15,  -- top margin
      Test_margin_left,
      App.screen.width - Test_margin_right,
      love.graphics.getFont(),
      14,
      15)  -- line height
end

-- all text_input events are also keypresses
-- TODO: handle chords of multiple keys
function edit.run_after_text_input(State, t)
  edit.keychord_press(State, t)
  edit.text_input(State, t)
  edit.key_release(State, t)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

-- not all keys are text_input
function edit.run_after_keychord(State, chord, key)
  edit.keychord_press(State, chord, key)
  edit.key_release(State, key)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_click(State, x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  edit.mouse_press(State, x,y, mouse_button)
  edit.draw(State)
  App.fake_mouse_release(x,y, mouse_button)
  edit.mouse_release(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_press(State, x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  edit.mouse_press(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_release(State, x,y, mouse_button)
  App.fake_mouse_release(x,y, mouse_button)
  edit.mouse_release(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end
