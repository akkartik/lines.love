function test_resize_window()
  io.write('\ntest_resize_window')
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  check_eq(App.screen.width, Margin_left+300, 'F - test_resize_window/baseline/width')
  check_eq(App.screen.height, 300, 'F - test_resize_window/baseline/height')
  App.resize(200, 400)
  check_eq(App.screen.width, 200, 'F - test_resize_window/width')
  check_eq(App.screen.height, 400, 'F - test_resize_window/height')
  -- TODO: how to make assertions about when App.update got past the early exit?
end

function test_drop_file()
  io.write('\ntest_drop_file')
  App.screen.init{width=Margin_left+300, height=300}
  App.filesystem['foo'] = 'abc\ndef\nghi\n'
  local fake_dropped_file = {
    opened = false,
    getFilename = function(self)
                    return 'foo'
                  end,
    open = function(self)
             self.opened = true
           end,
    lines = function(self)
              assert(self.opened)
              return App.filesystem['foo']:gmatch('[^\n]+')
            end,
    close = function(self)
              self.opened = false
            end,
  }
  App.filedropped(fake_dropped_file)
  check_eq(#Lines, 3, 'F - test_drop_file/#lines')
  check_eq(Lines[1].data, 'abc', 'F - test_drop_file/lines:1')
  check_eq(Lines[2].data, 'def', 'F - test_drop_file/lines:2')
  check_eq(Lines[3].data, 'ghi', 'F - test_drop_file/lines:3')
end

function test_drop_file_saves_previous()
  io.write('\ntest_drop_file_saves_previous')
  App.screen.init{width=Margin_left+300, height=300}
  -- initially editing a file called foo that hasn't been saved to filesystem yet
  Lines = load_array{'abc', 'def'}
  Filename = 'foo'
  schedule_save()
  -- now drag a new file bar from the filesystem
  App.filesystem['bar'] = 'abc\ndef\nghi\n'
  local fake_dropped_file = {
    opened = false,
    getFilename = function(self)
                    return 'bar'
                  end,
    open = function(self)
             self.opened = true
           end,
    lines = function(self)
              assert(self.opened)
              return App.filesystem['bar']:gmatch('[^\n]+')
            end,
    close = function(self)
              self.opened = false
            end,
  }
  App.filedropped(fake_dropped_file)
  -- filesystem now contains a file called foo
  check_eq(App.filesystem['foo'], 'abc\ndef\n', 'F - test_drop_file_saves_previous')
end

function test_adjust_line_width()
  io.write('\ntest_adjust_line_width')
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Line_width = 256
  App.draw()  -- initialize button
  App.run_after_mouse_press(256, Margin_top-3, 1)
  App.mouse_move(200, 37)
  -- no change for some time
  App.wait_fake_time(0.01)
  App.update(0)
  check_eq(Line_width, 256, 'F - test_adjust_line_width/early')
  -- after 0.1s the change takes
  App.wait_fake_time(0.1)
  App.update(0)
  check_eq(Line_width, 200, 'F - test_adjust_line_width')
end
