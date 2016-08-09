defmodule NervesAvahi.Alsa do
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    Logger.warn "Resetting alsa settings..."
    System.cmd(alsactrl(), ["restore"])
    {:ok, []}
  end

  def alsactrl do
    System.find_executable("alsactl")
  end
end

