defmodule JanisInit.ETH do
  @moduledoc """
  Attempt to push interrupts to CPU0 (i.e. away from the CPU we're running the
  audio thread on.)
  """

  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    # TODO: work this out from CPU number we're binding the audio to
    set_rps_cpus(eth0, '1')
    set_xps_cpus(eth0, '1')
    {:ok, []}
  end

  def set_rps_cpus(iface, affinity) do
    write!(rps_cpus(iface), affinity)
  end

  def set_xps_cpus(iface, affinity) do
    write!(xps_cpus(iface), affinity)
  end

  def rps_cpus(iface) do
    Path.join([iface, "queues/rx-0/rps_cpus"])
  end

  def xps_cpus(iface) do
    Path.join([iface, "queues/tx-0/xps_cpus"])
  end

  def eth0 do
    "/sys/class/net/eth0"
  end

  defp write!(path, value) do
    Logger.info "Setting #{path} ==> #{value}"
    File.write!(path, value, [:binary, :write])
  end
end
