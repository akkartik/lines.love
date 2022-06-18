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

function test_adjust_line_width()
  io.write('\ntest_adjust_line_width')
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Line_width = 256
  App.draw()  -- initialize button
  App.run_after_mouse_press(Margin_left+256, Margin_top-3, 1)
  App.mouse_move(Margin_left+200, 37)
  -- no change for some time
  App.wait_fake_time(0.01)
  App.update(0)
  check_eq(Line_width, 256, 'F - test_adjust_line_width/early')
  -- after 0.1s the change takes
  App.wait_fake_time(0.1)
  App.update(0)
  check_eq(Line_width, 200, 'F - test_adjust_line_width')
end
