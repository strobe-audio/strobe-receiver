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
    GenServer.start_link(__MODULE__, {broadcaster, latency}, name: __MODULE__)
  end

  def init({broadcaster, latency}) do
    Janis.set_logger_metadata
    Process.flag(:trap_exit, :true)
    {:ok, buffer} = Buffer.start_link(broadcaster)
    {:ok, data}   = start_data_connection(broadcaster, latency, buffer)
    {:ok, ctrl}   = start_ctrl_connection(broadcaster, latency, buffer)
    {:ok, %S{broadcaster: broadcaster, latency: latency, buffer: buffer, data: data, ctrl: ctrl}}
  end

  def handle_info({:EXIT, pid, :tcp_closed}, %S{data: pid} = state) do
    Logger.warn "Data connection closed, re-connecting..."
    {:ok, data} = start_data_connection(state.broadcaster, state.latency, state.buffer)
    {:noreply, %S{state | data: data}}
  end

  def handle_info({:EXIT, pid, :tcp_closed}, %S{ctrl: pid} = state) do
    Logger.warn "Ctrl connection closed, re-connecting..."
    {:ok, ctrl} = start_ctrl_connection(state.broadcaster, state.latency, state.buffer)
    {:noreply, %S{state | ctrl: ctrl}}
  end

  def handle_info(msg, state) do
    Logger.warn "#{__MODULE__} handle_info/2 unhandled message #{ inspect msg }"
    {:noreply, state}
  end

  defp start_ctrl_connection(broadcaster, latency, buffer) do
    start_connection(Ctrl, broadcaster, latency, buffer)
  end
  defp start_data_connection(broadcaster, latency, buffer) do
    start_connection(Data, broadcaster, latency, buffer)
  end

  defp start_connection(module, broadcaster, latency, buffer) do
    module.start_link(broadcaster, latency, buffer)
  end
end
