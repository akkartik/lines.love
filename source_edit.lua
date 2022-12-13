-- some constants people might like to tweak
Text_color = {r=0, g=0, b=0}
Cursor_color = {r=1, g=0, b=0}
Hyperlink_decoration_color = {r=0.4, g=0.4, b=1}
Stroke_color = {r=0, g=0, b=0}
Current_stroke_color = {r=0.7, g=0.7, b=0.7}  -- in process of being drawn
Current_name_background_color = {r=1, g=0, b=0, a=0.1}  -- name currently being edited
Focus_stroke_color = {r=1, g=0, b=0}  -- what mouse is hovering over
Highlight_color = {r=0.7, g=0.7, b=0.9}  -- selected text
Icon_color = {r=0.7, g=0.7, b=0.7}  -- color of current mode icon in drawings
Help_color = {r=0, g=0.5, b=0}
Help_background_color = {r=0, g=0.5, b=0, a=0.1}
Fold_color = {r=0, g=0.6, b=0}
Fold_background_color = {r=0, g=0.7, b=0}

Margin_top = 15
Margin_left = 25
Margin_right = 25

Drawing_padding_top = 10
Drawing_padding_bottom = 10
Drawing_padding_height = Drawing_padding_top + Drawing_padding_bottom

Same_point_distance = 4  -- pixel distance at which two points are considered the same

edit = {}

-- run in both tests and a real run
function edit.initialize_state(top, left, right, font_height, line_height)  -- currently always draws to bottom of screen
  local result = {
    -- a line is either bifold text or a drawing
    -- a line of bifold text consists of an A side and an optional B side
    --    mode = 'text',
    --    string data,
    --    string dataB,
    --    expanded: whether to show B side
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
    lines = {{mode='text', data='', dataB=nil, expanded=nil}},  -- array of lines

    -- Lines can be too long to fit on screen, in which case they _wrap_ into
    -- multiple _screen lines_.

    -- rendering wrapped text lines needs some additional short-lived data per line:
    --   startpos, the index of data the line starts rendering from, can only be >1 for topmost line on screen
    --   starty, the y coord in pixels the line starts rendering from
    --   fragments: snippets of rendered love.graphics.Text, guaranteed to not straddle screen lines
    --   screen_line_starting_pos: optional array of grapheme indices if it wraps over more than one screen line
    line_cache = {},

    -- Given wrapping, any potential location for the text cursor can be described in two ways:
    -- * schema 1: As a combination of line index and position within a line (in utf8 codepoint units)
    -- * schema 2: As a combination of line index, screen line index within the line, and a position within the screen line.
    -- Positions (and screen line indexes) can be in either the A or the B side.
    --
    -- Most of the time we'll only persist positions in schema 1, translating to
    -- schema 2 when that's convenient.
    --
    -- Make sure these coordinates are never aliased, so that changing one causes
    -- action at a distance.
    screen_top1 = {line=1, pos=1, posB=nil},  -- position of start of screen line at top of screen
    cursor1 = {line=1, pos=1, posB=nil},  -- position of cursor
    screen_bottom1 = {line=1, pos=1, posB=nil},  -- position of start of screen line at bottom of screen

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

    font_height = font_height,
    line_height = line_height,
    em = App.newText(love.graphics.getFont(), 'm'),  -- widest possible character width

    top = top,
    left = left,
    right = right,
    width = right-left,

    filename = love.filesystem.getUserDirectory()..'/lines.txt',  -- '/' should work even on Windows
    next_save = nil,

    -- undo
    history = {},
    next_history = 1,

    -- search
    search_term = nil,
    search_text = nil,
    search_backup = nil,  -- stuff to restore when cancelling search
  }
  return result
end  -- App.initialize_state

function edit.fixup_cursor(State)
  for i,line in ipairs(State.lines) do
    if line.mode == 'text' then
      State.cursor1.line = i
      break
    end
  end
end

