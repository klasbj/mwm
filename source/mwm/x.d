module mwm.x;

import std.stdio;

import xcb.xcb;
import xcb.xproto;
import xcb.xinerama;

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
    static xcb_connection_t *xconnection = null;
    static this() {
      xconnection = cast(xcb_connection_t*)g_xconnection;
    }

    alias xconnection this; // now aint this a cool feature!

    static xcb_connection_t* get_connection() { return xconnection; }
    static @property xcb_connection_t* connection() { return xconnection; }

    static void configureWindow(Window w) {
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

      xcb_configure_window(connection, w.window_id, mask, &values[0]);
    }

    static void raiseWindow(Window w) {
      uint value = XCB_STACK_MODE_ABOVE;
      xcb_configure_window(connection, w.window_id, XCB_CONFIG_WINDOW_STACK_MODE, &value);
    }

    static void flush() {
      xcb_flush(connection);
    }

    static const(Screen)[] getScreens() {
      Screen[] ss;
      auto active = xcb_xinerama_is_active_reply(connection,
                        xcb_xinerama_is_active(connection), null);
      if (active.state) {
        // Xinerama is active, get the screens
        auto res = xcb_xinerama_query_screens_reply(connection,
            xcb_xinerama_query_screens(connection), null);
        ss.length = res.number;

        auto it = xcb_xinerama_query_screens_screen_info_iterator(res);
        for (; it.rem > 0; xcb_xinerama_screen_info_next(&it)) {
          ss[res.number - it.rem] = Screen(
              it.data.x_org, it.data.y_org, it.data.width, it.data.height);
        }

        // remove duplicate screens
        ulong w = 0;

reader: for (ulong r = 0; r < ss.length; ++r) {
          foreach (x; ss[0..w])
            if (x == ss[r])
              continue reader;
          ss[w++] = ss[r];
        }
        ss = ss[0..w];

      } else {
        // No Xinerama, assume one monitor, the root window
        auto s = xcb_setup_roots_iterator( xcb_get_setup(connection) ).data;
        auto root = s.root;
        auto root_geom = *xcb_get_geometry_reply(connection, xcb_get_geometry(connection, root), null);
        ss.length = 1;
        ss[0] = Screen(root_geom.x, root_geom.y, root_geom.width, root_geom.height);
      }

      return ss;
    }
}

