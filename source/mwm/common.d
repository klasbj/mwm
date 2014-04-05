module mwm.common;

import std.stdio;
import std.string;
import std.conv;

import xcb.xproto;
import deimos.zmq.zmq;

shared bool quitTheProgram = false;

struct Position {
  int x;
  int y;
}

struct Size {
  uint width;
  uint height;
}

interface Layout {
  void arrange(Screen s);
  void insert(Screen s, const xcb_window_t window);
  void focus(Screen s, int delta);
  void move(Screen s, int delta);
}

class Screen {
  Position origin;
  Size size;
  /* List windows */
  /* Layout layout */

  this(int x, int y, uint w, uint h) {
    this.origin = Position(x,y);
    this.size = Size(w,h);
  }

  void sameAs(const Screen s) {
    this.origin = s.origin;
    this.size = s.size;
  }

  override string toString() {
    return "Screen(" ~
      to!string(origin) ~ "," ~
      to!string(size) ~ ")";
  }
}

class Window {
  xcb_window_t window_id;
  long screen;
  Position origin;
  Size size;

  this() { }
  this(xcb_window_t w, long screen) {
    this.window_id = w;
    this.screen = screen;
  }

  override string toString() {
    return "Window(" ~
      to!string(window_id) ~ "," ~
      to!string(screen) ~ "," ~
      to!string(origin) ~ "," ~
      to!string(size) ~ ")";
  }
}

class ZmqSocket {
  private:
    /* shared internal zeromq context */
    shared static void* g_ctx = null;
    shared static this() {
      g_ctx = cast(shared(void*))zmq_ctx_new();
    }
    shared static ~this() {
      zmq_ctx_destroy(cast(void*)g_ctx);
    }

    /* local context */
    static void *ctx;
    static this() {
      ctx = cast(void*)g_ctx;
    }

    /* object vars */
    void *socket;

  public:
    alias socket this;

    this(int type) {
      socket = zmq_socket(ctx, type);
      if (socket == null) {
        /* throw exception */
      }
    }
    ~this() {
      /* set LINGER to 1 second */
      int val = 1000;
      zmq_setsockopt(socket, ZMQ_LINGER, &val, 4);
      zmq_close(socket);

      writeln("closed socket");
    }

    void connect(string endpoint) {
      /* TODO check return */
      zmq_connect(socket, toStringz(endpoint));
    }

    void bind(string endpoint) {
      /* TODO check return */
      zmq_bind(socket, toStringz(endpoint));
    }

    void subscribe(const ubyte[] filter) {
      zmq_setsockopt(
          socket,
          ZMQ_SUBSCRIBE,
          cast(const void*)&filter[0],
          filter.length);
    }

    void send(const ubyte[] data) {
      zmq_msg_t msg;
      zmq_msg_init_size(&msg, data.length);
      (cast(ubyte*)zmq_msg_data(&msg))[0..data.length] = data[0..$];
      /* TODO check return */
      zmq_sendmsg(socket, &msg, 0);
    }

    ubyte[] recv() {
      zmq_msg_t msg;
      zmq_msg_init(&msg);
      /* TODO check return */
      zmq_recvmsg(socket, &msg, 0);

      auto len = zmq_msg_size(&msg);
      ubyte[] ret =(cast(ubyte*)zmq_msg_data(&msg))[0..len].dup;
      zmq_msg_close(&msg);

      return ret;
    }
}

