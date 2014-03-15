module dlangwm;

import std.algorithm;
import std.stdio;
import std.array;
import deimos.xcb.xcb;
import deimos.xcb.xproto;
import std.c.stdlib;

class Window {
  xcb_window_t win;
  uint x, y, width, height;
}

Window[xcb_window_t] windows;
xcb_window_t[] window_order;
ulong selected = 0;
xcb_window_t root;
xcb_connection_t          *c;
xcb_get_geometry_reply_t root_geom;

void function(xcb_generic_event_t*)[uint] handlers;

static this() {
  handlers[XCB_KEY_PRESS] = &keyPress;
  handlers[XCB_MAP_REQUEST] = &mapRequest;
  handlers[XCB_UNMAP_NOTIFY] = &unmapNotify;
  handlers[XCB_CONFIGURE_REQUEST] = &configureRequest;
}

void raiseWindow(Window w) {
  uint value = XCB_STACK_MODE_ABOVE;
  xcb_configure_window(c, w.win, XCB_CONFIG_WINDOW_STACK_MODE, &value);
  xcb_flush(c);
}

void keyPress(xcb_generic_event_t *ev) {
  auto e = cast(xcb_key_press_event_t*)ev;
  auto w = e.child;
  writeln(*e);
  writeln(e.detail);
  if (w == root || w == 0 ||
      selected >= window_order.length) return;
  switch (e.detail) {
    case 44:  // j
      selected = min(selected-1, window_order.length-1);
      raiseWindow(windows[window_order[selected]]);
      break;
    case 45:  // k
      if (++selected >= window_order.length) {
        selected = 0;
      }
      raiseWindow(windows[window_order[selected]]);
      break;
    default:
      break;
  }
}

void mapRequest(xcb_generic_event_t *ev) {
  auto e = cast(xcb_map_request_event_t*)ev;
  writeln("map request: ", *e);
  xcb_map_window(c, e.window);
  Window win;
  
  if (e.window in windows) {
    auto i = countUntil(window_order, e.window);
    selected = i;
    win = windows[e.window];
  } else {
    win = new Window();
    win.win = e.window;
    windows[win.win] = win;
    selected = window_order.length;
    window_order ~= win.win;
  }
    
  win.x = 0;
  win.y = 0;
  win.width = root_geom.width - root_geom.x;
  win.height = root_geom.height - root_geom.y;

  ushort mask =
    XCB_CONFIG_WINDOW_X |
    XCB_CONFIG_WINDOW_Y |
    XCB_CONFIG_WINDOW_WIDTH |
    XCB_CONFIG_WINDOW_HEIGHT |
    XCB_CONFIG_WINDOW_BORDER_WIDTH |
    XCB_CONFIG_WINDOW_STACK_MODE;

  uint[] values = [
    0,
    0,
    root_geom.width - root_geom.x,
    root_geom.height - root_geom.y,
    0,
    XCB_STACK_MODE_ABOVE
    ];

  xcb_configure_window(c, e.window, mask, &values[0]);
  xcb_flush(c);
}

void unmapNotify(xcb_generic_event_t *ev) {
  auto e = cast(xcb_unmap_notify_event_t*)ev;
  if (e.window in windows) {
    auto i = countUntil(window_order, e.window);
    windows.remove(e.window);
    window_order = window_order[0..i] ~ window_order[i+1..$];
    if (selected == i) {
      /* select a new top window */
      selected = min(selected-1, window_order.length-1);
      if (selected < window_order.length) {
        raiseWindow(windows[window_order[selected]]);
      }
    }
  }
}

void configureRequest(xcb_generic_event_t *ev) {
  auto e = cast(xcb_configure_request_event_t*)ev;
  writeln("configure request: ", *e);
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

int main()
{
  uint                       values[10];
  xcb_screen_t              *s;
  xcb_generic_event_t       *ev;
  bool                       done = false;

  /* open connection with the server */
  c = xcb_connect(null,null);
  if (xcb_connection_has_error(c)) {
    writefln("Cannot open display");
    return 1;
  }
                       /* get the first screen */
  s = xcb_setup_roots_iterator( xcb_get_setup(c) ).data;
  root = s.root;
  root_geom = *xcb_get_geometry_reply(c, xcb_get_geometry(c, root), null);

  //xcb_grab_key(c, true, root, XCB_MOD_MASK_3, XCB_NO_SYMBOL, XCB_GRAB_MODE_ASYNC,
  xcb_grab_key(c, true, root, XCB_MOD_MASK_1, 44, XCB_GRAB_MODE_ASYNC,
      XCB_GRAB_MODE_ASYNC);
  xcb_grab_key(c, true, root, XCB_MOD_MASK_1, 45, XCB_GRAB_MODE_ASYNC,
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
  }while(!done);
  /* close connection to server */
  xcb_disconnect(c);

  writeln("Exiting...");

  return 0;
}

