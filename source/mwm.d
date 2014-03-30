module main;

import deimos.zmq.zmq;

import core.thread;

import mwm.xrunner;
import mwm.wm;
import mwm.common;


int main()
{
  auto wmthread = new Thread(&mwm.wm.run);
  auto xthread = new Thread(&mwm.xrunner.run);

  wmthread.start();

  Thread.sleep(dur!"msecs"(1000));

  xthread.start();

  xthread.join();
  wmthread.join();

  return 0;
}

