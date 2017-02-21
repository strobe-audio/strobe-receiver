defmodule JanisInit.LED do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    # mmc0, cpu0-3, none
    write!("/sys/class/leds/led0/trigger", "cpu0")
    # write!("/sys/class/leds/led0/brightness", "1")
    # write!("/sys/class/leds/led1/brightness", "0")

    {:ok, []}
  end

  def write!(path, value) do
    Logger.info "Setting #{path} to mode '#{value}'"
    File.write!(path, value, [:binary, :write])
  end
end
