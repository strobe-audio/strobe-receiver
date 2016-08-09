defmodule JanisInit.Dbus do
  require Logger
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    # System.cmd(dbus_uuidgen(), ["--ensure=/root/machine-id"])
    port = IO.inspect Port.open({:spawn, cmd()}, [:binary, parallelism: true])
    {:ok, port}
  end

  def cmd do
    "#{dbus_daemon()} --config-file=/etc/dbus-1/system.conf --nofork --nopidfile"
  end

  def dbus_uuidgen do
    System.find_executable("dbus-uuidgen")
  end
  def dbus_daemon do
    System.find_executable("dbus-daemon")
  end
end
