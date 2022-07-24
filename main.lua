utf8 = require 'utf8'

require 'app'
require 'test'

require 'keychord'
require 'button'

require 'main_tests'

-- delegate most business logic to a layer that can be reused by other projects
require 'edit'
Editor_state = {}

-- called both in tests and real run
function App.initialize_globals()
  -- tests currently mostly clear their own state

  -- resize
  Last_resize_time = nil

  -- blinking cursor
  Cursor_time = 0
end

-- called only for real run
function App.initialize(arg)
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if love.filesystem.getInfo('config') then
    load_settings()
  else
    initialize_default_settings()
  end

  if #arg > 0 then
    Editor_state.filename = arg[1]
    Editor_state.lines = load_from_disk(Editor_state.filename)
    Text.redraw_all(Editor_state)
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
    edit.fixup_cursor(Editor_state)
  else
    Editor_state.lines = load_from_disk(Editor_state.filename)
    Text.redraw_all(Editor_state)
    edit.fixup_cursor(Editor_state)
  end
  love.window.setTitle('lines.love - '..Editor_state.filename)

  if #arg > 1 then
    print('ignoring commandline args after '..arg[1])
  end

  if rawget(_G, 'jit') then
    jit.off()
    jit.flush()
  end
end

function load_settings()
  local settings = json.decode(love.filesystem.read('config'))
  love.graphics.setFont(love.graphics.newFont(settings.font_height))
  -- maximize window to determine maximum allowable dimensions
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  -- set up desired window dimensions
  love.window.setPosition(settings.x, settings.y, settings.displayindex)
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.width, 200)
  App.screen.width, App.screen.height = settings.width, settings.height
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right, settings.font_height, math.floor(settings.font_height*1.3))
  Editor_state.filename = settings.filename
  Editor_state.screen_top1 = settings.screen_top
  Editor_state.cursor1 = settings.cursor
end

function initialize_default_settings()
  local font_height = 20
  love.graphics.setFont(love.graphics.newFont(font_height))
  local em = App.newText(love.graphics.getFont(), 'm')
  initialize_window_geometry(App.width(em))
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right)
  Editor_state.font_height = font_height
  Editor_state.line_height = math.floor(font_height*1.3)
  Editor_state.em = em
end

function initialize_window_geometry(em_width)
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  -- shrink height slightly to account for window decoration
  App.screen.height = App.screen.height-100
  App.screen.width = 40*em_width
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.width, 200)
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
end

function App.resize(w, h)
--?   print(("Window resized to width: %d and height: %d."):format(w, h))
  App.screen.width, App.screen.height = w, h
  Text.redraw_all(Editor_state)
  Editor_state.selection1 = {}  -- no support for shift drag while we're resizing
  Editor_state.right = App.screen.width-Margin_right
  Editor_state.width = Editor_state.right-Editor_state.left
  Text.tweak_screen_top_and_cursor(Editor_state, Editor_state.left, Editor_state.right)
  Last_resize_time = App.getTime()
end

function App.filedropped(file)
  -- first make sure to save edits on any existing file
  if Editor_state.next_save then
    save_to_disk(Editor_state.lines, Editor_state.filename)
  end
  -- clear the slate for the new file
  App.initialize_globals()  -- in particular, forget all undo history
  Editor_state.filename = file:getFilename()
  file:open('r')
  Editor_state.lines = load_from_file(file)
  file:close()
  for i,line in ipairs(Editor_state.lines) do
    if line.mode == 'text' then
      Editor_state.cursor1.line = i
      break
    end
  end
  love.window.setTitle('Text with Editor_state.lines - '..Editor_state.filename)
end

function App.draw()
  Button_handlers = {}
  edit.draw(Editor_state)
end

function App.update(dt)
  Cursor_time = Cursor_time + dt
  -- some hysteresis while resizing
  if Last_resize_time then
    if App.getTime() - Last_resize_time < 0.1 then
      return
    else
      Last_resize_time = nil
    end
  end
  edit.update(Editor_state, dt)
end

function love.quit()
  edit.quit(Editor_state)
  -- save some important settings
  local x,y,displayindex = love.window.getPosition()
  local filename = Editor_state.filename
  if filename:sub(1,1) ~= '/' then
    filename = love.filesystem.getWorkingDirectory()..'/'..filename  -- '/' should work even on Windows
  end
  local settings = {
    x=x, y=y, displayindex=displayindex,
    width=App.screen.width, height=App.screen.height,
    font_height=Editor_state.font_height,
    filename=filename,
    screen_top=Editor_state.screen_top1, cursor=Editor_state.cursor1}
  love.filesystem.write('config', json.encode(settings))
end

function App.mousepressed(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.mouse_pressed(Editor_state, x,y, mouse_button)
end

function App.mousereleased(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.mouse_released(Editor_state, x,y, mouse_button)
end

function App.textinput(t)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.textinput(Editor_state, t)
end

function App.keychord_pressed(chord, key)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.keychord_pressed(Editor_state, chord, key)
end

function App.keyreleased(key, scancode)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.key_released(Editor_state, key, scancode)
end
