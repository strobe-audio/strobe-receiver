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


