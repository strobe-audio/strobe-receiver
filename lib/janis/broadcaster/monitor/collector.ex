defmodule Janis.Broadcaster.Monitor.Collector do
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

  defp sync_exchange(_broadcaster) do
    Janis.Broadcaster.SNTP.time_delta
  end

  def terminate(:normal, _state) do
    :ok
  end

  def terminate(reason, _state) do
    Logger.warn "#{__MODULE__} terminating... #{ inspect reason }"
    :ok
  end
end
