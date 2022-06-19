-- text editor, particularly text drawing, horizontal wrap, vertical scrolling
Text = {}

local utf8 = require 'utf8'

require 'search'
require 'select'
require 'undo'
require 'text_tests'

-- return values:
--  y coordinate drawn until in px
--  position of start of final screen line drawn
function Text.draw(line, line_width, line_index)
--?   print('text.draw', line_index)
  love.graphics.setColor(0,0,0)
--?   love.graphics.line(Line_width,0, Line_width,App.screen.height)
  -- wrap long lines
  local x = Margin_left
  local y = line.y
  local pos = 1
  local screen_line_starting_pos = 1
  if line.fragments == nil then
    Text.compute_fragments(line, line_width)
  end
  Text.populate_screen_line_starting_pos(line_index)
--?   print('--')
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = App.width(frag_text)
    local frag_len = utf8.len(frag)
--?     local s=tostring
--?     print('('..s(x)..','..s(y)..') '..frag..'('..s(frag_width)..' vs '..s(line_width)..') '..s(line_index)..' vs '..s(Screen_top1.line)..'; '..s(pos)..' vs '..s(Screen_top1.pos)..'; bottom: '..s(Screen_bottom1.line)..'/'..s(Screen_bottom1.pos))
    if x + frag_width > line_width then
      assert(x > Margin_left)  -- no overfull lines
      -- update y only after drawing the first screen line of screen top
      if Text.lt1(Screen_top1, {line=line_index, pos=pos}) then
        y = y + Line_height
        if y + Line_height > App.screen.height then
--?           print('b', y, App.screen.height, '=>', screen_line_starting_pos)
          return y, screen_line_starting_pos
        end
        screen_line_starting_pos = pos
--?         print('text: new screen line', y, App.screen.height, screen_line_starting_pos)
      end
      x = Margin_left
    end
--?     print('checking to draw', pos, Screen_top1.pos)
    -- don't draw text above screen top
    if Text.le1(Screen_top1, {line=line_index, pos=pos}) then
      if Selection1.line then
        local lo, hi = Text.clip_selection(line_index, pos, pos+frag_len)
        Text.draw_highlight(line, x,y, pos, lo,hi)
      end
--?       print('drawing '..frag)
      App.screen.draw(frag_text, x,y)
    end
    -- render cursor if necessary
    if line_index == Cursor1.line then
      if pos <= Cursor1.pos and pos + frag_len > Cursor1.pos then
        if Search_term then
          if Lines[Cursor1.line].data:sub(Cursor1.pos, Cursor1.pos+utf8.len(Search_term)-1) == Search_term then
            local lo_px = Text.draw_highlight(line, x,y, pos, Cursor1.pos, Cursor1.pos+utf8.len(Search_term))
            love.graphics.setColor(0,0,0)
            love.graphics.print(Search_term, x+lo_px,y)
          end
        else
          Text.draw_cursor(x+Text.x(frag, Cursor1.pos-pos+1), y)
        end
      end
    end
    x = x + frag_width
    pos = pos + frag_len
  end
  if Search_term == nil then
    if line_index == Cursor1.line and Cursor1.pos == pos then
      Text.draw_cursor(x, y)
    end
  end
  return y, screen_line_starting_pos
end
-- manual tests:
--  draw with small line_width of 100

function Text.draw_cursor(x, y)
  -- blink every 0.5s
  if math.floor(Cursor_time*2)%2 == 0 then
    love.graphics.setColor(1,0,0)
    love.graphics.rectangle('fill', x,y, 3,Line_height)
    love.graphics.setColor(0,0,0)
  end
  Cursor_x = x
  Cursor_y = y+Line_height
end

function Text.compute_fragments(line, line_width)
--?   print('compute_fragments', line_width)
  line.fragments = {}
  local x = Margin_left
  -- try to wrap at word boundaries
  for frag in line.data:gmatch('%S*%s*') do
    local frag_text = App.newText(love.graphics.getFont(), frag)
    local frag_width = App.width(frag_text)
--?     print('x: '..tostring(x)..'; '..tostring(line_width-x)..'px to go')
--?     print('frag: ^'..frag..'$ is '..tostring(frag_width)..'px wide')
    if x + frag_width > line_width then
      while x + frag_width > line_width do
