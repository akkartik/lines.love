-- text editor, particularly text drawing, horizontal wrap, vertical scrolling
Text = {}
AB_padding = 20  -- space in pixels between A side and B side

-- draw a line starting from startpos to screen at y between State.left and State.right
-- return the final y, and pos,posB of start of final screen line drawn
function Text.draw(State, line_index, y, startpos, startposB, hide_cursor)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  line_cache.starty = y
  line_cache.startpos = startpos
  line_cache.startposB = startposB
  -- draw A side
  local overflows_screen, x, pos, screen_line_starting_pos
  if startpos then
    overflows_screen, x, y, pos, screen_line_starting_pos = Text.draw_wrapping_line(State, line_index, State.left, y, startpos)
    if overflows_screen then
      return y, screen_line_starting_pos
    end
    if Focus == 'edit' and State.cursor1.pos then
      if not hide_cursor and not State.search_term then
        if line_index == State.cursor1.line and State.cursor1.pos == pos then
          Text.draw_cursor(State, x, y)
        end
      end
    end
  else
    x = State.left
  end
  -- check for B side
--?   if line_index == 8 then print('checking for B side') end
  if line.dataB == nil then
    assert(y)
    assert(screen_line_starting_pos)
--?     if line_index == 8 then print('return 1') end
    return y, screen_line_starting_pos
  end
  if not State.expanded and not line.expanded then
    assert(y)
    assert(screen_line_starting_pos)
--?     if line_index == 8 then print('return 2') end
    button(State, 'expand', {x=x+AB_padding, y=y+2, w=App.width(State.em), h=State.line_height-4, color={1,1,1},
      icon = function(button_params)
               App.color(Fold_background_color)
               love.graphics.rectangle('fill', button_params.x, button_params.y, App.width(State.em), State.line_height-4, 2,2)
             end,
      onpress1 = function()
                   line.expanded = true
                 end,
    })
    return y, screen_line_starting_pos
  end
  -- draw B side
--?   if line_index == 8 then print('drawing B side') end
  App.color(Fold_color)
  if startposB then
    overflows_screen, x, y, pos, screen_line_starting_pos = Text.draw_wrapping_lineB(State, line_index, x,y, startposB)
  else
    overflows_screen, x, y, pos, screen_line_starting_pos = Text.draw_wrapping_lineB(State, line_index, x+AB_padding,y, 1)
  end
  if overflows_screen then
    return y, nil, screen_line_starting_pos
  end
--?   if line_index == 8 then print('a') end
  if Focus == 'edit' and State.cursor1.posB then
--?     if line_index == 8 then print('b') end
    if not hide_cursor and not State.search_term then
--?       if line_index == 8 then print('c', State.cursor1.line, State.cursor1.posB, line_index, pos) end
      if line_index == State.cursor1.line and State.cursor1.posB == pos then
        Text.draw_cursor(State, x, y)
      end
    end
  end
  return y, nil, screen_line_starting_pos
end

-- Given an array of fragments, draw the subset starting from pos to screen
-- starting from (x,y).
-- Return:
--  - whether we got to bottom of screen before end of line
--  - the final (x,y)
--  - the final pos
--  - starting pos of the final screen line drawn
function Text.draw_wrapping_line(State, line_index, x,y, startpos)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
--?   print('== line', line_index, '^'..line.data..'$')
  local screen_line_starting_pos = startpos
  Text.compute_fragments(State, line_index)
  local pos = 1
  initialize_color()
  for _, f in ipairs(line_cache.fragments) do
    App.color(Text_color)
    local frag, frag_text = f.data, f.text
    select_color(frag)
    local frag_len = utf8.len(frag)
--?     print('text.draw:', frag, 'at', line_index,pos, 'after', x,y)
    if pos < startpos then
      -- render nothing
--?       print('skipping', frag)
    else
      -- render fragment
      local frag_width = App.width(frag_text)
      if x + frag_width > State.right then
        assert(x > State.left)  -- no overfull lines
        y = y + State.line_height
        if y + State.line_height > App.screen.height then
          return --[[screen filled]] true, x,y, pos, screen_line_starting_pos
        end
        screen_line_starting_pos = pos
        x = State.left
      end
      if State.selection1.line then
        local lo, hi = Text.clip_selection(State, line_index, pos, pos+frag_len)
        Text.draw_highlight(State, line, x,y, pos, lo,hi)
      end
      -- Make [[WikiWords]] (single word, all in one screen line) clickable.
      local trimmed_word = rtrim(frag)  -- compute_fragments puts whitespace at the end
      if starts_with(trimmed_word, '[[') and ends_with(trimmed_word, ']]') then
        local filename = trimmed_word:gsub('^..(.*)..$', '%1')
        if source.link_exists(State, filename) then
          local filename_text = App.newText(love.graphics.getFont(), filename)
          button(State, 'link', {x=x+App.width(to_text('[[')), y=y, w=App.width(filename_text), h=State.line_height, color={1,1,1},
            icon = icon.hyperlink_decoration,
            onpress1 = function()
                         source.switch_to_file(filename)
                        end,
          })
        end
      end
      App.screen.draw(frag_text, x,y)
      -- render cursor if necessary
      if State.cursor1.pos and line_index == State.cursor1.line then
        if pos <= State.cursor1.pos and pos + frag_len > State.cursor1.pos then
          if State.search_term then
            if State.lines[State.cursor1.line].data:sub(State.cursor1.pos, State.cursor1.pos+utf8.len(State.search_term)-1) == State.search_term then
              local lo_px = Text.draw_highlight(State, line, x,y, pos, State.cursor1.pos, State.cursor1.pos+utf8.len(State.search_term))
              App.color(Text_color)
              love.graphics.print(State.search_term, x+lo_px,y)
            end
          elseif Focus == 'edit' then
            Text.draw_cursor(State, x+Text.x(frag, State.cursor1.pos-pos+1), y)
            App.color(Text_color)
          end
        end
      end
      x = x + frag_width
    end
    pos = pos + frag_len
  end
  return false, x,y, pos, screen_line_starting_pos
end

function Text.draw_wrapping_lineB(State, line_index, x,y, startpos)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  local screen_line_starting_pos = startpos
  Text.compute_fragmentsB(State, line_index, x)
  local pos = 1
  for _, f in ipairs(line_cache.fragmentsB) do
    local frag, frag_text = f.data, f.text
    local frag_len = utf8.len(frag)
--?     print('text.draw:', frag, 'at', line_index,pos, 'after', x,y)
    if pos < startpos then
      -- render nothing
--?       print('skipping', frag)
    else
      -- render fragment
      local frag_width = App.width(frag_text)
      if x + frag_width > State.right then
        assert(x > State.left)  -- no overfull lines
        y = y + State.line_height
        if y + State.line_height > App.screen.height then
          return --[[screen filled]] true, x,y, pos, screen_line_starting_pos
        end
        screen_line_starting_pos = pos
        x = State.left
      end
      if State.selection1.line then
        local lo, hi = Text.clip_selection(State, line_index, pos, pos+frag_len)
        Text.draw_highlight(State, line, x,y, pos, lo,hi)
      end
      App.screen.draw(frag_text, x,y)
      -- render cursor if necessary
      if State.cursor1.posB and line_index == State.cursor1.line then
        if pos <= State.cursor1.posB and pos + frag_len > State.cursor1.posB then
          if State.search_term then
            if State.lines[State.cursor1.line].dataB:sub(State.cursor1.posB, State.cursor1.posB+utf8.len(State.search_term)-1) == State.search_term then
              local lo_px = Text.draw_highlight(State, line, x,y, pos, State.cursor1.posB, State.cursor1.posB+utf8.len(State.search_term))
              App.color(Fold_color)
              love.graphics.print(State.search_term, x+lo_px,y)
            end
          elseif Focus == 'edit' then
            Text.draw_cursor(State, x+Text.x(frag, State.cursor1.posB-pos+1), y)
            App.color(Fold_color)
          end
        end
      end
      x = x + frag_width
    end
    pos = pos + frag_len
  end
  return false, x,y, pos, screen_line_starting_pos
end

function Text.draw_cursor(State, x, y)
  -- blink every 0.5s
  if math.floor(Cursor_time*2)%2 == 0 then
    App.color(Cursor_color)
    love.graphics.rectangle('fill', x,y, 3,State.line_height)
  end
  State.cursor_x = x
  State.cursor_y = y+State.line_height
end

