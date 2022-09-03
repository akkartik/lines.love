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
      add_hotkey_to_menu('ctrl+b: collapse debug prints')
    else
      add_hotkey_to_menu('ctrl+b: expand debug prints')
    end
    add_hotkey_to_menu('ctrl+d: create/edit debug print')
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
  if Text_cache[s] == nil then
    Text_cache[s] = App.newText(love.graphics.getFont(), s)
  end
  local width = App.width(Text_cache[s])
  if Menu_cursor + width > App.screen.width - 5 then
    return
  end
  App.color(Menu_command_color)
  App.screen.draw(Text_cache[s], Menu_cursor,5)
  Menu_cursor = Menu_cursor + width + 30
end

function source.draw_file_navigator()
  for i,file in ipairs(File_navigation.candidates) do
    if file == 'source' then
      App.color(Menu_border_color)
      love.graphics.line(Menu_cursor-10,2, Menu_cursor-10,Menu_status_bar_height-2)
    end
    add_file_to_menu(file, i == File_navigation.index)
  end
end

function add_file_to_menu(s, cursor_highlight)
  if Text_cache[s] == nil then
    Text_cache[s] = App.newText(love.graphics.getFont(), s)
  end
  local width = App.width(Text_cache[s])
  if Menu_cursor + width > App.screen.width - 5 then
    return
  end
  if cursor_highlight then
    App.color(Menu_highlight_color)
    love.graphics.rectangle('fill', Menu_cursor-5,5-2, App.width(Text_cache[s])+5*2,Editor_state.line_height+2*2)
  end
  App.color(Menu_command_color)
  App.screen.draw(Text_cache[s], Menu_cursor,5)
  Menu_cursor = Menu_cursor + width + 30
end

function keychord_pressed_on_file_navigator(chord, key)
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
  end
end
