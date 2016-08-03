defmodule NervesJanis.Dbus.Uuidgen do
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    port = Port.open({:spawn, cmd()}, [:binary, parallelism: true])
    {:ok, port}
  end

  def cmd do
    "#{dbus_uuidgen} --ensure"
  end

  def dbus_uuidgen do
    System.find_executable("dbus-uuidgen")
  end
end

