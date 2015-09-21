
defmodule Janis.Player.Emitter do
  require Logger

  def emit(emitter, packet) do
    send(emitter, {:emit, packet})
  end

  def start_link(opts) do
    :proc_lib.start_link(__MODULE__, :init, [opts])
  end

  def init([interval: packet_interval, packet_size: packet_size, pool: pool] = opts) do
    Logger.debug "Launched emitter #{inspect opts}"
    :proc_lib.init_ack({:ok, self})

    state = {
      {0, 0, 3000},                        # timing information
      {},                                  # packet
      {packet_interval, packet_size, pool} # config
    }
    wait(state)
  end

  def wait(state) do
    Logger.debug "Emitter.wait... #{inspect state}"
    receive do
      {:emit, packet} ->
        start(packet, state)
      msg ->
        Logger.debug "Emitter got #{inspect msg}"
        wait(state)
    end
  end

  def handle_cast({:emit, packet}, state) do
    {:noreply, state}
  end

  def start(packet, {{t, n, d}, _packet, _config} = state) do
    # Logger.disable(self)
    {t, _} = packet
    Logger.debug "Start emitter #{t - current_time}"
    state = {{Janis.microseconds, n, d}, packet, _config}
    test_packet state
  end

  def loop(state) do
    receive do
    after 2 ->
      test_packet new_state(state)
    end
  end

  def test_packet({{now, _, d}, {timestamp, _data}, _config} = state) do
    case timestamp - now do
      x when x <= 1 ->
        play_frame(state)
      x when x <= d ->
        loop_tight(state)
      _ ->
        loop(state)
    end
  end

  @jitter 250

  def loop_tight({{t, n, d}, {timestamp, _data}, _config}) do
    now = current_time
    state = {{now, n, d}, {timestamp, _data}, _config}
    case timestamp - now do
      x when x <= @jitter ->
        play_frame(state)
        # assuming that the interval between frames > 1ms
        # loop(next_frame(state))
      _ -> loop_tight(state)
    end
  end

    Logger.debug "Play frame.. #{current_time - timestamp}"
  def play_frame({_loop, {timestamp, data}, {_pi, _ps, pool} = _config} = state) do
    send_data = case current_time - timestamp do
      d when d <= 0 ->
        data
      d ->
        # do I skip from the beginning or the end...
        Logger.warn "Late #{d} skipping #{skip_bytes(d)} bytes"
        case skip_bytes(d) do
          s when s > byte_size(data) ->
            <<>>
          s ->
            << skip :: binary-size(s), rest :: binary >> = data
            rest
        end
    end

    if byte_size(send_data) > 0 do
      # Logger.debug "PLAY #{byte_size(send_data)}"
      Janis.Audio.play(send_data)
    end

    # loop(next_frame(state))
    Logger.debug "Check back into pool"
    :poolboy.checkin(pool, self)
    wait({_loop, {}, _config})
  end

  # One frame is 16 bits over 2 channels
  @bytes_per_frame 2 * 2
  @frames_per_us 44_100 / 1_000_000

  def skip_bytes(us) do
    round(Float.ceil(@frames_per_us * us)) * @bytes_per_frame
  end

  def new_state({{t, n, d}, packet, config}) do
    m = n+1
    now = current_time
    delay = case d do
      0 -> now - t
      _ -> (((n * d) + (now - t)) / m)
    end
    if rem(m, 1000) == 0 do
      Logger.debug "#{now}, #{m}, #{delay}"
    end
    {{now, m, delay}, packet, config}
  end

  def current_time do
    Janis.microseconds
  end

  def terminate(reason) do
  end
end

