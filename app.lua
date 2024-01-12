-- love.run: main entrypoint function for LÖVE
--
-- Most apps can just use the default shown in https://love2d.org/wiki/love.run,
-- but we need to override it to:
--   * recover from errors (by switching to the source editor)
--   * run all tests (functions starting with 'test_') on startup, and
--   * save some state that makes it possible to switch between the main app
--     and a source editor, while giving each the illusion of complete
--     control.
function love.run()
  Version, Major_version = App.love_version()
  App.snapshot_love()
  -- Tests always run at the start.
  App.run_tests_and_initialize()
--?   print('==')

  love.timer.step()
  local dt = 0

  return function()
    if love.event then
      love.event.pump()
      for name, a,b,c,d,e,f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            return a or 0
          end
        end
        xpcall(function() love.handlers[name](a,b,c,d,e,f) end, handle_error)
      end
    end

    dt = love.timer.step()
    xpcall(function() App.update(dt) end, handle_error)

    love.graphics.origin()
    love.graphics.clear(love.graphics.getBackgroundColor())
    xpcall(App.draw, handle_error)
    love.graphics.present()

    love.timer.sleep(0.001)
  end
end

function handle_error(err)
  local callstack = debug.traceback('', --[[stack frame]]2)
  Error_message = 'Error: ' .. tostring(err)..'\n'..cleaned_up_callstack(callstack)
  print(Error_message)
  if Current_app == 'run' then
    Settings.current_app = 'source'
    love.filesystem.write('config', json.encode(Settings))
    load_file_from_source_or_save_directory('main.lua')
    App.undo_initialize()
    App.run_tests_and_initialize()
  else
    -- abort without running love.quit handler
    Disable_all_quit_handlers = true
    love.event.quit()
  end
end

-- I tend to read code from files myself (say using love.filesystem calls)
-- rather than offload that to load().
-- Functions compiled in this manner have ugly filenames of the form [string "filename"]
-- This function cleans out this cruft from error callstacks.
function cleaned_up_callstack(callstack)
  local frames = {}
  for frame in string.gmatch(callstack, '[^\n]+\n*') do
    local line = frame:gsub('^%s*(.-)\n?$', '%1')
    local filename, rest = line:match('([^:]*):(.*)')
    local core_filename = filename:match('^%[string "(.*)"%]$')
    -- pass through frames that don't match this format
    -- this includes the initial line "stack traceback:"
    local new_frame = (core_filename or filename)..':'..rest
    table.insert(frames, new_frame)
  end
  -- the initial "stack traceback:" line was unindented and remains so
  return table.concat(frames, '\n\t')
end

-- The rest of this file wraps around various LÖVE primitives to support
-- automated tests. Often tests will run with a fake version of a primitive
-- that redirects to the real love.* version once we're done with tests.
--
-- Not everything is so wrapped yet. Sometimes you still have to use love.*
-- primitives directly.

App = {}

function App.love_version()
  local major_version, minor_version = love.getVersion()
  local version = major_version..'.'..minor_version
  return version, major_version
end

-- save/restore various framework globals we care about -- only on very first load
function App.snapshot_love()
  if Love_snapshot then return end
  Love_snapshot = {}
  -- save the entire initial font; it doesn't seem reliably recreated using newFont
  Love_snapshot.initial_font = love.graphics.getFont()
end

function App.undo_initialize()
  love.graphics.setFont(Love_snapshot.initial_font)
end

