module mwv.common;

import deimos.xcb.xproto;

shared bool quitTheProgram = false;

class Window {
  xcb_window_t win;
  uint x, y, width, height;
}

