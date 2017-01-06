defmodule Janis.Player do
  use GenServer

  alias Janis.Player.Buffer
  alias Janis.Player.Socket.Data
  alias Janis.Player.Socket.Ctrl

  require Logger

  defmodule S do
    @moduledoc false

    defstruct [
      :buffer,
      :data,
      :ctrl,
      :broadcaster,
      :latency,
    ]
  end

  def start_link(broadcaster, latency) do
    GenServer.start_link(__MODULE__, {broadcaster, latency})
  end

  def init({broadcaster, latency}) do
    Process.flag(:trap_exit, :true)
    {:ok, buffer} = Buffer.start_link(broadcaster)
    {:ok, data}   = start_connection(Data, broadcaster, latency, buffer)
    {:ok, ctrl}   = start_connection(Ctrl, broadcaster, latency, buffer)
    {:ok, %S{broadcaster: broadcaster, latency: latency, buffer: buffer, data: data, ctrl: ctrl}}
  end

  def handle_info({:EXIT, pid, :tcp_closed}, %S{data: pid} = state) do
    Logger.warn "Data connection closed, re-connecting..."
    {:ok, data} = start_connection(Data, state.broadcaster, state.latency, state.buffer)
    {:noreply, %S{state | data: data}}
  end

  def handle_info({:EXIT, pid, :tcp_closed}, %S{ctrl: pid} = state) do
    Logger.warn "Ctrl connection closed, re-connecting..."
    {:ok, data} = start_connection(Ctrl, state.broadcaster, state.latency, state.buffer)
    {:noreply, %S{state | data: data}}
  end

  defp start_connection(module, broadcaster, latency, buffer) do
    module.start_link(broadcaster, latency, buffer)
  end
end
