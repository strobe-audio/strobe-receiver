defmodule Janis.Player.Buffer do
  @moduledoc """
  Receives data from the buffer and passes it onto the playback process on demand
  """

  use     GenServer
  use     Monotonic
  require Logger

  alias   Janis.Player.Buffer.Delta


  defmodule S do
    defstruct [
      queue:           :queue.new,
      broadcaster:     nil,
      status:          :stopped,
      count:           0,
      time_delta:      nil,
      last_emit_check: nil,
      interval_timer:  nil,
      last_timestamp:  nil,
    ]
  end

  def start_link(broadcaster) do
    start_link(broadcaster, __MODULE__)
  end
  def start_link(broadcaster, _name) do
    GenServer.start_link(__MODULE__, broadcaster)
  end

  def put(buffer, packet) do
    GenServer.cast(buffer, {:put, packet})
  end

  def stop(buffer) do
    GenServer.cast(buffer, :stop)
  end

  def init(broadcaster) do
    Logger.info "init #{ inspect broadcaster }"
    # TODO: receiver a monitor instance to avoid having to register the monitor
    # process.
    Janis.Broadcaster.Monitor.add_time_delta_listener(self)
    {:ok, %S{broadcaster: broadcaster}}
  end

  def handle_cast({:put, packet}, state) do
    state = put_packet(packet, state)
    {:noreply, state}
  end

  def handle_cast({:init_time_delta, delta}, state) do
    Logger.debug "Init time delta, #{delta}"
    {:noreply, %S{ state | time_delta: Delta.new(delta) }}
  end

  def handle_cast({:time_delta_change, delta, next_measurement_time} = _msg, %S{time_delta: time_delta} = state) do
    # Logger.debug "Time delta change, #{monotonic_milliseconds} #{inspect msg}"
    {:noreply, %S{state | time_delta: Delta.update(delta, next_measurement_time, time_delta)}}
  end

  def handle_cast(:stop, state) do
    Janis.Audio.stop
    Logger.info "Buffer stopped..."
    {:noreply, %S{state | status: :stopped, queue: :queue.new}}
  end

  def handle_info(:check_emit, state) do
    state = maybe_emit_packets(state)
    {:noreply, state}
  end

  def next_packet({:value, packet}) do
    {:ok, packet}
  end

  def next_packet(:empty) do
    Logger.warn "Buffer underrun"
    {:error, :empty}
  end

  def put_packet(packet, %S{status: :stopped} = state) do
    {:ok, tref} = :timer.send_interval(check_emit_interval(state), :check_emit)
    # Because our check interval may be higher than the gap between now & the
    # first packet, we test for emission (?) when receiving the first packets
    put_packet!(packet, %S{state | status: :playing, interval_timer: tref}) |> maybe_emit_packets
  end

  def put_packet(packet, %S{last_timestamp: nil} = state) do
    put_packet!(packet, state)
  end
  def put_packet({timestamp, _data} = _packet, %S{last_timestamp: last_timestamp} = state)
  when timestamp <= last_timestamp do
    Logger.debug "Ignoring packet with timestamp in the past #{ timestamp } <= #{ last_timestamp }"
    state
  end
  def put_packet(packet, state) do
    put_packet!(packet, state)
  end

  def put_packet!(packet, %S{status: :playing, queue: queue, count: count} = state) do
    {translated_packet, state} = translate_packet(packet, state)
    { timestamp, _ } = translated_packet
    case timestamp - monotonic_microseconds do
      x when x <= 0 ->
        Logger.warn "Late packet #{x} µs"
      _ -> nil
    end
    queue  = cons(translated_packet, queue, count)
    %S{ state | queue: queue, count: count + 1, last_timestamp: timestamp }
  end

  defp check_emit_interval(%S{broadcaster: broadcaster}) do
    round(Janis.Broadcaster.stream_interval_ms(broadcaster) / 4.0)
  end

  def cons(packet, queue, count) do
    queue = :queue.snoc(queue, packet)
    monitor_queue_length(queue, count)
  end

  defp translate_packet({timestamp, data}, %S{time_delta: time_delta} = state) do
    { delta, time_delta } = Delta.current(time_delta)
    translated_timestamp = timestamp - delta
    { {translated_timestamp, data}, %S{ state | time_delta: time_delta } }
  end

  def maybe_emit_packets(%S{queue: queue} = state) do
    maybe_emit_packets(queue, state)
  end

  def maybe_emit_packets(queue, %S{broadcaster: broadcaster, last_emit_check: last_check} = state) do
    interval_ms = Janis.Broadcaster.stream_interval_ms(broadcaster)

    last_check = case last_check do
      c when is_nil(c) -> monotonic_microseconds
      c -> c
    end

    emit_interval = check_emit_interval(state)
    end_period = last_check + (emit_interval + (2 * interval_ms)) * 1000

    { queue, packets } = peek_queue(queue, end_period, [])

    state = case length(packets) do
      n when n > 0 ->
        %S{ emit_packets(state, packets) | queue: queue, status: :playing }
      _ -> state
    end

    %S{ state | last_emit_check: monotonic_microseconds }
  end

  def peek_queue(queue, end_period, packets_to_emit) do
    case :queue.peek(queue) do
      :empty -> { queue, packets_to_emit }

      {:value, {first_timestamp, _} = first_packet} ->
        case first_timestamp do
          t when t <= end_period ->
            queue = :queue.tail(queue)
            peek_queue(queue, end_period, [ first_packet | packets_to_emit ])
          _ ->
            { queue, packets_to_emit }
        end
    end
  end

  def emit_packets(state, []) do
    # This is a good time to clean up -- we've just emitted some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    state
  end

  def emit_packets(state, [packet | packets]) do
    state = emit_packet(state, packet)
    emit_packets(state, packets)
  end

  def emit_packet(state, packet) do
    Janis.Audio.play(packet)
    state
  end

  def monitor_queue_length(queue, _count) do
    case :queue.len(queue) do
      l when l > 50 ->
        Logger.warn "Overflow buffer! #{inspect (l + 1)}"
      l when l == 0 ->
        Logger.warn "Empty buffer!"
      l when l < 4 ->
        Logger.warn "Low buffer #{l}"
      _ -> nil
        # Logger.debug "q: #{l}"
    end
    queue
  end

  def terminate(_reason, %S{interval_timer: tref} = _state) do
    Logger.info "Stopping #{__MODULE__}"
    remove_handle(tref)
    :ok
  end

  defp remove_handle(nil), do: nil
  defp remove_handle(tref) do
    {:ok, :cancel} = :timer.cancel(tref)
  end
end
