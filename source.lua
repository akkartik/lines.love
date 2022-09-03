source = {}

Editor_state = {}

-- called both in tests and real run
function source.initialize_globals()
  -- tests currently mostly clear their own state

  Show_log_browser_side = false
  Focus = 'edit'
  Show_file_navigator = false
  File_navigation = {
    candidates = {
      'run',
      'run_tests',
      'log',
      'edit',
      'text',
      'search',
      'select',
      'undo',
      'text_tests',
      'file',
      'source',
      'source_tests',
      'commands',
      'log_browser',
      'source_edit',
      'source_text',
      'source_undo',
      'colorize',
      'source_text_tests',
      'source_file',
      'main',
      'button',
      'keychord',
      'app',
      'test',
      'json',
    },
    index = 1,
  }

  Menu_status_bar_height = nil  -- initialized below

  -- a few text objects we can avoid recomputing unless the font changes
  Text_cache = {}

  -- blinking cursor
  Cursor_time = 0
end

-- called only for real run
function source.initialize()
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if Settings and Settings.source then
    source.load_settings()
  else
    source.initialize_default_settings()
  end

  source.initialize_edit_side{'run.lua'}
  source.initialize_log_browser_side()

  Menu_status_bar_height = 5 + Editor_state.line_height + 5
  Editor_state.top = Editor_state.top + Menu_status_bar_height
  Log_browser_state.top = Log_browser_state.top + Menu_status_bar_height
end

-- environment for a mutable file of bifolded text
-- TODO: some initialization is also happening in load_settings/initialize_default_settings. Clean that up.
function source.initialize_edit_side(arg)
  if #arg > 0 then
    Editor_state.filename = arg[1]
    load_from_disk(Editor_state)
    Text.redraw_all(Editor_state)
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
  else
    load_from_disk(Editor_state)
    Text.redraw_all(Editor_state)
  end

  if #arg > 1 then
    print('ignoring commandline args after '..arg[1])
  end

  -- We currently start out with side B collapsed.
  -- Other options:
  --  * save all expanded state by line
  --  * expand all if any location is in side B
  if Editor_state.cursor1.line > #Editor_state.lines then
    Editor_state.cursor1 = {line=1, pos=1}
  end
  if Editor_state.screen_top1.line > #Editor_state.lines then
    Editor_state.screen_top1 = {line=1, pos=1}
  end
  edit.eradicate_locations_after_the_fold(Editor_state)

  if rawget(_G, 'jit') then
    jit.off()
    jit.flush()
  end
end

function source.load_settings()
  local settings = Settings.source
  love.graphics.setFont(love.graphics.newFont(settings.font_height))
  -- maximize window to determine maximum allowable dimensions
  love.window.setMode(0, 0)  -- maximize
  Display_width, Display_height, App.screen.flags = love.window.getMode()
  -- set up desired window dimensions
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(Display_width, 200)
  App.screen.flags.minheight = math.min(Display_height, 200)
  App.screen.width, App.screen.height = settings.width, settings.height
--?   print('setting window from settings:', App.screen.width, App.screen.height)
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
--?   print('loading source position', settings.x, settings.y, settings.displayindex)
  source.set_window_position_from_settings(settings)
  Show_log_browser_side = settings.show_log_browser_side
  local right = App.screen.width - Margin_right
  if Show_log_browser_side then
    right = App.screen.width/2 - Margin_right
  end
  Editor_state = edit.initialize_state(Margin_top, Margin_left, right, settings.font_height, math.floor(settings.font_height*1.3))
  Editor_state.filename = settings.filename
  Editor_state.screen_top1 = settings.screen_top
  Editor_state.cursor1 = settings.cursor
end

function source.set_window_position_from_settings(settings)
  -- setPosition doesn't quite seem to do what is asked of it on Linux.
  love.window.setPosition(settings.x, settings.y-37, settings.displayindex)
end

function source.initialize_default_settings()
  local font_height = 20
  love.graphics.setFont(love.graphics.newFont(font_height))
  local em = App.newText(love.graphics.getFont(), 'm')
  source.initialize_window_geometry(App.width(em))
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right)
  Editor_state.font_height = font_height
  Editor_state.line_height = math.floor(font_height*1.3)
  Editor_state.em = em
end

function source.initialize_window_geometry(em_width)
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  Display_width, Display_height, App.screen.flags = love.window.getMode()
  -- shrink height slightly to account for window decoration
  App.screen.height = Display_height-100
  App.screen.width = 40*em_width
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.width, 200)
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
  print('initializing source position')
  if Settings == nil then Settings = {} end
  if Settings.source == nil then Settings.source = {} end
  Settings.source.x, Settings.source.y, Settings.source.displayindex = love.window.getPosition()
end

function source.resize(w, h)
--?   print(("Window resized to width: %d and height: %d."):format(w, h))
  App.screen.width, App.screen.height = w, h
  Text.redraw_all(Editor_state)
  Editor_state.selection1 = {}  -- no support for shift drag while we're resizing
  if Show_log_browser_side then
    Editor_state.right = App.screen.width/2 - Margin_right
  else
    Editor_state.right = App.screen.width-Margin_right
  end
  Log_browser_state.left = App.screen.width/2 + Margin_right
  Log_browser_state.right = App.screen.width-Margin_right
  Editor_state.width = Editor_state.right-Editor_state.left
  Text.tweak_screen_top_and_cursor(Editor_state, Editor_state.left, Editor_state.right)
