-- major tests for drawings
-- We minimize assumptions about specific pixels, and try to test at the level
-- of specific shapes. In particular, no tests of freehand drawings.

function test_creating_drawing_saves()
  io.write('\ntest_creating_drawing_saves')
  App.screen.init{width=120, height=60}
  Filename = 'foo'
  Lines = load_array{}
  App.draw()
  -- click on button to create drawing
  App.run_after_mouse_click(8,Margin_top+8, 1)
  -- filesystem contains drawing and an empty line of text
  check_eq(App.filesystem['foo'], '```lines\n```\n\n', 'F - test_creating_drawing_saves')
end

function test_draw_line()
  io.write('\ntest_draw_line')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  Filename = 'foo'
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
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_line/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_line/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_draw_line/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/p2:y')
  -- The format on disk isn't perfectly stable. Table fields can be reordered.
  -- So just reload from disk to verify.
  Lines = load_from_disk(Filename)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_line/save/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_line/save/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_draw_line/save/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_draw_line/save/p1:x')
  check_eq(p1.y, 6, 'F - test_draw_line/save/p1:y')
  check_eq(p2.x, 35, 'F - test_draw_line/save/p2:x')
  check_eq(p2.y, 36, 'F - test_draw_line/save/p2:y')
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
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_horizontal_line/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_horizontal_line/#points')
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
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_circle/#shapes')
  check_eq(#drawing.points, 1, 'F - test_draw_circle/#points')
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
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_circle_mid_stroke/#shapes')
  check_eq(#drawing.points, 1, 'F - test_draw_circle_mid_stroke/#points')
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
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_arc/#shapes')
  check_eq(#drawing.points, 2, 'F - test_draw_arc/#points')
  check_eq(drawing.shapes[1].mode, 'arc', 'F - test_draw_horizontal_line/shape_mode')
  local arc = drawing.shapes[1]
  check_eq(arc.radius, 30, 'F - test_draw_arc/radius')
  local center = drawing.points[arc.center]
  check_eq(center.x, 35, 'F - test_draw_arc/center:x')
  check_eq(center.y, 36, 'F - test_draw_arc/center:y')
  check_eq(arc.start_angle, 0, 'F - test_draw_arc/start:angle')
  check_eq(arc.end_angle, math.pi/4, 'F - test_draw_arc/end:angle')
end

function test_draw_polygon()
  io.write('\ntest_draw_polygon')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  App.draw()
  check_eq(Current_drawing_mode, 'line', 'F - test_draw_polygon/baseline/drawing_mode')
  check_eq(#Lines, 2, 'F - test_draw_polygon/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_polygon/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_polygon/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_polygon/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_polygon/baseline/#shapes')
  -- first point
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_keychord('g')  -- polygon mode
  -- second point
  App.mouse_move(Margin_left+65, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('p')  -- add point
  -- final point
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+26, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_polygon/#shapes')
  check_eq(#drawing.points, 3, 'F - test_draw_polygon/vertices')
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'polygon', 'F - test_draw_polygon/shape_mode')
  check_eq(#shape.vertices, 3, 'F - test_draw_polygon/vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 5, 'F - test_draw_polygon/p1:x')
  check_eq(p.y, 6, 'F - test_draw_polygon/p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 65, 'F - test_draw_polygon/p2:x')
  check_eq(p.y, 36, 'F - test_draw_polygon/p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 35, 'F - test_draw_polygon/p3:x')
  check_eq(p.y, 26, 'F - test_draw_polygon/p3:y')
end

function test_draw_rectangle()
  io.write('\ntest_draw_rectangle')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  App.draw()
  check_eq(Current_drawing_mode, 'line', 'F - test_draw_rectangle/baseline/drawing_mode')
  check_eq(#Lines, 2, 'F - test_draw_rectangle/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_rectangle/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_rectangle/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_rectangle/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_rectangle/baseline/#shapes')
  -- first point
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_keychord('r')  -- rectangle mode
  -- second point/first edge
  App.mouse_move(Margin_left+42, Margin_top+Drawing_padding_top+45)
  App.run_after_keychord('p')
  -- override second point/first edge
  App.mouse_move(Margin_left+75, Margin_top+Drawing_padding_top+76)
  App.run_after_keychord('p')
  -- release (decides 'thickness' of rectangle perpendicular to first edge)
  App.run_after_mouse_release(Margin_left+15, Margin_top+Drawing_padding_top+26, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_rectangle/#shapes')
  check_eq(#drawing.points, 5, 'F - test_draw_rectangle/#points')  -- currently includes every point added
  local shape = drawing.shapes[1]
  check_eq(shape.mode, 'rectangle', 'F - test_draw_rectangle/shape_mode')
  check_eq(#shape.vertices, 4, 'F - test_draw_rectangle/vertices')
  local p = drawing.points[shape.vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_rectangle/p1:x')
  check_eq(p.y, 36, 'F - test_draw_rectangle/p1:y')
  local p = drawing.points[shape.vertices[2]]
  check_eq(p.x, 75, 'F - test_draw_rectangle/p2:x')
  check_eq(p.y, 76, 'F - test_draw_rectangle/p2:y')
  local p = drawing.points[shape.vertices[3]]
  check_eq(p.x, 70, 'F - test_draw_rectangle/p3:x')
  check_eq(p.y, 81, 'F - test_draw_rectangle/p3:y')
  local p = drawing.points[shape.vertices[4]]
  check_eq(p.x, 30, 'F - test_draw_rectangle/p4:x')
  check_eq(p.y, 41, 'F - test_draw_rectangle/p4:y')
end

function test_draw_rectangle_intermediate()
  io.write('\ntest_draw_rectangle_intermediate')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  App.draw()
  check_eq(Current_drawing_mode, 'line', 'F - test_draw_rectangle_intermediate/baseline/drawing_mode')
  check_eq(#Lines, 2, 'F - test_draw_rectangle_intermediate/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_rectangle_intermediate/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_rectangle_intermediate/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_rectangle_intermediate/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_rectangle_intermediate/baseline/#shapes')
  -- first point
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_keychord('r')  -- rectangle mode
  -- second point/first edge
  App.mouse_move(Margin_left+42, Margin_top+Drawing_padding_top+45)
  App.run_after_keychord('p')
  -- override second point/first edge
  App.mouse_move(Margin_left+75, Margin_top+Drawing_padding_top+76)
  App.run_after_keychord('p')
  local drawing = Lines[1]
  check_eq(#drawing.points, 3, 'F - test_draw_rectangle_intermediate/#points')  -- currently includes every point added
  local pending = drawing.pending
  check_eq(pending.mode, 'rectangle', 'F - test_draw_rectangle_intermediate/shape_mode')
  check_eq(#pending.vertices, 2, 'F - test_draw_rectangle_intermediate/vertices')
  local p = drawing.points[pending.vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_rectangle_intermediate/p1:x')
  check_eq(p.y, 36, 'F - test_draw_rectangle_intermediate/p1:y')
  local p = drawing.points[pending.vertices[2]]
  check_eq(p.x, 75, 'F - test_draw_rectangle_intermediate/p2:x')
  check_eq(p.y, 76, 'F - test_draw_rectangle_intermediate/p2:y')
  -- outline of rectangle is drawn based on where the mouse is, but we can't check that so far
end

function test_draw_square()
  io.write('\ntest_draw_square')
  -- display a drawing followed by a line of text (you shouldn't ever have a drawing right at the end)
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  App.draw()
  check_eq(Current_drawing_mode, 'line', 'F - test_draw_square/baseline/drawing_mode')
  check_eq(#Lines, 2, 'F - test_draw_square/baseline/#lines')
  check_eq(Lines[1].mode, 'drawing', 'F - test_draw_square/baseline/mode')
  check_eq(Lines[1].y, Margin_top+Drawing_padding_top, 'F - test_draw_square/baseline/y')
  check_eq(Lines[1].h, 128, 'F - test_draw_square/baseline/y')
  check_eq(#Lines[1].shapes, 0, 'F - test_draw_square/baseline/#shapes')
  -- first point
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_keychord('s')  -- square mode
  -- second point/first edge
  App.mouse_move(Margin_left+42, Margin_top+Drawing_padding_top+45)
  App.run_after_keychord('p')
  -- override second point/first edge
  App.mouse_move(Margin_left+65, Margin_top+Drawing_padding_top+66)
  App.run_after_keychord('p')
  -- release (decides which side of first edge to draw square on)
  App.run_after_mouse_release(Margin_left+15, Margin_top+Drawing_padding_top+26, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_draw_square/#shapes')
  check_eq(#drawing.points, 5, 'F - test_draw_square/#points')  -- currently includes every point added
  check_eq(drawing.shapes[1].mode, 'square', 'F - test_draw_square/shape_mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'F - test_draw_square/vertices')
  local p = drawing.points[drawing.shapes[1].vertices[1]]
  check_eq(p.x, 35, 'F - test_draw_square/p1:x')
  check_eq(p.y, 36, 'F - test_draw_square/p1:y')
  local p = drawing.points[drawing.shapes[1].vertices[2]]
  check_eq(p.x, 65, 'F - test_draw_square/p2:x')
  check_eq(p.y, 66, 'F - test_draw_square/p2:y')
  local p = drawing.points[drawing.shapes[1].vertices[3]]
  check_eq(p.x, 35, 'F - test_draw_square/p3:x')
  check_eq(p.y, 96, 'F - test_draw_square/p3:y')
  local p = drawing.points[drawing.shapes[1].vertices[4]]
  check_eq(p.x, 5, 'F - test_draw_square/p4:x')
  check_eq(p.y, 66, 'F - test_draw_square/p4:y')
end

function test_name_point()
  io.write('\ntest_name_point')
  -- create a drawing with a line
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  -- draw a line
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_name_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_name_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_name_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_name_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_name_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_name_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_name_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_name_point/baseline/p2:name')
  -- enter 'name' mode without moving the mouse
  App.run_after_keychord('C-n')
  check_eq(Current_drawing_mode, 'name', 'F - test_name_point/mode:1')
  App.run_after_textinput('A')
  check_eq(p2.name, 'A', 'F - test_name_point')
  -- still in 'name' mode
  check_eq(Current_drawing_mode, 'name', 'F - test_name_point/mode:2')
  -- exit 'name' mode
  App.run_after_keychord('return')
  check_eq(Current_drawing_mode, 'line', 'F - test_name_point/mode:3')
  check_eq(p2.name, 'A', 'F - test_name_point')
  -- change is saved
  Lines = load_from_disk(Filename)
  local p2 = Lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, 'A', 'F - test_name_point/save')
end

function test_move_point()
  io.write('\ntest_move_point')
  -- create a drawing with a line
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_move_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_move_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_move_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_move_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_move_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_move_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_move_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_move_point/baseline/p2:name')
  -- line is saved to disk
  Lines = load_from_disk(Filename)
  local drawing = Lines[1]
  local p2 = Lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 35, 'F - test_move_point/save/x')
  check_eq(p2.y, 36, 'F - test_move_point/save/y')
  App.draw()
  -- enter 'move' mode without moving the mouse
  App.run_after_keychord('C-u')
  check_eq(Current_drawing_mode, 'move', 'F - test_move_point/mode:1')
  -- point is lifted
  check_eq(drawing.pending.mode, 'move', 'F - test_move_point/mode:2')
  check_eq(drawing.pending.target_point, p2, 'F - test_move_point/target')
  -- move point
  App.mouse_move(Margin_left+26, Margin_top+Drawing_padding_top+44)
  App.update(0.05)
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'F - test_move_point/x')
  check_eq(p2.y, 44, 'F - test_move_point/y')
  -- exit 'move' mode
  App.run_after_mouse_click(Margin_left+26, Margin_top+Drawing_padding_top+44, 1)
  check_eq(Current_drawing_mode, 'line', 'F - test_move_point/mode:3')
  check_eq(drawing.pending, {}, 'F - test_move_point/pending')
  -- change is saved
  Lines = load_from_disk(Filename)
  local p2 = Lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.x, 26, 'F - test_move_point/save/x')
  check_eq(p2.y, 44, 'F - test_move_point/save/y')
end

function test_delete_lines_at_point()
  io.write('\ntest_delete_lines_at_point')
  -- create a drawing with two lines connected at a point
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_mouse_release(Margin_left+55, Margin_top+Drawing_padding_top+26, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 2, 'F - test_delete_lines_at_point/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_delete_lines_at_point/baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_lines_at_point/baseline/shape:2')
  -- hover on the common point and delete
  App.mouse_move(Margin_left+35, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('C-d')
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_lines_at_point/shape:1')
  check_eq(drawing.shapes[2].mode, 'deleted', 'F - test_delete_lines_at_point/shape:2')
  -- deleted points disappear after file is reloaded
  Lines = load_from_disk(Filename)
  check_eq(#Lines[1].shapes, 0, 'F - test_delete_lines_at_point/save')
end

function test_delete_line_under_mouse_pointer()
  io.write('\ntest_delete_line_under_mouse_pointer')
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_mouse_press(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  App.run_after_mouse_release(Margin_left+55, Margin_top+Drawing_padding_top+26, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 2, 'F - test_delete_line_under_mouse_pointer/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_delete_line_under_mouse_pointer/baseline/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_line_under_mouse_pointer/baseline/shape:2')
  -- hover on one of the lines and delete
  App.mouse_move(Margin_left+25, Margin_top+Drawing_padding_top+26)
  App.run_after_keychord('C-d')
  -- only that line is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_line_under_mouse_pointer/shape:1')
  check_eq(drawing.shapes[2].mode, 'line', 'F - test_delete_line_under_mouse_pointer/shape:2')
end

function test_delete_point_from_polygon()
  io.write('\ntest_delete_point_from_polygon')
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  -- first point
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_keychord('g')  -- polygon mode
  -- second point
  App.mouse_move(Margin_left+65, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('p')  -- add point
  -- third point
  App.mouse_move(Margin_left+35, Margin_top+Drawing_padding_top+26)
  App.run_after_keychord('p')  -- add point
  -- fourth point
  App.run_after_mouse_release(Margin_left+14, Margin_top+Drawing_padding_top+16, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_delete_point_from_polygon/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 4, 'F - test_delete_point_from_polygon/baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Margin_left+35, Margin_top+Drawing_padding_top+26)
  App.run_after_keychord('C-d')
  -- just the one point is deleted
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/shape')
  check_eq(#drawing.shapes[1].vertices, 3, 'F - test_delete_point_from_polygon/vertices')
end

function test_delete_point_from_polygon()
  io.write('\ntest_delete_point_from_polygon')
  -- create a drawing with two lines connected at a point
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  -- first point
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_keychord('g')  -- polygon mode
  -- second point
  App.mouse_move(Margin_left+65, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('p')  -- add point
  -- third point
  App.run_after_mouse_release(Margin_left+14, Margin_top+Drawing_padding_top+16, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_delete_point_from_polygon/baseline/#shapes')
  check_eq(drawing.shapes[1].mode, 'polygon', 'F - test_delete_point_from_polygon/baseline/mode')
  check_eq(#drawing.shapes[1].vertices, 3, 'F - test_delete_point_from_polygon/baseline/vertices')
  -- hover on a point and delete
  App.mouse_move(Margin_left+65, Margin_top+Drawing_padding_top+36)
  App.run_after_keychord('C-d')
  -- there's < 3 points left, so the whole polygon is deleted
  check_eq(drawing.shapes[1].mode, 'deleted', 'F - test_delete_point_from_polygon')
end

function test_undo_name_point()
  io.write('\ntest_undo_name_point')
  -- create a drawing with a line
  Filename = 'foo'
  App.screen.init{width=Margin_left+300, height=300}
  Lines = load_array{'```lines', '```', ''}
  Line_width = 256  -- drawing coordinates 1:1 with pixels
  Current_drawing_mode = 'line'
  App.draw()
  -- draw a line
  App.run_after_mouse_press(Margin_left+5, Margin_top+Drawing_padding_top+6, 1)
  App.run_after_mouse_release(Margin_left+35, Margin_top+Drawing_padding_top+36, 1)
  local drawing = Lines[1]
  check_eq(#drawing.shapes, 1, 'F - test_undo_name_point/baseline/#shapes')
  check_eq(#drawing.points, 2, 'F - test_undo_name_point/baseline/#points')
  check_eq(drawing.shapes[1].mode, 'line', 'F - test_undo_name_point/baseline/shape:1')
  local p1 = drawing.points[drawing.shapes[1].p1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(p1.x, 5, 'F - test_undo_name_point/baseline/p1:x')
  check_eq(p1.y, 6, 'F - test_undo_name_point/baseline/p1:y')
  check_eq(p2.x, 35, 'F - test_undo_name_point/baseline/p2:x')
  check_eq(p2.y, 36, 'F - test_undo_name_point/baseline/p2:y')
  check_nil(p2.name, 'F - test_undo_name_point/baseline/p2:name')
  check_eq(#History, 1, 'F - test_undo_name_point/baseline/history:1')
  -- enter 'name' mode without moving the mouse
  App.run_after_keychord('C-n')
  App.run_after_textinput('A')
  App.run_after_keychord('return')
  check_eq(p2.name, 'A', 'F - test_undo_name_point/baseline')
  check_eq(#History, 3, 'F - test_undo_name_point/baseline/history:2')
  check_eq(Next_history, 4, 'F - test_undo_name_point/baseline/next_history')
  -- undo
  App.run_after_keychord('C-z')
  local drawing = Lines[1]
  local p2 = drawing.points[drawing.shapes[1].p2]
  check_eq(Next_history, 3, 'F - test_undo_name_point/next_history')
  check_eq(p2.name, '', 'F - test_undo_name_point')  -- not quite what it was before, but close enough
  -- change is saved
  Lines = load_from_disk(Filename)
  local p2 = Lines[1].points[drawing.shapes[1].p2]
  check_eq(p2.name, '', 'F - test_undo_name_point/save')
end
