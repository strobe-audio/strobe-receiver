defmodule Janis.Broadcaster.SNTP do
  @moduledoc ~S"""
  An SNTP client.
  """

  use     GenServer
  use     Monotonic
  require Logger

  @name Janis.Broadcaster.SNTP

  def start_link(broadcaster) do
    GenServer.start_link(__MODULE__, broadcaster)
  end

  def init(broadcaster) do
    Logger.info "#{__MODULE__} initializing #{inspect broadcaster}"
    Process.flag(:trap_exit, true)
    {:ok, %{broadcaster: broadcaster, sync_count: 0}}
  end

  def terminate(reason, _state) do
    Logger.warn "#{__MODULE__} terminating #{inspect reason}"
    :ok
  end

  def measure_sync do
    measure_sync(@name)
  end
  def measure_sync(pid) do
    GenServer.call(pid, :measure_sync, 2000)
  end

  def time_delta(pid) do
    case measure_sync(pid) do
      {:ok, {start, receipt, reply, finish}} ->
        latency = (finish - start) / 2
        # https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_synchronization_algorithm
        delta = round(((receipt - start) + (reply - finish)) / 2)
        {:ok, latency, delta}
      {:error, _reason} = err ->
        err
    end
  end

  def handle_call(:measure_sync, _from, state) do
    {response, state} = state |> ntp_measure
    {:reply, response, state}
  end

  defp ntp_measure(%{broadcaster: broadcaster, sync_count: count} = state) do

    {:ok, socket} = :gen_udp.open(0, [mode: :binary, ip: {0, 0, 0, 0}, active: false])

    packet = <<
      count::size(64)-little-unsigned-integer,
      monotonic_microseconds()::size(64)-little-signed-integer
    >>

    response = case :gen_udp.send(socket, broadcaster.ip, broadcaster.port, packet) do
      {:error, _} = err -> err
      :ok               -> wait_response(socket)
    end
    :gen_udp.close(socket)
    {response, %{state | sync_count: count + 1}}
  end

  defp wait_response(socket) do
    :inet.setopts(socket, [active: :once])
    receive do
      {:udp, ^socket, addr, port, data} -> parse_response({addr, port, data})
      # what else would we get
      msg -> {:error, msg}
    after 1000 ->
      {:error, :timeout}
    end
  end

  defp parse_response({:ok, {_addr, _port, _data} = packet}) do
    parse_response(packet)
  end

  defp parse_response({_addr, _port, data}) do
    now = monotonic_microseconds()
    << _count::size(64)-little-unsigned-integer,
       originate::size(64)-little-signed-integer,
       receipt::size(64)-little-signed-integer,
       reply::size(64)-little-signed-integer
    >> = data
    {:ok, {originate, receipt, reply, now}}
  end

  defp parse_response({:error, :timeout}) do
    {:error, :timeout}
  end
end
