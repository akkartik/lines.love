-- Wrapper that combines the app with a 'source editor' that allows editing
-- the app in place.
--
-- The source editor is a sharp tool. I find it convenient, but I also often
-- end up in a bad state that requires dropping down to external tools
-- (editor, file manager) to fix.
--
-- Downstream forks provide a better, "freewheeling" experience for editing
-- apps live. The source editor provides a half-baked experience for editing
-- some of the primitives used by true freewheeling apps.

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
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.initialize_globals()
  if Current_app == 'run' then
    run.initialize_globals()
  elseif Current_app == 'source' then
    source.initialize_globals()
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end

  -- for hysteresis in a few places
  Current_time = 0
  Last_focus_time = 0  -- https://love2d.org/forums/viewtopic.php?p=249700
  Last_resize_time = 0
end

function App.initialize(arg)
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if Current_app == 'run' then
    run.initialize(arg)
  elseif Current_app == 'source' then
    source.initialize(arg)
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.resize(w,h)
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
  if Current_app == 'run' then
    if run.file_drop then run.file_drop(file) end
  elseif Current_app == 'source' then
    if source.file_drop then source.file_drop(file) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.focus(in_focus)
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
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.update(dt)
  Current_time = Current_time + dt
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

function App.keychord_press(chord, key)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  if chord == 'C-e' then
    -- carefully save settings
    if Current_app == 'run' then
      local source_settings = Settings.source
      Settings = run.settings()
      Settings.source = source_settings
      if run.quit then run.quit() end
      Current_app = 'source'
    elseif Current_app == 'source' then
      Settings.source = source.settings()
      if source.quit then source.quit() end
      Current_app = 'run'
    else
      assert(false, 'unknown app "'..Current_app..'"')
    end
    Settings.current_app = Current_app
    love.filesystem.write('config', json.encode(Settings))
    -- reboot
    load_file_from_source_or_save_directory('main.lua')
    App.undo_initialize()
    App.run_tests_and_initialize()
    return
  end
  if Current_app == 'run' then
    if run.keychord_press then run.keychord_press(chord, key) end
  elseif Current_app == 'source' then
    if source.keychord_press then source.keychord_press(chord, key) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.textinput(t)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  if Current_app == 'run' then
    if run.text_input then run.text_input(t) end
  elseif Current_app == 'source' then
    if source.text_input then source.text_input(t) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.keyreleased(key, scancode)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if Current_time < Last_focus_time + 0.01 then
    return
  end
  --
  if Current_app == 'run' then
    if run.key_release then run.key_release(key, scancode) end
  elseif Current_app == 'source' then
    if source.key_release then source.key_release(key, scancode) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousepressed(x,y, mouse_button)
--?   print('mouse press', x,y)
  if Current_app == 'run' then
    if run.mouse_press then run.mouse_press(x,y, mouse_button) end
  elseif Current_app == 'source' then
    if source.mouse_press then source.mouse_press(x,y, mouse_button) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousereleased(x,y, mouse_button)
  if Current_app == 'run' then
    if run.mouse_release then run.mouse_release(x,y, mouse_button) end
  elseif Current_app == 'source' then
    if source.mouse_release then source.mouse_release(x,y, mouse_button) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.wheelmoved(dx,dy)
  if Current_app == 'run' then
    if run.mouse_wheel_move then run.mouse_wheel_move(dx,dy) end
  elseif Current_app == 'source' then
    if source.mouse_wheel_move then source.mouse_wheel_move(dx,dy) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function love.quit()
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