function Text.populate_screen_line_starting_pos(State, line_index)
  local line = State.lines[line_index]
  if line.mode ~= 'text' then return end
  local line_cache = State.line_cache[line_index]
  if line_cache.screen_line_starting_pos then
    return
  end
  -- duplicate some logic from Text.draw
  Text.compute_fragments(State, line_index)
  line_cache.screen_line_starting_pos = {1}
  local x = State.left
  local pos = 1
  for _, f in ipairs(line_cache.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = App.width(frag_text)
    if x + frag_width > State.right then
      x = State.left
      table.insert(line_cache.screen_line_starting_pos, pos)
    end
    x = x + frag_width
    local frag_len = utf8.len(frag)
    pos = pos + frag_len
  end
end

function Text.compute_fragments(State, line_index)
--?   print('compute_fragments', line_index, 'between', State.left, State.right)
  local line = State.lines[line_index]
  if line.mode ~= 'text' then return end
  local line_cache = State.line_cache[line_index]
  if line_cache.fragments then
    return
  end
  line_cache.fragments = {}
  local x = State.left
  -- try to wrap at word boundaries
  for frag in line.data:gmatch('%S*%s*') do
    local frag_text = App.newText(love.graphics.getFont(), frag)
    local frag_width = App.width(frag_text)
--?     print('x: '..tostring(x)..'; frag_width: '..tostring(frag_width)..'; '..tostring(State.right-x)..'px to go')
    while x + frag_width > State.right do
--?       print(('checking whether to split fragment ^%s$ of width %d when rendering from %d'):format(frag, frag_width, x))
      if (x-State.left) < 0.8 * (State.right-State.left) then
--?         print('splitting')
        -- long word; chop it at some letter
        -- We're not going to reimplement TeX here.
        local bpos = Text.nearest_pos_less_than(frag, State.right - x)
--?         print('bpos', bpos)
        if bpos == 0 then break end  -- avoid infinite loop when window is too narrow
        local boffset = Text.offset(frag, bpos+1)  -- byte _after_ bpos
--?         print('space for '..tostring(bpos)..' graphemes, '..tostring(boffset-1)..' bytes')
        local frag1 = string.sub(frag, 1, boffset-1)
        local frag1_text = App.newText(love.graphics.getFont(), frag1)
        local frag1_width = App.width(frag1_text)
--?         print('extracting ^'..frag1..'$ of width '..tostring(frag1_width)..'px')
        assert(x + frag1_width <= State.right)
        table.insert(line_cache.fragments, {data=frag1, text=frag1_text})
        frag = string.sub(frag, boffset)
        frag_text = App.newText(love.graphics.getFont(), frag)
        frag_width = App.width(frag_text)
      end
      x = State.left  -- new line
    end
    if #frag > 0 then
--?       print('inserting ^'..frag..'$ of width '..tostring(frag_width)..'px')
      table.insert(line_cache.fragments, {data=frag, text=frag_text})
    end
    x = x + frag_width
  end
end

function Text.populate_screen_line_starting_posB(State, line_index, x)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  if line_cache.screen_line_starting_posB then
    return
  end
  -- duplicate some logic from Text.draw
  Text.compute_fragmentsB(State, line_index, x)
  line_cache.screen_line_starting_posB = {1}
  local pos = 1
  for _, f in ipairs(line_cache.fragmentsB) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = App.width(frag_text)
    if x + frag_width > State.right then
      x = State.left
      table.insert(line_cache.screen_line_starting_posB, pos)
    end
    x = x + frag_width
    local frag_len = utf8.len(frag)
    pos = pos + frag_len
  end
end

function Text.compute_fragmentsB(State, line_index, x)
--?   print('compute_fragmentsB', line_index, 'between', x, State.right)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  if line_cache.fragmentsB then
    return
  end
  line_cache.fragmentsB = {}
  -- try to wrap at word boundaries
  for frag in line.dataB:gmatch('%S*%s*') do
    local frag_text = App.newText(love.graphics.getFont(), frag)
    local frag_width = App.width(frag_text)
--?     print('x: '..tostring(x)..'; '..tostring(State.right-x)..'px to go')
    while x + frag_width > State.right do
--?       print(('checking whether to split fragment ^%s$ of width %d when rendering from %d'):format(frag, frag_width, x))
      if (x-State.left) < 0.8 * (State.right-State.left) then
--?         print('splitting')
        -- long word; chop it at some letter
        -- We're not going to reimplement TeX here.
        local bpos = Text.nearest_pos_less_than(frag, State.right - x)
--?         print('bpos', bpos)
        if bpos == 0 then break end  -- avoid infinite loop when window is too narrow
        local boffset = Text.offset(frag, bpos+1)  -- byte _after_ bpos
--?         print('space for '..tostring(bpos)..' graphemes, '..tostring(boffset-1)..' bytes')
        local frag1 = string.sub(frag, 1, boffset-1)
        local frag1_text = App.newText(love.graphics.getFont(), frag1)
        local frag1_width = App.width(frag1_text)
--?         print('extracting ^'..frag1..'$ of width '..tostring(frag1_width)..'px')
        assert(x + frag1_width <= State.right)
        table.insert(line_cache.fragmentsB, {data=frag1, text=frag1_text})
        frag = string.sub(frag, boffset)
        frag_text = App.newText(love.graphics.getFont(), frag)
        frag_width = App.width(frag_text)
      end
      x = State.left  -- new line
    end
    if #frag > 0 then
--?       print('inserting ^'..frag..'$ of width '..tostring(frag_width)..'px')
      table.insert(line_cache.fragmentsB, {data=frag, text=frag_text})
    end
    x = x + frag_width
  end
end

function Text.text_input(State, t)
  if App.mouse_down(1) then return end
  if App.ctrl_down() or App.alt_down() or App.cmd_down() then return end
  local before = snapshot(State, State.cursor1.line)
--?   print(State.screen_top1.line, State.screen_top1.pos, State.cursor1.line, State.cursor1.pos, State.screen_bottom1.line, State.screen_bottom1.pos)
  Text.insert_at_cursor(State, t)
  if State.cursor_y > App.screen.height - State.line_height then
    Text.populate_screen_line_starting_pos(State, State.cursor1.line)
    Text.snap_cursor_to_bottom_of_screen(State, State.left, State.right)
  end
  record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
end

function Text.insert_at_cursor(State, t)
  if State.cursor1.pos then
    local byte_offset = Text.offset(State.lines[State.cursor1.line].data, State.cursor1.pos)
    State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_offset-1)..t..string.sub(State.lines[State.cursor1.line].data, byte_offset)
    Text.clear_screen_line_cache(State, State.cursor1.line)
    State.cursor1.pos = State.cursor1.pos+1
  else
    assert(State.cursor1.posB)
    local byte_offset = Text.offset(State.lines[State.cursor1.line].dataB, State.cursor1.posB)
    State.lines[State.cursor1.line].dataB = string.sub(State.lines[State.cursor1.line].dataB, 1, byte_offset-1)..t..string.sub(State.lines[State.cursor1.line].dataB, byte_offset)
    Text.clear_screen_line_cache(State, State.cursor1.line)
    State.cursor1.posB = State.cursor1.posB+1
  end
end

-- Don't handle any keys here that would trigger text_input above.
function Text.keychord_press(State, chord)
--?   print('chord', chord, State.selection1.line, State.selection1.pos)
  --== shortcuts that mutate text
  if chord == 'return' then
    local before_line = State.cursor1.line
    local before = snapshot(State, before_line)
    Text.insert_return(State)
    State.selection1 = {}
    if State.cursor_y > App.screen.height - State.line_height then
      Text.snap_cursor_to_bottom_of_screen(State, State.left, State.right)
    end
    schedule_save(State)
    record_undo_event(State, {before=before, after=snapshot(State, before_line, State.cursor1.line)})
  elseif chord == 'tab' then
    local before = snapshot(State, State.cursor1.line)
--?     print(State.screen_top1.line, State.screen_top1.pos, State.cursor1.line, State.cursor1.pos, State.screen_bottom1.line, State.screen_bottom1.pos)
    Text.insert_at_cursor(State, '\t')
    if State.cursor_y > App.screen.height - State.line_height then
      Text.populate_screen_line_starting_pos(State, State.cursor1.line)
      Text.snap_cursor_to_bottom_of_screen(State, State.left, State.right)
