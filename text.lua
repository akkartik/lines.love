-- primitives for editing text
Text = {}

local utf8 = require 'utf8'

local Debug_new_render = false

-- return values:
--  y coordinate drawn until in px
--  position of start of final screen line drawn
function Text.draw(line, line_width, line_index)
  print('text.draw')
  love.graphics.setColor(0,0,0)
  -- wrap long lines
  local x = 25
  local y = line.y
  local pos = 1
  local screen_line_starting_pos = 1
  if line.fragments == nil then
    Text.compute_fragments(line, line_width)
  end
  line.screen_line_starting_pos = nil  -- TODO: avoid recomputing on every repaint
  if Debug_new_render then print('--') end
  for _, f in ipairs(line.fragments) do
    local frag, frag_text = f.data, f.text
    -- render fragment
    local frag_width = math.floor(App.width(frag_text)*Zoom)
    if x + frag_width > line_width then
      assert(x > 25)  -- no overfull lines
      if line_index > Screen_top1.line or pos > Screen_top1.pos then
        y = y + math.floor(15*Zoom)
        if New_foo then print('text: new screen line', y, App.screen.height, screen_line_starting_pos) end
        screen_line_starting_pos = pos
        if Debug_new_render then print('y', y) end
      end
      x = 25
      if line.screen_line_starting_pos == nil then
        line.screen_line_starting_pos = {1, pos}
      else
        table.insert(line.screen_line_starting_pos, pos)
      end
      if line_index > Screen_top1.line or pos > Screen_top1.pos then
        if y + math.floor(15*Zoom) >= App.screen.height then
          return y, screen_line_starting_pos
        end
      end
    end
    if Debug_new_render then print('checking to draw', pos, Screen_top1.pos) end
    if line_index > Screen_top1.line or pos >= Screen_top1.pos then
      if Debug_new_render then print('drawing '..frag) end
      App.screen.draw(frag_text, x,y, 0, Zoom)
    end
    -- render cursor if necessary
    local frag_len = utf8.len(frag)
    if line_index == Cursor1.line then
      if pos <= Cursor1.pos and pos + frag_len > Cursor1.pos then
        Text.draw_cursor(x+Text.cursor_x2(frag, Cursor1.pos-pos+1), y)
      end
    end
    x = x + frag_width
    pos = pos + frag_len
  end
  if line_index == Cursor1.line and Cursor1.pos == pos then
    Text.draw_cursor(x, y)
  end
  Debug_new_render = false
  return y, screen_line_starting_pos
end
-- manual tests:
--  draw with small line_width of 100
--  short words break on spaces
--  long words break when they must

function Text.draw_cursor(x, y)
  love.graphics.setColor(1,0,0)
  love.graphics.circle('fill', x,y+math.floor(15*Zoom), 2)
  love.graphics.setColor(0,0,0)
  Cursor_x = x
  Cursor_y = y+math.floor(15*Zoom)
end

function test_draw_text()
  print('test_draw_text')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi'}
  Line_width = 120
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Zoom = 1
  App.draw()
  local screen_top_margin = 15  -- pixels
  local line_height = 15  -- pixels
  local y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_draw_text/screen:1')
  y = y + line_height
  App.screen.check(y, 'def', 'F - test_draw_text/screen:2')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_draw_text/screen:3')
end

function test_pagedown()
  print('test_pagedown')
  App.screen.init{width=120, height=45}
  Lines = load_array{'abc', 'def', 'ghi'}
  Line_width = 120
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Zoom = 1
  local screen_top_margin = 15  -- pixels
  local line_height = math.floor(15*Zoom)  -- pixels
  -- initially the first two lines are displayed
  App.draw()
  local y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_pagedown/baseline/screen:1')
  y = y + line_height
  App.screen.check(y, 'def', 'F - test_pagedown/baseline/screen:2')
  -- after pagedown the bottom line becomes the top
  App.run_after_keychord('pagedown')
  y = screen_top_margin
  App.screen.check(y, 'def', 'F - test_pagedown/screen:1')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_pagedown/screen:2')
end

