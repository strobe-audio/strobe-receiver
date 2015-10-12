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

- `portaudio`
     sudo apt-get install -y portaudio19-dev

- `libsamplerate`:
     sudo apt-get install -y libsamplerate0 libsamplerate0-dev


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
