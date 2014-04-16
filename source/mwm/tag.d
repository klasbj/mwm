module mwm.tag;

import std.algorithm;
import std.conv;
import std.range;

import xcb.xproto;

import mwm.common;
import mwm.x;

class Tag {
  static const Screen offscreen = Screen(-1920*3, -1080*3, 1920, 1080);
  string id;
  Window[] windows;
  Window selected;
  Layout layout;
  Screen screen;

  override string toString() {
    return "Tag("
      ~ id
      ~ ", " ~ to!string(screen)
      ~ ", " ~ to!string(windows)
      ~ ")";
  }

  this(string id, Layout l) {
    this.id = id;
    this.screen = offscreen;
    this.layout = l;
  }

  void arrange() {
    auto sel_i = max(0, this.windows.countUntil(selected));
    auto arr_range = this.windows.cycle[sel_i..sel_i+this.windows.length].array;
    this.layout.arrange(this.screen, arr_range);
    foreach (w; this.windows) {
      X.configureWindow(w);
    }
    stack();
    X.flush();
  }

  void stack() {
    if (this.selected !is null &&
        this.selected.is_floating) {
      X.stackWindow(this.selected, XCB_STACK_MODE_ABOVE);
    }

    auto sel_i = max(0, this.windows.countUntil(selected));
    auto arr_range = this.windows.cycle[sel_i..sel_i+this.windows.length].array;

    wr("stacking: ", sel_i);

    Window s = null;
    foreach (w; arr_range) {
      if (!w.is_floating) {
        wr("stack window: ", w);
        X.stackWindow(w, XCB_STACK_MODE_BELOW, s);
        s = w;
      }
    }
    X.flush();
  }

  void pushWindow(Window w) {
    this.windows = [w] ~ this.windows;
    this.selected = w;
  }

  void popWindow(xcb_window_t w) {
    auto i = this.windows.countUntil!"a.window_id == b"(w);
    wr("popWindow: ", i, ", ", w, "; tag: ", this.id);
    if (i < 0) return;
    this.windows = this.windows[0..i] ~ this.windows[i+1..$];

    // if the selected window is popped
    if (this.selected !is null && this.selected.window_id == w) {
      this.focus();
    }
  }

  void setScreen(const Screen s = Tag.offscreen) {
    this.screen = s;
  }

  @property bool isOffscreen() const {
    return this.screen == Tag.offscreen;
  }

  void focus() {
    if (this.windows.length > 0) {
      this.selected = this.windows[0];
    } else {
      this.selected = null;
    }
  }

  void focus(long delta) {
    auto sel_i = this.windows.countUntil(selected);
    wr("focus ", sel_i, " + ", delta, " ", selected);
    if (sel_i < 0) return; // no window selected

    this.selected = this.windows.cycle[sel_i+delta];
  }

  void focus(Window w) {
    if (!this.windows.find(w).empty) {
      this.selected = w;
    }
  }

  void unfocus() {
    this.selected = null;
  }
}

unittest {
  Tag t = new Tag("1", null);
  assert(t.screen == Tag.offscreen);
  assert(t.isOffscreen);

  auto s = Screen(0,0,640,480);
  t.setScreen(s);
  assert(t.screen == s);
}