--?         print(x, frag, frag_width, line_width)
        if x < 0.8*line_width then
--?           print(frag, x, frag_width, line_width)
          -- long word; chop it at some letter
          -- We're not going to reimplement TeX here.
          local bpos = Text.nearest_pos_less_than(frag, line_width - x)
          assert(bpos > 0)  -- avoid infinite loop when window is too narrow
          local boffset = Text.offset(frag, bpos+1)  -- byte _after_ bpos
--?           print('space for '..tostring(bpos)..' graphemes, '..tostring(boffset)..' bytes')
          local frag1 = string.sub(frag, 1, boffset-1)
          local frag1_text = App.newText(love.graphics.getFont(), frag1)
          local frag1_width = App.width(frag1_text)
--?           print(frag, x, frag1_width, line_width)
          assert(x + frag1_width <= line_width)
--?           print('inserting '..frag1..' of width '..tostring(frag1_width)..'px')
          table.insert(line.fragments, {data=frag1, text=frag1_text})
          frag = string.sub(frag, boffset)
          frag_text = App.newText(love.graphics.getFont(), frag)
          frag_width = App.width(frag_text)
        end
        x = Margin_left  -- new line
      end
    end
    if #frag > 0 then
--?       print('inserting '..frag..' of width '..tostring(frag_width)..'px')
      table.insert(line.fragments, {data=frag, text=frag_text})
    end
    x = x + frag_width
  end
end

function Text.textinput(t)
  if App.mouse_down(1) then return end
  if App.ctrl_down() or App.alt_down() or App.cmd_down() then return end
  if Selection1.line then
    Text.delete_selection()
  end
  local before = snapshot(Cursor1.line)
--?   print(Screen_top1.line, Screen_top1.pos, Cursor1.line, Cursor1.pos, Screen_bottom1.line, Screen_bottom1.pos)
  Text.insert_at_cursor(t)
  if Cursor_y >= App.screen.height - Line_height then
    Text.populate_screen_line_starting_pos(Cursor1.line)
    Text.snap_cursor_to_bottom_of_screen()
--?     print('=>', Screen_top1.line, Screen_top1.pos, Cursor1.line, Cursor1.pos, Screen_bottom1.line, Screen_bottom1.pos)
  end
  record_undo_event({before=before, after=snapshot(Cursor1.line)})
end

function Text.insert_at_cursor(t)
  local byte_offset = Text.offset(Lines[Cursor1.line].data, Cursor1.pos)
  Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset-1)..t..string.sub(Lines[Cursor1.line].data, byte_offset)
  Lines[Cursor1.line].fragments = nil
  Lines[Cursor1.line].screen_line_starting_pos = nil
  Cursor1.pos = Cursor1.pos+1
end

-- Don't handle any keys here that would trigger love.textinput above.
function Text.keychord_pressed(chord)
--?   print('chord', chord, Selection1.line, Selection1.pos)
  --== shortcuts that mutate text
  if chord == 'return' then
    local before_line = Cursor1.line
    local before = snapshot(before_line)
    Text.insert_return()
    if (Cursor_y + Line_height) > App.screen.height then
      Text.snap_cursor_to_bottom_of_screen()
    end
    schedule_save()
    record_undo_event({before=before, after=snapshot(before_line, Cursor1.line)})
  elseif chord == 'tab' then
    local before = snapshot(Cursor1.line)
--?     print(Screen_top1.line, Screen_top1.pos, Cursor1.line, Cursor1.pos, Screen_bottom1.line, Screen_bottom1.pos)
    Text.insert_at_cursor('\t')
    if Cursor_y >= App.screen.height - Line_height then
      Text.populate_screen_line_starting_pos(Cursor1.line)
      Text.snap_cursor_to_bottom_of_screen()
