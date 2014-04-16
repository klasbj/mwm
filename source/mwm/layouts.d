module mwm.layouts;

import std.range;

import mwm.common;
import mwm.x;

class Maximize : Layout {
  //ulong selected;

  void arrange(const Screen s, ref Window[] windows) {
    foreach (w; windows) {
      if (w.is_floating) continue;
      w.origin = s.origin;
      w.size = s.size;
      wr("arrange window: ", w);
    }
  }
}


