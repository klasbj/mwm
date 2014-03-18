module mwv.common;

import std.stdio;
import std.string;

import deimos.xcb.xproto;
import deimos.zmq.zmq;

shared bool quitTheProgram = false;

T unpack(T)(const ubyte[] data) {
  T v = *(cast(T*)data[0..T.sizeof].ptr);
  version(LittleEndian) {
    ubyte* p = cast(ubyte*)&v;
    foreach (i; 0 .. T.sizeof/2) {
      auto tmp = p[i];
      p[i] = p[T.sizeof - 1 - i];
      p[T.sizeof - 1 - i] = tmp;
    }
  }
  return v;
}

T[] unpack(T : T[])(const ubyte[] data, int num) {
  assert(data.length >= num*T.sizeof);
  auto v = new T[num];
  foreach (i; 0..num) {
    v[i] = unpack!T(data[i*T.sizeof..$]);
  }
  return v.dup;
}

int pack(T)(ubyte* data, const T v) {
  *(cast(T*)data[0..T.sizeof].ptr) = v;
  version(LittleEndian) {
    foreach (i; 0 .. T.sizeof/2) {
      auto tmp = data[i];
      data[i] = data[T.sizeof - 1 - i];
      data[T.sizeof - 1 - i] = tmp;
    }
  }
  return T.sizeof;
}

int pack(T : T[])(ubyte* data, const T[] v) {
  foreach (i, vv; v) {
    pack(&data[i*T.sizeof], vv);
  }
  return cast(int)(v.length * T.sizeof);
}

unittest {
  assert(unpack!uint([ 0x01, 0x02, 0x03, 0x04 ]) == 0x01020304);
  assert(unpack!ushort([ 0x03, 0x04 ]) == 0x0304);

  ubyte[8] data;
  pack!ushort(&data[0], 0x0304);
  assert(data[0..2] == [ 0x03, 0x04 ]);
  assert(unpack!ushort(data) == 0x0304);

  assert(unpack!(short[])([ 0xff, 0xff, 0x01, 0x02, 0x03 ], 2) == [ -1, 0x0102 ]);
  pack!(short[])(&data[1], [ -1, 0x0102 ]);
  assert(data[1..5] == [ 0xff, 0xff, 0x01, 0x02 ]);
  assert(unpack!(short[])(data[1..5], 2) == [ -1, 0x0102 ]);
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

class Window {
  xcb_window_t win;
  uint x, y, width, height;
}

