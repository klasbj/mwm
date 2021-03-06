module mwm.messages;

import msgpack;
import xcb.xproto;

import std.stdio;
import std.traits;
import std.conv;

import mwm.common;

enum MessageType :ubyte {
  None,
  Screens,
  CreateWindow,
  DestroyWindow,
  ChangeFocus,
  ChangeScreen,
  ConfigureRequest,
}

template GenAliases(M...) {
  static if (M.length == 0) {
    enum GenAliases = "";
  } else {
    enum GenAliases = "alias MessageType." ~ to!string(M[0]) ~ " " ~ to!string(M[0]) ~ "; " ~
      GenAliases!(M[1..$]);
  }
}

mixin(GenAliases!(EnumMembers!MessageType));


interface IMessage {
  const ubyte getMessageType() const pure;
}

class Message(MessageType M) : IMessage {
  static if (M == MessageType.CreateWindow || M == MessageType.DestroyWindow) {
    xcb_window_t window_id;
    long screen;
    this(xcb_window_t w) pure {
      window_id = w;
      screen = -1;
    }
    this(xcb_window_t w, long s) pure {
      window_id = w;
      screen = s;
    }
  }
  else static if (M == MessageType.ChangeFocus) {
    xcb_window_t to_window;
    int diff;
    this(xcb_window_t to_w, int d) pure {
      to_window = to_w;
      diff = d;
    }
  }
  else static if (M == MessageType.ChangeScreen) {
    ulong to_screen;
    int diff;
    this(ulong to_s, int d) pure {
      to_screen = to_s;
      diff = d;
    }
  }
  else static if (M == MessageType.ConfigureRequest) {
    xcb_configure_request_event_t ev;
    this(xcb_configure_request_event_t *e) {
      ev = *e;
    }
  }

  /* always have a default constructor */
  this() pure { }

  static const ubyte identifier = M;

  const ubyte getMessageType() const pure { return M; }

  ubyte[] pack() const {
    return [identifier] ~ msgpack.pack(this);
  }
}

IMessage unpackMessage(const ubyte[] data) {
  template GenCase(string T) {
    const char[] GenCase = "case MessageType." ~ T ~
      ": return data[1..$].unpack!(Message!(MessageType." ~ T ~ "))();";
  }
  switch (data[0]) {
    foreach (immutable msgt ; EnumMembers!MessageType) {
      case msgt:
        return data[1..$].unpack!(Message!msgt)();
    }
    default:
      writeln("Unkown message type: ", data[0]);
      break;
  }
  return null;
}
