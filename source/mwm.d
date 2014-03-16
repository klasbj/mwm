module main;

import deimos.zmq.zmq;

import core.thread;

import mwm.x;
import mwm.wm;
import mwm.common;


int main()
{
  auto wmthread = new Thread(&mwm.wm.run);
  auto xthread = new Thread(&mwm.x.run);

  wmthread.start();

  Thread.sleep(dur!"msecs"(100));

  xthread.start();

  xthread.join();
  wmthread.join();

  return 0;
}

