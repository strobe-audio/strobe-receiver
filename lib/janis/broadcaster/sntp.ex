defmodule Janis.Broadcaster.SNTP do
  use GenServer
  use Monotonic

  @name Janis.Broadcaster.SNTP

  def start_link(_service, address, port, _config) do
    GenServer.start_link(__MODULE__, {address, port}, name: @name)
  end

  def init({address, port}) do
    {:ok, %{broadcaster: {parse_address(address), port}, sync_count: 0}}
  end

  defp parse_address(addr_string) do
    addr_string |> String.to_char_list
  end

  def measure_sync do
    GenServer.call(@name, :measure_sync)
  end

  def time_delta do
    case measure_sync do
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
    ntp_measure(state)
  end

  defp ntp_measure(%{broadcaster: {address, port} = _broadcaster, sync_count: count} = state) do
    {:ok, socket} = :gen_udp.open(0, [mode: :binary, ip: {0, 0, 0, 0}, active: false])

    packet = <<
    count::size(64)-little-unsigned-integer,
    monotonic_microseconds::size(64)-little-signed-integer
    >>
    :ok = :gen_udp.send(socket, address, port, packet)

    response = wait_response(socket)

    :ok = :gen_udp.close(socket)
    {:reply, response, %{state | sync_count: count + 1}}
  end

  defp wait_response(socket) do
    receive do
    after 0 ->
      :gen_udp.recv(socket, 0, 1000) |> parse_response
    end
  end

  defp parse_response({:ok, {_addr, _port, data}}) do
    now = monotonic_microseconds
    << count::size(64)-little-unsigned-integer,
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
