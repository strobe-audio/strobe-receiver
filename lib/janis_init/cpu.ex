defmodule JanisInit.Cpu do
  require Logger
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Enum.each(governors, &write(&1, "performance"))
    {:ok, []}
  end

  def write(governor, mode) do
    IO.inspect [governor, mode]
     File.write!(governor, mode, [:binary, :write])
  end

  def cpus do
    Path.wildcard("/sys/devices/system/cpu/cpu[0-9]*")
  end

  def governors do
    cpus |> Enum.map(&Path.join(&1, "cpufreq/scaling_governor"))
  end
end

