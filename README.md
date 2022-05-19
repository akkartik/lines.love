Known issues:
* Touchpads can drag the mouse pointer using a light touch or a heavy click.
  On Linux, drags using the light touch get interrupted when a key is pressed.
  You'll have to press down to drag.
* No support yet for Unicode graphemes spanning multiple codepoints.
* The text cursor will always stay on the screen. This can have some strange
  implications:
    * A long series of drawings will get silently skipped when you hit
      page-down, until a line of text can be showed on screen.
    * If there's no line of text at the bottom of the file, one will be
      created.
  So far this app isn't really designed for all-drawing files. I'm really just
  targeting mostly-text files with a few drawings mixed in.