--?       print('=>', Screen_top1.line, Screen_top1.pos, Cursor1.line, Cursor1.pos, Screen_bottom1.line, Screen_bottom1.pos)
    end
    schedule_save()
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  elseif chord == 'backspace' then
    if Selection1.line then
      Text.delete_selection()
      schedule_save()
      return
    end
    local before
    if Cursor1.pos > 1 then
      before = snapshot(Cursor1.line)
      local byte_start = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos-1)
      local byte_end = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
      if byte_start then
        if byte_end then
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)..string.sub(Lines[Cursor1.line].data, byte_end)
        else
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)
        end
        Lines[Cursor1.line].fragments = nil
        Cursor1.pos = Cursor1.pos-1
      end
    elseif Cursor1.line > 1 then
      before = snapshot(Cursor1.line-1, Cursor1.line)
      if Lines[Cursor1.line-1].mode == 'drawing' then
        table.remove(Lines, Cursor1.line-1)
      else
        -- join lines
        Cursor1.pos = utf8.len(Lines[Cursor1.line-1].data)+1
        Lines[Cursor1.line-1].data = Lines[Cursor1.line-1].data..Lines[Cursor1.line].data
        Lines[Cursor1.line-1].fragments = nil
        table.remove(Lines, Cursor1.line)
      end
      Cursor1.line = Cursor1.line-1
    end
    if Text.lt1(Cursor1, Screen_top1) then
      local top2 = Text.to2(Screen_top1)
      top2 = Text.previous_screen_line(top2)
      Screen_top1 = Text.to1(top2)
      Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
    end
    assert(Text.le1(Screen_top1, Cursor1))
    schedule_save()
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  elseif chord == 'delete' then
    if Selection1.line then
      Text.delete_selection()
      schedule_save()
      return
    end
    local before
    if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
      before = snapshot(Cursor1.line)
    else
      before = snapshot(Cursor1.line, Cursor1.line+1)
    end
    if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
      local byte_start = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
      local byte_end = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos+1)
      if byte_start then
        if byte_end then
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)..string.sub(Lines[Cursor1.line].data, byte_end)
        else
          Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_start-1)
        end
        Lines[Cursor1.line].fragments = nil
        -- no change to Cursor1.pos
      end
    elseif Cursor1.line < #Lines then
      if Lines[Cursor1.line+1].mode == 'drawing' then
        table.remove(Lines, Cursor1.line+1)
      else
        -- join lines
        Lines[Cursor1.line].data = Lines[Cursor1.line].data..Lines[Cursor1.line+1].data
        Lines[Cursor1.line].fragments = nil
        table.remove(Lines, Cursor1.line+1)
      end
    end
    schedule_save()
    record_undo_event({before=before, after=snapshot(Cursor1.line)})
  --== shortcuts that move the cursor
  elseif chord == 'left' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.left()
  elseif chord == 'right' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.right()
  elseif chord == 'S-left' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.left()
  elseif chord == 'S-right' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.right()
  -- C- hotkeys reserved for drawings, so we'll use M-
  elseif chord == 'M-left' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.word_left()
  elseif chord == 'M-right' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.word_right()
  elseif chord == 'M-S-left' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.word_left()
  elseif chord == 'M-S-right' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.word_right()
  elseif chord == 'home' then
    if Selection1.line then
      Selection1 = {}
    end
    Cursor1.pos = 1
  elseif chord == 'end' then
    if Selection1.line then
      Selection1 = {}
    end
    Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
  elseif chord == 'S-home' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Cursor1.pos = 1
  elseif chord == 'S-end' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
  elseif chord == 'up' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.up()
  elseif chord == 'down' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.down()
  elseif chord == 'S-up' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.up()
  elseif chord == 'S-down' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.down()
  elseif chord == 'pageup' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.pageup()
  elseif chord == 'pagedown' then
    if Selection1.line then
      Selection1 = {}
    end
    Text.pagedown()
  elseif chord == 'S-pageup' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.pageup()
  elseif chord == 'S-pagedown' then
    if Selection1.line == nil then
      Selection1 = {line=Cursor1.line, pos=Cursor1.pos}
    end
    Text.pagedown()
  end
end

function Text.insert_return()
  local byte_offset = Text.offset(Lines[Cursor1.line].data, Cursor1.pos)
  table.insert(Lines, Cursor1.line+1, {mode='text', data=string.sub(Lines[Cursor1.line].data, byte_offset)})
  Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset-1)
  Lines[Cursor1.line].fragments = nil
  Cursor1.line = Cursor1.line+1
  Cursor1.pos = 1
end

function Text.pageup()
--?   print('pageup')
  -- duplicate some logic from love.draw
  local top2 = Text.to2(Screen_top1)
