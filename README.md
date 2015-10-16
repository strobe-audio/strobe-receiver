Janis
=====

```elixir

{:ok, song} = File.read "/Users/garry/Seafile/Peep/audio/song.raw"

Janis.Player.play song

```

Dependencies
------------

- erlang 18.x

- elixir 1.x

- `avahi`, `dnssd`
    sudo apt-get install -y avahi-daemon libavahi-compat-libdnssd-dev
- `portaudio`
     sudo apt-get install -y portaudio19-dev

- `libsamplerate`:

     sudo bash -c 'echo /usr/local/lib >> /etc/ld.so.conf'
     git clone https://github.com/erikd/libsamplerate.git
     cd libsamplerate
     ./autogen.sh --prefix=/usr
     make
     sudo make install

     # sudo apt-get install -y libsamplerate0 libsamplerate0-dev

TODO
----

- The buffer's view of the time delta will fall way out of sync if the player is paused -- buffer needs to know if it's paused so it can stop smearing the delta changes...
- Improve OS X monotonic time function. e.g. using https://github.com/ChisholmKyle/PosixMachTiming/blob/master/src/timing_test.c
- Look at improved packet offset smoothing behaviour. Need something that filters out the very small scale fluctuations but doesn't lag too far behind the 'actual' value -- impossible?
  - http://www.edaboard.com/thread160059.html
- Ramped time diff to improve behaviour of PID control
- Look at Ziegler–Nichols method for tuning the PID factors
  - https://en.m.wikipedia.org/wiki/PID_controller
  - https://controls.engin.umich.edu/wiki/index.php/PIDTuningClassical

- use this ring buffer? http://www.liblfds.org/

Calculate re-sampling needed
----------------------------

Trying to figure out the real playback rate of the audio card so we can
re-sample the audio data to keep the playback rate at the one dictated by the
server is like trying to fit a line to a set of data points: we're looking for
the gradient of the line becauase this tells us the difference in rates between
the server stream time and the playback rate.

So the measurements for this would be
  - `t`: the absolute/monotonic time
  - `ẟp`: the difference between the active packet's actual time offset
    (calculated by taking the packets given timestamp and adding on the number
    of samples played / time per sample) and the one calculated from `t -
    timestamp`. That is comparing the actual time since the packet's timestamp
    and the `audio time` defined in terms of frames per second (at a playback
    rate of 44100 frames per second)

This is called a ['linear regresssion'][] or, more precisely a 'simple linear regression'

But normally for a linear regression, you take the entire sample and perform
the calculation once. What I need to do is calculate the value based on some
kind of rolling, fixed-size, sample.

http://stats.stackexchange.com/questions/6920/efficient-online-linear-regression
https://en.wikipedia.org/wiki/Design_matrix#Simple_Regression

[linear regression]: https://en.wikipedia.org/wiki/Linear_regression

Soft real-time
--------------

- install `libcap2-bin` on Ubuntu/debian/raspbian
- <http://www.drdobbs.com/soft-real-time-programming-with-linux/184402031>
- <http://man7.org/linux/man-pages/man7/capabilities.7.html> :

```
    CAP_SYS_NICE

    * Raise process nice value (nice(2), setpriority(2)) and
      change the nice value for arbitrary processes;
    * set real-time scheduling policies for calling process, and
      set scheduling policies and priorities for arbitrary
      processes (sched_setscheduler(2), sched_setparam(2),
      shed_setattr(2));
    * set CPU affinity for arbitrary processes
      (sched_setaffinity(2));
    * set I/O scheduling class and priority for arbitrary
      processes (ioprio_set(2));
    * apply migrate_pages(2) to arbitrary processes and allow
      processes to be migrated to arbitrary nodes;
    * apply move_pages(2) to arbitrary processes;
    * use the MPOL_MF_MOVE_ALL flag with mbind(2) and
      move_pages(2).
```

(see also <http://stackoverflow.com/questions/413807/is-there-a-way-for-non-root-processes-to-bind-to-privileged-ports-1024-on-l#414258> )

Avahi
-----

The broadcaster lookup is done using Avahi through [dnssd_erlang][]

This requires the following software (on Ubuntu):

    apt-get install avahi-daemon libavahi-compat-libdnssd-dev


[dnssd_erlang]: https://github.com/benoitc/dnssd_erlang

Port Audio
----------

- <http://portaudio.com/docs/v19-doxydocs/paex__ocean__shore_8c.html>: "Generate Pink Noise using Gardner method, and make "waves". Provides an example of how to post stuff to/from the audio callback using lock-free FIFOs implemented by the PA ringbuffer."

- You can get a value for the audio system latency: <http://portaudio.com/docs/v19-doxydocs/structPaStreamParameters.html#aa1e80ac0551162fd091db8936ccbe9a0> "Actual latency values for an open stream may be retrieved using the `inputLatency` and `outputLatency` fields of the `PaStreamInfo` structure returned by `Pa_GetStreamInfo()`"

Jack
----

See http://wiki.linuxaudio.org/wiki/raspberrypi

Installing Jack on RPi:

- http://rpi.autostatic.com
- `sudo apt-cache policy jackd2`:

```
jackd2:
  Installed: 1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1
  Candidate: 1.9.8~dfsg.4+20120529git007cdc37-5+rpi2
  Version table:
     1.9.8~dfsg.4+20120529git007cdc37-5+rpi2 0
        500 http://archive.raspberrypi.org/debian/ wheezy/main armhf Packages
     1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1 0
        500 http://rpi.autostatic.com/raspbian/ wheezy/main armhf Packages
     1.9.8~dfsg.4+20120529git007cdc37-5 0
        500 http://mirrordirector.raspbian.org/raspbian/ wheezy/main armhf Packages
```

- `sudo apt-get install libjack-jackd2-0=1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1 jackd2=1.9.8~dfsg.4+20120529git007cdc37-5+fixed1~raspbian1`


- List audio devices: `aplay -l`
