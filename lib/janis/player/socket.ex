defmodule Janis.Player.Socket do
  use     Monotonic
  use     GenServer
  require Logger

  @moduledoc """
  Listens on a UDP multicast socket and passes all received packets onto
  a given instance of Janis.Player.Buffer.
  """

  @name Janis.Player.Socket

  def start_link(address, stream_info, buffer) do
    GenServer.start_link(__MODULE__, [address, stream_info, buffer], name: @name)
  end

  def init([{broadcaster, port}, stream_info, buffer]) do
    Logger.debug "Player.Socket up #{inspect {broadcaster, port}}"
    Process.flag(:trap_exit, true)
    {:ok, socket} = open_socket(broadcaster, port)
    {:ok, {socket, nil, buffer, stream_info}}
  end

  def open_socket(broadcaster, port) do
    IO.inspect bind_address(broadcaster, port)
    :enm.sub(connect: bind_address(broadcaster, port), subscribe: "", active: true)
  end

  def bind_address(broadcaster, port) do
    IO.inspect Janis.Network.bind_address(broadcaster.ip)
    {:ok, addr} =  Janis.Network.bind_address(broadcaster.ip)
    "tcp://#{Janis.Network.ntoa(addr)}:#{port}"
  end

  def handle_info({:nnsub, __socket, data}, {_socket, _time, buffer, _stream_info} = state) do
    << _count::size(64)-little-unsigned-integer, timestamp::size(64)-little-signed-integer, audio::binary >> = data
    state = case {timestamp, audio} do
      {0, <<>>}  ->
        # Logger.debug "stp #{monotonic_milliseconds}"
        Janis.Player.Buffer.stop(buffer)
        state
      _ ->
        # Logger.debug "rec #{monotonic_milliseconds}"
        put({timestamp, audio}, state)
    end
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

  defp put(packet, {_socket, nil, _buffer, _stream_info} = state) do
    put!(packet, state)
  end

  defp put({timestamp, _data} = packet, {_socket, latest_timestamp, _buffer, _stream_info} = state) when timestamp > latest_timestamp  do
    put!(packet, state)
  end

  defp put({timestamp, _data}, {_socket, latest_timestamp, _buffer, _stream_info} = state) when timestamp <= latest_timestamp  do
    Logger.info "Ignoring packet with timestamp #{timestamp} #{timestamp - latest_timestamp}"
    state
  end

  defp put!({timestamp, _data} = packet, {socket, _ts, buffer, stream_info}) do
    Janis.Player.Buffer.put(buffer, packet)
    # This is a good time to clean up -- we've just received some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    {socket, timestamp, buffer, stream_info}
  end
end