--?   print(App.screen.height)
  local y = App.screen.height - Line_height
  while y >= Margin_top do
--?     print(y, top2.line, top2.screen_line, top2.screen_pos)
    if Screen_top1.line == 1 and Screen_top1.pos == 1 then break end
    if Lines[Screen_top1.line].mode == 'text' then
      y = y - Line_height
    elseif Lines[Screen_top1.line].mode == 'drawing' then
      y = y - Drawing_padding_height - Drawing.pixels(Lines[Screen_top1.line].h)
    end
    top2 = Text.previous_screen_line(top2)
  end
  Screen_top1 = Text.to1(top2)
  Cursor1.line = Screen_top1.line
  Cursor1.pos = Screen_top1.pos
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
--?   print(Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos)
--?   print('pageup end')
end

function Text.pagedown()
--?   print('pagedown')
  -- If a line/paragraph gets to a page boundary, I often want to scroll
  -- before I get to the bottom.
  -- However, only do this if it makes forward progress.
  local top2 = Text.to2(Screen_bottom1)
  if top2.screen_line > 1 then
    top2.screen_line = math.max(top2.screen_line-10, 1)
  end
  local new_top1 = Text.to1(top2)
  if Text.lt1(Screen_top1, new_top1) then
    Screen_top1 = new_top1
  else
    Screen_top1.line = Screen_bottom1.line
    Screen_top1.pos = Screen_bottom1.pos
  end
--?   print('setting top to', Screen_top1.line, Screen_top1.pos)
  Cursor1.line = Screen_top1.line
  Cursor1.pos = Screen_top1.pos
  Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
--?   print('top now', Screen_top1.line)
  Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
--?   print('pagedown end')
end

function Text.up()
  assert(Lines[Cursor1.line].mode == 'text')
--?   print('up', Cursor1.pos, Screen_top1.pos)
  local screen_line_index,screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
  if screen_line_starting_pos == 1 then
--?     print('cursor is at first screen line of its line')
    -- line is done; skip to previous text line
    local new_cursor_line = Cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
--?         print('found previous text line')
        Cursor1.line = new_cursor_line
        Text.populate_screen_line_starting_pos(Cursor1.line)
        -- previous text line found, pick its final screen line
--?         print('has multiple screen lines')
        local screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos
--?         print(#screen_line_starting_pos)
        screen_line_starting_pos = screen_line_starting_pos[#screen_line_starting_pos]
--?         print('previous screen line starts at pos '..tostring(screen_line_starting_pos)..' of its line')
        if Screen_top1.line > Cursor1.line then
          Screen_top1.line = Cursor1.line
          Screen_top1.pos = screen_line_starting_pos
--?           print('pos of top of screen is also '..tostring(Screen_top1.pos)..' of the same line')
        end
        local screen_line_starting_byte_offset = Text.offset(Lines[Cursor1.line].data, screen_line_starting_pos)
        local s = string.sub(Lines[Cursor1.line].data, screen_line_starting_byte_offset)
        Cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
        break
      end
    end
    if Cursor1.line < Screen_top1.line then
      Screen_top1.line = Cursor1.line
    end
  else
    -- move up one screen line in current line
--?     print('cursor is NOT at first screen line of its line')
    assert(screen_line_index > 1)
    new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index-1]
--?     print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
    if Screen_top1.line == Cursor1.line and Screen_top1.pos == screen_line_starting_pos then
      Screen_top1.pos = new_screen_line_starting_pos
--?       print('also setting pos of top of screen to '..tostring(Screen_top1.pos))
    end
    local new_screen_line_starting_byte_offset = Text.offset(Lines[Cursor1.line].data, new_screen_line_starting_pos)
    local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_byte_offset)
    Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
--?     print('cursor pos is now '..tostring(Cursor1.pos))
  end
end

function Text.down()
  assert(Lines[Cursor1.line].mode == 'text')
