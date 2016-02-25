defmodule Janis.Player.Socket do
  use     Monotonic
  use     GenServer
  require Logger

  @moduledoc """
  Listens on a Nanomsg SUB socket and passes all received packets onto
  a given instance of Janis.Player.Buffer.
  """

  @name Janis.Player.Socket

  @stop_command << "STOP" >>

  def start_link(address, stream_info, buffer) do
    GenServer.start_link(__MODULE__, [address, stream_info, buffer], name: @name)
  end

  def init([{broadcaster, port}, stream_info, buffer]) do
    Logger.debug "Player.Socket up #{inspect {broadcaster, port}}"
    Process.flag(:trap_exit, true)
    {:ok, socket} = open_socket(broadcaster, port)
    {:ok, {socket, 0, nil, buffer, stream_info}}
  end

  def open_socket(broadcaster, port) do
    IO.inspect bind_address(broadcaster, port)
    :enm.sub(connect: bind_address(broadcaster, port), subscribe: "", active: true, nodelay: true)
  end

  def bind_address(broadcaster, port) do
    "tcp://#{Janis.Network.ntoa(broadcaster.ip)}:#{port}"
  end

  def handle_info({:nnsub, __socket, @stop_command}, {socket, _count, _time, buffer, stream_info} = _state) do
    Janis.Player.Buffer.stop(buffer)
    {:noreply, {socket, 0, nil, buffer, stream_info}}
  end

  def handle_info({:nnsub, __socket, data}, state) do
    << _c        ::size(64)-little-unsigned-integer,
       timestamp ::size(64)-little-signed-integer,
       audio     ::binary
    >> = data

    put({timestamp, audio}, state)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug "Got message #{inspect msg}"
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info "Stopping #{__MODULE__} #{ inspect reason }"
    :ok
  end

  defp put({timestamp, _data} = packet, {_socket, _count, latest_timestamp, _buffer, _stream_info} = state) when timestamp > latest_timestamp  do
    put!(packet, state)
  end

  defp put({timestamp, _data}, {_socket, _count, latest_timestamp, _buffer, _stream_info} = state) when timestamp <= latest_timestamp  do
    Logger.info "Ignoring packet with timestamp #{timestamp} #{timestamp - latest_timestamp}"
    state
  end

  defp put!(packet, {_socket, _count, _ts, buffer, _stream_info} = state) do
    Janis.Player.Buffer.put(buffer, packet)
    # This is a good time to clean up -- we've just received some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    state
  end
end
