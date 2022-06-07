# Plain text with lines

An editor for plain text where you can also seamlessly insert line drawings.
Designed above all to be easy to modify and give you early warning if your
modifications break something.

http://akkartik.name/lines.html

## Selecting files

By default, lines.love reads/writes the file `lines.txt` in your default
user/home directory (`https://love2d.org/wiki/love.filesystem.getUserDirectory`).

To open a different file, either pass it in as a commandline argument or drag
and drop the file on to the lines.love window.

```sh
$ love . /path/to/file  # from this repo directory
$ path/to/love path/to/lines.love path/to/file/to/edit  # from anywhere
```

## Keyboard shortcuts

While editing text:
* `ctrl+f` to find patterns within a file
* `ctrl+c` to copy, `ctrl+x` to cut, `ctrl+v` to paste
* `ctrl+z` to undo, `ctrl+y` to redo
* `ctrl+=` to zoom in, `ctrl+-` to zoom out, `ctrl+0` to reset zoom

For shortcuts while editing drawings, consult the online help. Either:
* hover on a drawing and hit `ctrl+h`, or
* click on a drawing to start a stroke and then press and hold `h` to see your
  options at any point during a stroke.

## Known issues

* There's a bug in freehand drawings (C-p mode) that causes them to be
  highlighted even when the mouse is nowhere near them.

* No support yet for Unicode graphemes spanning multiple codepoints.

* Undo/redo can be sluggish in large files. If things get sluggish, killing
  the process can lose data.

* Large files may grow sluggish in other ways. Pasting more than a line or two
  gets slow. I've noticed in 100KB files that closing the window can take a
  few seconds. And it seems to take longer in proportion to how far down my
  edits are. The phenomenon persists even if I take out undo history.

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

* Can't scroll while selecting text with mouse.

* No scrollbars yet. That stuff is hard.

## Mirrors and Forks

Updates to lines.love can be downloaded from the following mirrors in addition
to the website above:
* https://github.com/akkartik/lines.love
* https://repo.or.cz/lines.love.git
* https://codeberg.org/akkartik/lines.love
* https://tildegit.org/akkartik/lines.love
* https://git.tilde.institute/akkartik/lines.love
* https://git.sr.ht/~akkartik/lines.love
* https://pagure.io/lines.love

Forks of Teliva are encouraged. If you show me your fork, I'll link to it
here.

## Feedback

[Most appreciated.](http://akkartik.name/contact)
