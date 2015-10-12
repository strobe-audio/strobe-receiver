defmodule Janis.Player.Socket do
  use     Monotonic
  use     GenServer
  require Logger

  @moduledoc """
  Listens on a UDP multicast socket and passes all received packets onto
  a given instance of Janis.Player.Buffer.
  """

  @name Janis.Player.Socket

  def start_link({ip, port}, stream_info, buffer) do
    GenServer.start_link(__MODULE__, [{ip, port}, stream_info, buffer], name: @name)
  end

  def init([ {ip, port}, stream_info, buffer ]) do
    Logger.debug "Player.Socket up #{inspect {ip, port}}"
    Process.flag(:trap_exit, true)
    {:ok, socket} = :gen_udp.open port, [:binary, active: true, ip: ip, add_membership: {ip, {0, 0, 0, 0}}, reuseaddr: true]
    # :ok = :gen_udp.controlling_process(socket, self)
    {:ok, {socket, nil, buffer, stream_info}}
  end

  def handle_info({:udp, __socket, __addr, __port, data}, {_socket, _time, buffer, _stream_info} = state) do
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

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__}"
    :ok
  end

  defp put(packet, {_socket, nil, _buffer, _stream_info} = state) do
    put!(packet, state)
  end

  defp put({timestamp, _data} = packet, {_socket, latest_timestamp, _buffer, _stream_info} = state) when timestamp > latest_timestamp  do
    put!(packet, state)
  end

  defp put({timestamp, _data} = packet, {_socket, latest_timestamp, _buffer, _stream_info} = state) when timestamp <= latest_timestamp  do
    Logger.info "Ignoring packet with timestamp #{timestamp} #{timestamp - latest_timestamp}"
    state
  end

  defp put!({timestamp, _data} = packet, {_socket, _ts, buffer, _stream_info} = state) do
    Janis.Player.Buffer.put(buffer, packet)
    {_socket, timestamp, buffer, _stream_info}
  end
end
