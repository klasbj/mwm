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
import msgpack;

bool quit = false;

X xserver = null;

static this() {
  xserver = new X();
}

const(Screen) *root;
const(Screen)[] screens;

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
  auto new_screens = xserver.getScreens();
  if (new_screens.length >= screens.length) {
    screens = new_screens;
  } else {
    foreach (x; new_screens.length .. screens.length) {
      foreach (w; windows.values) {
        if (w.screen == x) {
          w.screen = default_screen;
        }
      }
    }
    screens = new_screens;
  }
  root = &screens[0];
  writeln("Screens: ", screens);
}

void handle(Message!CreateWindow msg) {
  Window w = null;
  if (msg.window_id in windows) {
    auto i = countUntil(window_order, msg.window_id);
    selected = i;
    w = windows[msg.window_id];
  } else {
    w = new Window(msg.window_id, default_screen);
    windows[w.window_id] = w;
    selected = window_order.length;
    window_order ~= w.window_id;
  }

  w.origin = root.origin;
  w.size = root.size;

  X.configureWindow(w);
  X.flush();
}

void handle(Message!DestroyWindow msg) {
  writefln("DestroyWindow: %d", msg.window_id);
  if (msg.window_id in windows) {
    auto i = countUntil(window_order, msg.window_id);
    windows.remove(msg.window_id);
    window_order = window_order[0..i] ~ window_order[i+1..$];
    if (selected == i) {
      /* select a new top window */
      selected = min(selected-1, window_order.length-1);
      if (selected < window_order.length) {
        X.raiseWindow(windows[window_order[selected]]);
      }
    }
  }
}

void handle(Message!ChangeFocus msg) {
  if (window_order.length == 0) return;
  if (msg.diff != 0) {
    selected += msg.diff;
    if (selected < 0) {
      selected += window_order.length;
    } else if (selected >= window_order.length) {
      selected -= window_order.length;
    }
    X.raiseWindow(windows[window_order[selected]]);
  } else if (msg.to_window in windows) {
    selected = countUntil(window_order, msg.to_window);
    X.raiseWindow(windows[msg.to_window]);
  }
}

void handle(Message!ConfigureRequest msg) {
  int i = 0;
  uint[] values;
  auto e = &msg.ev;
  if (e.window in windows) {
    writeln("configureRequest: ", *e);
    auto w = windows[e.window];
    w.origin = root.origin;
    w.size = root.size;

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