function test_pagedown_skips_drawings()
  print('test_pagedown_skips_drawings')
  -- some lines of text with a drawing intermixed
  App.screen.init{width=50, height=80}
  Lines = load_array{'abc',               -- height 15
                     '```lines', '```',   -- height 25
                     'def',               -- height 15
                     'ghi'}               -- height 15
  check_eq(Lines[2].mode, 'drawing', 'F - test_pagedown_skips_drawings/baseline/lines')
  Line_width = App.screen.width
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Zoom = 1
  local screen_top_margin = 15  -- pixels
  local text height = 15
  local drawing_height = 20 + App.screen.width / 2  -- default
  -- initially the screen displays the first line and the drawing
  -- 15px margin + 15px line1 + 10px margin + 25px drawing + 10px margin = 75px < screen height 80px
  App.draw()
  local y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_pagedown_skips_drawings/baseline/screen:1')
  -- after pagedown the screen draws the screen up top
  -- 15px margin + 10px margin + 25px drawing + 10px margin + 15px line3 = 75px < screen height 80px
  App.run_after_keychord('pagedown')
--?   print('test: top:', Screen_top1.line)
  y = screen_top_margin + drawing_height
  App.screen.check(y, 'def', 'F - test_pagedown_skips_drawings/screen:1')
end

function test_down_arrow_moves_cursor()
  print('test_down_arrow_moves_cursor')
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=1, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Zoom = 1
  local screen_top_margin = 15  -- pixels
  local line_height = math.floor(15*Zoom)  -- pixels
  -- initially the first three lines are displayed
  App.draw()
  local y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_down_arrow_moves_cursor/baseline/screen:1')
  y = y + line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_moves_cursor/baseline/screen:2')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_moves_cursor/baseline/screen:3')
  -- after hitting the down arrow the screen is unchanged
  App.run_after_keychord('down')
  y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_down_arrow_moves_cursor/screen:1')
  y = y + line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_moves_cursor/screen:2')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_moves_cursor/screen:3')
  -- but the cursor moves down by 1 line
  check_eq(Cursor1.line, 2, 'F - test_down_arrow_moves_cursor/cursor')
end

function test_down_arrow_scrolls_down_by_one_line()
  print('test_down_arrow_scrolls_down_by_one_line')
  -- display the first three lines with the cursor on the bottom line
  App.screen.init{width=120, height=60}
  Lines = load_array{'abc', 'def', 'ghi', 'jkl'}
  Line_width = 120
  Cursor1 = {line=3, pos=1}
  Screen_top1 = {line=1, pos=1}
  Screen_bottom1 = {}
  Zoom = 1
  local screen_top_margin = 15  -- pixels
  local line_height = math.floor(15*Zoom)  -- pixels
  App.draw()
  local y = screen_top_margin
  App.screen.check(y, 'abc', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:1')
  y = y + line_height
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:2')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_scrolls_down_by_one_line/baseline/screen:3')
  -- after hitting the down arrow the screen scrolls down by one line
  App.run_after_keychord('down')
  y = screen_top_margin
  App.screen.check(y, 'def', 'F - test_down_arrow_scrolls_down_by_one_line/screen:1')
  y = y + line_height
  App.screen.check(y, 'ghi', 'F - test_down_arrow_scrolls_down_by_one_line/screen:2')
  y = y + line_height
  App.screen.check(y, 'jkl', 'F - test_down_arrow_scrolls_down_by_one_line/screen:3')
end

function Text.compute_fragments(line, line_width)
  line.fragments = {}
  local x = 25
  -- try to wrap at word boundaries
  for frag in line.data:gmatch('%S*%s*') do
    local frag_text = App.newText(love.graphics.getFont(), frag)
    local frag_width = math.floor(App.width(frag_text)*Zoom)
--?     print('x: '..tostring(x)..'; '..tostring(line_width-x)..'px to go')
--?     print('frag: ^'..frag..'$ is '..tostring(frag_width)..'px wide')
    if x + frag_width > line_width then
      while x + frag_width > line_width do
        if x < 0.8*line_width then
          -- long word; chop it at some letter
          -- We're not going to reimplement TeX here.
          local b = Text.nearest_cursor_pos(frag, line_width - x)
--?           print('space for '..tostring(b)..' graphemes')
          local frag1 = string.sub(frag, 1, b)
          local frag1_text = App.newText(love.graphics.getFont(), frag1)
          local frag1_width = math.floor(frag1App.width(_text)*Zoom)
