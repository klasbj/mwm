module main;


import core.thread;

import mwm.x;
import mwm.common;


int main()
{
  auto xthread = new Thread(&mwm.x.run);


  Thread.sleep(dur!"msecs"(100));

  xthread.start();

  xthread.join();

  return 0;
}

