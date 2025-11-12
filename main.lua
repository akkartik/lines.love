-- Entrypoint for the app. You can edit this file from within the app if
-- you're careful.

-- files that come with LÖVE; we can't edit those from within the app
utf8 = require 'utf8'

function load_file_from_source_or_save_directory(filename)
  local contents = love.filesystem.read(filename)
  local code, err = loadstring(contents, filename)
  if code == nil then
    error(err)
  end
  return code()
end

json = load_file_from_source_or_save_directory('json.lua')

load_file_from_source_or_save_directory('app.lua')
load_file_from_source_or_save_directory('test.lua')

load_file_from_source_or_save_directory('keychord.lua')
load_file_from_source_or_save_directory('button.lua')

-- both sides require (different parts of) the logging framework
load_file_from_source_or_save_directory('log.lua')

-- both sides use drawings
load_file_from_source_or_save_directory('icons.lua')
load_file_from_source_or_save_directory('drawing.lua')
  load_file_from_source_or_save_directory('geom.lua')
  load_file_from_source_or_save_directory('help.lua')
load_file_from_source_or_save_directory('drawing_tests.lua')

-- but some files we want to only load sometimes
function App.load()
  log_new('session')
  if love.filesystem.getInfo('config') then
    Settings = json.decode(love.filesystem.read('config'))
    Current_app = Settings.current_app
  end

  -- Current_app =
  --  | run
  --  | source
  --  | {name=warning message='...' next_app = run|source}

  if Current_app == nil then
    Current_app = 'run'
  end

  if Current_app == 'run' then
    load_file_from_source_or_save_directory('file.lua')
    load_file_from_source_or_save_directory('run.lua')
      load_file_from_source_or_save_directory('edit.lua')
      load_file_from_source_or_save_directory('text.lua')
        load_file_from_source_or_save_directory('search.lua')
        load_file_from_source_or_save_directory('select.lua')
        load_file_from_source_or_save_directory('undo.lua')
      load_file_from_source_or_save_directory('text_tests.lua')
    load_file_from_source_or_save_directory('run_tests.lua')
  elseif Current_app == 'source' then
    load_file_from_source_or_save_directory('source_file.lua')
    load_file_from_source_or_save_directory('source.lua')
      load_file_from_source_or_save_directory('commands.lua')
      load_file_from_source_or_save_directory('source_edit.lua')
      load_file_from_source_or_save_directory('log_browser.lua')
      load_file_from_source_or_save_directory('source_text.lua')
        load_file_from_source_or_save_directory('search.lua')
        load_file_from_source_or_save_directory('source_select.lua')
        load_file_from_source_or_save_directory('source_undo.lua')
        load_file_from_source_or_save_directory('colorize.lua')
      load_file_from_source_or_save_directory('source_text_tests.lua')
    load_file_from_source_or_save_directory('source_tests.lua')
  elseif current_app_is_warning() then
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.initialize_globals()
  Supported_versions = {'11.5', '11.4', '12.0'}  -- put the recommended version first
  check_love_version_for_tests()

  OS = love.system.getOS()

  if Current_app == 'run' then
    run.initialize_globals()
  elseif Current_app == 'source' then
    source.initialize_globals()
  elseif current_app_is_warning() then
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end

  -- for hysteresis in a few places
  Current_time = 0
  Last_focus_time = 0  -- https://love2d.org/forums/viewtopic.php?p=249700
  Last_resize_time = 0

  -- Another weird bit for a class of corner cases. E.g.:
  -- * I press ctrl+e, switch Current_app. I don't want the new app to receive
  --   text_input and key_release events.
  -- If I try to avoid text_input events by switching modes on key_release, I
  -- hit a new problem:
  -- * I press ctrl+e, am running an untested version, Current_app goes to
  --   'warning', and immediately rolls back out of 'warning' in the
  --   key_release event.
  -- Skip_rest_of_key_events is ugly, but feels cleaner than creating yet
  -- another possible value for Current_app.
  Skip_rest_of_key_events = nil
end

function check_love_version_for_tests()
  if array.find(Supported_versions, Version) == nil then
    -- warning to include in an error message if any tests failed
    Warning_before_tests = ("This app hasn't been tested with LÖVE version %s."):format(Version)
  end
end

function App.initialize(arg, unfiltered_arg)
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if Current_app == 'run' then
    run.initialize(arg, unfiltered_arg)
  elseif Current_app == 'source' then
    source.initialize(arg, unfiltered_arg)
  elseif current_app_is_warning() then
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end

  check_love_version()
end

function check_love_version()
  if array.find(Supported_versions, Version) == nil then
    show_warning(
      ("This app hasn't been tested with LÖVE version %s; please switch to version %s if you run into issues. Press any key to continue."):format(Version, Supported_versions[1]))
    -- continue initializing everything; hopefully we won't have errors during initialization
  end
end

function App.resize(w,h)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.resize then run.resize(w,h) end
  elseif Current_app == 'source' then
    if source.resize then source.resize(w,h) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
  Last_resize_time = Current_time
end