--?   print('down', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
  if Text.cursor_at_final_screen_line() then
    -- line is done, skip to next text line
--?     print('cursor at final screen line of its line')
    local new_cursor_line = Cursor1.line
    while new_cursor_line < #Lines do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = Text.nearest_cursor_pos(Lines[Cursor1.line].data, Cursor_x)
--?         print(Cursor1.pos)
        break
      end
    end
    if Cursor1.line > Screen_bottom1.line then
--?       print('screen top before:', Screen_top1.line, Screen_top1.pos)
--?       print('scroll up preserving cursor')
      Text.snap_cursor_to_bottom_of_screen()
--?       print('screen top after:', Screen_top1.line, Screen_top1.pos)
    end
  else
    -- move down one screen line in current line
    local scroll_down = false
    if Text.le1(Screen_bottom1, Cursor1) then
      scroll_down = true
    end
--?     print('cursor is NOT at final screen line of its line')
    local screen_line_index, screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
    new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index+1]
--?     print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
    local new_screen_line_starting_byte_offset = Text.offset(Lines[Cursor1.line].data, new_screen_line_starting_pos)
    local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_byte_offset)
    Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
--?     print('cursor pos is now', Cursor1.line, Cursor1.pos)
    if scroll_down then
--?       print('scroll up preserving cursor')
      Text.snap_cursor_to_bottom_of_screen()
--?       print('screen top after:', Screen_top1.line, Screen_top1.pos)
    end
  end
