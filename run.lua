run = {}

Editor_state = {}

-- called both in tests and real run
function run.initialize_globals()
  -- tests currently mostly clear their own state

  -- a few text objects we can avoid recomputing unless the font changes
  Text_cache = {}

  -- blinking cursor
  Cursor_time = 0
end

-- called only for real run
function run.initialize(arg)
  log_new('run')
  love.keyboard.setTextInput(true)  -- bring up keyboard on touch screen
  love.keyboard.setKeyRepeat(true)

  love.graphics.setBackgroundColor(1,1,1)

  if Settings then
    run.load_settings()
  else
    run.initialize_default_settings()
  end

  if #arg > 0 then
    Editor_state.filename = arg[1]
    load_from_disk(Editor_state)
    Text.redraw_all(Editor_state)
    Editor_state.screen_top1 = {line=1, pos=1}
    Editor_state.cursor1 = {line=1, pos=1}
    edit.fixup_cursor(Editor_state)
  else
    load_from_disk(Editor_state)
    Text.redraw_all(Editor_state)
    if Editor_state.cursor1.line > #Editor_state.lines or Editor_state.lines[Editor_state.cursor1.line].mode ~= 'text' then
      edit.fixup_cursor(Editor_state)
    end
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

function run.load_settings()
  love.graphics.setFont(love.graphics.newFont(Settings.font_height))
  -- determine default dimensions and flags
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  -- set up desired window dimensions
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.height, 200)
  App.screen.width, App.screen.height = Settings.width, Settings.height
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
  love.window.setPosition(Settings.x, Settings.y, Settings.displayindex)
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right, Settings.font_height, math.floor(Settings.font_height*1.3))
  Editor_state.filename = Settings.filename
  Editor_state.screen_top1 = Settings.screen_top
  Editor_state.cursor1 = Settings.cursor
end

function run.initialize_default_settings()
  local font_height = 20
  love.graphics.setFont(love.graphics.newFont(font_height))
  local em = App.newText(love.graphics.getFont(), 'm')
  run.initialize_window_geometry(App.width(em))
  Editor_state = edit.initialize_state(Margin_top, Margin_left, App.screen.width-Margin_right)
  Editor_state.font_height = font_height
  Editor_state.line_height = math.floor(font_height*1.3)
  Editor_state.em = em
  Settings = run.settings()
end

function run.initialize_window_geometry(em_width)
  -- maximize window
  love.window.setMode(0, 0)  -- maximize
  App.screen.width, App.screen.height, App.screen.flags = love.window.getMode()
  -- shrink height slightly to account for window decoration
  App.screen.height = App.screen.height-100
  App.screen.width = 40*em_width
  App.screen.flags.resizable = true
  App.screen.flags.minwidth = math.min(App.screen.width, 200)
  App.screen.flags.minheight = math.min(App.screen.height, 200)
  love.window.setMode(App.screen.width, App.screen.height, App.screen.flags)
end

function run.resize(w, h)
--?   print(("Window resized to width: %d and height: %d."):format(w, h))
  App.screen.width, App.screen.height = w, h
  Text.redraw_all(Editor_state)
  Editor_state.selection1 = {}  -- no support for shift drag while we're resizing
  Editor_state.right = App.screen.width-Margin_right
  Editor_state.width = Editor_state.right-Editor_state.left
  Text.tweak_screen_top_and_cursor(Editor_state, Editor_state.left, Editor_state.right)
end

function run.file_drop(file)
  -- first make sure to save edits on any existing file
  if Editor_state.next_save then
    save_to_disk(Editor_state)
  end
  -- clear the slate for the new file
  App.initialize_globals()
  Editor_state.filename = file:getFilename()
  file:open('r')
  Editor_state.lines = load_from_file(file)
  file:close()
  Text.redraw_all(Editor_state)
  edit.fixup_cursor(Editor_state)
  love.window.setTitle('lines.love - '..Editor_state.filename)
end

function run.draw()
  edit.draw(Editor_state)
end

function run.update(dt)
  Cursor_time = Cursor_time + dt
  edit.update(Editor_state, dt)
end

function run.quit()
  edit.quit(Editor_state)
end

function run.settings()
  if Settings == nil then
    Settings = {}
  end
  if Current_app == 'run' then
    Settings.x, Settings.y, Settings.displayindex = love.window.getPosition()
  end
  local filename = Editor_state.filename
  if is_relative_path(filename) then
    filename = love.filesystem.getWorkingDirectory()..'/'..filename  -- '/' should work even on Windows
  end
  return {
    x=Settings.x, y=Settings.y, displayindex=Settings.displayindex,
    width=App.screen.width, height=App.screen.height,
    font_height=Editor_state.font_height,
    filename=filename,
    screen_top=Editor_state.screen_top1, cursor=Editor_state.cursor1
  }
end

function run.mouse_press(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.mouse_press(Editor_state, x,y, mouse_button)
end

function run.mouse_release(x,y, mouse_button)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.mouse_release(Editor_state, x,y, mouse_button)
end

function run.text_input(t)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.text_input(Editor_state, t)
end

function run.keychord_press(chord, key)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.keychord_press(Editor_state, chord, key)
end

function run.key_release(key, scancode)
  Cursor_time = 0  -- ensure cursor is visible immediately after it moves
  return edit.key_release(Editor_state, key, scancode)
end

-- use this sparingly
function to_text(s)
  if Text_cache[s] == nil then
    Text_cache[s] = App.newText(love.graphics.getFont(), s)
  end
  return Text_cache[s]
end
