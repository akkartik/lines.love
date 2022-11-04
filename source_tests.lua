function test_resize_window()
  io.write('\ntest_resize_window')
  App.screen.init{width=300, height=300}
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Log_browser_state = edit.initialize_test_state()
  check_eq(App.screen.width, 300, 'F - test_resize_window/baseline/width')
  check_eq(App.screen.height, 300, 'F - test_resize_window/baseline/height')
  check_eq(Editor_state.left, Test_margin_left, 'F - test_resize_window/baseline/left_margin')
  check_eq(Editor_state.right, 300 - Test_margin_right, 'F - test_resize_window/baseline/right_margin')
  App.resize(200, 400)
  -- ugly; resize switches to real, non-test margins
  check_eq(App.screen.width, 200, 'F - test_resize_window/width')
  check_eq(App.screen.height, 400, 'F - test_resize_window/height')
  check_eq(Editor_state.left, Margin_left, 'F - test_resize_window/left_margin')
  check_eq(Editor_state.right, 200-Margin_right, 'F - test_resize_window/right_margin')
  check_eq(Editor_state.width, 200-Margin_left-Margin_right, 'F - test_resize_window/drawing_width')
  -- TODO: how to make assertions about when App.update got past the early exit?
end

function test_show_log_browser_side()
  io.write('\ntest_show_log_browser_side')
  App.screen.init{width=300, height=300}
  Display_width = App.screen.width
  Current_app = 'source'
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Text.redraw_all(Editor_state)
  Log_browser_state = edit.initialize_test_state()
  Text.redraw_all(Log_browser_state)
  log_browser.parse(Log_browser_state)
  check(not Show_log_browser_side, 'F - test_show_log_browser_side/baseline')
  -- pressing ctrl+l shows log-browser side
  Current_time = Current_time + 0.1
  App.run_after_keychord('C-l')
  check(Show_log_browser_side, 'F - test_show_log_browser_side')
end

function test_show_log_browser_side_doubles_window_width_if_possible()
  io.write('\ntest_show_log_browser_side_doubles_window_width_if_possible')
  -- initialize screen dimensions to half width
  App.screen.init{width=300, height=300}
  Display_width = App.screen.width*2
  -- initialize source app with left side occupying entire window (half the display)
  Current_app = 'source'
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.left = Margin_left
  Editor_state.right = App.screen.width - Margin_right
  local old_editor_right = Editor_state.right
  Text.redraw_all(Editor_state)
  Log_browser_state = edit.initialize_test_state()
  -- log browser has some arbitrary margins
  Log_browser_state.left = 200 + Margin_left
  Log_browser_state.right = 400
  Text.redraw_all(Log_browser_state)
  log_browser.parse(Log_browser_state)
  -- display log browser
  Current_time = Current_time + 0.1
  App.run_after_keychord('C-l')
  -- window width is doubled
  check_eq(App.screen.width, 600, 'F - test_show_log_browser_side_doubles_window_width_if_possible/display:width')
  -- left side margins are unchanged
  check_eq(Editor_state.left, Margin_left, 'F - test_show_log_browser_side_doubles_window_width_if_possible/edit:left')
  check_eq(Editor_state.right, old_editor_right, 'F - test_show_log_browser_side_doubles_window_width_if_possible/edit:right')
  -- log browser margins are adjusted
  check_eq(Log_browser_state.left, App.screen.width/2 + Margin_left, 'F - test_show_log_browser_side_doubles_window_width_if_possible/log:left')
  check_eq(Log_browser_state.right, App.screen.width - Margin_right, 'F - test_show_log_browser_side_doubles_window_width_if_possible/log:right')
end

function test_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width()
  io.write('\ntest_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width')
  -- initialize screen dimensions and indicate that it is maximized
  App.screen.init{width=300, height=300}
  Display_width = 300
  -- initialize source app with left side occupying more than half the display
  Current_app = 'source'
  Editor_state = edit.initialize_test_state()
  Editor_state.filename = 'foo'
  Editor_state.left = Margin_left
  Editor_state.right = 200
  Text.redraw_all(Editor_state)
  Log_browser_state = edit.initialize_test_state()
  -- log browser has some arbitrary margins
  Log_browser_state.left = 200 + Margin_left
  Log_browser_state.right = 400
  Text.redraw_all(Log_browser_state)
  log_browser.parse(Log_browser_state)
  -- display log browser
  Current_time = Current_time + 0.1
  App.run_after_keychord('C-l')
  -- margins are now adjusted
  check_eq(Editor_state.left, Margin_left, 'F - test_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width/edit:left')
  check_eq(Editor_state.right, App.screen.width/2 - Margin_right, 'F - test_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width/edit:right')
  check_eq(Log_browser_state.left, App.screen.width/2 + Margin_left, 'F - test_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width/log:left')
  check_eq(Log_browser_state.right, App.screen.width - Margin_right, 'F - test_show_log_browser_side_resizes_both_sides_if_cannot_double_window_width/log:right')
end

function test_drop_file()
  io.write('\ntest_drop_file')
  App.screen.init{width=Editor_state.left+300, height=300}
  Editor_state = edit.initialize_test_state()
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
  check_eq(#Editor_state.lines, 3, 'F - test_drop_file/#lines')
  check_eq(Editor_state.lines[1].data, 'abc', 'F - test_drop_file/lines:1')
  check_eq(Editor_state.lines[2].data, 'def', 'F - test_drop_file/lines:2')
  check_eq(Editor_state.lines[3].data, 'ghi', 'F - test_drop_file/lines:3')
  edit.draw(Editor_state)
end

function test_drop_file_saves_previous()
  io.write('\ntest_drop_file_saves_previous')
  App.screen.init{width=Editor_state.left+300, height=300}
  -- initially editing a file called foo that hasn't been saved to filesystem yet
  Editor_state.lines = load_array{'abc', 'def'}
  Editor_state.filename = 'foo'
  schedule_save(Editor_state)
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
