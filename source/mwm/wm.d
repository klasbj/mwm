module mwm.wm;

import std.stdio;
import std.traits;

import deimos.zmq.zmq;

import mwm.common;
import mwm.messages;
import msgpack;

bool quit = false;

void handle(Message!(MessageType.None) msg) {
  writeln("None message");
  quit = true;
}

void handle(Message!(MessageType.CreateWindow) msg) {
  writefln("CreateWindow: %d", msg.window_id);
}

void handle(Message!(MessageType.DestroyWindow) msg) {
  writefln("DestroyWindow: %d", msg.window_id);
}

void handle(IMessage msg) {
  final switch (msg.getMessageType()) {
    foreach (immutable msgt ; EnumMembers!MessageType) {
      case msgt:
        handle(cast(Message!(msgt))msg);
        break;
    }
  }
}

void run() {
  auto queue = new ZmqSocket(ZMQ_SUB);
  foreach (immutable msgt ; EnumMembers!MessageType) {
    queue.subscribe([cast(ubyte)msgt]);
  }
  //queue.subscribe(cast(ubyte[])"wm "); // TODO: ehm.. this can probably be safer...
  queue.bind("inproc://wm-q");
  queue.bind("ipc://wm-q");

  while (!quit) {
    ubyte[] data = queue.recv();
    try {
      auto msg = unpackMessage(data);
      handle(msg);
    }
    catch (Exception e) {
      writeln("caught: %s", e.msg);
    }
  }

  writeln("wm.run exiting...");

  delete queue;
}

