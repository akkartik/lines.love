-- major tests for drawings
-- We minimize assumptions about specific pixels, and try to test at the level
-- of specific shapes. In particular, no tests of freehand drawings.

function test_draw_line()
  io.write('\ntest_draw_line')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  check_eq(#Lines, 2, 'F - test_draw_line/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_line/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_line/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_line/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_line/baseline/#shapes')
  -- draw a line
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  check_eq(#Lines[1].shapes, 1, 'F - test_draw_line/#shapes')
  check_eq(#Lines[1].points, 2, 'F - test_draw_line/#points')
  local drawing = Lines[1]
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/p2:y')
end