--?       print('=>', State.screen_top1.line, State.screen_top1.pos, State.cursor1.line, State.cursor1.pos, State.screen_bottom1.line, State.screen_bottom1.pos)
    end
    schedule_save(State)
    record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
  elseif chord == 'backspace' then
    if State.selection1.line then
      Text.delete_selection(State, State.left, State.right)
      schedule_save(State)
      return
    end
    local before
    if State.cursor1.pos and State.cursor1.pos > 1 then
      before = snapshot(State, State.cursor1.line)
      local byte_start = utf8.offset(State.lines[State.cursor1.line].data, State.cursor1.pos-1)
      local byte_end = utf8.offset(State.lines[State.cursor1.line].data, State.cursor1.pos)
      if byte_start then
        if byte_end then
          State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_start-1)..string.sub(State.lines[State.cursor1.line].data, byte_end)
        else
          State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_start-1)
        end
        State.cursor1.pos = State.cursor1.pos-1
      end
    elseif State.cursor1.posB then
      if State.cursor1.posB > 1 then
        before = snapshot(State, State.cursor1.line)
        local byte_start = utf8.offset(State.lines[State.cursor1.line].dataB, State.cursor1.posB-1)
        local byte_end = utf8.offset(State.lines[State.cursor1.line].dataB, State.cursor1.posB)
        if byte_start then
          if byte_end then
            State.lines[State.cursor1.line].dataB = string.sub(State.lines[State.cursor1.line].dataB, 1, byte_start-1)..string.sub(State.lines[State.cursor1.line].dataB, byte_end)
          else
            State.lines[State.cursor1.line].dataB = string.sub(State.lines[State.cursor1.line].dataB, 1, byte_start-1)
          end
          State.cursor1.posB = State.cursor1.posB-1
        end
      else
        -- refuse to delete past beginning of side B
      end
    elseif State.cursor1.line > 1 then
      before = snapshot(State, State.cursor1.line-1, State.cursor1.line)
      if State.lines[State.cursor1.line-1].mode == 'drawing' then
        table.remove(State.lines, State.cursor1.line-1)
        table.remove(State.line_cache, State.cursor1.line-1)
      else
        -- join lines
        State.cursor1.pos = utf8.len(State.lines[State.cursor1.line-1].data)+1
        State.lines[State.cursor1.line-1].data = State.lines[State.cursor1.line-1].data..State.lines[State.cursor1.line].data
        table.remove(State.lines, State.cursor1.line)
        table.remove(State.line_cache, State.cursor1.line)
      end
      State.cursor1.line = State.cursor1.line-1
    end
    if State.screen_top1.line > #State.lines then
      Text.populate_screen_line_starting_pos(State, #State.lines)
      local line_cache = State.line_cache[#State.line_cache]
      State.screen_top1 = {line=#State.lines, pos=line_cache.screen_line_starting_pos[#line_cache.screen_line_starting_pos]}
    elseif Text.lt1(State.cursor1, State.screen_top1) then
      local top2 = Text.to2(State, State.screen_top1)
      top2 = Text.previous_screen_line(State, top2, State.left, State.right)
      State.screen_top1 = Text.to1(State, top2)
      Text.redraw_all(State)  -- if we're scrolling, reclaim all fragments to avoid memory leaks
    end
    Text.clear_screen_line_cache(State, State.cursor1.line)
    assert(Text.le1(State.screen_top1, State.cursor1))
    schedule_save(State)
    record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
  elseif chord == 'delete' then
    if State.selection1.line then
      Text.delete_selection(State, State.left, State.right)
      schedule_save(State)
      return
    end
    local before
    if State.cursor1.posB or State.cursor1.pos <= utf8.len(State.lines[State.cursor1.line].data) then
      before = snapshot(State, State.cursor1.line)
    else
      before = snapshot(State, State.cursor1.line, State.cursor1.line+1)
    end
    if State.cursor1.pos and State.cursor1.pos <= utf8.len(State.lines[State.cursor1.line].data) then
      local byte_start = utf8.offset(State.lines[State.cursor1.line].data, State.cursor1.pos)
      local byte_end = utf8.offset(State.lines[State.cursor1.line].data, State.cursor1.pos+1)
      if byte_start then
        if byte_end then
          State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_start-1)..string.sub(State.lines[State.cursor1.line].data, byte_end)
        else
          State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_start-1)
        end
        -- no change to State.cursor1.pos
      end
    elseif State.cursor1.posB then
      if State.cursor1.posB <= utf8.len(State.lines[State.cursor1.line].dataB) then
        local byte_start = utf8.offset(State.lines[State.cursor1.line].dataB, State.cursor1.posB)
        local byte_end = utf8.offset(State.lines[State.cursor1.line].dataB, State.cursor1.posB+1)
        if byte_start then
          if byte_end then
            State.lines[State.cursor1.line].dataB = string.sub(State.lines[State.cursor1.line].dataB, 1, byte_start-1)..string.sub(State.lines[State.cursor1.line].dataB, byte_end)
          else
            State.lines[State.cursor1.line].dataB = string.sub(State.lines[State.cursor1.line].dataB, 1, byte_start-1)
          end
          -- no change to State.cursor1.pos
        end
      else
        -- refuse to delete past end of side B
      end
    elseif State.cursor1.line < #State.lines then
      if State.lines[State.cursor1.line+1].mode == 'text' then
        -- join lines
        State.lines[State.cursor1.line].data = State.lines[State.cursor1.line].data..State.lines[State.cursor1.line+1].data
        -- delete side B on first line
        State.lines[State.cursor1.line].dataB = State.lines[State.cursor1.line+1].dataB
      end
      table.remove(State.lines, State.cursor1.line+1)
      table.remove(State.line_cache, State.cursor1.line+1)
    end
    Text.clear_screen_line_cache(State, State.cursor1.line)
    schedule_save(State)
    record_undo_event(State, {before=before, after=snapshot(State, State.cursor1.line)})
  --== shortcuts that move the cursor
  elseif chord == 'left' then
    Text.left(State)
    State.selection1 = {}
  elseif chord == 'right' then
    Text.right(State)
    State.selection1 = {}
  elseif chord == 'S-left' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.left(State)
  elseif chord == 'S-right' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.right(State)
  -- C- hotkeys reserved for drawings, so we'll use M-
  elseif chord == 'M-left' then
    Text.word_left(State)
    State.selection1 = {}
  elseif chord == 'M-right' then
    Text.word_right(State)
    State.selection1 = {}
  elseif chord == 'M-S-left' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.word_left(State)
  elseif chord == 'M-S-right' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.word_right(State)
  elseif chord == 'home' then
    Text.start_of_line(State)
    State.selection1 = {}
  elseif chord == 'end' then
    Text.end_of_line(State)
    State.selection1 = {}
  elseif chord == 'S-home' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.start_of_line(State)
  elseif chord == 'S-end' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.end_of_line(State)
  elseif chord == 'up' then
    Text.up(State)
    State.selection1 = {}
  elseif chord == 'down' then
    Text.down(State)
    State.selection1 = {}
  elseif chord == 'S-up' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.up(State)
  elseif chord == 'S-down' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.down(State)
  elseif chord == 'pageup' then
    Text.pageup(State)
    State.selection1 = {}
  elseif chord == 'pagedown' then
    Text.pagedown(State)
    State.selection1 = {}
  elseif chord == 'S-pageup' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.pageup(State)
  elseif chord == 'S-pagedown' then
    if State.selection1.line == nil then
      State.selection1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}
    end
    Text.pagedown(State)
  end
end

function Text.insert_return(State)
  if State.cursor1.pos then
    -- when inserting a newline, move any B side to the new line
    local byte_offset = Text.offset(State.lines[State.cursor1.line].data, State.cursor1.pos)
    table.insert(State.lines, State.cursor1.line+1, {mode='text', data=string.sub(State.lines[State.cursor1.line].data, byte_offset), dataB=State.lines[State.cursor1.line].dataB})
    table.insert(State.line_cache, State.cursor1.line+1, {})
    State.lines[State.cursor1.line].data = string.sub(State.lines[State.cursor1.line].data, 1, byte_offset-1)
    State.lines[State.cursor1.line].dataB = nil
    Text.clear_screen_line_cache(State, State.cursor1.line)
    State.cursor1 = {line=State.cursor1.line+1, pos=1}
  else
    -- disable enter when cursor is on the B side
  end
end

function Text.pageup(State)
--?   print('pageup')
  -- duplicate some logic from love.draw
  local top2 = Text.to2(State, State.screen_top1)
--?   print(App.screen.height)
  local y = App.screen.height - State.line_height
  while y >= State.top do
