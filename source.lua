-- Source editor that lets me edit the app from within. However, it's a sharp
-- tool. I find it convenient, but I also often end up in a bad state that
-- requires dropping down to external tools (editor, file manager) to fix.
--
-- Downstream forks provide a better, "freewheeling" experience for editing
-- apps live. The source editor provides a half-baked experience for editing
-- some of the primitives used by true freewheeling apps.
source = {}

Editor_state = {}

-- called both in tests and real run
function source.initialize_globals()
  -- tests currently mostly clear their own state

  Show_log_browser_side = false
  Focus = 'edit'
  Show_file_navigator = false
  File_navigation = {
    all_candidates = {
      'run',
      'run_tests',
      'log',
      'edit',
      'drawing',
      'help',
      'text',
      'search',
      'select',
      'undo',
      'text_tests',
      'geom',
      'drawing_tests',
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
    filter = '',
    cursors = {},  -- filename to cursor1, screen_top1
  }
  File_navigation.candidates = File_navigation.all_candidates  -- modified with filter

  Menu_status_bar_height = 5 + --[[line height in tests]] 15 + 5

  -- blinking cursor
  Cursor_time = 0
end

-- called only for real run
function source.initialize()
  log_new('source')
  if Settings and Settings.source then
    source.load_settings()
  else
    source.initialize_default_settings()
  end

  source.initialize_edit_side()
  source.initialize_log_browser_side()

  Menu_status_bar_height = 5 + Editor_state.line_height + 5
  Editor_state.top = Editor_state.top + Menu_status_bar_height
  Log_browser_state.top = Log_browser_state.top + Menu_status_bar_height



  -- keep a few blank lines around: https://merveilles.town/@akkartik/110084833821965708
  love.window.setTitle('lines.love - source')



end

-- environment for a mutable file
-- TODO: some initialization is also happening in load_settings/initialize_default_settings. Clean that up.
function source.initialize_edit_side()
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  if File_navigation.cursors[Editor_state.filename] then
    Editor_state.screen_top1 = File_navigation.cursors[Editor_state.filename].screen_top1
    Editor_state.cursor1 = File_navigation.cursors[Editor_state.filename].cursor1
  else
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
  end
  edit.check_locs(Editor_state)

  if Editor_state.cursor1.line > #Editor_state.lines then
    Editor_state.cursor1 = {line=1, pos=1}
  end
  if Editor_state.screen_top1.line > #Editor_state.lines then
    Editor_state.screen_top1 = {line=1, pos=1}
  end

  if rawget(_G, 'jit') then
    jit.off()
    jit.flush()
  end
end

function source.load_settings()
  local settings = Settings.source
  love.graphics.setFont(love.graphics.newFont(settings.font_height))
  source.resize_window_from_settings(settings)
--?   print('loading source position', settings.x, settings.y, settings.displayindex)
  source.set_window_position_from_settings(settings)
  Show_log_browser_side = settings.show_log_browser_side
  local right = App.screen.width - Margin_right
  if Show_log_browser_side then
    right = App.screen.width/2 - Margin_right
  end
  Editor_state = edit.initialize_state(Margin_top, Margin_left, right, settings.font_height, math.floor(settings.font_height*1.3))
  Editor_state.filename = settings.filename
  Editor_state.filename = basename(Editor_state.filename)  -- migrate settings that used full paths; we now support only relative paths within the app
  if settings.cursors then
    File_navigation.cursors = settings.cursors
    Editor_state.screen_top1 = File_navigation.cursors[Editor_state.filename].screen_top1
    Editor_state.cursor1 = File_navigation.cursors[Editor_state.filename].cursor1
  else
    -- migrate old settings
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
  end
end

function source.resize_window_from_settings(settings)
  local os = love.system.getOS()
  if os == 'Android' or os == 'iOS' then
    -- maximizing on iOS breaks text rendering: https://github.com/deltadaedalus/vudu/issues/7
    -- no point second-guessing window dimensions on mobile
    App.screen.width, App.screen.height, App.screen.flags = App.screen.size()
    return
  end
  -- maximize window to determine maximum allowable dimensions
  App.screen.resize(0, 0)  -- maximize
  Display_width, Display_height, App.screen.flags = App.screen.size()
  -- set up desired window dimensions
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(Display_width, 200)
  App.screen.flags.minheight = math.min(Display_height, 200)
  App.screen.width, App.screen.height = settings.width, settings.height
--?   print('setting window from settings:', App.screen.width, App.screen.height)
  App.screen.resize(App.screen.width, App.screen.height, App.screen.flags)
end

function source.set_window_position_from_settings(settings)
  -- love.window.setPosition doesn't quite seem to do what is asked of it on Linux.
  App.screen.move(settings.x, settings.y-37, settings.displayindex)
end

function source.initialize_default_settings()
  local font_height = 20
  love.graphics.setFont(love.graphics.newFont(font_height))
  source.initialize_window_geometry(App.width('m'))
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right)
  Editor_state.filename = 'run.lua'
  Editor_state.font_height = font_height
  Editor_state.line_height = math.floor(font_height*1.3)
