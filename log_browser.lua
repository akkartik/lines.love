-- environment for immutable logs
-- optionally reads extensions for rendering some types from the source codebase that generated them
--
-- We won't care too much about long, wrapped lines. If they lines get too
-- long to manage, you need a better, graphical rendering for them. Load
-- functions to render them into the log_render namespace.

function source.initialize_log_browser_side()
  Log_browser_state = edit.initialize_state(Margin_top, Editor_state.right + Margin_right + Margin_left, (Editor_state.right+Margin_right)*2, Editor_state.font, Editor_state.font_height, Editor_state.line_height)
  Log_browser_state.filename = 'log'
  load_from_disk(Log_browser_state)  -- TODO: pay no attention to Fold
  log_browser.parse(Log_browser_state)
  Text.redraw_all(Log_browser_state)
  Log_browser_state.screen_top1 = {line=1, pos=1}
  Log_browser_state.cursor1 = {line=1, pos=1}
end

Section_stack = {}
Section_border_color = {r=0.7, g=0.7, b=0.7}
Cursor_line_background_color = {r=0.7, g=0.7, b=0, a=0.1}

Section_border_padding_horizontal = 30  -- TODO: adjust this based on font height (because we draw text vertically along the borders
Section_border_padding_vertical = 15  -- TODO: adjust this based on font height

log_browser = {}

function log_browser.parse(State)
  for _,line in ipairs(State.lines) do
    if line.data ~= '' then
      local rest
      line.filename, line.line_number, rest = line.data:match('%[string "([^:]*)"%]:([^:]*):%s*(.*)')
      if line.filename == nil then
        line.filename, line.line_number, rest = line.data:match('([^:]*):([^:]*):%s*(.*)')
      end
      if rest then
        line.data = rest
      end
      line.line_number = tonumber(line.line_number)
      if line.data:sub(1,1) == '{' then
        local data = json.decode(line.data)
        if log_render[data.name] then
          line.data = data
        end
        line.section_stack = table.shallowcopy(Section_stack)
      elseif line.data:match('%[ u250c') then
        line.section_stack = table.shallowcopy(Section_stack)  -- as it is at the beginning
        local section_name = line.data:match('u250c%s*(.*)')
        table.insert(Section_stack, {name=section_name})
        line.section_begin = true
        line.section_name = section_name
        line.data = nil
      elseif line.data:match('%] u2518') then
        local section_name = line.data:match('] u2518%s*(.*)')
        if array.find(Section_stack, function(x) return x.name == section_name end) then
          while table.remove(Section_stack).name ~= section_name do
            --
          end
          line.section_end = true
          line.section_name = section_name
          line.data = nil
        end
        line.section_stack = table.shallowcopy(Section_stack)
      else
        -- string
        line.section_stack = table.shallowcopy(Section_stack)
      end
    else
      line.section_stack = {}
    end
  end
end

function table.shallowcopy(x)
  return {unpack(x)}
end

function log_browser.draw(State, hide_cursor)
  assert(#State.lines == #State.line_cache, ('line_cache is out of date; %d elements when it should be %d'):format(#State.line_cache, #State.lines))
  local mouse_line_index = log_browser.line_index(State, App.mouse_x(), App.mouse_y())
  local y = State.top
  for line_index = State.screen_top1.line,#State.lines do
    App.color(Text_color)
    local line = State.lines[line_index]
    if y + State.line_height > App.screen.height then break end
    local height = State.line_height
    if should_show(line) then
      local xleft = render_stack_left_margin(State, line_index, line, y)
      local xright = render_stack_right_margin(State, line_index, line, y)
      if line.section_name then
        App.color(Section_border_color)
        if line.section_begin then
          local sectiony = y+Section_border_padding_vertical
          love.graphics.line(xleft,sectiony, xleft,y+State.line_height)
          love.graphics.line(xright,sectiony, xright,y+State.line_height)
          love.graphics.line(xleft,sectiony, xleft+50-2,sectiony)
          love.graphics.print(line.section_name, xleft+50,y)
          love.graphics.line(xleft+50+App.width(line.section_name)+2,sectiony, xright,sectiony)
        else assert(line.section_end, "log line has a section name, but it's neither the start nor end of a section")
          local sectiony = y+State.line_height-Section_border_padding_vertical
          love.graphics.line(xleft,y, xleft,sectiony)
          love.graphics.line(xright,y, xright,sectiony)
          love.graphics.line(xleft,sectiony, xleft+50-2,sectiony)
          love.graphics.print(line.section_name, xleft+50,y)
          love.graphics.line(xleft+50+App.width(line.section_name)+2,sectiony, xright,sectiony)
        end
      else
        if type(line.data) == 'string' then
          local old_left, old_right = State.left,State.right
          State.left,State.right = xleft,xright
          Text.draw(State, line_index, y, --[[startpos]] 1, hide_cursor)
          State.left,State.right = old_left,old_right
        else
          height = log_render[line.data.name](line.data, xleft, y, xright-xleft)
        end
      end
      if App.mouse_x() > Log_browser_state.left and line_index == mouse_line_index then
        App.color(Cursor_line_background_color)
        love.graphics.rectangle('fill', xleft,y, xright-xleft, height)
      end
      y = y + height
    end
  end
end

function render_stack_left_margin(State, line_index, line, y)
  if line.section_stack == nil then
    -- assertion message
    for k,v in pairs(line) do
      print(k)
    end
  end
  App.color(Section_border_color)
  for i=1,#line.section_stack do
    local x = State.left + (i-1)*Section_border_padding_horizontal
    love.graphics.line(x,y, x,y+log_browser.height(State, line_index))
    if y < 30 then
      love.graphics.print(line.section_stack[i].name, x+State.font_height+5, y+5, --[[vertically]] math.pi/2)
    end
    if y > App.screen.height-log_browser.height(State, line_index) then
      love.graphics.print(line.section_stack[i].name, x+State.font_height+5, App.screen.height-App.width(line.section_stack[i].name)-5, --[[vertically]] math.pi/2)
    end
  end
  return log_browser.left_margin(State, line)
end

function render_stack_right_margin(State, line_index, line, y)
  App.color(Section_border_color)
  for i=1,#line.section_stack do
    local x = State.right - (i-1)*Section_border_padding_horizontal
    love.graphics.line(x,y, x,y+log_browser.height(State, line_index))
    if y < 30 then
      love.graphics.print(line.section_stack[i].name, x, y+5, --[[vertically]] math.pi/2)
    end
    if y > App.screen.height-log_browser.height(State, line_index) then
      love.graphics.print(line.section_stack[i].name, x, App.screen.height-App.width(line.section_stack[i].name)-5, --[[vertically]] math.pi/2)
    end
  end
  return log_browser.right_margin(State, line)
end

function should_show(line)
  -- Show a line if every single section it's in is expanded.
  for i=1,#line.section_stack do
    local section = line.section_stack[i]
    if not section.expanded then
      return false
    end
  end
  return true
end

function log_browser.left_margin(State, line)
  return State.left + #line.section_stack*Section_border_padding_horizontal
end

function log_browser.right_margin(State, line)
  return State.right - #line.section_stack*Section_border_padding_horizontal
end

function log_browser.update(State, dt)
end

function log_browser.quit(State)
end

function log_browser.mouse_press(State, x,y, mouse_button)
  local line_index = log_browser.line_index(State, x,y)
  if line_index == nil then
    -- below lower margin
    return
  end
  -- leave some space to click without focusing
  local line = State.lines[line_index]
  local xleft = log_browser.left_margin(State, line)
  local xright = log_browser.right_margin(State, line)
  if x < xleft or x > xright then
    return
  end
  -- if it's a section begin/end and the section is collapsed, expand it
  -- TODO: how to collapse?
  if line.section_begin or line.section_end then
    -- HACK: get section reference from next/previous line
    local new_section
    if line.section_begin then
      if line_index < #State.lines then
        local next_section_stack = State.lines[line_index+1].section_stack
        if next_section_stack then
          new_section = next_section_stack[#next_section_stack]
        end
      end
    elseif line.section_end then
      if line_index > 1 then
        local previous_section_stack = State.lines[line_index-1].section_stack
        if previous_section_stack then
          new_section = previous_section_stack[#previous_section_stack]
        end
      end
    end
    if new_section and new_section.expanded == nil then
      new_section.expanded = true
      return
    end
  end
  -- open appropriate file in source side
  if line.filename ~= Editor_state.filename then
    source.switch_to_file(line.filename)
  end
  -- set cursor
  Editor_state.cursor1 = {line=line.line_number, pos=1}
  -- make sure it's visible
  -- TODO: handle extremely long lines
  Editor_state.screen_top1.line = math.max(0, Editor_state.cursor1.line-5)
  -- show cursor
  Focus = 'edit'
end

function log_browser.line_index(State, mx,my)
  -- duplicate some logic from log_browser.draw
  local y = State.top
  for line_index = State.screen_top1.line,#State.lines do
    local line = State.lines[line_index]
    if should_show(line) then
      y = y + log_browser.height(State, line_index)
      if my < y then
        return line_index
      end
      if y > App.screen.height then break end
    end
  end
end

function log_browser.mouse_release(State, x,y, mouse_button)
end

function log_browser.mouse_wheel_move(State, dx,dy)
  if dy > 0 then
    for i=1,math.floor(dy) do
      log_browser.up(State)
    end
  elseif dy < 0 then
    for i=1,math.floor(-dy) do
      log_browser.down(State)
    end
  end
end

function log_browser.text_input(State, t)
end

function log_browser.keychord_press(State, chord, key)
  -- move
  if chord == 'up' then
    log_browser.up(State)
  elseif chord == 'down' then
    log_browser.down(State)
  elseif chord == 'pageup' then
    local y = 0
    while State.screen_top1.line > 1 and y < App.screen.height - 100 do
      State.screen_top1.line = State.screen_top1.line - 1
      if should_show(State.lines[State.screen_top1.line]) then
        y = y + log_browser.height(State, State.screen_top1.line)
      end
    end
  elseif chord == 'pagedown' then
    local y = 0
    while State.screen_top1.line < #State.lines and y < App.screen.height - 100 do
      if should_show(State.lines[State.screen_top1.line]) then
        y = y + log_browser.height(State, State.screen_top1.line)
      end
      State.screen_top1.line = State.screen_top1.line + 1
    end
  end
end

function log_browser.up(State)
  while State.screen_top1.line > 1 do
    State.screen_top1.line = State.screen_top1.line-1
    if should_show(State.lines[State.screen_top1.line]) then
      break
    end
  end
end

function log_browser.down(State)
  while State.screen_top1.line < #State.lines do
    State.screen_top1.line = State.screen_top1.line+1
    if should_show(State.lines[State.screen_top1.line]) then
      break
    end
  end
end

function log_browser.height(State, line_index)
  local line = State.lines[line_index]
  if line.data == nil then
    -- section header
    return State.line_height
  elseif type(line.data) == 'string' then
    return State.line_height
  else
    if line.height == nil then
--?       print('nil line height! rendering off screen to calculate')
      line.height = log_render[line.data.name](line.data, State.left, App.screen.height, State.right-State.left)
    end
    return line.height
  end
end

function log_browser.key_release(State, key, scancode)
end
