defmodule NervesJanis.Avahi do
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    port = Port.open({:spawn, cmd()}, [:binary, parallelism: true])
    {:ok, port}
  end

  def cmd do
    avahi_daemon
  end
  def avahi_daemon do
    System.find_executable("avahi-daemon")
  end
end