function App.run_tests_and_initialize()
  App.load()
  Test_errors = {}
  App.run_tests()
  if #Test_errors > 0 then
    local error_message = ''
    if Warning_before_tests then
      error_message = Warning_before_tests..'\n\n'
    end
    error_message = error_message .. ('There were %d test failures:\n%s'):format(#Test_errors, table.concat(Test_errors))
    error(error_message)
  end
  App.disable_tests()
  App.initialize_globals()
  App.initialize(love.arg.parseGameArguments(arg), arg)
end

function App.run_tests()
  local sorted_names = {}
  for name,binding in pairs(_G) do
    if name:find('test_') == 1 then
      table.insert(sorted_names, name)
    end
  end
  table.sort(sorted_names)
  for _,name in ipairs(sorted_names) do
    App.initialize_for_test()
--?     print('=== '..name)
--?     _G[name]()
    xpcall(_G[name], function(err) prepend_debug_info_to_test_failure(name, err) end)
  end
  -- clean up all test methods
  for _,name in ipairs(sorted_names) do
    _G[name] = nil
  end
end

function App.initialize_for_test()
  App.screen.init{width=100, height=50}
  App.screen.contents = {}  -- clear screen
  App.filesystem = {}
  App.source_dir = ''
  App.current_dir = ''
  App.save_dir = ''
  App.fake_keys_pressed = {}
  App.fake_mouse_state = {x=-1, y=-1}
  App.initialize_globals()
end

-- App.screen.resize and App.screen.move seem like better names than
-- love.window.setMode and love.window.setPosition respectively. They'll
-- be side-effect-free during tests, and they'll save their results in
-- attributes of App.screen for easy access.

App.screen={}

-- Use App.screen.init in tests to initialize the fake screen.
function App.screen.init(dims)
  App.screen.width = dims.width
  App.screen.height = dims.height
end

function App.screen.resize(width, height, flags)
  App.screen.width = width
  App.screen.height = height
  App.screen.flags = flags
end

function App.screen.size()
  return App.screen.width, App.screen.height, App.screen.flags
end

function App.screen.move(x,y, displayindex)
  App.screen.x = x
  App.screen.y = y
  App.screen.displayindex = displayindex
end

function App.screen.position()
  return App.screen.x, App.screen.y, App.screen.displayindex
end

-- If you use App.screen.print instead of love.graphics.print,
-- tests will be able to check what was printed using App.screen.check below.
--
-- One drawback of this approach: the y coordinate used depends on font size,
-- which feels brittle.

function App.screen.print(msg, x,y)
  local screen_row = 'y'..tostring(y)
--?   print('drawing "'..msg..'" at y '..tostring(y))
  local screen = App.screen
  if screen.contents[screen_row] == nil then
    screen.contents[screen_row] = {}
    for i=0,screen.width-1 do
      screen.contents[screen_row][i] = ''
    end
  end
  if x < screen.width then
    screen.contents[screen_row][x] = msg
  end
end

function App.screen.check(y, expected_contents, msg)
--?   print('checking for "'..expected_contents..'" at y '..tostring(y))
  local screen_row = 'y'..tostring(y)
  local contents = ''
  if App.screen.contents[screen_row] == nil then
    error('no text at y '..tostring(y))
  end
  for i,s in ipairs(App.screen.contents[screen_row]) do
    contents = contents..s
  end
  check_eq(contents, expected_contents, msg)
end

-- If you access the time using App.get_time instead of love.timer.getTime,
-- tests will be able to move the time back and forwards as needed using
-- App.wait_fake_time below.

App.time = 1
function App.get_time()
  return App.time
end
function App.wait_fake_time(t)
  App.time = App.time + t
end

function App.width(text)
  return love.graphics.getFont():getWidth(text)
end

-- If you access the clipboard using App.get_clipboard and App.set_clipboard
-- instead of love.system.getClipboardText and love.system.setClipboardText
-- respectively, tests will be able to manipulate the clipboard by
-- reading/writing App.clipboard.

App.clipboard = ''
function App.get_clipboard()
  return App.clipboard
end
function App.set_clipboard(s)
  App.clipboard = s
end

-- In tests I mostly send chords all at once to the keyboard handlers.
-- However, you'll occasionally need to check if a key is down outside a handler.
-- If you use App.key_down instead of love.keyboard.isDown, tests will be able to
-- simulate keypresses using App.fake_key_press and App.fake_key_release
-- below. This isn't very realistic, though, and it's up to tests to
-- orchestrate key presses that correspond to the handlers they invoke.

App.fake_keys_pressed = {}
function App.key_down(key)
  return App.fake_keys_pressed[key]
end

function App.fake_key_press(key)
  App.fake_keys_pressed[key] = true
end
function App.fake_key_release(key)
  App.fake_keys_pressed[key] = nil
end

-- Tests mostly will invoke mouse handlers directly. However, you'll
-- occasionally need to check if a mouse button is down outside a handler.
-- If you use App.mouse_down instead of love.mouse.isDown, tests will be able to
-- simulate mouse clicks using App.fake_mouse_press and App.fake_mouse_release
-- below. This isn't very realistic, though, and it's up to tests to
-- orchestrate presses that correspond to the handlers they invoke.

App.fake_mouse_state = {x=-1, y=-1}  -- x,y always set

function App.mouse_move(x,y)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
end
function App.mouse_down(mouse_button)
  return App.fake_mouse_state[mouse_button]
end
function App.mouse_x()
  return App.fake_mouse_state.x
end
function App.mouse_y()
  return App.fake_mouse_state.y
end

function App.fake_mouse_press(x,y, mouse_button)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
  App.fake_mouse_state[mouse_button] = true
end
function App.fake_mouse_release(x,y, mouse_button)
  App.fake_mouse_state.x = x
  App.fake_mouse_state.y = y
  App.fake_mouse_state[mouse_button] = nil
end

-- If you use App.open_for_reading and App.open_for_writing instead of other
-- various Lua and LÖVE helpers, tests will be able to check the results of
-- file operations inside the App.filesystem table.

function App.open_for_reading(filename)
  if App.filesystem[filename] then
    return {
      lines = function(self)
                return App.filesystem[filename]:gmatch('[^\n]+')
              end,
      read = function(self)
               return App.filesystem[filename]
             end,
      close = function(self)
              end,
    }
  end
end

function App.read_file(filename)
  return App.filesystem[filename]
end

function App.open_for_writing(filename)
  App.filesystem[filename] = ''
  return {
    write = function(self, s)
              App.filesystem[filename] = App.filesystem[filename]..s
            end,
    close = function(self)
            end,
  }
end

function App.write_file(filename, contents)
  App.filesystem[filename] = contents
  return --[[status]] true
end

function App.mkdir(dirname)
  -- nothing in test mode
end

function App.remove(filename)
  App.filesystem[filename] = nil
end

-- Some helpers to trigger an event and then refresh the screen. Akin to one
-- iteration of the event loop.

-- all textinput events are also keypresses
-- TODO: handle chords of multiple keys
function App.run_after_textinput(t)
  App.keypressed(t)
  App.textinput(t)
  App.keyreleased(t)
  App.screen.contents = {}
  App.draw()
end

-- not all keys are textinput
-- TODO: handle chords of multiple keys
function App.run_after_keychord(chord)
  App.keychord_press(chord)
  App.keyreleased(chord)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_click(x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  App.mousepressed(x,y, mouse_button)
  App.fake_mouse_release(x,y, mouse_button)
  App.mousereleased(x,y, mouse_button)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_press(x,y, mouse_button)
  App.fake_mouse_press(x,y, mouse_button)
  App.mousepressed(x,y, mouse_button)
  App.screen.contents = {}
  App.draw()
end

function App.run_after_mouse_release(x,y, mouse_button)
  App.fake_mouse_release(x,y, mouse_button)
  App.mousereleased(x,y, mouse_button)
  App.screen.contents = {}
  App.draw()
end

-- miscellaneous internal helpers

function App.color(color)
  love.graphics.setColor(color.r, color.g, color.b, color.a)
end

-- prepend file/line/test
function prepend_debug_info_to_test_failure(test_name, err)
  local err_without_line_number = err:gsub('^[^:]*:[^:]*: ', '')
  local stack_trace = debug.traceback('', --[[stack frame]]5)
  local file_and_line_number = stack_trace:gsub('stack traceback:\n', ''):gsub(': .*', '')
  local full_error = file_and_line_number..':'..test_name..' -- '..err_without_line_number
--?   local full_error = file_and_line_number..':'..test_name..' -- '..err_without_line_number..'\t\t'..stack_trace:gsub('\n', '\n\t\t')
  table.insert(Test_errors, full_error)
end

nativefs = require 'nativefs'

local Keys_down = {}

-- call this once all tests are run
-- can't run any tests after this
function App.disable_tests()
  -- have LÖVE delegate all handlers to App if they exist
  -- make sure to late-bind handlers like LÖVE's defaults do
  for name in pairs(love.handlers) do
    if App[name] then
      -- love.keyboard.isDown doesn't work on Android, so emulate it using
      -- keypressed and keyreleased events
      if name == 'keypressed' then
        love.handlers[name] = function(key, scancode, isrepeat)
                                Keys_down[key] = true
                                return App.keypressed(key, scancode, isrepeat)
                              end
      elseif name == 'keyreleased' then
        love.handlers[name] = function(key, scancode)
                                Keys_down[key] = nil
                                return App.keyreleased(key, scancode)
                              end
      else
        love.handlers[name] = function(...) App[name](...) end
      end
    end
  end

  -- test methods are disallowed outside tests
  App.run_tests = nil
  App.disable_tests = nil
  App.screen.init = nil
  App.filesystem = nil
  App.time = nil
  App.run_after_textinput = nil
  App.run_after_keychord = nil
  App.keypress = nil
  App.keyrelease = nil
  App.run_after_mouse_click = nil
  App.run_after_mouse_press = nil
  App.run_after_mouse_release = nil
  App.fake_keys_pressed = nil
  App.fake_key_press = nil
  App.fake_key_release = nil
  App.fake_mouse_state = nil
  App.fake_mouse_press = nil
  App.fake_mouse_release = nil
  -- other methods dispatch to real hardware
  App.screen.resize = love.window.setMode
  App.screen.size = love.window.getMode
  App.screen.move = love.window.setPosition
  App.screen.position = love.window.getPosition
  App.screen.print = love.graphics.print
  App.open_for_reading =
      function(filename)
        local result = nativefs.newFile(filename)
        local ok, err = result:open('r')
        if ok then
          return result
        else
          return ok, err
        end
      end
  App.read_file =
      function(path)
        if not is_absolute_path(path) then
          return --[[status]] false, 'Please use an unambiguous absolute path.'
        end
        local f, err = App.open_for_reading(path)
        if err then
          return --[[status]] false, err
        end
        local contents = f:read()
        f:close()
        return contents
      end
  App.open_for_writing =
      function(filename)
        local result = nativefs.newFile(filename)
        local ok, err = result:open('w')
        if ok then
          return result
        else
          return ok, err
        end
      end
  App.write_file =
      function(path, contents)
        if not is_absolute_path(path) then
          return --[[status]] false, 'Please use an unambiguous absolute path.'
        end
        local f, err = App.open_for_writing(path)
        if err then
          return --[[status]] false, err
        end
        f:write(contents)
        f:close()
        return --[[status]] true
      end
  App.files = nativefs.getDirectoryItems
  App.file_info = nativefs.getInfo
  App.mkdir = nativefs.createDirectory
  App.remove = nativefs.remove
  App.source_dir = love.filesystem.getSource()..'/'  -- '/' should work even on Windows
  App.current_dir = nativefs.getWorkingDirectory()..'/'
  App.save_dir = love.filesystem.getSaveDirectory()..'/'
  App.get_time = love.timer.getTime
  App.get_clipboard = love.system.getClipboardText
  App.set_clipboard = love.system.setClipboardText
  App.key_down = function(key) return Keys_down[key] end
  App.mouse_move = love.mouse.setPosition
  App.mouse_down = love.mouse.isDown
  App.mouse_x = love.mouse.getX
  App.mouse_y = love.mouse.getY
end
