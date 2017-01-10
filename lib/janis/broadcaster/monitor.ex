defmodule Janis.Broadcaster.Monitor do
  @moduledoc """
  Responsible for coordinating the synchronisation with the broadcaster:

  - Calculate latency
  - Calculate time deltas (through the SNTP client)

  Once we have calculated an initial latency & time delta this module
  also starts a `Janis.Player` instance.
  """

  use     Monotonic
  use     GenServer
  require Logger

  alias   Janis.Broadcaster.Monitor.Collector
  alias   Janis.Math.MovingAverage

  defmodule S do
    defstruct [
      broadcaster: nil,
      sntp: nil,
      delta: nil,
      latency: 0,
      measurement_count: 0,
      packet_count: 0,
      collector: nil,
      delta_listeners: [],
      next_measurement_time: nil,
      delta_average: Janis.Math.DoubleExponentialMovingAverage.new(0.1, 0.02)
    ]
  end

  @monitor_name Janis.Broadcaster.Monitor

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

  def start_link(broadcaster) do
    GenServer.start_link(__MODULE__, broadcaster, name: @monitor_name)
  end

  def init(broadcaster) do
    Janis.set_logger_metadata
    Logger.info "Starting Broadcaster.Monitor #{inspect broadcaster}"
    {:ok, sntp} = Janis.Broadcaster.SNTP.start_link(broadcaster)
    Process.flag(:trap_exit, true)
    {:ok, collect_measurements(%S{sntp: sntp, broadcaster: broadcaster})}
  end

  defp collect_measurements(%S{measurement_count: count} = state) do
    {interval, sample_size, delay} = cond do
      count == 0 -> { 100, 10, 0     }
      true       -> { 100, 1,  1_000 }
    end
    :timer.send_after(delay, self(), {:start_collection, interval, sample_size})
    %S{ state | next_measurement_time: monotonic_milliseconds() + delay + (sample_size * interval) }
  end

  ########################################################

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.info "Got exit #{ inspect reason }, stopping..."
    {:stop, :normal, state}
  end

  def handle_info({:start_collection, interval, sample_size}, %{sntp: sntp} = state) do
    {:ok, pid} = Collector.start_collector(self(), sntp, interval, sample_size)
    {:noreply, %S{ state | collector: pid}}
  end

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

  def handle_cast(:sntp_connection_failure, state) do
    Logger.warn "Got sntp connection error, terminating..."
    {:stop, :normal, state}
  end

  def handle_cast({:append_measurement, measurement}, %S{measurement_count: 0} = state) do
    # First measurement! Join receiver channel!
    %S{latency: latency, broadcaster: broadcaster} = state = append_measurement(measurement, state)
    Logger.info "Joining broadcaster ... #{inspect broadcaster} latency: #{ latency }"
    Janis.Player.start_link(broadcaster, latency)
    {:noreply, state}
  end

  def handle_cast({:append_measurement, measurement}, state) do
    {:noreply, append_measurement(measurement, state)}
  end

  def append_measurement({new_latency, new_delta} = _measurement, %S{measurement_count: measurement_count, delta: delta} = state) do
    state = append_latency_measurement(new_latency, state)
    state = append_delta_measurement(new_delta, state)

    state = %S{ state | measurement_count: measurement_count + 1 }
    state = collect_measurements(state)
    notify_delta_change(delta, state)
    # This is a good time to clean up -- we've just emitted some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self())
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
    Logger.debug "Time Δ: #{String.rjust(to_string(measured_delta), 5)} / #{String.ljust(to_string(new_delta - old_delta), 5)} | #{String.rjust(to_string(new_delta), 5)} ~ #{ Float.round(avg.b + 0.0, 3) }"
    %S{ state | delta: new_delta, delta_average: avg }
  end

  def terminate(reason, _state) do
    Logger.warn "#{__MODULE__} terminating... #{ inspect reason }"
    :ok
  end
end