end

function source.initialize_window_geometry(em_width)
  local os = love.system.getOS()
  if os == 'Android' or os == 'iOS' then
    -- maximizing on iOS breaks text rendering: https://github.com/deltadaedalus/vudu/issues/7
    -- no point second-guessing window dimensions on mobile
    App.screen.width, App.screen.height, App.screen.flags = App.screen.size()
    return
  end
  -- maximize window
  App.screen.resize(0, 0)  -- maximize
  Display_width, Display_height, App.screen.flags = App.screen.size()
  -- shrink height slightly to account for window decoration
  App.screen.height = Display_height-100
  App.screen.width = 40*em_width
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.height, 200)
  App.screen.resize(App.screen.width, App.screen.height, App.screen.flags)
  print('initializing source position')
  if Settings == nil then Settings = {} end
  if Settings.source == nil then Settings.source = {} end
  Settings.source.x, Settings.source.y, Settings.source.displayindex = App.screen.position()
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

function source.file_drop(file)
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



  -- keep a few blank lines around: https://merveilles.town/@akkartik/110084833821965708
  love.window.setTitle('lines.love - source')



end

-- a copy of source.file_drop when given a filename
function source.switch_to_file(filename)
  -- first make sure to save edits on any existing file
  if Editor_state.next_save then
    save_to_disk(Editor_state)
  end
  -- save cursor position
  File_navigation.cursors[Editor_state.filename] = {cursor1=Editor_state.cursor1, screen_top1=Editor_state.screen_top1}
  -- clear the slate for the new file
  Editor_state.filename = filename
  load_from_disk(Editor_state)
  Text.redraw_all(Editor_state)
  if File_navigation.cursors[filename] then
    Editor_state.screen_top1 = File_navigation.cursors[filename].screen_top1
    Editor_state.cursor1 = File_navigation.cursors[filename].cursor1
  else
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
  end
end

function source.draw()
  edit.draw(Editor_state, --[[hide cursor?]] Show_file_navigator)
  if Show_log_browser_side then
    -- divider
    App.color(Divider_color)
    love.graphics.rectangle('fill', App.screen.width/2-1,Menu_status_bar_height, 3,App.screen.height)
    --
    log_browser.draw(Log_browser_state)
  end
  source.draw_menu_bar()
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
end

function source.settings()
  if Current_app == 'source' then
--?     print('reading source window position')
    Settings.source.x, Settings.source.y, Settings.source.displayindex = App.screen.position()
  end
