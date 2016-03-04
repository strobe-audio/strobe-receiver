defmodule Janis.Player.Socket do
  use     Monotonic
  use     GenServer
  require Logger

  @moduledoc """
  A container for our two real socket connections, data & control.
  """

  @name         Janis.Player.Socket
  @stop_command << "STOP" >>

  defmodule S do
    @moduledoc false
    defstruct [:broadcaster, :data, :ctrl]
  end

  def start_link(broadcaster, latency, buffer) do
    GenServer.start_link(__MODULE__, [broadcaster, latency, buffer], name: @name)
  end

  def init([broadcaster, latency, buffer]) do
    {:ok, data} = Janis.Player.Socket.Data.start_link(broadcaster, latency, buffer)
    {:ok, ctrl} = Janis.Player.Socket.Ctrl.start_link(broadcaster, latency, buffer)

    {:ok, %S{broadcaster: broadcaster, ctrl: ctrl, data: data}}
  end
end
