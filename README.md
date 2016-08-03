# NervesJanis

On linux:

Install Erlang 19, Elixir, etc

Assuming ubuntu 16.04 Xenial Xerus

https://hexdocs.pm/nerves/installation.html

```
curl -O -L https://packages.erlang-solutions.com/erlang/esl-erlang/FLAVOUR_1_general/esl-erlang_19.0-1~ubuntu~xenial_amd64.deb
```



```
cd ~
mkdir nerves_build; cd nerves_build
git clone https://github.com/nerves-project/nerves_system_br.git
git clone https://github.com/nerves-project/nerves_system_rpi3.git
cd nerves_system_br
bash ./create-build.sh ../nerves_system_rpi3/nerves_defconfig ../NERVES_SYSTEM
cd ../NERVES_SYSTEM
make menuconfig
```

# you have to do something along the lines of

```
apt-get install build-essential python python3 curl wget
```

when you are running `mix firmware` you are going to need to set an environment variable. if you have a bash type shell do: `export NERVES_SYSTEM=~/nerves_build/NERVES_SYSTEM`


#

No need for nerves_uart. You just need to change the erlinit.config file to output the iex prompt through the serial port and run picocom or some other com port terminal program on your laptop.

[2:47]
For the Raspberry Pi 2, the erlinit.config file should reference ttyAMA0 instead of tty1. We should probably document it better, but if you look at the system's README.md file, it kind of says that: https://github.com/nerves-project/nerves_system_rpi2

Actually, if you forget about this, `erlinit` prints what you need to do out the serial port.


You can get shell access by adding `--run-on-exit /bin/sh` to your erlinit.config file and then exiting iex by CTRL-C, CTRL-C or any other means.