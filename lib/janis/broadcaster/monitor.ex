defmodule Janis.Broadcaster.Monitor do
  use     GenServer
  require Logger
  alias   Janis.Broadcaster.Monitor.Collector

  defmodule S do
    defstruct broadcaster: nil,
              delta: 0,
              latency: 0,
              measurement_count: 0,
              packet_count: 0,
              player: nil
  end

  @monitor_name Janis.Broadcaster.Monitor

  def time_delta do
    GenServer.call(@monitor_name, :get_delta)
  end

  ### GenServer API

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config}, name: @monitor_name)
  end

  # def init({service, address, port, config} = broadcaster) do
  def init({service, address, port, config} = broadcaster) do
    Logger.info "Starting Broadcaster.Monitor #{inspect broadcaster}"
    Process.flag(:trap_exit, true)
    {:ok, collect_measurements(%S{broadcaster: broadcaster})}
  end

  def terminate(reason, state) do
    Logger.info "Stopping Broadcaster.Monitor"
    Janis.Player.stop_player
    :ok
  end

  defp collect_measurements(%S{measurement_count: count, broadcaster: broadcaster} = state) do
    {interval, sample_size} = case count do
      # _ when count == 0  -> { 100, 31}
      _ when count == 0  -> { 100, 11} # debugging value -- saves me a bit of waiting
      _ when count  < 10 -> { 100, 11}
      _ when count >= 20 -> {1000, 11}
      _ when count >= 10 -> { 500, 11}
    end
    Collector.start_link(self, broadcaster, interval, sample_size)
    state
  end

  ########################################################

  def handle_call(:get_delta, _from, %S{delta: delta} = state) do
    {:reply, {:ok, delta}, state}
  end

  def handle_call({:translate_packet, {timestamp, data}}, _from, %S{delta: delta} = state) do
    translated_timestamp = (timestamp - delta)
    {:reply, {translated_timestamp, data}, state}
  end

  def handle_cast({:append_measurement, measurement}, %S{measurement_count: 0} = state) do
    # First measurement! Join receiver channel!
    %S{latency: latency} = state = append_measurement(measurement, state)
    Logger.info "Joining broadcaster ... #{inspect state} "
    Janis.Broadcaster.Socket.join(%{latency: latency})
    {:noreply, state}
  end

  def handle_cast({:append_measurement, measurement}, state) do
    {:noreply, append_measurement(measurement, state)}
  end

  def append_measurement({mlatency, mdelta} = _measurement, %S{measurement_count: measurement_count, latency: latency, delta: delta} = state) do
    # calculate new delta & latency using Cumulative moving average, see:
    # https://en.wikipedia.org/wiki/Moving_average
    new_count = measurement_count + 1
    max_latency = case mlatency do
      _ when mlatency > latency -> mlatency
      _ -> latency
    end
    avg_delta = round (((measurement_count * delta) + mdelta) / new_count)
    state = %S{ state | measurement_count: new_count, latency: max_latency, delta: avg_delta }
    Logger.info "New time delta measurement #{delta} -> #{avg_delta} (#{avg_delta - delta})"
    {:ok, c_time, e_time} = Janis.Audio.time
    Logger.info("C time: #{c_time}; E time: #{e_time} delta: #{c_time - e_time}")
    collect_measurements(state)
    state
  end

  defmodule Collector do
    require Logger

    def start_link(monitor, broadcaster, interval, count) do
      GenServer.start_link(__MODULE__, {monitor, broadcaster, interval, count})
    end

    def init({monitor, broadcaster, interval, count}) do
      Process.send_after(self, :measure, 1)
      {:ok, %{monitor: monitor, broadcaster: broadcaster, interval: interval, count: count, measurements: []}}
    end

    def handle_info(:measure, %{count: count, interval: interval} = state) when count > 0 do
      Process.send_after(self, :measure, interval)
      {:noreply, measure_sync(state)}
    end

    def handle_info(:measure, %{count: count, monitor: monitor} = state) when count <= 0 do
      {latency, delta} = calculate_sync(state)
      GenServer.cast(monitor, {:append_measurement, {latency, delta}})
      {:noreply, state}
    end

    defp measure_sync(%{measurements: measurements, count: count, broadcaster: broadcaster} = state) when count > 0  do
      case sync_exchange(broadcaster) do
        {:ok, {start, receipt, reply, finish}} ->
          latency = (finish - start) / 2
          # https://en.wikipedia.org/wiki/Network_Time_Protocol#Clock_synchronization_algorithm
          delta = round(((receipt - start) + (reply - finish)) / 2)
          %{ state | count: count - 1,  measurements: [{latency, delta} | measurements]}
        {:error, _reason} = err ->
          Logger.warn "Error measuring time sync #{inspect err}"
          state
      end
    end

    # http://www.mine-control.com/zack/timesync/timesync.html
    defp calculate_sync(%{measurements: measurements} = _state) do
      sorted_measurements = Enum.sort_by measurements, fn({latency, _delta}) -> latency end
      {:ok, median} = Enum.fetch sorted_measurements, round(Float.floor(length(measurements)/2))
      {median_latency, _} = median
      std_deviation = std_deviation(sorted_measurements, median_latency)
      discard_limit = median_latency + std_deviation
      valid_measurements = Enum.reject sorted_measurements, fn({latency, _delta}) -> latency > discard_limit end
      { max_latency, _delta } = Enum.max_by measurements, fn({latency, _delta}) -> latency end
      average_delta = Enum.reduce(valid_measurements, 0, fn({_latency, delta}, acc) -> acc + delta end) / length(valid_measurements)
      { round(max_latency), round(average_delta) }
    end

    defp std_deviation(measurements, median_latency) do
      variance = Enum.reduce(measurements, 0, fn({latency, _delta}, acc) ->
        acc + :math.pow(latency - median_latency, 2)
      end) / length(measurements)
      :math.sqrt(variance)
    end

    defp sync_exchange(broadcaster) do
      Janis.Broadcaster.SNTP.measure_sync
    end

    def terminate(reason, state) do
      :ok
    end
  end
end
