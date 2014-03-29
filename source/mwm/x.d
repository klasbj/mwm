module mwm.x;

import std.algorithm;
import std.stdio;
import std.array;
import deimos.xcb.xcb;
import deimos.xcb.xproto;
import deimos.zmq.zmq;
import std.c.stdlib;
import msgpack;


import mwm.common;
import mwm.messages;

xcb_window_t root;
xcb_get_geometry_reply_t root_geom;
X c;
ZmqSocket queue;

static this() {
  c = new X();

  queue = new ZmqSocket(ZMQ_PUB);
  queue.connect("inproc://wm-q");
}
static ~this() {
  delete queue;
}

class X {
  private:
    /* Global context X connection */
    shared static xcb_connection_t *g_xconnection = null;
    shared static this() {
      auto c = xcb_connect(null,null);
      if (xcb_connection_has_error(c)) {
        writefln("Cannot open display");
        /* TODO throw exception? */
      } else {
        g_xconnection = cast(shared(xcb_connection_t*))c;
      }
    }
    shared static ~this() {
      if (g_xconnection != null) {
        xcb_disconnect(cast(xcb_connection_t*)g_xconnection);
      }
    }

    /* Object- and thread-local X connection */
    xcb_connection_t *xconnection = null;
  public:
    this() {
      xconnection = cast(xcb_connection_t*)g_xconnection;
    }

    alias xconnection this; // now aint this a cool feature!

    xcb_connection_t* get_connection() { return xconnection; }

    void configureWindow(Window w) {
      ushort mask =
        XCB_CONFIG_WINDOW_X |
        XCB_CONFIG_WINDOW_Y |
        XCB_CONFIG_WINDOW_WIDTH |
        XCB_CONFIG_WINDOW_HEIGHT |
        XCB_CONFIG_WINDOW_BORDER_WIDTH |
        XCB_CONFIG_WINDOW_STACK_MODE;

      uint[] values = [
        w.origin.x,
        w.origin.y,
        w.size.width,
        w.size.height,
        0,
        XCB_STACK_MODE_ABOVE
          ];

      xcb_configure_window(this, w.window_id, mask, &values[0]);
      xcb_flush(this);
    }

    void raiseWindow(Window w) {
      uint value = XCB_STACK_MODE_ABOVE;
      xcb_configure_window(c, w.window_id, XCB_CONFIG_WINDOW_STACK_MODE, &value);
      xcb_flush(c);
    }
}

immutable(void function(xcb_generic_event_t*)[uint]) handlers;

static this() {
  handlers[XCB_KEY_PRESS] = &keyPress;
  handlers[XCB_MAP_REQUEST] = &mapRequest;
  handlers[XCB_UNMAP_NOTIFY] = &unmapNotify;
  handlers[XCB_CONFIGURE_REQUEST] = &configureRequest;
}

int setup() {
  uint                       values[10];
  xcb_screen_t              *s;

  if (c.get_connection() == null) {
    writefln("Cannot open display");
    return 1;
  }

  /* get the first screen */
  s = xcb_setup_roots_iterator( xcb_get_setup(c) ).data;
  root = s.root;
  root_geom = *xcb_get_geometry_reply(c, xcb_get_geometry(c, root), null);

  queue.send(new Message!Screens(root, root_geom).pack());

  //xcb_grab_key(c, true, root, XCB_MOD_MASK_3, XCB_NO_SYMBOL, XCB_GRAB_MODE_ASYNC,
  xcb_grab_key(c, true, root, XCB_MOD_MASK_1, 44, XCB_GRAB_MODE_ASYNC,
      XCB_GRAB_MODE_ASYNC);
  xcb_grab_key(c, true, root, XCB_MOD_MASK_1, 45, XCB_GRAB_MODE_ASYNC,
      XCB_GRAB_MODE_ASYNC);
  xcb_grab_key(c, true, root, XCB_MOD_MASK_1, 24, XCB_GRAB_MODE_ASYNC,
      XCB_GRAB_MODE_ASYNC);

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
  delete queue;
}

void disconnect() {
  /* close connection to server */
}


void keyPress(xcb_generic_event_t *ev) {
  /* TODO Forward all key presses to wm? */
  auto e = cast(xcb_key_press_event_t*)ev;
  auto w = e.child;
  writeln(*e);
  writeln(e.detail);
  switch (e.detail) {
    case 24:  // j
      quitTheProgram = true;
      break;
    case 44:  // j
      queue.send(new Message!ChangeFocus(0, -1).pack());
      break;
    case 45:  // k
      queue.send(new Message!ChangeFocus(0, 1).pack());
      break;
    default:
      break;
  }
}

void mapRequest(xcb_generic_event_t *ev) {
  /* TODO Leave mapping of the window (?), send a command to wm */
  auto e = cast(xcb_map_request_event_t*)ev;
  writeln("map request: ", *e);
  xcb_map_window(c, e.window);
  Window win;

  queue.send(new Message!CreateWindow(e.window).pack());
}

void unmapNotify(xcb_generic_event_t *ev) {
  /* TODO send command to wm */
  /* TODO check e.from_configure */
  /* TODO Remove WM_STATE property */
  auto e = cast(xcb_unmap_notify_event_t*)ev;
  queue.send(new Message!DestroyWindow(e.window).pack());
}

void configureRequest(xcb_generic_event_t *ev) {
  /* this seems reasonable, I think? */
  auto e = cast(xcb_configure_request_event_t*)ev;
  int i = 0;
  uint[] values;
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
  xcb_configure_window(c, e.window, e.value_mask, &values[0]);
  xcb_flush(c);
}

