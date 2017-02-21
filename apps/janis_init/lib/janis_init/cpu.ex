defmodule JanisInit.Cpu do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do

    governors
    |> Enum.zip(~w(powersave powersave powersave performance))
    |> Enum.each(fn({cpu, setting}) -> JanisInit.Cpu.write!(cpu, setting) end)

    write!("/proc/sys/vm/swappiness", "0")
    write!("/proc/sys/kernel/sched_min_granularity_ns", "750000")
    write!("/proc/sys/kernel/sched_wakeup_granularity_ns", "1000000")
    write!("/proc/sys/kernel/sched_latency_ns", "1500000")

    {:ok, []}
  end

  def write!(path, value) do
    Logger.info "Setting #{path} to mode '#{value}'"
    File.write!(path, value, [:binary, :write])
  end

  def cpus do
    Path.wildcard("/sys/devices/system/cpu/cpu[0-9]*")
  end

  def governors do
    cpus |> Enum.map(&Path.join(&1, "cpufreq/scaling_governor"))
  end
end
