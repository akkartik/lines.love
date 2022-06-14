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
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_draw_line/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/p2:y')
end

function test_draw_horizontal_line()
  io.write('\ntest_draw_horizontal_line')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'manhattan'
  App.draw()
  check_eq(#Lines, 2, 'F - test_draw_horizontal_line/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_horizontal_line/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_horizontal_line/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_horizontal_line/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_horizontal_line/baseline/#shapes')
  -- draw a line that is more horizontal than vertical
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+26, 1)
  check_eq(#Lines[1].shapes, 1, 'F - test_draw_horizontal_line/#shapes')
  check_eq(#Lines[1].points, 2, 'F - test_draw_horizontal_line/#points')
  local drawing = Lines[1]
  check_eq(drawing.shapes[1].mode, 'manhattan', 'F - test_draw_horizontal_line/shape_mode')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_horizontal_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_horizontal_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_horizontal_line/p2:x')
  check_eq(p2.y, p1.y, 'F - test_draw_horizontal_line/p2:y')
end

function test_draw_circle()
  io.write('\ntest_draw_circle')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  check_eq(#Lines, 2, 'F - test_draw_circle/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_circle/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_circle/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_circle/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_circle/baseline/#shapes')
  -- draw a circle
  App.mouse_move(Margin_left+4, Margin_top+Drawing_padding_top+4)  -- hover on drawing
  App.run_after_keychord('C-o')
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_mouse_release(Margin_left+35+30, Margin_top+Drawing_padding_top+36, 1)
  check_eq(#Lines[1].shapes, 1, 'F - test_draw_circle/#shapes')
  check_eq(#Lines[1].points, 1, 'F - test_draw_circle/#points')
  local drawing = Lines[1]
  check_eq(drawing.shapes[1].mode, 'circle', 'F - test_draw_horizontal_line/shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'F - test_draw_circle/radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'F - test_draw_circle/center:x')
  check_eq(center.y, 36, 'F - test_draw_circle/center:y')
end

function test_keys_do_not_affect_shape_when_mouse_up()
  io.write('\ntest_keys_do_not_affect_shape_when_mouse_up')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  -- hover over drawing and press 'o' without holding mouse
  App.mouse_move(Margin_left+4, Margin_top+Drawing_padding_top+4)  -- hover on drawing
  App.run_after_keychord('o')
  -- no change to drawing mode
  check_eq(Current_drawing_mode, 'line', 'F - test_keys_do_not_affect_shape_when_mouse_up/drawing_mode')
  -- no change to text either because we didn't run the textinput event
end

function test_draw_circle_mid_stroke()
  io.write('\ntest_draw_circle_mid_stroke')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  check_eq(#Lines, 2, 'F - test_draw_circle_mid_stroke/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_circle_mid_stroke/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_circle_mid_stroke/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_circle_mid_stroke/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_circle_mid_stroke/baseline/#shapes')
  -- draw a circle
  App.mouse_move(Margin_left+4, Margin_top+Drawing_padding_top+4)  -- hover on drawing
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_keychord('o')
  App.run_after_mouse_release(Margin_left+35+30, Margin_top+Drawing_padding_top+36, 1)
  check_eq(#Lines[1].shapes, 1, 'F - test_draw_circle_mid_stroke/#shapes')
  check_eq(#Lines[1].points, 1, 'F - test_draw_circle_mid_stroke/#points')
  local drawing = Lines[1]
  check_eq(drawing.shapes[1].mode, 'circle', 'F - test_draw_horizontal_line/shape_mode')
  check_eq(drawing.shapes[1].radius, 30, 'F - test_draw_circle_mid_stroke/radius')
  local center = drawing.points[drawing.shapes[1].center]
  check_eq(center.x, 35, 'F - test_draw_circle_mid_stroke/center:x')
  check_eq(center.y, 36, 'F - test_draw_circle_mid_stroke/center:y')
end

function test_draw_arc()
  io.write('\ntest_draw_arc')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'circle'
  App.draw()
  check_eq(#Lines, 2, 'F - test_draw_arc/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_arc/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_arc/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_arc/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_arc/baseline/#shapes')
  -- draw an arc
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.mouse_move(Margin_left+35+30, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('a')  -- arc mode
  App.run_after_mouse_release(Margin_left+35+50, Margin_top+Drawing_padding_top+36+50, 1)  -- 45°
  check_eq(#Lines[1].shapes, 1, 'F - test_draw_arc/#shapes')
  check_eq(#Lines[1].points, 2, 'F - test_draw_arc/#points')
  local drawing = Lines[1]
  check_eq(drawing.shapes[1].mode, 'arc', 'F - test_draw_horizontal_line/shape_mode')
  local arc = drawing.shapes[1]
  check_eq(arc.radius, 30, 'F - test_draw_arc/radius')
  local center = drawing.points[arc.center]
  check_eq(center.x, 35, 'F - test_draw_arc/center:x')
  check_eq(center.y, 36, 'F - test_draw_arc/center:y')
  check_eq(arc.start_angle, 0, 'F - test_draw_arc/start:angle')
  check_eq(arc.end_angle, math.pi/4, 'F - test_draw_arc/end:angle')
end
