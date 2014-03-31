module xrunner;

import std.algorithm;
import std.stdio;
import std.array;
import xcb.xcb;
import xcb.xproto;
import deimos.zmq.zmq;
import std.c.stdlib;
import msgpack;


import mwm.common;
import mwm.messages;
import mwm.x;

xcb_window_t root;
X c;
ZmqSocket queue;

static this() {
  c = new X();
}
static ~this() {
  delete queue;
}

immutable(void function(xcb_generic_event_t*)[uint]) handlers;

static this() {
  handlers[XCB_KEY_PRESS] = &keyPress;
  handlers[XCB_MAP_REQUEST] = &mapRequest;
  handlers[XCB_UNMAP_NOTIFY] = &unmapNotify;
  handlers[XCB_CONFIGURE_REQUEST] = &configureRequest;
  handlers[XCB_CONFIGURE_NOTIFY] = &configureNotify;
}

int setup() {
  uint                       values[10];
  xcb_screen_t              *s;

  if (c.get_connection() == null) {
    writefln("Cannot open display");
    return 1;
  }

  /* Connect to the wm queue */
  queue = new ZmqSocket(ZMQ_PUB);
  queue.connect("inproc://wm-q");

  /* get the first screen */
  s = xcb_setup_roots_iterator( xcb_get_setup(c) ).data;
  root = s.root;

  import core.thread;
  Thread.sleep(dur!"msecs"(100)); /* sleep to allow zmq to connect */

  queue.send(new Message!Screens().pack());

  foreach (immutable x; Keys) {
    xcb_grab_key(c, true, root, x.mod, x.key, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC);
  }

  /*
  xcb_grab_button(c, false, root, XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE,
      XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, root, XCB_NONE, 1, XCB_MOD_MASK_1
      );

  xcb_grab_button(c, false, root, XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE,
      XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, root, XCB_NONE, 3, XCB_MOD_MASK_1
      );
      */

  values[0] =
    XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
    XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
    XCB_EVENT_MASK_STRUCTURE_NOTIFY |
    XCB_EVENT_MASK_PROPERTY_CHANGE |
    XCB_EVENT_MASK_ENTER_WINDOW |
    XCB_EVENT_MASK_LEAVE_WINDOW;
  xcb_change_window_attributes(c, root, XCB_CW_EVENT_MASK, &values[0]);

  xcb_flush(c);

  return 0;
}

void run() {
  xcb_generic_event_t *ev = null;
  bool done = false;


  if (setup()) {
    writeln("Unable to connect to X server");
    queue.send(new Message!None().pack());
    return;
  }

  /* event loop */
  writeln("Starting event loop...");
  do{
    stdout.flush();
    ev = xcb_wait_for_event(c);
    if (!ev) break;
    uint response_type = ev.response_type & ~0x80;

    if (response_type in handlers)
      handlers[response_type](ev);
    else
      writeln("Unknown event: ", *ev);

    free(ev);
  }while(!quitTheProgram);

  queue.send(new Message!None().pack());

  writeln("X Exiting...");

  disconnect();
}

void disconnect() {
  /* close connection to the wm queue */
  delete queue;
}

mixin template KeyBase() {
  enum key = K;
  enum mod = M;
}

template KeySendMessage(uint K, uint M, MessageType MT, A...) {
  mixin KeyBase;
  const args = new Message!MT(A);
  void exec(T)(const T obj) {
    queue.send(obj.pack());
  }
}

template KeyPrint(uint K, uint M, Msg...) {
  mixin KeyBase;
  static assert(Msg.length > 0);
  enum args = Msg;
  alias exec = writefln;
}

import std.typetuple;

alias Keys = TypeTuple!(
  KeySendMessage!(24, XCB_MOD_MASK_1, None),      // q
  KeySendMessage!(44, XCB_MOD_MASK_1, ChangeFocus, 0, -1), // j
  KeySendMessage!(45, XCB_MOD_MASK_1, ChangeFocus, 0, 1),  // k
  KeyPrint!(54, XCB_MOD_MASK_1, "Hello. C has been pressed. %d", 123), // c
  );

void keyPress(xcb_generic_event_t *ev) {
  /* TODO Forward all key presses to wm? */
  auto e = cast(xcb_key_press_event_t*)ev;
  auto w = e.child;
  writeln(*e);
  writeln(e.detail);
  switch (e.detail) { // keycode
    foreach (immutable x; Keys) {
      case x.key:
        x.exec(x.args);
        break;
    }
    default:
      break;
  }
}

void mapRequest(xcb_generic_event_t *ev) {
  auto e = cast(xcb_map_request_event_t*)ev;
  xcb_map_window(c, e.window);
  queue.send(new Message!CreateWindow(e.window).pack());
}

void unmapNotify(xcb_generic_event_t *ev) {
  /* TODO check e.from_configure */
  /* TODO Remove WM_STATE property */
  auto e = cast(xcb_unmap_notify_event_t*)ev;
  queue.send(new Message!DestroyWindow(e.window).pack());
}

void configureRequest(xcb_generic_event_t *ev) {
  auto e = cast(xcb_configure_request_event_t*)ev;
  queue.send(new Message!ConfigureRequest(e).pack());
}

void configureNotify(xcb_generic_event_t *ev) {
  auto e = cast(xcb_configure_notify_event_t*)ev;
  if (e.window == root) {
    /* configure notify for the root window, let wm update geometry */
    queue.send(new Message!Screens().pack());
  }
}
