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
  return edit.initialize_globals()
end

-- called only for real run
function App.initialize(arg)
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if love.filesystem.getInfo('config') then
    load_settings()
  else
    load_defaults()
  end

  if #arg > 0 then
    Filename = arg[1]
    Lines = load_from_disk(Filename)
    Screen_top1 = {line=1, pos=1}
    Cursor1 = {line=1, pos=1}
    for i,line in ipairs(Lines) do
      if line.mode == 'text' then
        Cursor1.line = i
        break
      end
    end
  else
    Lines = load_from_disk(Filename)
    if Cursor1.line > #Lines or Lines[Cursor1.line].mode ~= 'text' then
      for i,line in ipairs(Lines) do
        if line.mode == 'text' then
          Cursor1.line = i
          break
        end
      end
    end
  end
  love.window.setTitle('lines.love - '..Filename)

  if #arg > 1 then
    print('ignoring commandline args after '..arg[1])
  end

  if rawget(_G, 'jit') then
    jit.off()
    jit.flush()
  end
end

function load_settings()
  -- maximize window to determine maximum allowable dimensions
  love.window.setMode(0, 0)  -- maximize
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  --
  local settings = json.decode(love.filesystem.read('config'))
  love.window.setPosition(settings.x, settings.y, settings.displayindex)
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.width, 200)
  App.screen.width, App.screen.height = settings.width, settings.height
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
  Filename = settings.filename
  initialize_font_settings(settings.font_height)
  Screen_top1 = settings.screen_top
  Cursor1 = settings.cursor
end

function load_defaults()
  initialize_font_settings(20)
  initialize_window_geometry()
end

function initialize_window_geometry()
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  -- shrink slightly to account for window decoration
  App.screen.width = 40*App.width(Em)
  App.screen.height = App.screen.height-100
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.width, 200)
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
end

function App.resize(w, h)
--?   print(("Window resized to width: %d and height: %d."):format(w, h))
  App.screen.width, App.screen.height = w, h
  Text.redraw_all()
  Selection1 = {}  -- no support for shift drag while we're resizing
  Text.tweak_screen_top_and_cursor(Margin_left, App.screen.height-Margin_right)
  Last_resize_time = App.getTime()
end

function initialize_font_settings(font_height)
  Font_height = font_height
  love.graphics.setFont(love.graphics.newFont(Font_height))
  Line_height = math.floor(font_height*1.3)

  Em = App.newText(love.graphics.getFont(), 'm')
end

function App.filedropped(file)
  -- first make sure to save edits on any existing file
  if Next_save then
    save_to_disk(Lines, Filename)
  end
  -- clear the slate for the new file
  App.initialize_globals()  -- in particular, forget all undo history
  Filename = file:getFilename()
  file:open('r')
  Lines = load_from_file(file)
  file:close()
  for i,line in ipairs(Lines) do
    if line.mode == 'text' then
      Cursor1.line = i
      break
    end
  end
  love.window.setTitle('Text with Lines - '..Filename)
end

function App.draw()
  Button_handlers = {}
  edit.draw()
end

function App.update(dt)
  edit.update(dt)
end

function love.quit()
  edit.quit()
  -- save some important settings
  local x,y,displayindex = love.window.getPosition()
  local filename = Filename
  if filename:sub(1,1) ~= '/' then
    filename = love.filesystem.getWorkingDirectory()..'/'..filename  -- '/' should work even on Windows
  end
  local settings = {
    x=x, y=y, displayindex=displayindex,
    width=App.screen.width, height=App.screen.height,
    font_height=Font_height,
    filename=filename,
    screen_top=Screen_top1, cursor=Cursor1}
  love.filesystem.write('config', json.encode(settings))
end

function App.mousepressed(x,y, mouse_button)
  return edit.mouse_pressed(x,y, mouse_button)
end

function App.mousereleased(x,y, mouse_button)
  return edit.mouse_released(x,y, mouse_button)
end

function App.textinput(t)
  return edit.textinput(t)
end

function App.keychord_pressed(chord, key)
  return edit.keychord_pressed(chord, key)
end

function App.keyreleased(key, scancode)
  return edit.key_released(key, scancode)
end