--?     print(y, top2.line, top2.screen_line, top2.screen_pos)
    if State.screen_top1.line == 1 and State.screen_top1.pos and State.screen_top1.pos == 1 then break end
    if State.lines[State.screen_top1.line].mode == 'text' then
      y = y - State.line_height
    elseif State.lines[State.screen_top1.line].mode == 'drawing' then
      y = y - Drawing_padding_height - Drawing.pixels(State.lines[State.screen_top1.line].h, State.width)
    end
    top2 = Text.previous_screen_line(State, top2)
  end
  State.screen_top1 = Text.to1(State, top2)
  State.cursor1 = {line=State.screen_top1.line, pos=State.screen_top1.pos, posB=State.screen_top1.posB}
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary(State)
--?   print(State.cursor1.line, State.cursor1.pos, State.screen_top1.line, State.screen_top1.pos)
--?   print('pageup end')
end

function Text.pagedown(State)
--?   print('pagedown')
  local bot2 = Text.to2(State, State.screen_bottom1)
  local new_top1 = Text.to1(State, bot2)
  if Text.lt1(State.screen_top1, new_top1) then
    State.screen_top1 = new_top1
  else
    State.screen_top1 = {line=State.screen_bottom1.line, pos=State.screen_bottom1.pos, posB=State.screen_bottom1.posB}
  end
--?   print('setting top to', State.screen_top1.line, State.screen_top1.pos)
  State.cursor1 = {line=State.screen_top1.line, pos=State.screen_top1.pos, posB=State.screen_top1.posB}
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary(State)
--?   print('top now', State.screen_top1.line)
  Text.redraw_all(State)  -- if we're scrolling, reclaim all fragments to avoid memory leaks
--?   print('pagedown end')
end

function Text.up(State)
  assert(State.lines[State.cursor1.line].mode == 'text')
  if State.cursor1.pos then
    Text.upA(State)
  else
    Text.upB(State)
  end
end

function Text.upA(State)
--?   print('up', State.cursor1.line, State.cursor1.pos, State.screen_top1.line, State.screen_top1.pos)
  local screen_line_starting_pos, screen_line_index = Text.pos_at_start_of_screen_line(State, State.cursor1)
  if screen_line_starting_pos == 1 then
--?     print('cursor is at first screen line of its line')
    -- line is done; skip to previous text line
    local new_cursor_line = State.cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if State.lines[new_cursor_line].mode == 'text' then
--?         print('found previous text line')
        State.cursor1 = {line=State.cursor1.line-1, pos=nil}
        Text.populate_screen_line_starting_pos(State, State.cursor1.line)
        -- previous text line found, pick its final screen line
--?         print('has multiple screen lines')
        local screen_line_starting_pos = State.line_cache[State.cursor1.line].screen_line_starting_pos
