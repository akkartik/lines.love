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

-- but some files we want to only load sometimes
function App.load()
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
      load_file_from_source_or_save_directory('icons.lua')
      load_file_from_source_or_save_directory('text_tests.lua')
    load_file_from_source_or_save_directory('run_tests.lua')
    load_file_from_source_or_save_directory('drawing.lua')
      load_file_from_source_or_save_directory('geom.lua')
      load_file_from_source_or_save_directory('help.lua')
    load_file_from_source_or_save_directory('drawing_tests.lua')
  else
    load_file_from_source_or_save_directory('source_file.lua')
    load_file_from_source_or_save_directory('source.lua')
      load_file_from_source_or_save_directory('commands.lua')
      load_file_from_source_or_save_directory('source_edit.lua')
      load_file_from_source_or_save_directory('log_browser.lua')
      load_file_from_source_or_save_directory('source_text.lua')
        load_file_from_source_or_save_directory('search.lua')
        load_file_from_source_or_save_directory('select.lua')
        load_file_from_source_or_save_directory('source_undo.lua')
        load_file_from_source_or_save_directory('colorize.lua')
      load_file_from_source_or_save_directory('source_text_tests.lua')
    load_file_from_source_or_save_directory('source_tests.lua')
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
  Last_focus_time = App.getTime()  -- https://love2d.org/forums/viewtopic.php?p=249700
  Last_resize_time = App.getTime()
end

function App.initialize(arg)
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
  Last_resize_time = App.getTime()
end

function App.filedropped(file)
  if Current_app == 'run' then
    if run.filedropped then run.filedropped(file) end
  elseif Current_app == 'source' then
    if source.filedropped then source.filedropped(file) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.focus(in_focus)
  if in_focus then
    Last_focus_time = App.getTime()
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
  -- some hysteresis while resizing
  if App.getTime() < Last_resize_time + 0.1 then
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

function App.keychord_pressed(chord, key)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if App.getTime() < Last_focus_time + 0.01 then
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
    if run.keychord_pressed then run.keychord_pressed(chord, key) end
  elseif Current_app == 'source' then
    if source.keychord_pressed then source.keychord_pressed(chord, key) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.textinput(t)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if App.getTime() < Last_focus_time + 0.01 then
    return
  end
  --
  if Current_app == 'run' then
    if run.textinput then run.textinput(t) end
  elseif Current_app == 'source' then
    if source.textinput then source.textinput(t) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.keyreleased(chord, key)
  -- ignore events for some time after window in focus (mostly alt-tab)
  if App.getTime() < Last_focus_time + 0.01 then
    return
  end
  --
  if Current_app == 'run' then
    if run.key_released then run.key_released(chord, key) end
  elseif Current_app == 'source' then
    if source.key_released then source.key_released(chord, key) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousepressed(x,y, mouse_button)
--?   print('mouse press', x,y)
  if Current_app == 'run' then
    if run.mouse_pressed then run.mouse_pressed(x,y, mouse_button) end
  elseif Current_app == 'source' then
    if source.mouse_pressed then source.mouse_pressed(x,y, mouse_button) end
  else
    assert(false, 'unknown app "'..Current_app..'"')
  end
end

function App.mousereleased(x,y, mouse_button)
  if Current_app == 'run' then
    if run.mouse_released then run.mouse_released(x,y, mouse_button) end
  elseif Current_app == 'source' then
    if source.mouse_released then source.mouse_released(x,y, mouse_button) end
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
