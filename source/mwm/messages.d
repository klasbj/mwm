module mwm.messages;

import msgpack;
import deimos.xcb.xproto;

import std.stdio;
import std.traits;

import mwm.common;

enum MessageType :ubyte {
  None = 0,
  CreateWindow,
  DestroyWindow,
//  ConfigureRequest,
//  Screens,
}

interface IMessage {
  const ubyte getMessageType() const pure;
}

class Message(MessageType M) : IMessage {
  static if (M == MessageType.None) {
  }
  else static if (M == MessageType.CreateWindow || M == MessageType.DestroyWindow) {
    xcb_window_t window_id;
    this(xcb_window_t w) pure {
      window_id = w;
    }
    this() pure { }
  }

  static const ubyte identifier = M;

  const ubyte getMessageType() const pure { return M; }

  ubyte[] pack() {
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