--?   print('saving source settings', Settings.source.x, Settings.source.y, Settings.source.displayindex)
  File_navigation.cursors[Editor_state.filename] = {cursor1=Editor_state.cursor1, screen_top1=Editor_state.screen_top1}
  return {
    x=Settings.source.x, y=Settings.source.y, displayindex=Settings.source.displayindex,
    width=App.screen.width, height=App.screen.height,
    font_height=Editor_state.font_height,
    filename=Editor_state.filename,
    cursors=File_navigation.cursors,
    show_log_browser_side=Show_log_browser_side,
    focus=Focus,
  }
end

function source.mouse_press(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
--?   print('mouse click', x, y)
--?   print(Editor_state.left, Editor_state.right)
--?   print(Log_browser_state.left, Log_browser_state.right)
  if Show_file_navigator and y < Menu_status_bar_height + File_navigation.num_lines * Editor_state.line_height then
    -- send click to buttons
    edit.mouse_press(Editor_state, x,y, mouse_button)
    return
  end
  if x < Editor_state.right + Margin_right then
--?     print('click on edit side')
    if Focus ~= 'edit' then
      Focus = 'edit'
      return
    end
    edit.mouse_press(Editor_state, x,y, mouse_button)
  elseif Show_log_browser_side and Log_browser_state.left <= x and x < Log_browser_state.right then
--?     print('click on log_browser side')
    if Focus ~= 'log_browser' then
      Focus = 'log_browser'
      return
    end
    log_browser.mouse_press(Log_browser_state, x,y, mouse_button)
    for _,line_cache in ipairs(Editor_state.line_cache) do line_cache.starty = nil end  -- just in case we scroll
  end
end

function source.mouse_release(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.mouse_release(Editor_state, x,y, mouse_button)
  else
    return log_browser.mouse_release(Log_browser_state, x,y, mouse_button)
  end
end

function source.mouse_wheel_move(dx,dy)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.mouse_wheel_move(Editor_state, dx,dy)
  else
    return log_browser.mouse_wheel_move(Log_browser_state, dx,dy)
  end
end

function source.text_input(t)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Show_file_navigator then
    text_input_on_file_navigator(t)
    return
  end
  if Focus == 'edit' then
    return edit.text_input(Editor_state, t)
  else
    return log_browser.text_input(Log_browser_state, t)
  end
end

function source.keychord_press(chord, key)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
--?   print('source keychord')
  if Show_file_navigator then
    keychord_press_on_file_navigator(chord, key)
    return
  end
  if chord == 'C-l' then
--?     print('C-l')
    Show_log_browser_side = not Show_log_browser_side
    if Show_log_browser_side then
      App.screen.width = math.min(Display_width, App.screen.width*2)
      Editor_state.right = App.screen.width/2 - Margin_right
      Log_browser_state.left = App.screen.width/2 + Margin_left
      Log_browser_state.right = App.screen.width - Margin_right
    else
      App.screen.width = Editor_state.right + Margin_right
    end
--?     print('setting window:', App.screen.width, App.screen.height)
    App.screen.resize(App.screen.width, App.screen.height, App.screen.flags)
--?     print('done setting window')
    -- try to restore position if possible
    -- if the window gets wider the window manager may not respect this
    if not App.run_tests then
      source.set_window_position_from_settings(Settings.source)
    end
    return
  end
  if chord == 'C-k' then
    -- clear logs
    love.filesystem.remove('log')
    -- restart to reload state of logs on screen
    Settings.source = source.settings()
    source.quit()
    love.filesystem.write('config', json.encode(Settings))
    load_file_from_source_or_save_directory('main.lua')
    App.undo_initialize()
    App.run_tests_and_initialize()
    return
  end
  if chord == 'C-g' then
    Show_file_navigator = true
    return
  end
  if Focus == 'edit' then
    return edit.keychord_press(Editor_state, chord, key)
  else
    return log_browser.keychord_press(Log_browser_state, chord, key)
  end
end

function source.key_release(key, scancode)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  if Focus == 'edit' then
    return edit.key_release(Editor_state, key, scancode)
  else
    return log_browser.keychord_press(Log_browser_state, chordkey, scancode)
  end
end
