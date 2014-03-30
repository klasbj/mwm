module mwm.x;

import std.stdio;

import xcb.xcb;
import xcb.xproto;

import mwm.common;

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

  public:
    /* Object- and thread-local X connection */
    xcb_connection_t *xconnection = null;
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
      xcb_configure_window(this, w.window_id, XCB_CONFIG_WINDOW_STACK_MODE, &value);
      xcb_flush(this);
    }
}

