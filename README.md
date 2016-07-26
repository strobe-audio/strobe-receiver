Janis
=====

```elixir

{:ok, song} = File.read "/Users/garry/Seafile/Peep/audio/song.raw"

Janis.Player.play song

```

TODO
----

- [ ] monitior broadcaster process from dnssd
- [x] remove unused enm dep

Dependencies
------------

- erlang 18.x

- elixir 1.x

- `avahi`, `dnssd`

    sudo apt-get install -y avahi-daemon libavahi-compat-libdnssd-dev

- `portaudio`

     sudo apt-get install -y portaudio19-dev

     brew install portaudio

- `libsamplerate`:

     sudo apt-get install -y libsamplerate0 libsamplerate0-dev

     brew install libsamplerate

Running
------

### Install

- http://docs.emlid.com/navio/Downloads/Real-time-Linux-RPi2/

- RPi audio software: http://rpi.autostatic.com/

- Upgrade gcc:

    ```bash
    sudo apt-get install -y gcc-4.8
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.6 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.6
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
    sudo update-alternatives --config gcc
    ```

- Erlang/OTP 18:
  https://wtfleming.github.io/2015/12/10/embedded-elixir-raspberry-pi/

    ```bash
    apt-get install wget libssl-dev ncurses-dev m4 unixodbc-dev erlang-dev
    wget http://www.erlang.org/download/otp_src_18.2.1.tar.gz
    tar -xzvf otp_src_18.2.1.tar.gz
    cd otp_src_18.2.1
    ./configure --without-javac  --without-wx
    make && sudo make install
    ```

- Elixir:

    ```
    wget https://github.com/elixir-lang/elixir/releases/download/v1.2.3/Precompiled.zip
    sudo mkdir /usr/lib/elixir
    cd /usr/lib/elixir/
    sudo unzip /home/pi/Precompiled.zip
    sudo bash -c "echo 'export PATH=/usr/lib/elixir/bin:${PATH}' > /etc/profile.d/elixir.sh"
    ```


- `/etc/asound.conf`:

```
pcm.!default {
    type hw
    # card can also be 0
    card IQaudIODAC
}

ctl.!default {
    type hw
    # card can also be 0
    card IQaudIODAC
}
```

- `/etc/modprobe.d/alsa-blacklist.conf`:

```
blacklist snd_bcm2835
```

- Add i2c dac overlay:

    `sudo vim /boot/config.txt`

    add:

    `dtoverlay=iqaudio-dacplus`

- `/etc/modules`

    ```
    #snd-bcm2835
    i2c-dev
    spi-dev
    snd_soc_pcm512x_i2c
    snd_soc_iqaudio_dac
    ```

- Add the user to the audio group: `sudo usermod -a -G audio $USER`



### Linux

Use chrt to use a Round-robin scheduler by default (plus running as root enables the fifo scheduler for the audio thread)

    make && sudo chrt --rr 99  /home/garry/elixir-current/bin/iex -S /home/garry/elixir-current/bin/mix
    make && sudo chrt --rr 99  /usr/lib/elixir/bin/iex -S /usr/lib/elixir/bin/mix

Running the entire app as fifo seems like a good idea but seems to lead to madness -- perhaps because the receiver starves the rest of the system of processor time (?). Things stop working anyway.

Audio Setup
-----------

The sound card clicks between tracks unless you disable the auto-mute feature.

Exactly the best way to do this is a WIP but as a working solution:

- run `alsamixer`
- set "Auto Mute Time Left" and "Auto Mute Time Right" to their max values (10.66s <- ??)
- `/usr/bin/amixer -c 0 sset "Auto Mute" Disabled` - not sure this does anything
- `sudo alsactl store` save the settings

Other DACS:

- https://polyvection.com/ very low-cost DACs:
  - https://polyvection.com/support/plain-series/comparison-chart/ - PlainDAC would be adequate - that's only ~ E10
  - https://polyvection.com/shop/plaindac/
  - All support Pi2 natively + Beaglebone black (with kernel mods)

Possible alternate computers
----------------------------

- Beaglebone black:
  - https://hifiduino.wordpress.com/2014/03/10/beaglebone-black-for-audio/
  - http://beagleboard.org/black

TODO
----

- Improve OS X monotonic time function. e.g. using https://github.com/ChisholmKyle/PosixMachTiming/blob/master/src/timing_test.c
- Look at improved packet offset smoothing behaviour. Need something that filters out the very small scale fluctuations but doesn't lag too far behind the 'actual' value -- impossible?
  - http://www.edaboard.com/thread160059.html
- Look at Ziegler–Nichols method for tuning the PID factors
  - https://en.m.wikipedia.org/wiki/PID_controller
  - https://controls.engin.umich.edu/wiki/index.php/PIDTuningClassical


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