function edit.draw(State, hide_cursor)
  State.button_handlers = {}
  App.color(Text_color)
  if #State.lines ~= #State.line_cache then
    print(('line_cache is out of date; %d when it should be %d'):format(#State.line_cache, #State.lines))
    assert(false)
  end
  if not Text.le1(State.screen_top1, State.cursor1) then
    print(State.screen_top1.line, State.screen_top1.pos, State.screen_top1.posB, State.cursor1.line, State.cursor1.pos, State.cursor1.posB)
    assert(false)
  end
  State.cursor_x = nil
  State.cursor_y = nil
  local y = State.top
--?   print('== draw')
  for line_index = State.screen_top1.line,#State.lines do
    local line = State.lines[line_index]
--?     print('draw:', y, line_index, line, line.mode)
    if y + State.line_height > App.screen.height then break end
    State.screen_bottom1 = {line=line_index, pos=nil, posB=nil}
    if line.mode == 'text' then
--?     print('text.draw', y, line_index)
      local startpos, startposB = 1, nil
      if line_index == State.screen_top1.line then
        if State.screen_top1.pos then
          startpos = State.screen_top1.pos
        else
          startpos, startposB = nil, State.screen_top1.posB
        end
      end
      if line.data == '' then
        -- button to insert new drawing
        button(State, 'draw', {x=4,y=y+4, w=12,h=12, color={1,1,0},
          icon = icon.insert_drawing,
          onpress1 = function()
                       Drawing.before = snapshot(State, line_index-1, line_index)
                       table.insert(State.lines, line_index, {mode='drawing', y=y, h=256/2, points={}, shapes={}, pending={}})
                       table.insert(State.line_cache, line_index, {})
                       if State.cursor1.line >= line_index then
                         State.cursor1.line = State.cursor1.line+1
                       end
                       schedule_save(State)
                       record_undo_event(State, {before=Drawing.before, after=snapshot(State, line_index-1, line_index+1)})
                     end,
        })
      end
      y, State.screen_bottom1.pos, State.screen_bottom1.posB = Text.draw(State, line_index, y, startpos, startposB, hide_cursor)
      y = y + State.line_height
--?       print('=> y', y)
    elseif line.mode == 'drawing' then
      y = y+Drawing_padding_top
      Drawing.draw(State, line_index, y)
      y = y + Drawing.pixels(line.h, State.width) + Drawing_padding_bottom
    else
      print(line.mode)
      assert(false)
    end
  end
  if State.search_term then
    Text.draw_search_bar(State)
  end
end

function edit.update(State, dt)
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
  end
end

function edit.mouse_pressed(State, x,y, mouse_button)
  if State.search_term then return end
--?   print('press')
  if mouse_press_consumed_by_any_button_handler(State, x,y, mouse_button) then
    -- press on a button and it returned 'true' to short-circuit
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
        --    i.e. mouse_released should never look at shift state
        State.old_cursor1 = State.cursor1
        State.old_selection1 = State.selection1
        State.mousepress_shift = App.shift_down()
        local pos,posB = Text.to_pos_on_line(State, line_index, x, y)
  --?       print(x,y, 'setting cursor:', line_index, pos, posB)
        State.selection1 = {line=line_index, pos=pos, posB=posB}
--?         print('selection', State.selection1.line, State.selection1.pos, State.selection1.posB)
        break
      end
    elseif line.mode == 'drawing' then
      local line_cache = State.line_cache[line_index]
      if Drawing.in_drawing(line, line_cache, x, y, State.left,State.right) then
        State.lines.current_drawing_index = line_index
        State.lines.current_drawing = line
        Drawing.before = snapshot(State, line_index)
        Drawing.mouse_pressed(State, line_index, x,y, mouse_button)
        break
      end
    end
  end
end

function edit.mouse_released(State, x,y, mouse_button)
  if State.search_term then return end
--?   print('release')
  if State.lines.current_drawing then
    Drawing.mouse_released(State, x,y, mouse_button)
    schedule_save(State)
    if Drawing.before then
      record_undo_event(State, {before=Drawing.before, after=snapshot(State, State.lines.current_drawing_index)})
      Drawing.before = nil
    end
  else
    for line_index,line in ipairs(State.lines) do
      if line.mode == 'text' then
        if Text.in_line(State, line_index, x,y) then
--?           print('reset selection')
          local pos,posB = Text.to_pos_on_line(State, line_index, x, y)
          State.cursor1 = {line=line_index, pos=pos, posB=posB}
--?           print('cursor', State.cursor1.line, State.cursor1.pos, State.cursor1.posB)
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
  if State.search_term then
    State.search_term = State.search_term..t
    State.search_text = nil
    Text.search_next(State)
  elseif State.current_drawing_mode == 'name' then
    local before = snapshot(State, State.lines.current_drawing_index)
    local drawing = State.lines.current_drawing
    local p = drawing.points[drawing.pending.target_point]
    p.name = p.name..t
    record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
  else
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    Text.textinput(State, t)
  end
  schedule_save(State)
end

function edit.keychord_pressed(State, chord, key)
  if State.selection1.line and
      not State.lines.current_drawing and
      -- printable character created using shift key => delete selection
      -- (we're not creating any ctrl-shift- or alt-shift- combinations using regular/printable keys)
      (not App.shift_down() or utf8.len(key) == 1) and
      chord ~= 'C-a' and chord ~= 'C-c' and chord ~= 'C-x' and chord ~= 'backspace' and backspace ~= 'delete' and not App.is_cursor_movement(chord) then
    Text.delete_selection(State, State.left, State.right)
  end
  if State.search_term then
    if chord == 'escape' then
      State.search_term = nil
      State.search_text = nil
      State.cursor1 = State.search_backup.cursor
      State.screen_top1 = State.search_backup.screen_top
      State.search_backup = nil
      Text.redraw_all(State)  -- if we're scrolling, reclaim all fragments to avoid memory leaks
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
      if State.cursor1.pos then
        State.cursor1.pos = State.cursor1.pos+1
      else
        State.cursor1.posB = State.cursor1.posB+1
      end
      Text.search_next(State)
    elseif chord == 'up' then
      Text.search_previous(State)
    end
    return
  elseif chord == 'C-f' then
    State.search_term = ''
    State.search_backup = {
      cursor={line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB},
      screen_top={line=State.screen_top1.line, pos=State.screen_top1.pos, posB=State.screen_top1.posB},
    }
    assert(State.search_text == nil)
  -- bifold text
  elseif chord == 'M-b' then
    State.expanded = not State.expanded
    Text.redraw_all(State)
    if not State.expanded then
      for _,line in ipairs(State.lines) do
        line.expanded = nil
      end
      edit.eradicate_locations_after_the_fold(State)
    end
  elseif chord == 'M-d' then
    if State.cursor1.posB == nil then
      local before = snapshot(State, State.cursor1.line)
      if State.lines[State.cursor1.line].dataB == nil then
        State.lines[State.cursor1.line].dataB = ''
      end
      State.lines[State.cursor1.line].expanded = true
      State.cursor1.pos = nil
      State.cursor1.posB = 1
      if Text.cursor_out_of_screen(State) then
        Text.snap_cursor_to_bottom_of_screen(State, State.left, State.right)
      end
      schedule_save(State)
      record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
    end
  -- zoom
  elseif chord == 'C-=' then
    edit.update_font_settings(State, State.font_height+2)
    Text.redraw_all(State)
  elseif chord == 'C--' then
    edit.update_font_settings(State, State.font_height-2)
    Text.redraw_all(State)
  elseif chord == 'C-0' then
    edit.update_font_settings(State, 20)
    Text.redraw_all(State)
  -- undo
  elseif chord == 'C-z' then
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    local event = undo_event(State)
    if event then
      local src = event.before
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.after, event.before)
      patch_placeholders(State.line_cache, event.after, event.before)
      -- invalidate various cached bits of lines
      State.lines.current_drawing = nil
      -- if we're scrolling, reclaim all fragments to avoid memory leaks
      Text.redraw_all(State)
      schedule_save(State)
    end
  elseif chord == 'C-y' then
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    local event = redo_event(State)
    if event then
      local src = event.after
      State.screen_top1 = deepcopy(src.screen_top)
      State.cursor1 = deepcopy(src.cursor)
      State.selection1 = deepcopy(src.selection)
      patch(State.lines, event.before, event.after)
      -- invalidate various cached bits of lines
      State.lines.current_drawing = nil
      -- if we're scrolling, reclaim all fragments to avoid memory leaks
      Text.redraw_all(State)
      schedule_save(State)
    end
  -- clipboard
  elseif chord == 'C-a' then
    State.selection1 = {line=1, pos=1}
    State.cursor1 = {line=#State.lines, pos=utf8.len(State.lines[#State.lines].data)+1, posB=nil}
  elseif chord == 'C-c' then
    local s = Text.selection(State)
    if s then
      App.setClipboardText(s)
    end
  elseif chord == 'C-x' then
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    local s = Text.cut_selection(State, State.left, State.right)
    if s then
      App.setClipboardText(s)
    end
    schedule_save(State)
  elseif chord == 'C-v' then
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    -- We don't have a good sense of when to scroll, so we'll be conservative
    -- and sometimes scroll when we didn't quite need to.
    local before_line = State.cursor1.line
    local before = snapshot(State, before_line)
    local clipboard_data = App.getClipboardText()
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
    schedule_save(State)
    record_undo_event(State, {before=before, after=snapshot(State, before_line, State.cursor1.line)})
  -- dispatch to drawing or text
  elseif App.mouse_down(1) or chord:sub(1,2) == 'C-' then
    -- DON'T reset line_cache.starty here
    local drawing_index, drawing = Drawing.current_drawing(State)
    if drawing_index then
      local before = snapshot(State, drawing_index)
      Drawing.keychord_pressed(State, chord)
      record_undo_event(State, {before=before, after=snapshot(State, drawing_index)})
      schedule_save(State)
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
      local before = snapshot(State, State.lines.current_drawing_index)
      local drawing = State.lines.current_drawing
      local p = drawing.points[drawing.pending.target_point]
      if chord == 'escape' then
        p.name = nil
        record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
      elseif chord == 'backspace' then
        local len = utf8.len(p.name)
        local byte_offset = Text.offset(p.name, len-1)
        if len == 1 then byte_offset = 0 end
        p.name = string.sub(p.name, 1, byte_offset)
        record_undo_event(State, {before=before, after=snapshot(State, State.lines.current_drawing_index)})
      end
    end
    schedule_save(State)
  else
    for _,line_cache in ipairs(State.line_cache) do line_cache.starty = nil end  -- just in case we scroll
    Text.keychord_pressed(State, chord)
  end
end

function edit.eradicate_locations_after_the_fold(State)
  -- eradicate side B from any locations we track
  if State.cursor1.posB then
    State.cursor1.posB = nil
    State.cursor1.pos = utf8.len(State.lines[State.cursor1.line].data)
    State.cursor1.pos = Text.pos_at_start_of_screen_line(State, State.cursor1)
  end
  if State.screen_top1.posB then
    State.screen_top1.posB = nil
    State.screen_top1.pos = utf8.len(State.lines[State.screen_top1.line].data)
    State.screen_top1.pos = Text.pos_at_start_of_screen_line(State, State.screen_top1)
  end
end

function edit.key_released(State, key, scancode)
end

function edit.update_font_settings(State, font_height)
  State.font_height = font_height
  love.graphics.setFont(love.graphics.newFont(State.font_height))
  State.line_height = math.floor(font_height*1.3)
  State.em = App.newText(love.graphics.getFont(), 'm')
  Text_cache = {}
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
      14,  -- font height assuming default LÖVE font
      15)  -- line height
end

-- all textinput events are also keypresses
-- TODO: handle chords of multiple keys
function edit.run_after_textinput(State, t)
  edit.keychord_pressed(State, t)
  edit.textinput(State, t)
  edit.key_released(State, t)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

-- not all keys are textinput
function edit.run_after_keychord(State, chord)
  edit.keychord_pressed(State, chord)
  edit.key_released(State, chord)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_click(State, x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  edit.mouse_pressed(State, x,y, mouse_button)
  App.fake_mouse_release(x,y, mouse_button)
  edit.mouse_released(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_press(State, x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  edit.mouse_pressed(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end

function edit.run_after_mouse_release(State, x,y, mouse_button)
  App.fake_mouse_release(x,y, mouse_button)
  edit.mouse_released(State, x,y, mouse_button)
  App.screen.contents = {}
  edit.update(State, 0)
  edit.draw(State)
end
