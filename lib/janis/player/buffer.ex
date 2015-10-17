defmodule Janis.Player.Buffer do
  use     GenServer
  use     Monotonic
  require Logger

  @moduledoc """
  Receives data from the buffer and passes it onto the playback process on demand
  """

  defmodule Delta do
    @moduledoc "Smear changes to time delta into the smallest increment possible"

    require Monotonic

    def new(current_delta) do
      %{current: current_delta, pending: 0, d: 0, time: 0}
    end

    def update(new_delta, next_measurement_time, %{current: current, pending: pending} = state) do
      diff = new_delta - (current + pending)
      t = next_measurement_time - monotonic_milliseconds
      d = (diff / t)
      %{ current: current, pending: diff, d: d, time: monotonic_milliseconds}
    end

    def current(%{current: current, pending: 0} = state) do
      {current, state}
    end

    def current(%{current: current, pending: pending, d: d, time: t} = state) do
      now = monotonic_milliseconds
      dt  = now - t
      c   = round Float.ceil(d * dt)
      c   = Enum.min [pending, c]
      current = current + c
      pending = pending - c
      {current, %{state | current: current, pending: pending, time: now}}
    end
  end

  defmodule S do
    defstruct queue:       :queue.new,
              stream_info: nil,
              status:      :stopped,
              count:       0,
              time_delta:  nil
  end

  def start_link(stream_info, name) do
    GenServer.start_link(__MODULE__, stream_info, name: name)
  end

  def put(buffer, packet) do
    GenServer.cast(buffer, {:put, packet})
  end

  def stop(buffer) do
    GenServer.cast(buffer, :stop)
  end

  def init(stream_info) do
    # Logger.disable(self)
    Logger.info "Player.Buffer up"
    Process.flag(:trap_exit, true)
    Janis.Broadcaster.Monitor.add_time_delta_listener(self)
    {:ok, %S{stream_info: stream_info}}
  end

  def handle_cast({:put, packet}, state) do
    state = put_packet(packet, state)
    {:noreply, state}
  end

  def handle_cast({:init_time_delta, delta}, state) do
    Logger.debug "Init time delta, #{delta}"
    {:noreply, %S{ state | time_delta: Delta.new(delta) }}
  end

  def handle_cast({:time_delta_change, delta, next_measurement_time} = msg, %S{time_delta: time_delta} = state) do
    Logger.debug "Time delta change, #{monotonic_milliseconds} #{inspect msg}"
    {:noreply, %S{state | time_delta: Delta.update(delta, next_measurement_time, time_delta)}}
  end

  def handle_cast(:stop, state) do
    Logger.info "Buffer stopped..."
    {:noreply, state}
  end

  def handle_info({:DOWN, _monitor, :process, _channel, reason}, state) do
    # Logger.debug "Emitter down"
    {:noreply, state}
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

  def put_packet(packet, %S{status: :stopped, stream_info: {interval_ms, _size}} = state) do
    :timer.send_interval(2, :check_emit)
    put_packet(packet, %S{state | status: :playing})
  end

  def put_packet(packet, %S{status: :playing, queue: queue, stream_info: {interval_ms, _size}, count: count} = state) do
    {translated_packet, state} = translate_packet(packet, state)
    queue  = cons(translated_packet, queue, count)
    %S{ state | queue: queue, count: count + 1 }
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

  def maybe_emit_packets(queue, %S{stream_info: {interval_ms, _size}} = state) do

    # packets = :queue.to_list(queue)
    # now = monotonic_microseconds
    interval_us = interval_ms * 1000
    #
    # {to_emit, to_keep} = Enum.partition packets, fn({t, _}) ->
    #   (t - now) < interval_us
    # end
    #
    #
    # unless Enum.empty?(to_emit) do
    #   queue = :queue.from_list(to_keep)
    #   state = emit_packets(state, to_emit)
    #   state = %S{state | queue: queue, status: :playing }
    # end
    #
    # state

    case :queue.head(queue) do
      :empty -> state
      {first_timestamp, _} = first_packet ->
        case first_timestamp - monotonic_microseconds do
          i when i < interval_us ->
            state = emit_packet(state, first_packet)
            queue = :queue.tail(queue)
            %S{state | queue: queue, status: :playing }
          _ ->
            state
        end
    end
  end

  def emit_packets(state, []) do
    state
  end

  def emit_packets(state, [packet | packets]) do
    state = emit_packet(state, packet)
    emit_packets(state, packets)
  end

  def emit_packet(state, packet) do
    # Logger.debug "emt #{monotonic_microseconds}"
    Janis.Audio.play(packet)
    state
  end

  def monitor_queue_length(queue, count) do
    case :queue.len(queue) do
      l when l > 20 ->
        Logger.warn "Overflow buffer! #{inspect (l + 1)}"
      l when l == 0 ->
        Logger.warn "Empty buffer!"
      l when l < 2 ->
        Logger.warn "Low buffer #{l}"
      l ->
        case rem(count, 100) do
          0 -> Logger.debug "len #{l}"
          _ ->
        end
    end
    queue
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__}"
    Janis.Broadcaster.Monitor.remove_time_delta_listener(self)
    :ok
  end
end

