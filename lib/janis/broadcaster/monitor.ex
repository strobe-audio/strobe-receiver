defmodule Janis.Broadcaster.Monitor do
  use     Monotonic
  use     GenServer
  require Logger

  alias   Janis.Broadcaster.Monitor.Collector
  alias   Janis.Math.MovingAverage

  defmodule S do
    defstruct broadcaster: nil,
              delta: nil,
              latency: 0,
              measurement_count: 0,
              packet_count: 0,
              player: nil,
              delta_listeners: [],
              next_measurement_time: nil,
              delta_average: Janis.Math.DoubleExponentialMovingAverage.new(0.05, 0.05)
  end

  @monitor_name Janis.Broadcaster.Monitor
  @delta_step   2

  def time_delta do
    GenServer.call(@monitor_name, :get_delta)
  end

  def add_time_delta_listener(listener) do
    GenServer.cast(@monitor_name, {:add_time_delta_listener, listener})
  end

  def remove_time_delta_listener(listener) do
    GenServer.cast(@monitor_name, {:remove_time_delta_listener, listener})
  end

  ### GenServer API

  def start_link(service, address, port, config) do
    GenServer.start_link(__MODULE__, {service, address, port, config}, name: @monitor_name)
  end

  # def init({service, address, port, config} = broadcaster) do
  def init({service, address, port, config} = broadcaster) do
    Logger.info "Starting Broadcaster.Monitor #{inspect broadcaster}"
    {:ok, collect_measurements(%S{broadcaster: broadcaster})}
  end

  def handle_info({:start_collection, interval, sample_size}, %{broadcaster: broadcaster} = state) do
    {:ok, _pid} = Collector.start_link(self, broadcaster, interval, sample_size)
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__} #{inspect reason}"
    Janis.Player.stop_player
    :ok
  end

  defp collect_measurements(%S{measurement_count: count, broadcaster: broadcaster} = state) do
    {interval, sample_size, delay} = cond do
      count == 0 -> { 50,  31, 0 }
      true       -> { 100, 7,  2_000 }
    end
    :timer.send_after(delay, self, {:start_collection, interval, sample_size})
    %S{ state | next_measurement_time: monotonic_milliseconds + delay + (sample_size * interval) }
  end

  ########################################################

  def handle_call(:get_delta, _from, %S{delta: delta} = state) do
    {:reply, {:ok, delta}, state}
  end

  def handle_cast({:add_time_delta_listener, listener}, %S{delta_listeners: listeners, delta: delta} = state) do

    GenServer.cast(listener, {:init_time_delta, delta})
    {:noreply, %S{ state | delta_listeners: [ listener | listeners ] }}
  end

  def handle_cast({:remove_time_delta_listener, listener}, %S{delta_listeners: listeners} = state) do
    listeners = Enum.reject listeners, &(&1 == listener)
    {:noreply, %S{ state | delta_listeners: listeners }}
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
    state = collect_measurements(state)
    notify_delta_change(delta, state)
    # This is a good time to clean up -- we've just emitted some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    state
  end

  defp notify_delta_change(old_delta, %S{delta: new_delta, next_measurement_time: t, delta_listeners: listeners }) do
    if old_delta != new_delta do
      notify_delta_change(new_delta, t, listeners)
    end
  end

  defp notify_delta_change(_delta, _next_measurement_time, []) do
  end

  defp notify_delta_change(delta, next_measurement_time, [listener | listeners]) do
    GenServer.cast(listener, {:time_delta_change, delta, next_measurement_time})
    notify_delta_change(delta, next_measurement_time, listeners)
  end

  defp append_latency_measurement(new_latency, %S{ latency: latency } = state) do
    max_latency = case new_latency do
      _ when new_latency > latency -> new_latency
      _ -> latency
    end
    %S{ state | latency: max_latency }
  end

  defp append_delta_measurement(measured_delta, %S{ delta_average: avg } = state) do
    old_delta = MovingAverage.average(avg) |> round
    avg       = MovingAverage.update(avg, measured_delta)
    new_delta = MovingAverage.average(avg) |> round
    Logger.info "New time delta measurement [#{measured_delta}] - #{new_delta} (#{new_delta - old_delta}) ~ #{ Float.round(avg.b + 0.0, 3) }"
    %S{ state | delta: new_delta, delta_average: avg }
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
      {:stop, :normal, state}
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

    def terminate(:normal, state) do
      :ok
    end

    def terminate(reason, state) do
      Logger.warn "Janis.Broadcaster.Monitor terminating... #{ inspect reason }"
      :ok
    end
  end
end