--?         print(#screen_line_starting_pos)
        screen_line_starting_pos = screen_line_starting_pos[#screen_line_starting_pos]
        local screen_line_starting_byte_offset = Text.offset(State.lines[State.cursor1.line].data, screen_line_starting_pos)
        local s = string.sub(State.lines[State.cursor1.line].data, screen_line_starting_byte_offset)
        State.cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
        break
      end
    end
  else
    -- move up one screen line in current line
    assert(screen_line_index > 1)
    local new_screen_line_starting_pos = State.line_cache[State.cursor1.line].screen_line_starting_pos[screen_line_index-1]
    local new_screen_line_starting_byte_offset = Text.offset(State.lines[State.cursor1.line].data, new_screen_line_starting_pos)
    local s = string.sub(State.lines[State.cursor1.line].data, new_screen_line_starting_byte_offset)
    State.cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
--?     print('cursor pos is now '..tostring(State.cursor1.pos))
  end
  if Text.lt1(State.cursor1, State.screen_top1) then
    local top2 = Text.to2(State, State.screen_top1)
    top2 = Text.previous_screen_line(State, top2)
    State.screen_top1 = Text.to1(State, top2)
  end
end

function Text.upB(State)
  local line_cache = State.line_cache[State.cursor1.line]
  local screen_line_starting_posB, screen_line_indexB = Text.pos_at_start_of_screen_lineB(State, State.cursor1)
  assert(screen_line_indexB >= 1)
  if screen_line_indexB == 1 then
    -- move to A side of previous line
    local new_cursor_line = State.cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if State.lines[new_cursor_line].mode == 'text' then
        State.cursor1 = {line=State.cursor1.line-1, posB=nil}
        Text.populate_screen_line_starting_pos(State, State.cursor1.line)
        local prev_line_cache = State.line_cache[State.cursor1.line]
        local prev_screen_line_starting_pos = prev_line_cache.screen_line_starting_pos[#prev_line_cache.screen_line_starting_pos]
        local prev_screen_line_starting_byte_offset = Text.offset(State.lines[State.cursor1.line].data, prev_screen_line_starting_pos)
        local s = string.sub(State.lines[State.cursor1.line].data, prev_screen_line_starting_byte_offset)
        State.cursor1.pos = prev_screen_line_starting_pos + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
        break
      end
    end
  elseif screen_line_indexB == 2 then
    -- all-B screen-line to potentially A+B screen-line
    local xA = Margin_left + Text.screen_line_width(State, State.cursor1.line, #line_cache.screen_line_starting_pos) + AB_padding
    if State.cursor_x < xA then
      State.cursor1.posB = nil
      Text.populate_screen_line_starting_pos(State, State.cursor1.line)
      local new_screen_line_starting_pos = line_cache.screen_line_starting_pos[#line_cache.screen_line_starting_pos]
      local new_screen_line_starting_byte_offset = Text.offset(State.lines[State.cursor1.line].data, new_screen_line_starting_pos)
      local s = string.sub(State.lines[State.cursor1.line].data, new_screen_line_starting_byte_offset)
      State.cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
    else
      Text.populate_screen_line_starting_posB(State, State.cursor1.line)
      local new_screen_line_starting_posB = line_cache.screen_line_starting_posB[screen_line_indexB-1]
      local new_screen_line_starting_byte_offsetB = Text.offset(State.lines[State.cursor1.line].dataB, new_screen_line_starting_posB)
      local s = string.sub(State.lines[State.cursor1.line].dataB, new_screen_line_starting_byte_offsetB)
      State.cursor1.posB = new_screen_line_starting_posB + Text.nearest_cursor_pos(s, State.cursor_x-xA, State.left) - 1
    end
  else
    assert(screen_line_indexB > 2)
    -- all-B screen-line to all-B screen-line
    Text.populate_screen_line_starting_posB(State, State.cursor1.line)
    local new_screen_line_starting_posB = line_cache.screen_line_starting_posB[screen_line_indexB-1]
    local new_screen_line_starting_byte_offsetB = Text.offset(State.lines[State.cursor1.line].dataB, new_screen_line_starting_posB)
    local s = string.sub(State.lines[State.cursor1.line].dataB, new_screen_line_starting_byte_offsetB)
    State.cursor1.posB = new_screen_line_starting_posB + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
  end
  if Text.lt1(State.cursor1, State.screen_top1) then
    local top2 = Text.to2(State, State.screen_top1)
    top2 = Text.previous_screen_line(State, top2)
    State.screen_top1 = Text.to1(State, top2)
  end
end

-- cursor on final screen line (A or B side) => goes to next screen line on A side
-- cursor on A side => move down one screen line (A side) in current line
-- cursor on B side => move down one screen line (B side) in current line
function Text.down(State)
  assert(State.lines[State.cursor1.line].mode == 'text')
--?   print('down', State.cursor1.line, State.cursor1.pos, State.screen_top1.line, State.screen_top1.pos, State.screen_bottom1.line, State.screen_bottom1.pos)
  if Text.cursor_at_final_screen_line(State) then
    -- line is done, skip to next text line
--?     print('cursor at final screen line of its line')
    local new_cursor_line = State.cursor1.line
    while new_cursor_line < #State.lines do
      new_cursor_line = new_cursor_line+1
      if State.lines[new_cursor_line].mode == 'text' then
        State.cursor1 = {
          line = new_cursor_line,
          pos = Text.nearest_cursor_pos(State.lines[new_cursor_line].data, State.cursor_x, State.left),
        }
--?         print(State.cursor1.pos)
        break
      end
    end
    if State.cursor1.line > State.screen_bottom1.line then
--?       print('screen top before:', State.screen_top1.line, State.screen_top1.pos)
--?       print('scroll up preserving cursor')
      Text.snap_cursor_to_bottom_of_screen(State)
--?       print('screen top after:', State.screen_top1.line, State.screen_top1.pos)
    end
  elseif State.cursor1.pos then
    -- move down one screen line (A side) in current line
    local scroll_down = Text.le1(State.screen_bottom1, State.cursor1)
--?     print('cursor is NOT at final screen line of its line')
    local screen_line_starting_pos, screen_line_index = Text.pos_at_start_of_screen_line(State, State.cursor1)
    Text.populate_screen_line_starting_pos(State, State.cursor1.line)
    local new_screen_line_starting_pos = State.line_cache[State.cursor1.line].screen_line_starting_pos[screen_line_index+1]
--?     print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
    local new_screen_line_starting_byte_offset = Text.offset(State.lines[State.cursor1.line].data, new_screen_line_starting_pos)
    local s = string.sub(State.lines[State.cursor1.line].data, new_screen_line_starting_byte_offset)
    State.cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
--?     print('cursor pos is now', State.cursor1.line, State.cursor1.pos)
    if scroll_down then
--?       print('scroll up preserving cursor')
      Text.snap_cursor_to_bottom_of_screen(State)
--?       print('screen top after:', State.screen_top1.line, State.screen_top1.pos)
    end
  else
    -- move down one screen line (B side) in current line
    local scroll_down = false
    if Text.le1(State.screen_bottom1, State.cursor1) then
      scroll_down = true
    end
    local cursor_line = State.lines[State.cursor1.line]
    local cursor_line_cache = State.line_cache[State.cursor1.line]
    local cursor2 = Text.to2(State, State.cursor1)
    assert(cursor2.screen_lineB < #cursor_line_cache.screen_line_starting_posB)
    local screen_line_starting_posB, screen_line_indexB = Text.pos_at_start_of_screen_lineB(State, State.cursor1)
    Text.populate_screen_line_starting_posB(State, State.cursor1.line)
    local new_screen_line_starting_posB = cursor_line_cache.screen_line_starting_posB[screen_line_indexB+1]
    local new_screen_line_starting_byte_offsetB = Text.offset(cursor_line.dataB, new_screen_line_starting_posB)
    local s = string.sub(cursor_line.dataB, new_screen_line_starting_byte_offsetB)
    State.cursor1.posB = new_screen_line_starting_posB + Text.nearest_cursor_pos(s, State.cursor_x, State.left) - 1
    if scroll_down then
      Text.snap_cursor_to_bottom_of_screen(State)
    end
  end
--?   print('=>', State.cursor1.line, State.cursor1.pos, State.screen_top1.line, State.screen_top1.pos, State.screen_bottom1.line, State.screen_bottom1.pos)
end

function Text.start_of_line(State)
  if State.cursor1.pos then
    State.cursor1.pos = 1
  else
    State.cursor1.posB = 1
  end
  if Text.lt1(State.cursor1, State.screen_top1) then
    State.screen_top1 = {line=State.cursor1.line, pos=State.cursor1.pos, posB=State.cursor1.posB}  -- copy
  end
end

function Text.end_of_line(State)
  if State.cursor1.pos then
    State.cursor1.pos = utf8.len(State.lines[State.cursor1.line].data) + 1
  else
    State.cursor1.posB = utf8.len(State.lines[State.cursor1.line].dataB) + 1
  end
  if Text.cursor_out_of_screen(State) then
    Text.snap_cursor_to_bottom_of_screen(State)
  end
end

function Text.word_left(State)
  -- we can cross the fold, so check side A/B one level down
  Text.skip_whitespace_left(State)
  Text.left(State)
  Text.skip_non_whitespace_left(State)
end

function Text.word_right(State)
  -- we can cross the fold, so check side A/B one level down
  Text.skip_whitespace_right(State)
  Text.right(State)
  Text.skip_non_whitespace_right(State)
  if Text.cursor_out_of_screen(State) then
    Text.snap_cursor_to_bottom_of_screen(State)
  end
end

function Text.skip_whitespace_left(State)
  if State.cursor1.pos then
    Text.skip_whitespace_leftA(State)
  else
    Text.skip_whitespace_leftB(State)
  end
end

function Text.skip_non_whitespace_left(State)
  if State.cursor1.pos then
    Text.skip_non_whitespace_leftA(State)
  else
    Text.skip_non_whitespace_leftB(State)
  end
end

function Text.skip_whitespace_leftA(State)
  while true do
    if State.cursor1.pos == 1 then
      break
    end
    if Text.match(State.lines[State.cursor1.line].data, State.cursor1.pos-1, '%S') then
      break
    end
    Text.left(State)
  end
end

function Text.skip_whitespace_leftB(State)
  while true do
    if State.cursor1.posB == 1 then
      break
    end
    if Text.match(State.lines[State.cursor1.line].dataB, State.cursor1.posB-1, '%S') then
      break
    end
    Text.left(State)
  end
end

function Text.skip_non_whitespace_leftA(State)
  while true do
    if State.cursor1.pos == 1 then
      break
    end
    assert(State.cursor1.pos > 1)
    if Text.match(State.lines[State.cursor1.line].data, State.cursor1.pos-1, '%s') then
      break
    end
    Text.left(State)
  end
end

function Text.skip_non_whitespace_leftB(State)
  while true do
    if State.cursor1.posB == 1 then
      break
    end
    assert(State.cursor1.posB > 1)
    if Text.match(State.lines[State.cursor1.line].dataB, State.cursor1.posB-1, '%s') then
      break
    end
    Text.left(State)
  end
end

function Text.skip_whitespace_right(State)
  if State.cursor1.pos then
    Text.skip_whitespace_rightA(State)
  else
    Text.skip_whitespace_rightB(State)
  end
end

function Text.skip_non_whitespace_right(State)
  if State.cursor1.pos then
    Text.skip_non_whitespace_rightA(State)
  else
    Text.skip_non_whitespace_rightB(State)
  end
end

function Text.skip_whitespace_rightA(State)
  while true do
    if State.cursor1.pos > utf8.len(State.lines[State.cursor1.line].data) then
      break
    end
    if Text.match(State.lines[State.cursor1.line].data, State.cursor1.pos, '%S') then
      break
    end
    Text.right_without_scroll(State)
  end
end

function Text.skip_whitespace_rightB(State)
  while true do
    if State.cursor1.posB > utf8.len(State.lines[State.cursor1.line].dataB) then
      break
    end
    if Text.match(State.lines[State.cursor1.line].dataB, State.cursor1.posB, '%S') then
      break
    end
    Text.right_without_scroll(State)
  end
end

function Text.skip_non_whitespace_rightA(State)
  while true do
    if State.cursor1.pos > utf8.len(State.lines[State.cursor1.line].data) then
      break
    end
    if Text.match(State.lines[State.cursor1.line].data, State.cursor1.pos, '%s') then
      break
    end
    Text.right_without_scroll(State)
  end
end

function Text.skip_non_whitespace_rightB(State)
  while true do
    if State.cursor1.posB > utf8.len(State.lines[State.cursor1.line].dataB) then
      break
    end
    if Text.match(State.lines[State.cursor1.line].dataB, State.cursor1.posB, '%s') then
      break
    end
    Text.right_without_scroll(State)
  end
end

function Text.match(s, pos, pat)
  local start_offset = Text.offset(s, pos)
  assert(start_offset)
  local end_offset = Text.offset(s, pos+1)
  assert(end_offset > start_offset)
  local curr = s:sub(start_offset, end_offset-1)
  return curr:match(pat)
end

function Text.left(State)
  if State.cursor1.pos then
    Text.leftA(State)
  else
    Text.leftB(State)
  end
end

function Text.leftA(State)
  if State.cursor1.pos > 1 then
    State.cursor1.pos = State.cursor1.pos-1
  else
    local new_cursor_line = State.cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if State.lines[new_cursor_line].mode == 'text' then
        State.cursor1 = {
          line = new_cursor_line,
          pos = utf8.len(State.lines[new_cursor_line].data) + 1,
        }
        break
      end
    end
  end
  if Text.lt1(State.cursor1, State.screen_top1) then
    local top2 = Text.to2(State, State.screen_top1)
    top2 = Text.previous_screen_line(State, top2)
    State.screen_top1 = Text.to1(State, top2)
  end
end

function Text.leftB(State)
  if State.cursor1.posB > 1 then
    State.cursor1.posB = State.cursor1.posB-1
  else
    -- overflow back into A side
    State.cursor1.posB = nil
    State.cursor1.pos = utf8.len(State.lines[State.cursor1.line].data) + 1
  end
  if Text.lt1(State.cursor1, State.screen_top1) then
    local top2 = Text.to2(State, State.screen_top1)
    top2 = Text.previous_screen_line(State, top2)
    State.screen_top1 = Text.to1(State, top2)
  end
end

function Text.right(State)
  Text.right_without_scroll(State)
  if Text.cursor_out_of_screen(State) then
    Text.snap_cursor_to_bottom_of_screen(State)
  end
end

function Text.right_without_scroll(State)
  assert(State.lines[State.cursor1.line].mode == 'text')
  if State.cursor1.pos then
    Text.right_without_scrollA(State)
  else
    Text.right_without_scrollB(State)
  end
end

function Text.right_without_scrollA(State)
  if State.cursor1.pos <= utf8.len(State.lines[State.cursor1.line].data) then
    State.cursor1.pos = State.cursor1.pos+1
  else
    local new_cursor_line = State.cursor1.line
    while new_cursor_line <= #State.lines-1 do
      new_cursor_line = new_cursor_line+1
      if State.lines[new_cursor_line].mode == 'text' then
        State.cursor1 = {line=new_cursor_line, pos=1}
        break
      end
    end
  end
end

function Text.right_without_scrollB(State)
  if State.cursor1.posB <= utf8.len(State.lines[State.cursor1.line].dataB) then
    State.cursor1.posB = State.cursor1.posB+1
  else
    -- overflow back into A side
    local new_cursor_line = State.cursor1.line
    while new_cursor_line <= #State.lines-1 do
      new_cursor_line = new_cursor_line+1
      if State.lines[new_cursor_line].mode == 'text' then
        State.cursor1 = {line=new_cursor_line, pos=1}
        break
      end
    end
  end
end

function Text.pos_at_start_of_screen_line(State, loc1)
  Text.populate_screen_line_starting_pos(State, loc1.line)
  local line_cache = State.line_cache[loc1.line]
  for i=#line_cache.screen_line_starting_pos,1,-1 do
    local spos = line_cache.screen_line_starting_pos[i]
    if spos <= loc1.pos then
      return spos,i
    end
  end
  assert(false)
end

function Text.pos_at_start_of_screen_lineB(State, loc1)
  Text.populate_screen_line_starting_pos(State, loc1.line)
  local line_cache = State.line_cache[loc1.line]
  local x = Margin_left + Text.screen_line_width(State, loc1.line, #line_cache.screen_line_starting_pos) + AB_padding
  Text.populate_screen_line_starting_posB(State, loc1.line, x)
  for i=#line_cache.screen_line_starting_posB,1,-1 do
    local sposB = line_cache.screen_line_starting_posB[i]
    if sposB <= loc1.posB then
      return sposB,i
    end
  end
  assert(false)
end

function Text.cursor_at_final_screen_line(State)
  Text.populate_screen_line_starting_pos(State, State.cursor1.line)
  local line = State.lines[State.cursor1.line]
  local screen_lines = State.line_cache[State.cursor1.line].screen_line_starting_pos
--?   print(screen_lines[#screen_lines], State.cursor1.pos)
  if (not State.expanded and not line.expanded) or
      line.dataB == nil then
    return screen_lines[#screen_lines] <= State.cursor1.pos
  end
  if State.cursor1.pos then
    -- ignore B side
    return screen_lines[#screen_lines] <= State.cursor1.pos
  end
  assert(State.cursor1.posB)
  local line_cache = State.line_cache[State.cursor1.line]
  local x = Margin_left + Text.screen_line_width(State, State.cursor1.line, #line_cache.screen_line_starting_pos) + AB_padding
  Text.populate_screen_line_starting_posB(State, State.cursor1.line, x)
  local screen_lines = State.line_cache[State.cursor1.line].screen_line_starting_posB
  return screen_lines[#screen_lines] <= State.cursor1.posB
end

function Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary(State)
  local y = State.top
  while State.cursor1.line <= #State.lines do
    if State.lines[State.cursor1.line].mode == 'text' then
      break
    end
--?     print('cursor skips', State.cursor1.line)
    y = y + Drawing_padding_height + Drawing.pixels(State.lines[State.cursor1.line].h, State.width)
    State.cursor1.line = State.cursor1.line + 1
  end
  -- hack: insert a text line at bottom of file if necessary
  if State.cursor1.line > #State.lines then
    assert(State.cursor1.line == #State.lines+1)
    table.insert(State.lines, {mode='text', data=''})
    table.insert(State.line_cache, {})
  end
--?   print(y, App.screen.height, App.screen.height-State.line_height)
  if y > App.screen.height - State.line_height then
--?     print('scroll up')
    Text.snap_cursor_to_bottom_of_screen(State)
  end
end

-- should never modify State.cursor1
function Text.snap_cursor_to_bottom_of_screen(State)
--?   print('to2:', State.cursor1.line, State.cursor1.pos, State.cursor1.posB)
  local top2 = Text.to2(State, State.cursor1)
--?   print('to2: =>', top2.line, top2.screen_line, top2.screen_pos, top2.screen_lineB, top2.screen_posB)
  -- slide to start of screen line
  if top2.screen_pos then
    top2.screen_pos = 1
  else
    assert(top2.screen_posB)
    top2.screen_posB = 1
  end
--?   print('snap', State.screen_top1.line, State.screen_top1.pos, State.screen_top1.posB, State.cursor1.line, State.cursor1.pos, State.cursor1.posB, State.screen_bottom1.line, State.screen_bottom1.pos, State.screen_bottom1.posB)
--?   print('cursor pos '..tostring(State.cursor1.pos)..' is on the #'..tostring(top2.screen_line)..' screen line down')
  local y = App.screen.height - State.line_height
  -- duplicate some logic from love.draw
  while true do
--?     print(y, 'top2:', State.lines[top2.line].data, top2.line, top2.screen_line, top2.screen_pos, top2.screen_lineB, top2.screen_posB)
    if top2.line == 1 and top2.screen_line == 1 then break end
    if top2.screen_line > 1 or State.lines[top2.line-1].mode == 'text' then
      local h = State.line_height
      if y - h < State.top then
        break
      end
      y = y - h
    else
      assert(top2.line > 1)
      assert(State.lines[top2.line-1].mode == 'drawing')
      -- We currently can't draw partial drawings, so either skip it entirely
      -- or not at all.
      local h = Drawing_padding_height + Drawing.pixels(State.lines[top2.line-1].h, State.width)
      if y - h < State.top then
        break
      end
--?       print('skipping drawing of height', h)
      y = y - h
    end
    top2 = Text.previous_screen_line(State, top2)
  end
--?   print('top2 finally:', top2.line, top2.screen_line, top2.screen_pos)
  State.screen_top1 = Text.to1(State, top2)
--?   print('top1 finally:', State.screen_top1.line, State.screen_top1.pos)
--?   print('snap =>', State.screen_top1.line, State.screen_top1.pos, State.screen_top1.posB, State.cursor1.line, State.cursor1.pos, State.cursor1.posB, State.screen_bottom1.line, State.screen_bottom1.pos, State.screen_bottom1.posB)
  Text.redraw_all(State)  -- if we're scrolling, reclaim all fragments to avoid memory leaks
end

function Text.in_line(State, line_index, x,y)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  if line_cache.starty == nil then return false end  -- outside current page
  if y < line_cache.starty then return false end
  local num_screen_lines = 0
  if line_cache.startpos then
    Text.populate_screen_line_starting_pos(State, line_index)
    num_screen_lines = num_screen_lines + #line_cache.screen_line_starting_pos - Text.screen_line_index(line_cache.screen_line_starting_pos, line_cache.startpos) + 1
  end
--?   print('#screenlines after A', num_screen_lines)
  if line.dataB and (State.expanded or line.expanded) then
    local x = Margin_left + Text.screen_line_width(State, line_index, #line_cache.screen_line_starting_pos) + AB_padding
    Text.populate_screen_line_starting_posB(State, line_index, x)
--?     print('B:', x, #line_cache.screen_line_starting_posB)
    if line_cache.startposB then
      num_screen_lines = num_screen_lines + #line_cache.screen_line_starting_posB - Text.screen_line_indexB(line_cache.screen_line_starting_posB, line_cache.startposB)  -- no +1; first screen line of B side overlaps with A side
    else
      num_screen_lines = num_screen_lines + #line_cache.screen_line_starting_posB - Text.screen_line_indexB(line_cache.screen_line_starting_posB, 1)  -- no +1; first screen line of B side overlaps with A side
    end
  end
--?   print('#screenlines after B', num_screen_lines)
  return y < line_cache.starty + State.line_height*num_screen_lines
end

-- convert mx,my in pixels to schema-1 coordinates
-- returns: pos, posB
-- scenarios:
--   line without B side
--   line with B side collapsed
--   line with B side expanded
--   line starting rendering in A side (startpos ~= nil)
--   line starting rendering in B side (startposB ~= nil)
--   my on final screen line of A side
--     mx to right of A side with no B side
--     mx to right of A side but left of B side
--     mx to right of B side
-- preconditions:
--  startpos xor startposB
--  expanded -> dataB
function Text.to_pos_on_line(State, line_index, mx, my)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  assert(my >= line_cache.starty)
  -- duplicate some logic from Text.draw
  local y = line_cache.starty
--?   print('click', line_index, my, 'with line starting at', y, #line_cache.screen_line_starting_pos)  -- , #line_cache.screen_line_starting_posB)
  if line_cache.startpos then
    local start_screen_line_index = Text.screen_line_index(line_cache.screen_line_starting_pos, line_cache.startpos)
    for screen_line_index = start_screen_line_index,#line_cache.screen_line_starting_pos do
      local screen_line_starting_pos = line_cache.screen_line_starting_pos[screen_line_index]
      local screen_line_starting_byte_offset = Text.offset(line.data, screen_line_starting_pos)
--?       print('iter', y, screen_line_index, screen_line_starting_pos, string.sub(line.data, screen_line_starting_byte_offset))
      local nexty = y + State.line_height
      if my < nexty then
        -- On all wrapped screen lines but the final one, clicks past end of
        -- line position cursor on final character of screen line.
        -- (The final screen line positions past end of screen line as always.)
        if screen_line_index < #line_cache.screen_line_starting_pos and mx > State.left + Text.screen_line_width(State, line_index, screen_line_index) then
--?           print('past end of non-final line; return')
          return line_cache.screen_line_starting_pos[screen_line_index+1]-1
        end
        local s = string.sub(line.data, screen_line_starting_byte_offset)
--?         print('return', mx, Text.nearest_cursor_pos(s, mx, State.left), '=>', screen_line_starting_pos + Text.nearest_cursor_pos(s, mx, State.left) - 1)
        local screen_line_posA = Text.nearest_cursor_pos(s, mx, State.left)
        if line.dataB == nil then
          -- no B side
          return screen_line_starting_pos + screen_line_posA - 1
        end
        if not State.expanded and not line.expanded then
          -- B side is not expanded
          return screen_line_starting_pos + screen_line_posA - 1
        end
        local lenA = utf8.len(s)
        if screen_line_posA < lenA then
          -- mx is within A side
          return screen_line_starting_pos + screen_line_posA - 1
        end
        local max_xA = State.left+Text.x(s, lenA+1)
        if mx < max_xA + AB_padding then
          -- mx is in the space between A and B side
          return screen_line_starting_pos + screen_line_posA - 1
        end
        mx = mx - max_xA - AB_padding
        local screen_line_posB = Text.nearest_cursor_pos(line.dataB, mx, --[[no left margin]] 0)
        return nil, screen_line_posB
      end
      y = nexty
    end
  end
  -- look in screen lines composed entirely of the B side
  assert(State.expanded or line.expanded)
  local start_screen_line_indexB
  if line_cache.startposB then
    start_screen_line_indexB = Text.screen_line_indexB(line_cache.screen_line_starting_posB, line_cache.startposB)
  else
    start_screen_line_indexB = 2  -- skip the first line of side B, which we checked above
  end
  for screen_line_indexB = start_screen_line_indexB,#line_cache.screen_line_starting_posB do
    local screen_line_starting_posB = line_cache.screen_line_starting_posB[screen_line_indexB]
    local screen_line_starting_byte_offsetB = Text.offset(line.dataB, screen_line_starting_posB)
--?     print('iter2', y, screen_line_indexB, screen_line_starting_posB, string.sub(line.dataB, screen_line_starting_byte_offsetB))
    local nexty = y + State.line_height
    if my < nexty then
      -- On all wrapped screen lines but the final one, clicks past end of
      -- line position cursor on final character of screen line.
      -- (The final screen line positions past end of screen line as always.)
--?       print('aa', mx, State.left, Text.screen_line_widthB(State, line_index, screen_line_indexB))
      if screen_line_indexB < #line_cache.screen_line_starting_posB and mx > State.left + Text.screen_line_widthB(State, line_index, screen_line_indexB) then
--?         print('past end of non-final line; return')
        return nil, line_cache.screen_line_starting_posB[screen_line_indexB+1]-1
      end
      local s = string.sub(line.dataB, screen_line_starting_byte_offsetB)
--?       print('return', mx, Text.nearest_cursor_pos(s, mx, State.left), '=>', screen_line_starting_posB + Text.nearest_cursor_pos(s, mx, State.left) - 1)
      return nil, screen_line_starting_posB + Text.nearest_cursor_pos(s, mx, State.left) - 1
    end
    y = nexty
  end
  assert(false)
end

function Text.screen_line_width(State, line_index, i)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  local start_pos = line_cache.screen_line_starting_pos[i]
  local start_offset = Text.offset(line.data, start_pos)
  local screen_line
  if i < #line_cache.screen_line_starting_pos then
    local past_end_pos = line_cache.screen_line_starting_pos[i+1]
    local past_end_offset = Text.offset(line.data, past_end_pos)
    screen_line = string.sub(line.data, start_offset, past_end_offset-1)
  else
    screen_line = string.sub(line.data, start_pos)
  end
  local screen_line_text = App.newText(love.graphics.getFont(), screen_line)
  return App.width(screen_line_text)
end

function Text.screen_line_widthB(State, line_index, i)
  local line = State.lines[line_index]
  local line_cache = State.line_cache[line_index]
  local start_posB = line_cache.screen_line_starting_posB[i]
  local start_offsetB = Text.offset(line.dataB, start_posB)
  local screen_line
  if i < #line_cache.screen_line_starting_posB then
--?     print('non-final', i)
    local past_end_posB = line_cache.screen_line_starting_posB[i+1]
    local past_end_offsetB = Text.offset(line.dataB, past_end_posB)
--?     print('between', start_offsetB, past_end_offsetB)
    screen_line = string.sub(line.dataB, start_offsetB, past_end_offsetB-1)
  else
--?     print('final', i)
--?     print('after', start_offsetB)
    screen_line = string.sub(line.dataB, start_offsetB)
  end
  local screen_line_text = App.newText(love.graphics.getFont(), screen_line)
--?   local result = App.width(screen_line_text)
--?   print('=>', result)
--?   return result
  return App.width(screen_line_text)
end

function Text.screen_line_index(screen_line_starting_pos, pos)
  for i = #screen_line_starting_pos,1,-1 do
    if screen_line_starting_pos[i] <= pos then
      return i
    end
  end
end

function Text.screen_line_indexB(screen_line_starting_posB, posB)
  if posB == nil then
    return 0
  end
  assert(screen_line_starting_posB)
  for i = #screen_line_starting_posB,1,-1 do
    if screen_line_starting_posB[i] <= posB then
      return i
    end
  end
end

-- convert x pixel coordinate to pos
-- oblivious to wrapping
-- result: 1 to len+1
function Text.nearest_cursor_pos(line, x, left)
  if x < left then
    return 1
  end
  local len = utf8.len(line)
  local max_x = left+Text.x(line, len+1)
  if x > max_x then
    return len+1
  end
  local leftpos, rightpos = 1, len+1
--?   print('-- nearest', x)
  while true do
--?     print('nearest', x, '^'..line..'$', leftpos, rightpos)
    if leftpos == rightpos then
      return leftpos
    end
    local curr = math.floor((leftpos+rightpos)/2)
    local currxmin = left+Text.x(line, curr)
    local currxmax = left+Text.x(line, curr+1)
--?     print('nearest', x, leftpos, rightpos, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      if x-currxmin < currxmax-x then
        return curr
      else
        return curr+1
      end
    end
    if leftpos >= rightpos-1 then
      return rightpos
    end
    if currxmin > x then
      rightpos = curr
    else
      leftpos = curr
    end
  end
  assert(false)
end

-- return the nearest index of line (in utf8 code points) which lies entirely
-- within x pixels of the left margin
-- result: 0 to len+1
function Text.nearest_pos_less_than(line, x)
--?   print('', '-- nearest_pos_less_than', line, x)
  local len = utf8.len(line)
  local max_x = Text.x_after(line, len)
  if x > max_x then
    return len+1
  end
  local left, right = 0, len+1
  while true do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.x_after(line, curr+1)
    local currxmax = Text.x_after(line, curr+2)
--?     print('', x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      return curr
    end
    if left >= right-1 then
      return left
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  assert(false)
end

function Text.x_after(s, pos)
  local offset = Text.offset(s, math.min(pos+1, #s+1))
  local s_before = s:sub(1, offset-1)
--?   print('^'..s_before..'$')
  local text_before = App.newText(love.graphics.getFont(), s_before)
  return App.width(text_before)
end

function Text.x(s, pos)
  local offset = Text.offset(s, pos)
  local s_before = s:sub(1, offset-1)
  local text_before = App.newText(love.graphics.getFont(), s_before)
  return App.width(text_before)
end

function Text.to2(State, loc1)
  if State.lines[loc1.line].mode == 'drawing' then
    return {line=loc1.line, screen_line=1, screen_pos=1}
  end
  if loc1.pos then
    return Text.to2A(State, loc1)
  else
    return Text.to2B(State, loc1)
  end
end

function Text.to2A(State, loc1)
  local result = {line=loc1.line}
  local line_cache = State.line_cache[loc1.line]
  Text.populate_screen_line_starting_pos(State, loc1.line)
  for i=#line_cache.screen_line_starting_pos,1,-1 do
    local spos = line_cache.screen_line_starting_pos[i]
    if spos <= loc1.pos then
      result.screen_line = i
      result.screen_pos = loc1.pos - spos + 1
      break
    end
  end
  assert(result.screen_pos)
  return result
end

function Text.to2B(State, loc1)
  local result = {line=loc1.line}
  local line_cache = State.line_cache[loc1.line]
  Text.populate_screen_line_starting_pos(State, loc1.line)
  local x = Margin_left + Text.screen_line_width(State, loc1.line, #line_cache.screen_line_starting_pos) + AB_padding
  Text.populate_screen_line_starting_posB(State, loc1.line, x)
  for i=#line_cache.screen_line_starting_posB,1,-1 do
    local sposB = line_cache.screen_line_starting_posB[i]
    if sposB <= loc1.posB then
      result.screen_lineB = i
      result.screen_posB = loc1.posB - sposB + 1
      break
    end
  end
  assert(result.screen_posB)
  return result
end

function Text.to1(State, loc2)
  if loc2.screen_pos then
    return Text.to1A(State, loc2)
  else
    return Text.to1B(State, loc2)
  end
end

function Text.to1A(State, loc2)
  local result = {line=loc2.line, pos=loc2.screen_pos}
  if loc2.screen_line > 1 then
    result.pos = State.line_cache[loc2.line].screen_line_starting_pos[loc2.screen_line] + loc2.screen_pos - 1
  end
  return result
end

function Text.to1B(State, loc2)
  local result = {line=loc2.line, posB=loc2.screen_posB}
  if loc2.screen_lineB > 1 then
    result.posB = State.line_cache[loc2.line].screen_line_starting_posB[loc2.screen_lineB] + loc2.screen_posB - 1
  end
  return result
end

function Text.lt1(a, b)
  if a.line < b.line then
    return true
  end
  if a.line > b.line then
    return false
  end
  -- A side < B side
  if a.pos and not b.pos then
    return true
  end
  if not a.pos and b.pos then
    return false
  end
  if a.pos then
    return a.pos < b.pos
  else
    return a.posB < b.posB
  end
end

function Text.le1(a, b)
  return eq(a, b) or Text.lt1(a, b)
end

function Text.offset(s, pos1)
  if pos1 == 1 then return 1 end
  local result = utf8.offset(s, pos1)
  if result == nil then
    print(pos1, #s, s)
  end
  assert(result)
  return result
end

function Text.previous_screen_line(State, loc2)
  if loc2.screen_pos then
    return Text.previous_screen_lineA(State, loc2)
  else
    return Text.previous_screen_lineB(State, loc2)
  end
end

function Text.previous_screen_lineA(State, loc2)
  if loc2.screen_line > 1 then
    return {line=loc2.line, screen_line=loc2.screen_line-1, screen_pos=1}
  elseif loc2.line == 1 then
    return loc2
  else
    Text.populate_screen_line_starting_pos(State, loc2.line-1)
    if State.lines[loc2.line-1].dataB == nil or
        (not State.expanded and not State.lines[loc2.line-1].expanded) then
--?       print('c1', loc2.line-1, State.lines[loc2.line-1].data, '==', State.lines[loc2.line-1].dataB, State.line_cache[loc2.line-1].fragmentsB)
      return {line=loc2.line-1, screen_line=#State.line_cache[loc2.line-1].screen_line_starting_pos, screen_pos=1}
    end
    -- try to switch to B
    local prev_line_cache = State.line_cache[loc2.line-1]
    local x = Margin_left + Text.screen_line_width(State, loc2.line-1, #prev_line_cache.screen_line_starting_pos) + AB_padding
    Text.populate_screen_line_starting_posB(State, loc2.line-1, x)
    local screen_line_starting_posB = State.line_cache[loc2.line-1].screen_line_starting_posB
--?     print('c', loc2.line-1, State.lines[loc2.line-1].data, '==', State.lines[loc2.line-1].dataB, '==', #screen_line_starting_posB, 'starting from x', x)
    if #screen_line_starting_posB > 1 then
--?       print('c2')
      return {line=loc2.line-1, screen_lineB=#State.line_cache[loc2.line-1].screen_line_starting_posB, screen_posB=1}
    else
--?       print('c3')
      -- if there's only one screen line, assume it overlaps with A, so remain in A
      return {line=loc2.line-1, screen_line=#State.line_cache[loc2.line-1].screen_line_starting_pos, screen_pos=1}
    end
  end
end

function Text.previous_screen_lineB(State, loc2)
  if loc2.screen_lineB > 2 then  -- first screen line of B side overlaps with A side
    return {line=loc2.line, screen_lineB=loc2.screen_lineB-1, screen_posB=1}
  else
    -- switch to A side
    -- TODO: handle case where fold lands precisely at end of a new screen-line
    return {line=loc2.line, screen_line=#State.line_cache[loc2.line].screen_line_starting_pos, screen_pos=1}
  end
end

-- resize helper
function Text.tweak_screen_top_and_cursor(State)
  if State.screen_top1.pos == 1 then return end
  Text.populate_screen_line_starting_pos(State, State.screen_top1.line)
  local line = State.lines[State.screen_top1.line]
  local line_cache = State.line_cache[State.screen_top1.line]
  for i=2,#line_cache.screen_line_starting_pos do
    local pos = line_cache.screen_line_starting_pos[i]
    if pos == State.screen_top1.pos then
      break
    end
    if pos > State.screen_top1.pos then
      -- make sure screen top is at start of a screen line
      local prev = line_cache.screen_line_starting_pos[i-1]
      if State.screen_top1.pos - prev < pos - State.screen_top1.pos then
        State.screen_top1.pos = prev
      else
        State.screen_top1.pos = pos
      end
      break
    end
  end
  -- make sure cursor is on screen
  if Text.lt1(State.cursor1, State.screen_top1) then
    State.cursor1 = {line=State.screen_top1.line, pos=State.screen_top1.pos}
  elseif State.cursor1.line >= State.screen_bottom1.line then
--?     print('too low')
    if Text.cursor_out_of_screen(State) then
--?       print('tweak')
      local pos,posB = Text.to_pos_on_line(State, State.screen_bottom1.line, State.right-5, App.screen.height-5)
      State.cursor1 = {line=State.screen_bottom1.line, pos=pos, posB=posB}
    end
  end
end

-- slightly expensive since it redraws the screen
function Text.cursor_out_of_screen(State)
  App.draw()
  return State.cursor_y == nil
  -- this approach is cheaper and almost works, except on the final screen
  -- where file ends above bottom of screen
--?   local botpos = Text.pos_at_start_of_screen_line(State, State.cursor1)
--?   local botline1 = {line=State.cursor1.line, pos=botpos}
--?   return Text.lt1(State.screen_bottom1, botline1)
end

function source.link_exists(State, filename)
  if State.link_cache == nil then
    State.link_cache = {}
  end
  if State.link_cache[filename] == nil then
    State.link_cache[filename] = file_exists(filename)
  end
  return State.link_cache[filename]
end

function Text.redraw_all(State)
--?   print('clearing fragments')
  State.line_cache = {}
  for i=1,#State.lines do
    State.line_cache[i] = {}
  end
  State.link_cache = {}
end

function Text.clear_screen_line_cache(State, line_index)
  State.line_cache[line_index].fragments = nil
  State.line_cache[line_index].fragmentsB = nil
  State.line_cache[line_index].screen_line_starting_pos = nil
  State.line_cache[line_index].screen_line_starting_posB = nil
end

function trim(s)
  return s:gsub('^%s+', ''):gsub('%s+$', '')
end

function ltrim(s)
  return s:gsub('^%s+', '')
end

function rtrim(s)
  return s:gsub('%s+$', '')
end

function starts_with(s, sub)
  return s:find(sub, 1, --[[no escapes]] true) == 1
end

function ends_with(s, sub)
  return s:reverse():find(sub:reverse(), 1, --[[no escapes]] true) == 1
end