--?           print('inserting '..frag1..' of width '..tostring(frag1_width)..'px')
          table.insert(line.fragments, {data=frag1, text=frag1_text})
          frag = string.sub(frag, b+1)
          frag_text = App.newText(love.graphics.getFont(), frag)
          frag_width = math.floor(App.width(frag_text)*Zoom)
        end
        x = 25  -- new line
      end
    end
    if #frag > 0 then
--?       print('inserting '..frag..' of width '..tostring(frag_width)..'px')
      table.insert(line.fragments, {data=frag, text=frag_text})
    end
  end
end

function Text.textinput(t)
  if love.mouse.isDown('1') then return end
  Text.insert_at_cursor(t)
end

function Text.insert_at_cursor(t)
  local byte_offset
  if Cursor1.pos > 1 then
    byte_offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos-1)
  else
    byte_offset = 0
  end
  Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset)..t..string.sub(Lines[Cursor1.line].data, byte_offset+1)
  Lines[Cursor1.line].fragments = nil
  Cursor1.pos = Cursor1.pos+1
end

-- Don't handle any keys here that would trigger love.textinput above.
function Text.keychord_pressed(chord)
--?   Debug_new_render = true
  if chord == 'return' then
    local byte_offset = utf8.offset(Lines[Cursor1.line].data, Cursor1.pos)
    table.insert(Lines, Cursor1.line+1, {mode='text', data=string.sub(Lines[Cursor1.line].data, byte_offset)})
    Lines[Cursor1.line].data = string.sub(Lines[Cursor1.line].data, 1, byte_offset-1)
    Lines[Cursor1.line].fragments = nil
    Cursor1.line = Cursor1.line+1
    Cursor1.pos = 1
    save_to_disk(Lines, Filename)
  elseif chord == 'tab' then
    Text.insert_at_cursor('\t')
    save_to_disk(Lines, Filename)
  elseif chord == 'left' then
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
  elseif chord == 'right' then
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
  elseif chord == 'home' then
    Cursor1.pos = 1
  elseif chord == 'end' then
    Cursor1.pos = utf8.len(Lines[Cursor1.line].data) + 1
  elseif chord == 'backspace' then
    if Cursor1.pos > 1 then
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
    save_to_disk(Lines, Filename)
  elseif chord == 'delete' then
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
    save_to_disk(Lines, Filename)
  elseif chord == 'up' then
    assert(Lines[Cursor1.line].mode == 'text')
--?     print('up', Cursor1.pos, Screen_top1.pos)
    local screen_line_index,screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
    if screen_line_starting_pos == 1 then
--?       print('cursor is at first screen line of its line')
      -- line is done; skip to previous text line
      local new_cursor_line = Cursor1.line
      while new_cursor_line > 1 do
        new_cursor_line = new_cursor_line-1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor1.line = new_cursor_line
          if Lines[Cursor1.line].screen_line_starting_pos == nil then
            Cursor1.pos = Text.nearest_cursor_pos(Lines[Cursor1.line].data, Cursor_x)
            break
          end
          -- previous text line found, pick its final screen line
          local screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos
          screen_line_starting_pos = screen_line_starting_pos[#screen_line_starting_pos]
--?           print('previous screen line starts at pos '..tostring(screen_line_starting_pos)..' of its line')
          if Screen_top1.line == Cursor1.line and Screen_top1.pos == screen_line_starting_pos then
            Screen_top1.pos = screen_line_starting_pos
--?             print('pos of top of screen is also '..tostring(Screen_top1.pos)..' of the same line')
          end
          local s = string.sub(Lines[Cursor1.line].data, screen_line_starting_pos)
          Cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
          break
        end
      end
      if Cursor1.line < Screen_top1.line then
        Screen_top1.line = Cursor1.line
      end
    else
      -- move up one screen line in current line
--?       print('cursor is NOT at first screen line of its line')
      assert(screen_line_index > 1)
      new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index-1]
--?       print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
      if Screen_top1.line == Cursor1.line and Screen_top1.pos == screen_line_starting_pos then
        Screen_top1.pos = new_screen_line_starting_pos
--?         print('also setting pos of top of screen to '..tostring(Screen_top1.pos))
      end
      local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_pos)
      Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
