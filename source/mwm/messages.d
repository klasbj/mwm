module mwm.messages;

import msgpack;
import deimos.xcb.xproto;

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
//  ConfigureRequest,
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
  static if (M == MessageType.None) {
  }
  else static if (M == MessageType.Screens) {
    xcb_window_t root_window;
    xcb_get_geometry_reply_t root_geom;
    this(xcb_window_t root, xcb_get_geometry_reply_t geom) pure {
      root_window = root;
      root_geom = geom;
    }
  }
  else static if (M == MessageType.CreateWindow || M == MessageType.DestroyWindow) {
    xcb_window_t window_id;
    this(xcb_window_t w) pure {
      window_id = w;
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
