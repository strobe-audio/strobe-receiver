defmodule Janis.Player.Buffer do
  use     GenServer
  use     Monotonic
  require Logger

  @moduledoc """
  Receives data from the buffer and passes it onto the playback process on demand
  """

  defmodule S do
    defstruct queue:       :queue.new,
              stream_info: nil,
              status:      :stopped,
              count:       0
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
    {:ok, %S{stream_info: stream_info}}
  end

  def handle_cast({:put, packet}, state) do
    state = put_packet(packet, state)
    {:noreply, state}
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
    queue  = cons(packet, queue, count)
    %S{ state | queue: queue, count: count + 1 }
  end

  def cons(packet, queue, count) do
    translated_packet = {timestamp, _data} = Janis.Broadcaster.translate_packet(packet)
    # Logger.debug "put #{timestamp - monotonic_microseconds}"
    queue = :queue.in(translated_packet, queue)
    monitor_queue_length(queue, count)
  end

  def maybe_emit_packets(%S{queue: queue} = state) do
    maybe_emit_packets(queue, state)
  end

  def maybe_emit_packets(queue, %S{stream_info: {interval_ms, _size}} = state) do

    packets = :queue.to_list(queue)
    now = monotonic_microseconds
    interval_us = interval_ms * 1000

    {to_emit, to_keep} = Enum.partition packets, fn({t, _}) ->
      (t - now) < interval_us
    end


    unless Enum.empty?(to_emit) do
      queue = :queue.from_list(to_keep)
      state = emit_packets(state, to_emit)
      state = %S{state | queue: queue, status: :playing }
    end

    state
    # case :queue.peek(queue) do
    #   {:value, {first_timestamp, _} = first_packet} ->
    #     case first_timestamp - monotonic_microseconds do
    #       i when i < interval_us ->
    #         state = emit_packet(state, first_packet)
    #         queue = :queue.drop(queue)
    #         %S{state | queue: queue, status: :playing }
    #       _ ->
    #         state
    #     end
    #   :empty ->
    #     state
    # end
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
    :ok
  end
end

