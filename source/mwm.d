module main;

import deimos.zmq.zmq;

import core.thread;

import mwm.xrunner;
import mwm.wm;
import mwm.common;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;

extern(C) void sigchld(int _) nothrow @system {
  try {
    while (0 < waitpid(-1, null, WNOHANG)) { }
  } catch { }
}


int main()
{
  if (signal(SIGCHLD, &sigchld) == SIG_ERR) {
    wr("unable to install sigchld handler");
  }

  auto wmthread = new Thread(&mwm.wm.run);
  auto xthread = new Thread(&mwm.xrunner.run);

  wmthread.start();

  Thread.sleep(dur!"msecs"(100));

  xthread.start();

  xthread.join();
  wmthread.join();

  return 0;
}

