module mwm.wm;

import std.stdio;

import deimos.zmq.zmq;

import mwm.common;


void run() {
  auto queue = new ZmqSocket(ZMQ_SUB);
  queue.subscribe(cast(ubyte[])"wm "); // TODO: ehm.. this can probably be safer...
  queue.bind("inproc://wm-q");
  queue.bind("ipc://wm-q");

  int x = 1;
  while (x != 0) {
    ubyte[] data = queue.recv();
    x = *cast(int*)data[3..7];
    writefln("received integer: %x", x);
  }

  writeln("wm.run exiting...");

  destroy(queue);
}

