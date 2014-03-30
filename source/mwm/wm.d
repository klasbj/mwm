module mwm.wm;

import std.stdio;
import std.traits;
import std.algorithm;
import std.array;

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

Screen root;

Window[xcb_window_t] windows;
xcb_window_t[] window_order;
long selected = 0;

void handle(Message!None msg) {
  writeln("None message");
  quit = true;
  quitTheProgram = true;
}

void handle(Message!Screens msg) {
  writefln("Screens: %s %s", msg.root_window, msg.root_geom);
  root = new Screen(cast(int)msg.root_window,
      msg.root_geom.x, msg.root_geom.y,
      msg.root_geom.width, msg.root_geom.height);
}

void handle(Message!CreateWindow msg) {
  writefln("CreateWindow: %d", msg.window_id);
  Window w = null;
  if (msg.window_id in windows) {
    auto i = countUntil(window_order, msg.window_id);
    selected = i;
    w = windows[msg.window_id];
  } else {
    w = new Window(msg.window_id);
    windows[w.window_id] = w;
    selected = window_order.length;
    window_order ~= w.window_id;
  }

  w.origin = root.origin;
  w.size = root.size;

  xserver.configureWindow(w);
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
        xserver.raiseWindow(windows[window_order[selected]]);
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
    xserver.raiseWindow(windows[window_order[selected]]);
  } else if (msg.to_window in windows) {
    selected = countUntil(window_order, msg.to_window);
    xserver.raiseWindow(windows[msg.to_window]);
  }
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
  //queue.subscribe(cast(ubyte[])"wm "); // TODO: ehm.. this can probably be safer...
  queue.bind("inproc://wm-q");
  queue.bind("ipc://wm-q");

  while (!quit) {
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

