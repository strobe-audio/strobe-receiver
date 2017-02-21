# Strobe Receiver

http://strobe.audio

This is the Elixir umbrella app for the receiver side of the Strobe multi-room
audio system.

This repo holds both the receiver Elixir application and also the [Nerves][]
based firmware application that allows the receiver to be installed as firmware
on a Raspberry Pi 2/3 device.

[Nerves]: http://nerves-project.org/

## Supported hardware

Currently the supported hardware is:

- [Raspberry Pi 2](https://www.raspberrypi.org/products/raspberry-pi-2-model-b/)
- [Raspberry Pi 3](https://www.raspberrypi.org/products/raspberry-pi-3-model-b/)
- [IQaudIO Pi-DAC+](http://iqaudio.co.uk/audio/8-pi-dac-0712411999643.html)
- [IQaudIO Pi-DACZero](http://iqaudio.co.uk/audio/38-pi-daczero.html)

Beyond that you'll need to install & run a single [Strobe Hub][] and to connect
your chosen DAC(s) to an amplifier & speakers.

[Strobe Hub]: https://github.com/strobe-audio/strobe-hub

## Running locally

It's possible to run the receiver locally if you'd like to play music through
your computer or are interested in working on the Strobe system.

The receiver app is called [janis][].

[janis]: https://en.wikipedia.org/wiki/Janis_Joplin


### Requirements

##### Erlang/OTP r18+

Mac:

    brew install erlang

##### A working Elixir installation.

Currently only Elixir 1.3 is supported so the recommended approach is to
install & use the [asdf](https://github.com/asdf-vm/asdf) version manager.

First install asdf by following the instructions in the repo, then add the
Elixir plugin and install Elixir 1.3.4


    asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
    asdf install elixir 1.3.4
    asdf local elixir 1.3.4


##### Libraries

Interfacing with your system's audio hardware is done via [Portaudio][] which
you can install via homebrew on a mac:


     brew install portaudio


or via apt on a Debian/Ubuntu machine:


     sudo apt-get install -y portaudio19-dev

Constant synchronisation of the audio is achieved by constant tiny amounts of
audio resampling, this is done using [libsamplerate][]


Mac:

     brew install libsamplerate

Debian/Ubuntu:

     sudo apt-get install -y libsamplerate0 libsamplerate0-dev


Service discovery is attempted using DNSSD/[mDNS][] using Bonjour/Avahi:

     sudo apt-get install -y avahi-daemon libavahi-compat-libdnssd-dev

[Portaudio]: http://www.portaudio.com/
[libsamplerate]: http://www.mega-nerd.com/SRC/
[mDNS]: https://en.wikipedia.org/wiki/Multicast_DNS

## Building the Firmware

The following will build the Strobe Receiver firmware and allow you to burn
it to an SD card ready for booting your Receiver.

### Requirements

You must run the following commands within a Linux environment, either real or
virtualized.

First we need the buildroot dependencies:


    sudo apt-get install git g++ libssl-dev libncurses5-dev bc m4 make unzip cmake


then you'll need a working Elixir 1.3 installation as detailed above.

### Building

The following instructions will build firmware for a Raspberry Pi 3. If you
want to build for a Raspberry Pi 2, then replace `rpi3` with `rpi2` in all the
subsequent commands.

This requires a lot of diskspace, so make sure you have something like 8GB of
freespace on whichever disk you're doing this on.

I'm assuming a subdirectory of your home partition here, but you can do this
from anywhere, you just need to reference the location in the subsequent `mix`
commands.

The following commands will generate & compile the required buildroot
environment for the Strobe receiver firmware.


    mkdir ~/nerves-firmware
    cd ~/nerves-firmware

    git clone https://github.com/nerves-project/nerves_system_br.git
    git clone https://github.com/strobe-audio/nerves_system_rpi3

    mkdir NERVES_SYSTEM_RPI3
    cd nerves_system_br

    ./create-build.sh ../nerves_system_rpi3/nerves_defconfig ../NERVES_SYSTEM_RPI3

    cd ../NERVES_SYSTEM_RPI3
    make


This will take a _long_ time the first time it is run -- subsequent builds are
incremental & will be quicker.

Once that's complete we are ready to build & burn the Elixir side of things.

If you haven't already done so, clone this repository


    cd ~

    git clone https://github.com/strobe-audio/strobe-receiver.git

    cd strobe-receiver/apps/nerves_janis


Be sure to reference the buildroot system you compiled in the previous steps.


    NERVES_SYSTEM=~/nerves-firmware/NERVES_SYSTEM_RPI3 NERVES_TARGET=rpi3 mix deps.get


if you want you could make the `NERVES_SYSTEM` and `NERVES_TARGET` env settings
persistent (I haven't done this so all the commands work out of the box).


    export NERVES_SYSTEM=~/nerves-firmware/NERVES_SYSTEM_RPI3
    export NERVES_TARGET=rpi3


Now we can compile the firmware into a `.fw` file ready for writing to our SD
card using `fwup`


    NERVES_SYSTEM=~/nerves-firmware/NERVES_SYSTEM_RPI3 NERVES_TARGET=rpi3 mix firmware


Now insert an SD card, if you haven't already:


    NERVES_SYSTEM=~/nerves-firmware/NERVES_SYSTEM_RPI3 NERVES_TARGET=rpi3 mix firmware.burn

You're now good to go. Pop the SD card into your RPi3 and turn it on. You
should see a new receiver appear in the Strobe UI.

## License

Stobe Audio Receiver
Copyright (C) 2017 Garry Hill

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

