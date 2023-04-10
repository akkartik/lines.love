# Some useful building blocks

Apps can be composed of a wide variety of building blocks that you
can use in your functions, including a small number of functions that get
automatically called for you as appropriate.

## Variables you can read

* `App.screen`
  * `width` and `height` -- integer dimensions for the app window in pixels.
  * `flags` -- some properties of the app window. See [`flags` in `love.graphics.getMode`](https://love2d.org/wiki/love.window.getMode)
    for details.

## Functions that get automatically called

* `App.initialize_globals()` -- called before running each test and also
  before the app starts up. As the name suggests, use this to initialize all
  your global variables to something consistent. I also find it useful to be
  able to see all my global variables in one place, and avoid defining
  top-level variables anywhere else (unless they're constants and never going
  to be modified).

* `App.initialize(arg)` -- called when app starts up after
  `App.initialize_globals`. Provides in `arg` an array of words typed in if
  you ran it from a terminal window.
  (Based on [LÖVE](https://love2d.org/wiki/love.load).)

* `App.quit()` -- called before the app shuts down.
  (Based on [LÖVE](https://love2d.org/wiki/love.quit).)

* `App.focus(start?)` -- called when the app starts or stops receiving
  keypresses. `start?` will be `true` when app starts receiving keypresses and
  `false` when keypresses move to another window.
  (Based on [LÖVE](https://love2d.org/wiki/love.focus).)

* `App.resize(w,h)` -- called when you resize the app window. Provides new
  window dimensions in `w` and `h`. Don't bother updating `App.screen.width`
  and `App.screen.height`, that will happen automatically before calling
  `on.resize`.
  (Based on [LÖVE](https://love2d.org/wiki/love.resize))

* `App.filedropped(file)` -- called when a file icon is dragged and dropped on
  the app window. Provides in `file` an object representing the file that was
  dropped, that will respond to the following messages:

    * `file:getFilename()` returning a string name
    * `file:read()` returning the entire file contents in a single string

  (Based on [LÖVE](https://love2d.org/wiki/love.filedropped).)

* `App.draw()` -- called to draw on the window, around 30 times a second.
  (Based on [LÖVE](https://love2d.org/wiki/love.draw).)

* `App.update(dt)` -- called after every call to `on.draw`. Make changes to
  your app's variables here rather than in `on.draw`. Provides in `dt` the
  time since the previous call to `on.update`, which can be useful for things
  like smooth animations.
  (Based on [LÖVE](https://love2d.org/wiki/love.update).)

* `App.mousepressed(x,y, mouse_button)` -- called when you press down on a
  mouse button. Provides in `x` and `y` the point on the screen at which the
  click occurred, and in `mouse_button` an integer id of the mouse button
  pressed.
  `1` is the primary mouse button (the left button on a right-handed mouse),
  `2` is the secondary button (the right button on a right-handed mouse),
  and `3` is the middle button. Further buttons are mouse-dependent.
  (Based on [LÖVE](https://love2d.org/wiki/love.mousepressed).)

* `App.mousereleased(x,y, mouse_button)` -- called when you release a mouse
  button. Provides the same arguments as `on.mouse_press()` above.
  (Based on [LÖVE](https://love2d.org/wiki/love.mousereleased).)

* `App.wheelmoved(dx,dy)` -- called when you use the scroll wheel on a mouse
  that has it. Provides in `dx` and `dy` an indication of how fast the wheel
  is being scrolled. Positive values for `dx` indicate movement to the right.
  Positive values for `dy` indicate upward movement.
  (Based on [LÖVE](https://love2d.org/wiki/love.wheelmoved).)

* `App.keychord_press(chord, key)` -- called when you press a key-combination.
  Provides in `key` a string name for the key most recently pressed ([valid
  values](https://love2d.org/wiki/KeyConstant)). Provides in `chord` a
  string representation of the current key combination, consisting of the key
  with the following prefixes:
    * `C-` if one of the `ctrl` keys is pressed,
    * `M-` if one of the `alt` keys is pressed,
    * `S-` if one of the `shift` keys is pressed, and
    * `s-` if the `windows`/`cmd`/`super` key is pressed.

* `App.textinput(t)` -- called when you press a key combination that yields
  (roughly) a printable character. For example, `shift` and `a` pressed
  together will call `on.textinput` with `A`.
  (Based on [LÖVE](https://love2d.org/wiki/love.textinput).)

* `App.keyrelease(key)` -- called when you press a key on the keyboard.
  Provides in `key` a string name for the key ([valid values](https://love2d.org/wiki/KeyConstant)).
  (Based on [LÖVE](https://love2d.org/wiki/love.keyreleased), including other
  variants.)

## Functions you can call

Everything in the [LÖVE](https://love2d.org/wiki/Main_Page) and
[Lua](https://www.lua.org/manual/5.1/manual.html) guides is available to you,
but here's a brief summary of the most useful primitives. Some primitives have
new, preferred names under the `App` namespace, often because these variants
are more testable. If you run them within a test you'll be able to make
assertions on their side-effects.

### regarding the app window

* `width, height, flags = App.screen.size()` -- returns the dimensions and
  some properties of the app window.
  (Based on [LÖVE](https://love2d.org/wiki/love.window.getMode).)

* `App.screen.resize(width, height, flags)` -- modify the size and properties
  of the app window. The OS may or may not act on the request.
  (Based on [LÖVE](https://love2d.org/wiki/love.window.setMode).)

* `x, y, displayindex = App.screen.position()` -- returns the coordinates and
  monitor index (if you have more than one monitor) for the top-left corner of
  the app window.
  (Based on [LÖVE](https://love2d.org/wiki/love.window.getPosition).)

* `App.screen.move(x, y, displayindex)` -- moves the app window so its
  top-left corner is at the specified coordinates of the specified monitor.
  The OS may or may not act on the request.
  (Based on [LÖVE](https://love2d.org/wiki/love.window.setPosition).)

### drawing to the app window

* `App.screen.print(text, x,y)` -- print the given `text` in the current font
  using the current color so its top-left corner is at the specified
  coordinates of the app window.
  (Based on [LÖVE](https://love2d.org/wiki/love.graphics.print).)

* `love.graphics.getFont()` -- returns a representation of the current font.
  (From [LÖVE](https://love2d.org/wiki/love.graphics.getFont).)

* `love.graphics.setFont(font)` -- switches the current font to `font`.
  (From [LÖVE](https://love2d.org/wiki/love.graphics.setFont).)

* `love.graphics.newFont(filename)` -- creates a font from the given font
  file.
  (From [LÖVE](https://love2d.org/wiki/love.graphics.newFont), including other
  variants.)

* `App.width(text)` returns the width of `text` in pixels when rendered using
  the current font.
  (Based on [LÖVE](https://love2d.org/wiki/Font:getWidth).)

* `App.color(color)` -- sets the current color based on the fields `r`, `g`,
  `b` and `a` (for opacity) of the table `color`.
  (Based on [LÖVE](https://love2d.org/wiki/love.graphics.setColor).)

* `love.graphics.line(x1,y1, x2,y2)` -- draws a line from (`x1`,`y1`) to
  (`x2`, `y2`) in the app window using the current color, clipping data for
  negative coordinates and coordinates outside (`App.screen.width`,
  `App.screen.height`)
  (From [LÖVE](https://love2d.org/wiki/love.graphics.line), including other
  variants.)

* `love.graphics.rectangle(mode, x, y, w, h)` -- draws a rectangle using the
  current color, with a top-left corner at (`x`, `y`), with dimensions `width`
  along the x axis and `height` along the y axis
  (though check out https://love2d.org/wiki/love.graphics for ways to scale
  and rotate shapes).
  `mode` is a string, either `'line'` (to draw just the outline) and `'fill'`.
  (From [LÖVE](https://love2d.org/wiki/love.graphics.circle), including other
  variants.)

* `love.graphics.circle(mode, x, y, r)` -- draws a circle using the current
  color, centered at (`x`, `y`) and with radius `r`.
  `mode` is a string, either `'line'` and `'fill'`.
  (From [LÖVE](https://love2d.org/wiki/love.graphics.circle), including other
  variants.)

* `love.graphics.arc(mode, x, y, r, angle1, angle2)` -- draws an arc of a
  circle using the current color, centered at (`x`, `y`) and with radius `r`.
  `mode` is a string, either `'line'` and `'fill'`.
  `angle1` and `angle2` are in [radians](https://en.wikipedia.org/wiki/Radian).
  (From [LÖVE](https://love2d.org/wiki/love.graphics.circle), including other
  variants.)

There's much more I could include here; check out [the LÖVE manual](https://love2d.org/wiki/love.graphics).

### mouse primitives

* `App.mouse_move(x, y)` -- sets the current position of the mouse to (`x`,
  `y`).
  (Based on [LÖVE](https://love2d.org/wiki/love.mouse.setPosition).)

* `App.mouse_down(mouse_button)` -- returns `true` if the button
  `mouse_button` is pressed. See `on.mouse_press` for `mouse_button` codes.
  (Based on [LÖVE](https://love2d.org/wiki/love.mouse.isDown).)

* `App.mouse_x()` -- returns the x coordinate of the current position of the
  mouse.
  (Based on [LÖVE](https://love2d.org/wiki/love.mouse.getX).)

* `App.mouse_y()` -- returns the x coordinate of the current position of the
  mouse.
  (Based on [LÖVE](https://love2d.org/wiki/love.mouse.getY).)

### keyboard primitives

* `App.modifier_down(key)` -- returns `true` if the given key (doesn't
  actually have to be just a modifier) is currently pressed.
  (Based on [LÖVE](https://love2d.org/wiki/love.keyboard.isDown).)

### interacting with files

* `App.open_for_reading(filename)` -- returns a file handle that you can
  [`read()`](https://www.lua.org/manual/5.1/manual.html#pdf-file:read) from.
  Make sure `filename` is an absolute path so that your app can work reliably
  by double-clicking on it.
  (Based on [Lua](https://www.lua.org/manual/5.1/manual.html#pdf-io.open).)

* `App.open_for_writing(filename)` -- returns a file handle that you can
  [`write()`](https://www.lua.org/manual/5.1/manual.html#pdf-file:write) to.
  Make sure `filename` is an absolute path so that your app can work reliably
  by double-clicking on it.
  (Based on [Lua](https://www.lua.org/manual/5.1/manual.html#pdf-io.open).)

* `json.encode(obj)` -- returns a JSON string for an object `obj` that will
  recreate `obj` when passed to `json.decode`. `obj` can be of most types but
  has some exceptions.
  (From [json.lua](https://github.com/rxi/json.lua).)

* `json.decode(obj)` -- turns a JSON string into a Lua object.
  (From [json.lua](https://github.com/rxi/json.lua).)

* `love.filesystem.getDirectoryItems(dir)` -- returns an unsorted array of the
  files and directories available under `dir`. `dir` must be relative to
  [LÖVE's save directory](https://love2d.org/wiki/love.filesystem.getSaveDirectory).
  There is no easy, portable way in Lua/LÖVE to list directories outside the
  save dir.
  (From [LÖVE](https://love2d.org/wiki/love.filesystem.getDirectoryItems).]

* `love.filesystem.getInfo(filename)` -- returns some information about
  `filename`, particularly whether it exists (non-`nil` return value) or not.
  `filename` must be relative to [LÖVE's save directory](https://love2d.org/wiki/love.filesystem.getSaveDirectory).
  (From [LÖVE](https://love2d.org/wiki/love.filesystem.getInfo).]

* `os.remove(filename)` -- removes a file or empty directory. Definitely make
  sure `filename` is an absolute path.
  (From [Lua](https://www.lua.org/manual/5.1/manual.html#pdf-os.remove).)

There's much more I could include here; check out [the LÖVE manual](https://love2d.org/wiki/love.filesystem)
and [the Lua manual](https://www.lua.org/manual/5.1/manual.html#5.7).

### desiderata

* `App.getTime()` -- returns the number of seconds elapsed since some
  unspecified start time.
  (Based on [LÖVE](https://love2d.org/wiki/love.timer.getTime).)

* `App.getClipboardText()` -- returns a string with the current clipboard
  contents.
  (Based on [LÖVE](https://love2d.org/wiki/love.system.getClipboardText).)

* `App.setClipboardText(text)` -- stores the string `text` in the clipboard.
  (Based on [LÖVE](https://love2d.org/wiki/love.system.setClipboardText).)

There's much more I could include here; check out [the LÖVE manual](https://love2d.org/wiki)
and [the Lua manual](https://www.lua.org/manual/5.1/manual.html).
