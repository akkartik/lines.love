# Plain text with lines

http://akkartik.name/lines.html

## Known issues

* No support yet for Unicode graphemes spanning multiple codepoints.

* The text cursor will always stay on the screen. This can have some strange
  implications:

    * A long series of drawings will get silently skipped when you hit
      page-down, until a line of text can be showed on screen.
    * If there's no line of text at the top of the file, you may not be able
      to scroll back up to the top with page-up.

  So far this app isn't really designed for drawing-heavy files. For now I'm
  targeting mostly-text files with a few drawings mixed in.

* No clipping yet for drawings. In particular, circles and point labels can
  overflow a drawing.

* Insufficient handling of constraints when moving points. For example, if you
  draw a manhattan line and then move one of the points, you may not be able
  to hover on it anymore.

  There's two broad ways to fix this. The first is to relax constraints,
  switch the manhattan line to not be manhattan. The second is to try to
  maintain constraints. Either constrain the point to only move along one line
  (but what if it's connected to two manhattan lines?!), or constrain the
  other end of the line to move alongside. I'm not sure yet which would be
  more useful. Getting into constraints would also make the program more
  complex.

  Bottomline: at the moment moving points connected to manhattan lines,
  rectangles or squares can break drawings in subtle ways.

* Touchpads can drag the mouse pointer using a light touch or a heavy click.
  On Linux, drags using the light touch get interrupted when a key is pressed.
  You'll have to press down to drag.
