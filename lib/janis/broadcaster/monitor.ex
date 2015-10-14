defmodule Janis.Broadcaster.Monitor do
  use     GenServer
  require Logger
  alias   Janis.Broadcaster.Monitor.Collector

  defmodule S do
    defstruct broadcaster: nil,
              delta: nil,
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

  def handle_info({:start_collection, interval, sample_size}, %{broadcaster: broadcaster} = state) do
    Collector.start_link(self, broadcaster, interval, sample_size)
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info "Stopping Broadcaster.Monitor"
    Janis.Player.stop_player
    :ok
  end

  defp collect_measurements(%S{measurement_count: count, broadcaster: broadcaster} = state) do
    {interval, sample_size, delay} = case count do
      _ when count  < 10 -> { 50, 11, 0}
      _ when count >= 20 -> { 80, 21, 4000}
      _ when count >= 10 -> { 80, 21, 1000}
    end
    :timer.send_after(delay, self, {:start_collection, interval, sample_size})
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

  def append_measurement({new_latency, new_delta} = _measurement, %S{measurement_count: measurement_count, latency: latency, delta: delta} = state) do
    state = append_latency_measurement(new_latency, state)
    state = append_delta_measurement(new_delta, state)

    state = %S{ state | measurement_count: measurement_count + 1 }
    collect_measurements(state)
    state
  end

  defp append_latency_measurement(new_latency, %S{ latency: latency } = state) do
    max_latency = case new_latency do
      _ when new_latency > latency -> new_latency
      _ -> latency
    end
    %S{ state | latency: max_latency }
  end

  defp append_delta_measurement(new_delta, %S{ delta: nil} = state) do
    %S{ state | delta: new_delta }
  end

  defp append_delta_measurement(new_delta, %S{ delta: delta} = state) do
	 	# /* double newavg = oldavg + (d / n); */
		# double newavg = new + (0.999 * (oldavg - new));
    # avg_delta = round (((measurement_count * delta) + new_delta) / new_count)
    # avg_delta = (delta  + (new_delta - delta) / 20) |> round
    avg_delta = (new_delta + (0.9 * (delta - new_delta))) |> round
    # avg_delta = (delta  + (new_delta - delta) / 20) |> round
    Logger.info "New time delta measurement #{delta}/#{new_delta} #{delta} -> #{avg_delta} (#{avg_delta - delta})"
    %S{ state | delta: avg_delta }
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
        {:ok, latency, delta} ->
          %{ state | count: count - 1,  measurements: [{latency, delta} | measurements]}
        {:error, _reason} = err ->
          Logger.warn "Error measuring time sync #{inspect err}"
          state
      end
    end

    # http://www.mine-control.com/zack/timesync/timesync.html
    defp calculate_sync(%{measurements: measurements} = _state) do
      sorted_measurements = Enum.sort_by measurements, fn({latency, _delta}) -> latency end
      {:ok, {median_latency, _}} = Enum.fetch sorted_measurements, round(Float.floor(length(measurements)/2))
      std_deviation = std_deviation(sorted_measurements, median_latency)
      discard_limit = median_latency + std_deviation
      valid_measurements = Enum.reject sorted_measurements, fn({latency, _delta}) -> latency > discard_limit end
      { max_latency, _delta } = Enum.max_by valid_measurements, fn({latency, _delta}) -> latency end
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
      Janis.Broadcaster.SNTP.time_delta
    end

    def terminate(reason, state) do
      :ok
    end
  end
end