--?   print('end resize')
end

function source.filedropped(file)
  -- first make sure to save edits on any existing file
  if Editor_state.next_save then
    save_to_disk(Editor_state)
  end
  -- clear the slate for the new file
  Editor_state.filename = file:getFilename()
  file:open('r')
  Editor_state.lines = load_from_file(file)
  file:close()
  Text.redraw_all(Editor_state)
  Editor_state.screen_top1 = {line=1, pos=1}
  Editor_state.cursor1 = {line=1, pos=1}
end

-- a copy of source.filedropped when given a filename
function source.switch_to_file(filename)
  -- first make sure to save edits on any existing file
  if Editor_state.next_save then
    save_to_disk(Editor_state)
  end
  -- clear the slate for the new file
  Editor_state.filename = filename
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  Editor_state.screen_top1 = {line=1, pos=1}
  Editor_state.cursor1 = {line=1, pos=1}
end

function source.draw()
  source.draw_menu_bar()
  edit.draw(Editor_state)
  if Show_log_browser_side then
    -- divider
    App.color(Divider_color)
    love.graphics.rectangle('fill', App.screen.width/2-1,Menu_status_bar_height, 3,App.screen.height)
    --
    log_browser.draw(Log_browser_state)
  end
end

function source.update(dt)
  Cursor_time = Cursor_time + dt
  if App.mouse_x() < Editor_state.right then
    edit.update(Editor_state, dt)
  elseif Show_log_browser_side then
    log_browser.update(Log_browser_state, dt)
  end
end

function source.quit()
  edit.quit(Editor_state)
  log_browser.quit(Log_browser_state)
  -- convert any bifold files here
end

function source.convert_bifold_text(infilename, outfilename)
  local contents = love.filesystem.read(infilename)
  contents = contents:gsub('\u{1e}', ';')
  love.filesystem.write(outfilename, contents)
end

function source.settings()
  if Current_app == 'source' then
--?     print('reading source window position')
    Settings.source.x, Settings.source.y, Settings.source.displayindex = love.window.getPosition()
  end
  local filename = Editor_state.filename
  if filename:sub(1,1) ~= '/' then
    filename = love.filesystem.getWorkingDirectory()..'/'..filename  -- '/' should work even on Windows
  end
--?   print('saving source settings', Settings.source.x, Settings.source.y, Settings.source.displayindex)
  return {
    x=Settings.source.x, y=Settings.source.y, displayindex=Settings.source.displayindex,
    width=App.screen.width, height=App.screen.height,
    font_height=Editor_state.font_height,
    filename=filename,
    screen_top=Editor_state.screen_top1, cursor=Editor_state.cursor1,
    show_log_browser_side=Show_log_browser_side,
    focus=Focus,
  }
end

function source.mouse_pressed(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
--?   print('mouse click', x, y)
--?   print(Editor_state.left, Editor_state.right)
--?   print(Log_browser_state.left, Log_browser_state.right)
  if Editor_state.left <= x and x < Editor_state.right then
--?     print('click on edit side')
    if Focus ~= 'edit' then
      Focus = 'edit'
    end
    edit.mouse_pressed(Editor_state, x,y, mouse_button)
  elseif Show_log_browser_side and Log_browser_state.left <= x and x < Log_browser_state.right then
--?     print('click on log_browser side')
    if Focus ~= 'log_browser' then
      Focus = 'log_browser'
    end
    log_browser.mouse_pressed(Log_browser_state, x,y, mouse_button)
    for _,line_cache in ipairs(Editor_state.line_cache) do line_cache.starty = nil end  -- just in case we scroll
  end
end

function source.mouse_released(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.mouse_released(Editor_state, x,y, mouse_button)
  else
    return log_browser.mouse_released(Log_browser_state, x,y, mouse_button)
  end
end

function source.textinput(t)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.textinput(Editor_state, t)
  else
    return log_browser.textinput(Log_browser_state, t)
  end
end

function source.keychord_pressed(chord, key)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
--?   print('source keychord')
  if Show_file_navigator then
    keychord_pressed_on_file_navigator(chord, key)
    return
  end
  if chord == 'C-l' then
--?     print('C-l')
    Show_log_browser_side = not Show_log_browser_side
    if Show_log_browser_side then
      App.screen.width = Log_browser_state.right + Margin_right
    else
      App.screen.width = Editor_state.right + Margin_right
    end
--?     print('setting window:', App.screen.width, App.screen.height)
    love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
--?     print('done setting window')
    -- try to restore position if possible
    -- if the window gets wider the window manager may not respect this
    source.set_window_position_from_settings(Settings.source)
    return
  end
  if chord == 'C-g' then
    Show_file_navigator = true
    File_navigation.index = 1
    return
  end
  if Focus == 'edit' then
    return edit.keychord_pressed(Editor_state, chord, key)
  else
    return log_browser.keychord_pressed(Log_browser_state, chord, key)
  end
end

function source.key_released(key, scancode)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.key_released(Editor_state, key, scancode)
  else
    return log_browser.keychord_pressed(Log_browser_state, chordkey, scancode)
  end
end

-- use this sparingly
function to_text(s)
  if Text_cache[s] == nil then
    Text_cache[s] = App.newText(love.graphics.getFont(), s)
  end
  return Text_cache[s]
end
