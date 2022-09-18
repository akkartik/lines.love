Menu_background_color = {r=0.6, g=0.8, b=0.6}
Menu_border_color = {r=0.6, g=0.7, b=0.6}
Menu_command_color = {r=0.2, g=0.2, b=0.2}
Menu_highlight_color = {r=0.5, g=0.7, b=0.3}

function source.draw_menu_bar()
  if App.run_tests then return end  -- disable in tests
  App.color(Menu_background_color)
  love.graphics.rectangle('fill', 0,0, App.screen.width, Menu_status_bar_height)
  App.color(Menu_border_color)
  love.graphics.rectangle('line', 0,0, App.screen.width, Menu_status_bar_height)
  App.color(Menu_command_color)
  Menu_cursor = 5
  if Show_file_navigator then
    source.draw_file_navigator()
    return
  end
  add_hotkey_to_menu('ctrl+e: run')
  if Focus == 'edit' then
    add_hotkey_to_menu('ctrl+g: switch file')
    if Show_log_browser_side then
      add_hotkey_to_menu('ctrl+l: hide log browser')
    else
      add_hotkey_to_menu('ctrl+l: show log browser')
    end
    if Editor_state.expanded then
      add_hotkey_to_menu('alt+b: collapse debug prints')
    else
      add_hotkey_to_menu('alt+b: expand debug prints')
    end
    add_hotkey_to_menu('alt+d: create/edit debug print')
    add_hotkey_to_menu('ctrl+f: find in file')
    add_hotkey_to_menu('alt+left alt+right: prev/next word')
  elseif Focus == 'log_browser' then
    -- nothing yet
  else
    assert(false, 'unknown focus "'..Focus..'"')
  end
  add_hotkey_to_menu('ctrl+z ctrl+y: undo/redo')
  add_hotkey_to_menu('ctrl+x ctrl+c ctrl+v: cut/copy/paste')
  add_hotkey_to_menu('ctrl+= ctrl+- ctrl+0: zoom')
end

function add_hotkey_to_menu(s)
  local s_text = to_text(s)
  local width = App.width(s_text)
  if Menu_cursor + width > App.screen.width - 5 then
    return
  end
  App.color(Menu_command_color)
  App.screen.draw(s_text, Menu_cursor,5)
  Menu_cursor = Menu_cursor + width + 30
end

function source.draw_file_navigator()
  if File_navigation.num_lines == nil then
    File_navigation.num_lines = source.num_lines_for_file_navigator()
  end
  App.color(Menu_background_color)
  love.graphics.rectangle('fill', 0,Menu_status_bar_height, App.screen.width, File_navigation.num_lines * Editor_state.line_height)
  local x,y = 5, Menu_status_bar_height
  for i,filename in ipairs(File_navigation.candidates) do
    if filename == 'source' then
      App.color(Menu_border_color)
      love.graphics.line(Menu_cursor-10,2, Menu_cursor-10,Menu_status_bar_height-2)
    end
    x,y = add_file_to_menu(x,y, filename, i == File_navigation.index)
    if Menu_cursor >= App.screen.width - 5 then
      break
    end
  end
end

function source.num_lines_for_file_navigator()
  local result = 1
  local x = 5
  for i,filename in ipairs(File_navigation.candidates) do
    local width = App.width(to_text(filename))
    if x + width > App.screen.width - 5 then
      result = result+1
      x = 5 + width
    else
      x = x + width + 30
    end
  end
  return result
end

function add_file_to_menu(x,y, s, cursor_highlight)
  local s_text = to_text(s)
  local width = App.width(s_text)
  if x + width > App.screen.width - 5 then
    y = y + Editor_state.line_height
    x = 5
  end
  if cursor_highlight then
    App.color(Menu_highlight_color)
    love.graphics.rectangle('fill', x-5,y-2, width+5*2,Editor_state.line_height+2*2)
  end
  App.color(Menu_command_color)
  App.screen.draw(s_text, x,y)
  x = x + width + 30
  return x,y
end

function keychord_pressed_on_file_navigator(chord, key)
  log(2, 'file navigator: '..chord)
  log(2, ('cursor initially at %d %s'):format(File_navigation.index, File_navigation.candidates[File_navigation.index]))
  if chord == 'escape' then
    Show_file_navigator = false
  elseif chord == 'return' then
    local candidate = guess_source(File_navigation.candidates[File_navigation.index]..'.lua')
    source.switch_to_file(candidate)
    Show_file_navigator = false
  elseif chord == 'left' then
    if File_navigation.index > 1 then
      File_navigation.index = File_navigation.index-1
    end
  elseif chord == 'right' then
    if File_navigation.index < #File_navigation.candidates then
      File_navigation.index = File_navigation.index+1
    end
  elseif chord == 'down' then
    file_navigator_down()
  elseif chord == 'up' then
    file_navigator_up()
  end
end

function file_navigator_up()
  local y, x, width = file_coord(File_navigation.index)
  local index = file_index(y-Editor_state.line_height, x, width)
  if index then
    File_navigation.index = index
  end
end

function file_navigator_down()
  local y, x, width = file_coord(File_navigation.index)
  local index = file_index(y+Editor_state.line_height, x, width)
  if index then
    File_navigation.index = index
  end
end

function file_coord(index)
  local y,x = Menu_status_bar_height, 5
  for i,filename in ipairs(File_navigation.candidates) do
    local width = App.width(to_text(filename))
    if x + width > App.screen.width - 5 then
      y = y + Editor_state.line_height
      x = 5
    end
    if i == index then
    return y, x, width
    end
    x = x + width + 30
  end
end

function file_index(fy, fx, fwidth)
  log_start('file index')
  log(2, ('for %d %d %d'):format(fy, fx, fwidth))
  local y,x = Menu_status_bar_height, 5
  local best_guess, best_guess_x, best_guess_width
  for i,filename in ipairs(File_navigation.candidates) do
    local width = App.width(to_text(filename))
    if x + width > App.screen.width - 5 then
      y = y + Editor_state.line_height
      x = 5
    end
    if y == fy then
      log(2, ('%d: correct row; considering %d %s %d %d'):format(y, i, filename, x, width))
      if best_guess == nil then
        log(2, 'nil')
        best_guess = i
        best_guess_x = x
        best_guess_width = width
      elseif math.abs(fx + fwidth/2 - x - width/2) < math.abs(fx + fwidth/2 - best_guess_x - best_guess_width/2) then
        best_guess = i
        best_guess_x = x
        best_guess_width = width
      end
      log(2, ('best guess now %d %s %d %d'):format(best_guess, File_navigation.candidates[best_guess], best_guess_x, best_guess_width))
    end
    x = x + width + 30
  end
  log_end('file index')
  return best_guess
end