--?       print('cursor pos is now '..tostring(Cursor1.pos))
    end
  elseif chord == 'down' then
    assert(Lines[Cursor1.line].mode == 'text')
    print('down', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
    if Text.cursor_at_final_screen_line() then
      -- line is done, skip to next text line
      print('cursor at final screen line of its line')
--?       os.exit(1)
      local new_cursor_line = Cursor1.line
      while new_cursor_line < #Lines do
        new_cursor_line = new_cursor_line+1
        if Lines[new_cursor_line].mode == 'text' then
          Cursor1.line = new_cursor_line
          Cursor1.pos = Text.nearest_cursor_pos(Lines[Cursor1.line].data, Cursor_x)
          print(Cursor1.pos)
          break
        end
      end
      if Cursor1.line > Screen_bottom1.line then
        print('screen top before:', Screen_top1.line, Screen_top1.pos)
        Screen_top1.line = Cursor1.line
        print('scroll up preserving cursor')
        Text.scroll_up_while_cursor_on_screen()
        print('screen top after:', Screen_top1.line, Screen_top1.pos)
      end
    else
      -- move down one screen line in current line
      print('cursor is NOT at final screen line of its line')
      local screen_line_index, screen_line_starting_pos = Text.pos_at_start_of_cursor_screen_line()
      new_screen_line_starting_pos = Lines[Cursor1.line].screen_line_starting_pos[screen_line_index+1]
      print('switching pos of screen line at cursor from '..tostring(screen_line_starting_pos)..' to '..tostring(new_screen_line_starting_pos))
      local s = string.sub(Lines[Cursor1.line].data, new_screen_line_starting_pos)
      Cursor1.pos = new_screen_line_starting_pos + Text.nearest_cursor_pos(s, Cursor_x) - 1
      print('cursor pos is now', Cursor1.line, Cursor1.pos)
      Screen_top1.line = Cursor1.line
      print('scroll up preserving cursor')
      Text.scroll_up_while_cursor_on_screen()
      print('screen top after:', Screen_top1.line, Screen_top1.pos)
    end
    print('=>', Cursor1.line, Cursor1.pos, Screen_top1.line, Screen_top1.pos, Screen_bottom1.line, Screen_bottom1.pos)
  end
end

function Text.pos_at_start_of_cursor_screen_line()
  if Lines[Cursor1.line].screen_line_starting_pos == nil then
    return 1,1
  end
  for i=#Lines[Cursor1.line].screen_line_starting_pos,1,-1 do
    local spos = Lines[Cursor1.line].screen_line_starting_pos[i]
    if spos <= Cursor1.pos then
      return i,spos
    end
  end
  assert(false)
end

function Text.cursor_at_final_screen_line()
  if Lines[Cursor1.line].screen_line_starting_pos == nil then
    return true
  end
  screen_lines = Lines[Cursor1.line].screen_line_starting_pos
  print(screen_lines[#screen_lines], Cursor1.pos)
  return screen_lines[#screen_lines] <= Cursor1.pos
end

function Text.move_cursor_down_to_next_text_line_while_scrolling_again_if_necessary()
  local y = 15  -- top margin
  while Cursor1.line <= #Lines do
    if Lines[Cursor1.line].mode == 'text' then
      break
    end
    print('cursor skips', Cursor1.line)
    y = y + 20 + Drawing.pixels(Lines[Cursor1.line].h)
    Cursor1.line = Cursor1.line + 1
  end
  -- hack: insert a text line at bottom of file if necessary
  if Cursor1.line > #Lines then
    assert(Cursor1.line == #Lines+1)
    table.insert(Lines, {mode='text', data=''})
  end
--?   print(y, App.screen.height, App.screen.height-math.floor(15*Zoom))
  if y > App.screen.height - math.floor(15*Zoom) then
--?   if Cursor1.line > Screen_bottom1.line then
    print('scroll up')
    Screen_top1.line = Cursor1.line
    Text.scroll_up_while_cursor_on_screen()
  end
end

function Text.scroll_up_while_cursor_on_screen()
  local top2 = Text.to2(Cursor1)
--?   print('cursor pos '..tostring(Cursor1.pos)..' is on the #'..tostring(top2.screen_line)..' screen line down')
  local y = App.screen.height - math.floor(15*Zoom)
  -- duplicate some logic from love.draw
  while true do
--?     print(y, 'top2:', top2.line, top2.screen_line, top2.screen_pos)
    if top2.line == 1 and top2.screen_line == 1 then break end
    if top2.screen_line > 1 or Lines[top2.line-1].mode == 'text' then
      local h = math.floor(15*Zoom)
      if y - h < 15 then  -- top margin = 15
        break
      end
      y = y - h
    else
      assert(top2.line > 1)
      assert(Lines[top2.line-1].mode == 'drawing')
      -- We currently can't draw partial drawings, so either skip it entirely
      -- or not at all.
      local h = 20 + Drawing.pixels(Lines[top2.line-1].h)
      if y - h < 15 then
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
end

function Text.in_line(line, x,y)
  if line.y == nil then return false end  -- outside current page
  if x < 16 then return false end
  if y < line.y then return false end
  if line.screen_line_starting_pos == nil then return y < line.y + math.floor(15*Zoom) end
  return y < line.y + #line.screen_line_starting_pos * math.floor(15*Zoom)
end

function Text.move_cursor(line_index, line, mx, my)
  Cursor1.line = line_index
  if line.screen_line_starting_pos == nil then
    Cursor1.pos = Text.nearest_cursor_pos(line.data, mx)
    return
  end
  assert(line.fragments)
  assert(my >= line.y)
  -- duplicate some logic from Text.draw
  local y = line.y
  for screen_line_index,screen_line_starting_pos in ipairs(line.screen_line_starting_pos) do
    local nexty = y + math.floor(15*Zoom)
    if my < nexty then
      -- On all wrapped screen lines but the final one, clicks past end of
      -- line position cursor on final character of screen line.
      -- (The final screen line positions past end of screen line as always.)
      if mx > Line_width and screen_line_index < #line.screen_line_starting_pos then
        Cursor1.pos = line.screen_line_starting_pos[screen_line_index+1]
        return
      end
      local s = string.sub(line.data, screen_line_starting_pos)
      Cursor1.pos = screen_line_starting_pos + Text.nearest_cursor_pos(s, mx) - 1
      return
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

function Text.nearest_cursor_pos(line, x)
  if x == 0 then
    return 1
  end
  local len = utf8.len(line)
  local max_x = Text.cursor_x(line, len+1)
  if x > max_x then
    return len+1
  end
  local left, right = 1, len+1
--?   print('--')
  while true do
    local curr = math.floor((left+right)/2)
    local currxmin = Text.cursor_x(line, curr)
    local currxmax = Text.cursor_x(line, curr+1)
--?     print(x, left, right, curr, currxmin, currxmax)
    if currxmin <= x and x < currxmax then
      return curr
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

function Text.cursor_x(line_data, cursor_pos)
  local line_before_cursor = line_data:sub(1, cursor_pos-1)
  local text_before_cursor = App.newText(love.graphics.getFont(), line_before_cursor)
  return 25 + math.floor(App.width(text_before_cursor)*Zoom)
end

function Text.cursor_x2(s, cursor_pos)
  local s_before_cursor = s:sub(1, cursor_pos-1)
  local text_before_cursor = App.newText(love.graphics.getFont(), s_before_cursor)
  return math.floor(App.width(text_before_cursor)*Zoom)
end

function Text.to2(pos1)
  assert(Lines[pos1.line].mode == 'text')
  local result = {line=pos1.line, screen_line=1}
  if Lines[pos1.line].screen_line_starting_pos == nil then
    result.screen_pos = pos1.pos
  else
    for i=#Lines[pos1.line].screen_line_starting_pos,1,-1 do
      local spos = Lines[pos1.line].screen_line_starting_pos[i]
      if spos <= pos1.pos then
        result.screen_line = i
        result.screen_pos = pos1.pos - spos + 1
        break
      end
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

function Text.previous_screen_line(pos2)
  if pos2.screen_line > 1 then
    return {line=pos2.line, screen_line=pos2.screen_line-1, screen_pos=1}
  elseif pos2.line == 1 then
    return pos2
  elseif Lines[pos2.line-1].mode == 'drawing' then
    return {line=pos2.line-1, screen_line=1, screen_pos=1}
  else
    local l = Lines[pos2.line-1]
    if l.screen_line_starting_pos == nil then
      return {line=pos2.line-1, screen_line=1, screen_pos=1}
    else
      return {line=pos2.line-1, screen_line=#Lines[pos2.line-1].screen_line_starting_pos, screen_pos=1}
    end
  end
end

return Text