--?   print('=>', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
end

function Text.word_left()
  while true do
    Text.left()
    if Cursor1.pos == 1 then break end
    assert(Cursor1.pos > 1)
    local offset = Text.offset(Lines[Cursor1.line].data, Cursor1.pos)
    assert(offset > 1)
    if Lines[Cursor1.line].data:sub(offset-1,offset-1) == ' ' then
      break
    end
  end
end

function Text.word_right()
  while true do
    Text.right()
    if Cursor1.pos > utf8.len(Lines[Cursor1.line].data) then break end
    local offset = Text.offset(Lines[Cursor1.line].data, Cursor1.pos)
    if Lines[Cursor1.line].data:sub(offset,offset) == ' ' then  -- TODO: other space characters
      break
    end
  end
end

function Text.left()
  assert(Lines[Cursor1.line].mode == 'text')
  if Cursor1.pos > 1 then
    Cursor1.pos = Cursor1.pos-1
  else
    local new_cursor_line = Cursor1.line
    while new_cursor_line > 1 do
      new_cursor_line = new_cursor_line-1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
        break
      end
    end
    if Cursor1.line < Screen_top1.line then
      Screen_top1.line = Cursor1.line
    end
  end
end

function Text.right()
  assert(Lines[Cursor1.line].mode == 'text')
  if Cursor1.pos <= utf8.len(Lines[Cursor1.line].data) then
    Cursor1.pos = Cursor1.pos+1
  else
    local new_cursor_line = Cursor1.line
    while new_cursor_line <= #Lines-1 do
      new_cursor_line = new_cursor_line+1
      if Lines[new_cursor_line].mode == 'text' then
        Cursor1.line = new_cursor_line
        Cursor1.pos = 1
        break
      end
    end
    if Cursor1.line > Screen_bottom1.line then
      Screen_top1.line = Cursor1.line
    end
  end
end

function Text.pos_at_start_of_cursor_screen_line()
  Text.populate_screen_line_starting_pos(Cursor1.line)
  for i=#Lines[Cursor1.line].screen_line_starting_pos,1,-1 do
    local spos = Lines[Cursor1.line].screen_line_starting_pos[i]
    if spos <= Cursor1.pos then
      return i,spos
    end
  end
  assert(false)
end

function Text.cursor_at_final_screen_line()
  Text.populate_screen_line_starting_pos(Cursor1.line)
  local screen_lines = Lines[Cursor1.line].screen_line_starting_pos
--?   print(screen_lines[#screen_lines], Cursor1.pos)
  return screen_lines[#screen_lines] <= Cursor1.pos
end

function Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  local y = Margin_top
  while Cursor1.line <= #Lines do
    if Lines[Cursor1.line].mode == 'text' then
      break
    end
--?     print('cursor skips', Cursor1.line)
    y = y + Drawing_padding_height + Drawing.pixels(Lines[Cursor1.line].h)
    Cursor1.line = Cursor1.line + 1
  end
  -- hack: insert a text line at bottom of file if necessary
  if Cursor1.line > #Lines then
    assert(Cursor1.line == #Lines+1)
    table.insert(Lines, {mode='text', data=''})
  end
--?   print(y, App.screen.height, App.screen.height-Line_height)
  if y > App.screen.height - Line_height then
--?     print('scroll up')
    Text.snap_cursor_to_bottom_of_screen()
  end
end

function Text.snap_cursor_to_bottom_of_screen()
  local top2 = Text.to2(Cursor1)
  top2.screen_pos = 1  -- start of screen line
--?   print('cursor pos '..tostring(Cursor1.pos)..' is on the #'..tostring(top2.screen_line)..' screen line down')
  local y = App.screen.height - Line_height
  -- duplicate some logic from love.draw
  while true do
--?     print(y, 'top2:', top2.line, top2.screen_line, top2.screen_pos)
    if top2.line == 1 and top2.screen_line == 1 then break end
    if top2.screen_line > 1 or Lines[top2.line-1].mode == 'text' then
      local h = Line_height
      if y - h < Margin_top then
        break
      end
      y = y - h
    else
      assert(top2.line > 1)
      assert(Lines[top2.line-1].mode == 'drawing')
      -- We currently can't draw partial drawings, so either skip it entirely
      -- or not at all.
      local h = Drawing_padding_height + Drawing.pixels(Lines[top2.line-1].h)
      if y - h < Margin_top then
        break
      end
--?       print('skipping drawing of height', h)
      y = y - h
    end
    top2 = Text.previous_screen_line(top2)
  end
--?   print('top2 finally:', top2.line, top2.screen_line, top2.screen_pos)
  Screen_top1 = Text.to1(top2)
--?   print('top1 finally:', Screen_top1.line, Screen_top1.pos)
  Text.redraw_all()  -- if we're scrolling, reclaim all fragments to avoid memory leaks
end

function Text.in_line(line_index,line, x,y)
  if line.y == nil then return false end  -- outside current page
  if x < Margin_left then return false end
  if y < line.y then return false end
  Text.populate_screen_line_starting_pos(line_index)
  return y < line.y + #line.screen_line_starting_pos * Line_height
end

-- convert mx,my in pixels to schema-1 coordinates
function Text.to_pos_on_line(line, mx, my)
--?   print('Text.to_pos_on_line', mx, my, 'width', Line_width)
  if line.fragments == nil then
    Text.compute_fragments(line, Line_width)
  end
  assert(my >= line.y)
  -- duplicate some logic from Text.draw
  local y = line.y
  for screen_line_index,screen_line_starting_pos in ipairs(line.screen_line_starting_pos) do
      local screen_line_starting_byte_offset = Text.offset(line.data, screen_line_starting_pos)
--?     print('iter', y, screen_line_index, screen_line_starting_pos, string.sub(line.data, screen_line_starting_byte_offset))
    local nexty = y + Line_height
    if my < nexty then
      -- On all wrapped screen lines but the final one, clicks past end of
      -- line position cursor on final character of screen line.
      -- (The final screen line positions past end of screen line as always.)
      if mx > Line_width and screen_line_index < #line.screen_line_starting_pos then
--?         print('past end of non-final line; return')
        return line.screen_line_starting_pos[screen_line_index+1]
      end
      local s = string.sub(line.data, screen_line_starting_byte_offset)
--?       print('return', mx, Text.nearest_cursor_pos(s, mx), '=>', screen_line_starting_pos + Text.nearest_cursor_pos(s, mx) - 1)
      return screen_line_starting_pos + Text.nearest_cursor_pos(s, mx) - 1
    end
    y = nexty
  end
  assert(false)
end
-- manual test:
--  line: abc
--        def
--        gh
--  fragments: abc, def, gh
--  click inside e
--  line_starting_pos = 1 + 3 = 4
--  nearest_cursor_pos('defgh', mx) = 2
--  Cursor1.pos = 4 + 2 - 1 = 5
-- manual test:
--  click inside h
--  line_starting_pos = 1 + 3 + 3 = 7
--  nearest_cursor_pos('gh', mx) = 2
--  Cursor1.pos = 7 + 2 - 1 = 8

function Text.nearest_cursor_pos(line, x)  -- x includes left margin
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Margin_left+Text.x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('-- nearest', x)
  while true do
--?     print('nearest', x, '^'..line..'$', left, right)
    if left == right then
      return left
    end
    local curr = math.floor((left+right)/2)
    local currxmin = Margin_left+Text.x(line, curr)
    local currxmax = Margin_left+Text.x(line, curr+1)
--?     print('nearest', x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      if x-currxmin < currxmax-x then
        return curr
      else
        return curr+1
      end
    end
    if left >= right-1 then
      return right
    end
    if currxmin > x then
      right = curr
    else
      left = curr
    end
  end
  assert(false)
end

function Text.nearest_pos_less_than(line, x)  -- x DOES NOT include left margin
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Text.x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('--')
  while true do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.x(line, curr+1)
    local currxmax = Text.x(line, curr+2)
--?     print(x, left, right, curr, currxmin, currxmax)
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

function Text.x(s, pos)
  local offset = Text.offset(s, pos)
  local s_before = s:sub(1, offset-1)
  local text_before = App.newText(love.graphics.getFont(), s_before)
  return App.width(text_before)
end

function Text.to2(pos1)
  if Lines[pos1.line].mode == 'drawing' then
    return {line=pos1.line, screen_line=1, screen_pos=1}
  end
  local result = {line=pos1.line, screen_line=1}
  Text.populate_screen_line_starting_pos(pos1.line)
  for i=#Lines[pos1.line].screen_line_starting_pos,1,-1 do
    local spos = Lines[pos1.line].screen_line_starting_pos[i]
    if spos <= pos1.pos then
      result.screen_line = i
      result.screen_pos = pos1.pos - spos + 1
      break
    end
  end
  assert(result.screen_pos)
  return result
end

function Text.to1(pos2)
  local result = {line=pos2.line, pos=pos2.screen_pos}
  if pos2.screen_line > 1 then
    result.pos = Lines[pos2.line].screen_line_starting_pos[pos2.screen_line] + pos2.screen_pos - 1
  end
  return result
end

function Text.eq1(a, b)
  return a.line == b.line and a.pos == b.pos
end

function Text.lt1(a, b)
  if a.line < b.line then
    return true
  end
  if a.line > b.line then
    return false
  end
  return a.pos < b.pos
end

function Text.le1(a, b)
  if a.line < b.line then
    return true
  end
  if a.line > b.line then
    return false
  end
  return a.pos <= b.pos
end

function Text.offset(s, pos1)
  if pos1 == 1 then return 1 end
  local result = utf8.offset(s, pos1)
  if result == nil then
    print(Cursor1.line, Cursor1.pos, #Lines[Cursor1.line].data, Lines[Cursor1.line].data)
    print(pos1, #s, s)
  end
  assert(result)
  return result
end

function Text.previous_screen_line(pos2)
  if pos2.screen_line > 1 then
    return {line=pos2.line, screen_line=pos2.screen_line-1, screen_pos=1}
  elseif pos2.line == 1 then
    return pos2
  elseif Lines[pos2.line-1].mode == 'drawing' then
    return {line=pos2.line-1, screen_line=1, screen_pos=1}
  else
    local l = Lines[pos2.line-1]
    Text.populate_screen_line_starting_pos(pos2.line-1)
    return {line=pos2.line-1, screen_line=#Lines[pos2.line-1].screen_line_starting_pos, screen_pos=1}
  end
end

function Text.populate_screen_line_starting_pos(line_index)
--?   print('Text.populate_screen_line_starting_pos', line_index)
  local line = Lines[line_index]
  if line.screen_line_starting_pos then
    return
  end
  -- duplicate some logic from Text.draw
  if line.fragments == nil then
    Text.compute_fragments(line, Line_width)
  end
  line.screen_line_starting_pos = {1}
  local x = Margin_left
  local pos = 1
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = App.width(frag_text)
--?     print(x, pos, frag, frag_width)
    if x + frag_width > Line_width then
      x = Margin_left
      table.insert(line.screen_line_starting_pos, pos)
--?       print('new screen line:', #line.screen_line_starting_pos, pos)
    end
    x = x + frag_width
    local frag_len = utf8.len(frag)
    pos = pos + frag_len
  end
end

function Text.redraw_all()
--?   print('clearing fragments')
  for _,line in ipairs(Lines) do
    line.y = nil
    line.fragments = nil
    line.screen_line_starting_pos = nil
  end
end

return Text
