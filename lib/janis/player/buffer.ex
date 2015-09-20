defmodule Janis.Player.Buffer do
  use     GenServer
  require Logger

  @moduledoc """
  Receives data from the buffer and passes it onto the playback process on demand
  """

  defmodule S do
    defstruct queue:       :queue.new,
              stream_info: nil,
              status:      :stopped
  end

  def start_link(stream_info, name) do
    GenServer.start_link(__MODULE__, stream_info, name: name)
  end

  # def get(buffer) do
  #   GenServer.call(buffer, :get)
  # end

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
    Logger.debug "Emitter down"
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

  def put_packet(packet, %S{status: :playing, queue: queue, stream_info: {interval_ms, _size}} = state) do
    queue  = cons(packet, queue)
    %S{ state | queue: queue }
  end

  def cons(packet, queue) do
    translated_packet = {timestamp, _data} = Janis.Broadcaster.translate_packet(packet)
    queue = :queue.in(translated_packet, queue)
    monitor_queue_length(queue)
  end

  def maybe_emit_packets(%S{queue: queue} = state) do
    maybe_emit_packets(queue, state)
  end

  def maybe_emit_packets(queue, %S{stream_info: {interval_ms, _size}} = state) do

    packets = :queue.to_list(queue)
    now = Janis.microseconds
    interval_us = interval_ms * 1000

    {to_emit, to_keep} = Enum.partition packets, fn({t, _}) ->
      (t - now) < interval_us
    end


    unless Enum.empty?(to_emit) do
      queue = :queue.from_list(to_keep)
      emit_packet(to_emit)
      state = %S{state | queue: queue, status: :playing }
    end

    state
    # case :queue.peek(queue) do
    #   {:value, {first_timestamp, _} = first_packet} ->
    #     case first_timestamp - Janis.microseconds do
    #       i when i < interval_us ->
    #         {:ok, pid} = emit_packet(first_packet)
    #         queue = :queue.drop(queue)
    #         %S{state | queue: queue, status: :playing }
    #       _ ->
    #         state
    #     end
    #   :empty ->
    #     state
    # end
  end

  def emit_packet([]) do
  end

  def emit_packet([packet | packets]) do
    # pid = spawn(Janis.Player.Emitter, :new, [self, packet])
    emitter = :poolboy.checkout(Janis.Player.EmitterPool)
    Janis.Player.Emitter.emit(emitter, packet)
    emit_packet(packets)
  end

  def monitor_queue_length(queue) do
    case :queue.len(queue) do
      l when l > 20 ->
        Logger.warn "Overflow buffer! #{inspect (l + 1)}"
      l when l == 0 ->
        Logger.warn "Empty buffer!"
      l when l < 2 ->
        Logger.warn "Low buffer #{l}"
      _ ->
    end
    queue
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__}"
    :ok
  end
end

