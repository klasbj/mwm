module mwm.wm;

import std.stdio;
import std.traits;
import std.algorithm;
import std.array;
import std.range;

import deimos.zmq.zmq;
import xcb.xproto;

import mwm.common;
import mwm.messages;
import mwm.x;
import mwm.tag;
import mwm.layouts;
import msgpack;

bool quit = false;

const(Screen) *root;
const(Screen)[] screens;
ulong selected_screen = 0;
Tag[] tags;

static this() {
  tags = [ new Tag("1", new Maximize()), new Tag("2", new Maximize()) ];
}

Tag selectedTag() {
  wr("selectedTag");
  auto ts = tags.filter!(a => a.screen == screens[selected_screen]).array;
  assert(ts.length > 0);
  if (ts.length > 1) {
    writeln("WARNING: more than one tag matches a monitor??");
  }
  return ts[0];
}


Window[xcb_window_t] windows;
xcb_window_t[] window_order;
long selected = 0;
long default_screen = 0;

void handle(Message!None msg) {
  writeln("None message");
  quit = true;
  quitTheProgram = true;
}

void handle(Message!Screens msg) {
  auto new_screens = X.getScreens();

  bool[ulong] occupied;
  foreach (i, s; screens) {
    wr("screen ", i, " ", screens);
    foreach (t; tags.filter!(a => a.screen == s)) {
      if (i < new_screens.length && i !in occupied) {
        t.setScreen(new_screens[i]);
        occupied[i] = true;
      } else {
        t.setScreen(); // offscreen
      }
    }
  }

  screens = new_screens;
  selected_screen = mod(selected_screen, screens.length);
  wr("Selected screen is now: ", selected_screen, " ", screens[selected_screen]);

  wr("123", screens);
  root = &screens[0];
  auto i = 0UL;
  while (i in occupied) { i++; }
  wr("bu");
  foreach (t; tags) {
    if (i >= screens.length) break;
    wr("t: ", t);
    if (t.isOffscreen) {
      wr("is offscreen");
      t.setScreen(screens[i]);
      occupied[i] = true;
      while (i in occupied) { i++; }
    }
  }
  wr("Tags: ", tags);
  wr("Screens: ", screens);
}

void handle(Message!CreateWindow msg) {
  Window w = null;
  auto tag = selectedTag();
  if (msg.window_id in windows) {
    /* Do something? */
  } else {
    w = new Window(msg.window_id);
    tag.pushWindow(w);
    windows[w.window_id] = w;
  }

  tag.arrange();
}

void handle(Message!DestroyWindow msg) {
  writefln("DestroyWindow: %d", msg.window_id);

  foreach (t; tags) {
    t.popWindow(msg.window_id);
    t.arrange;
  }

  if (msg.window_id in windows) {
    windows.remove(msg.window_id);
  }
}

void handle(Message!ChangeFocus msg) {
  if (msg.diff != 0) {
    auto t = selectedTag;
    t.focus(msg.diff);
    t.arrange();
  } else if (msg.to_window in windows) {
    selected = countUntil(window_order, msg.to_window);
    X.raiseWindow(windows[msg.to_window]); // TODO better this...
  }
}

void handle(Message!ChangeScreen msg) {
  if (msg.diff != 0) {
    selected_screen = mod(selected_screen + msg.diff, screens.length);
  } else if (msg.to_screen < screens.length) {
    selected_screen = msg.to_screen;
  }
  wr("Selected screen is now: ", selected_screen, " ", screens[selected_screen]);
}

void handle(Message!ConfigureRequest msg) {
  int i = 0;
  uint[] values;
  auto e = &msg.ev;
  if (e.window in windows) {
    writeln("configureRequest: ", *e);
    auto w = windows[e.window];
    //w.origin = root.origin;
    //w.size = root.size;

    X.configureWindow(w);
  } else {
    if (e.value_mask & XCB_CONFIG_WINDOW_X)
      values ~= e.x;
    if (e.value_mask & XCB_CONFIG_WINDOW_Y)
      values ~= e.y;
    if (e.value_mask & XCB_CONFIG_WINDOW_WIDTH)
      values ~= e.width;
    if (e.value_mask & XCB_CONFIG_WINDOW_HEIGHT)
      values ~= e.height;
    if (e.value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH)
      values ~= e.border_width;
    if (e.value_mask & XCB_CONFIG_WINDOW_SIBLING)
      values ~= e.sibling;
    if (e.value_mask & XCB_CONFIG_WINDOW_STACK_MODE)
      values ~= e.stack_mode;
    xcb_configure_window(X.connection, e.window, e.value_mask, &values[0]);
    wr("doh: ", e.window);
  }
  X.flush();
}

void master_handle(IMessage msg) {
  final switch (msg.getMessageType()) {
    foreach (immutable msgt ; EnumMembers!MessageType) {
      case msgt:
        handle(cast(Message!(msgt))msg);
        break;
    }
  }
}

void run() {
  auto queue = new ZmqSocket(ZMQ_SUB);
  foreach (immutable msgt ; EnumMembers!MessageType) {
    queue.subscribe([cast(ubyte)msgt]);
  }
  queue.bind("inproc://wm-q");
  queue.bind("ipc://wm-q");

  writeln("wm loop starting...");
  while (!quit) {
    stdout.flush();
    ubyte[] data = queue.recv();
    writeln("Received data");
    stdout.flush();
    try {
      auto msg = unpackMessage(data);
      master_handle(msg);
    }
    catch (Exception e) {
      writefln("caught: %s", e.msg);
    }
  }

  writeln("wm.run exiting...");

  delete queue;
}

