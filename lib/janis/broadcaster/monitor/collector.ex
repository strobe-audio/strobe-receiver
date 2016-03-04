defmodule Janis.Broadcaster.Monitor.Collector do
  @moduledoc ~S"""
  Makes a certain number of SNTP requests and calculates an average, returning
  it to the given monitor instance.
  """

  require Logger

  defmodule S do
    @moduledoc false
    defstruct [:sntp, :monitor, :interval, :count, measurements: [], errors: 0]
  end

  def start_link(monitor, sntp, interval, count) do
    GenServer.start_link(__MODULE__, {monitor, sntp, interval, count})
  end

  def init({monitor, sntp, interval, count}) do
    schedule(1)
    {:ok, %S{monitor: monitor, sntp: sntp, interval: interval, count: count}}
  end

  def handle_info(:measure, %S{count: count, interval: interval} = state) when count > 0 do
    try do
      state = measure_sync_and_schedule(state)
      {:noreply, state}
    catch
      :error ->
        {:stop, {:shutdown, :error}, state}
    end
  end

  def handle_info(:measure, %S{count: count, monitor: monitor} = state) when count <= 0 do
    {latency, delta} = calculate_sync(state)
    GenServer.cast(monitor, {:append_measurement, {latency, delta}})
    {:stop, :normal, state}
  end

  defp measure_sync_and_schedule(state) do
    result = measure_sync(state)
    schedule(state.interval)
    result
  end

  defp measure_sync(%S{errors: errors} = state) when errors > 10  do
    throw(:error)
  end

  defp measure_sync(%S{measurements: measurements, count: count, sntp: sntp} = state) when count > 0  do
    case sync_exchange(sntp) do
      {:ok, latency, delta} ->
        %S{ state | count: count - 1,  errors: 0, measurements: [{latency, delta} | measurements]}
      {:error, _reason} = err ->
        Logger.warn "Error measuring time sync #{inspect err}"
        %S{state | errors: state.errors + 1}
    end
  end

  # http://www.mine-control.com/zack/timesync/timesync.html
  defp calculate_sync(%S{measurements: measurements} = _state) do
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

  defp sync_exchange(sntp) do
    Janis.Broadcaster.SNTP.time_delta(sntp)
  end

  defp schedule(interval) do
    Process.send_after(self, :measure, interval)
  end

  def terminate(:normal, _state) do
    :ok
  end

  def terminate(reason, _state) do
    Logger.warn "#{__MODULE__} terminating... #{ inspect reason }"
    :ok
  end
end
