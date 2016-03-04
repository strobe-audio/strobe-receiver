defmodule Janis.Player do
  use GenServer

  @name Janis.Player

  alias Janis.Player.Buffer
  alias Janis.Player.Socket.Data
  alias Janis.Player.Socket.Ctrl

  defmodule S do
    @moduledoc false
    defstruct [:buffer, :data, :ctrl]
  end

  def start_link(broadcaster, latency) do
    GenServer.start_link(__MODULE__, {broadcaster, latency})
  end

  def init({broadcaster, latency}) do
    {:ok, buffer} = Buffer.start_link(broadcaster)
    {:ok, data}   = Data.start_link(broadcaster, latency, buffer)
    {:ok, ctrl}   = Ctrl.start_link(broadcaster, latency, buffer)
    {:ok, %S{buffer: buffer, data: data, ctrl: ctrl}}
  end
end