function App.filedropped(file)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.file_drop then run.file_drop(file) end
  elseif Current_app == 'source' then
    if source.file_drop then source.file_drop(file) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.focus(in_focus)
  if current_app_is_warning() then return end
  if in_focus then
    Last_focus_time = Current_time
  end
  if Current_app == 'run' then
    if run.focus then run.focus(in_focus) end
  elseif Current_app == 'source' then
    if source.focus then source.focus(in_focus) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.draw()
  if Current_app == 'run' then
    run.draw()
  elseif Current_app == 'source' then
    source.draw()
  elseif current_app_is_warning() then
    love.graphics.setColor(0,0,1)
    love.graphics.rectangle('fill', 0,0, App.screen.width, App.screen.height)
    love.graphics.setColor(1,1,1)
    love.graphics.printf(Current_app.message, 40,40, 600)
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.update(dt)
  Current_time = Current_time + dt
  if current_app_is_warning() then return end
  -- some hysteresis while resizing
  if Current_time < Last_resize_time + 0.1 then
    return
  end
  --
  if Current_app == 'run' then
    run.update(dt)
  elseif Current_app == 'source' then
    source.update(dt)
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.keychord_press(chord, key, scancode, is_repeat)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  Skip_rest_of_key_events = nil
  if current_app_is_warning() then
    if chord == 'C-c' then
      love.system.setClipboardText(warning_message())
    else
      clear_warning()
      Skip_rest_of_key_events = true
    end
    return
  end
  if chord == 'C-e' then
    -- carefully save settings
    if Current_app == 'run' then
      local source_settings = Settings.source
      Settings = run.settings()
      Settings.source = source_settings
      if run.quit then run.quit() end
      Current_app = 'source'
      -- preserve any Error_message when going from run to source
    elseif Current_app == 'source' then
      Settings.source = source.settings()
      if source.quit then source.quit() end
      Current_app = 'run'
      Error_message = nil
    elseif current_app_is_warning() then
    else
      assert(false, 'unknown app "'..Current_app..'"')
    end
    Settings.current_app = Current_app
    love.filesystem.write('config', json.encode(Settings))
    -- reboot
    load_file_from_source_or_save_directory('main.lua')
    App.undo_initialize()
    App.run_tests_and_initialize()
    Skip_rest_of_key_events = true
    return
  end
  if Current_app == 'run' then
    if run.keychord_press then run.keychord_press(chord, key, scancode, is_repeat) end
  elseif Current_app == 'source' then
    if source.keychord_press then source.keychord_press(chord, key, scancode, is_repeat) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.textinput(t)
  if current_app_is_warning() then return end
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  if Skip_rest_of_key_events then return end
  if Current_app == 'run' then
    if run.text_input then run.text_input(t) end
  elseif Current_app == 'source' then
    if source.text_input then source.text_input(t) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.keyreleased(key, scancode)
  if current_app_is_warning() then return end
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  if Skip_rest_of_key_events then return end
  if Current_app == 'run' then
    if run.key_release then run.key_release(key, scancode) end
  elseif Current_app == 'source' then
    if source.key_release then source.key_release(key, scancode) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousepressed(x,y, mouse_button, is_touch, presses)
  if current_app_is_warning() then return end
--?   print('mouse press', x,y)
  if Current_app == 'run' then
    if run.mouse_press then run.mouse_press(x,y, mouse_button, is_touch, presses) end
  elseif Current_app == 'source' then
    if source.mouse_press then source.mouse_press(x,y, mouse_button, is_touch, presses) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousereleased(x,y, mouse_button, is_touch, presses)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.mouse_release then run.mouse_release(x,y, mouse_button, is_touch, presses) end
  elseif Current_app == 'source' then
    if source.mouse_release then source.mouse_release(x,y, mouse_button, is_touch, presses) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousemoved(x,y, dx,dy, is_touch)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.mouse_move then run.mouse_move(x,y, dx,dy, is_touch) end
  elseif Current_app == 'source' then
    if source.mouse_move then source.mouse_move(x,y, dx,dy, is_touch) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.wheelmoved(dx,dy)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.mouse_wheel_move then run.mouse_wheel_move(dx,dy) end
  elseif Current_app == 'source' then
    if source.mouse_wheel_move then source.mouse_wheel_move(dx,dy) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousefocus(in_focus)
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    if run.mouse_focus then run.mouse_focus(in_focus) end
  elseif Current_app == 'source' then
    if source.mouse_focus then source.mouse_focus(in_focus) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function love.quit()
  if Disable_all_quit_handlers then return end
  if current_app_is_warning() then return end
  if Current_app == 'run' then
    local source_settings = Settings.source
    Settings = run.settings()
    Settings.source = source_settings
  else
    Settings.source = source.settings()
  end
  Settings.current_app = Current_app
  love.filesystem.write('config', json.encode(Settings))
  if Current_app == 'run' then
    if run.quit then run.quit() end
  elseif Current_app == 'source' then
    if source.quit then source.quit() end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function current_app_is_warning()
  return type(Current_app) == 'table' and Current_app.name == 'warning'
end

function show_warning(message)
  assert(type(Current_app) == 'string')
  Current_app = {
    name = 'warning',
    message = message,
    next_app = Current_app,
  }
end

function clear_warning()
  assert(type(Current_app) == 'table')
  Current_app = Current_app.next_app
end

function warning_message()
  assert(type(Current_app) == 'table')
  return Current_app.message
end
