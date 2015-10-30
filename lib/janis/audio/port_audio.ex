defmodule Janis.Audio.PortAudio do
  require Logger
  use     Monotonic
  use     GenServer

  @shared_lib  "portaudio"
  @packet_size 3528

  @sample_freq        Application.get_env(:janis, :sample_freq, 44100)
  @sample_bits        Application.get_env(:janis, :sample_bits, 16)
  @sample_channels    Application.get_env(:janis, :sample_channels, 2)

  # need us per byte

  @sample_bytes       div(@sample_bits, 8)
  @frame_bytes        (@sample_bytes * @sample_channels)
  @frames_per_packet  div(@packet_size, @frame_bytes)
  @frame_duration_us  1_000_000 * (1.0 / @sample_freq)


  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def init(:ok) do
    Logger.info "Starting portaudio driver..."
    :ok = load_driver
    port = Port.open({:spawn_driver, @shared_lib}, [:stderr_to_stdout, :binary, :stream])
    {:ok, {port}}
  end

  @play_command 1
  @time_command 2
  @flsh_command 3
  @gvol_command 4
  @svol_command 5

  def handle_call(:time, _from, {port} = state) do
    {:ok, c_time} = Port.control(port, @time_command, <<>>) |> decode_port_response
    {:reply, {:ok, c_time, monotonic_microseconds}, state}
  end

  def handle_call(:get_volume, _from, {port} = state) do
    {:ok, volume} = Port.control(port, @gvol_command, <<>>) |> decode_port_response
    {:reply, {:ok, volume}, state}
  end

  def handle_cast({:play, {_timestamp, _data} = packet}, {port} = state) do
    state = play_packet(packet, state)
    {:noreply, state}
  end

  def handle_cast({:set_volume, volume}, {port} = state) do
    Logger.debug "Set volume #{volume}"
    :ok = Port.control(port, @svol_command, <<volume::size(32)-native-float>>) |> decode_port_response
    {:noreply, state}
  end

  defp play_packet(packet, state) do
    play_packets(split_packet(packet), state)
  end

  defp play_packets([], state) do
    # This is a good time to clean up -- we've just played some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    state
  end

  defp play_packets([packet | packets], {port} = state) do
    {:ok, buffer_size} = Port.control(port, @play_command, audio_packet(packet)) |> decode_port_response
    # TODO: decide if we're worried about the audio buffer here.
    # case buffer_size do
    #   1 -> Logger.warn "Audio driver has low buffer #{buffer_size}"
    #   _ ->
    # end
    play_packets(packets, state)
  end

  defp decode_port_response(iodata) do
    IO.iodata_to_binary(iodata) |> :erlang.binary_to_term
  end

  @doc """
  Takes a single >= 3528 byte timestamped packet & splits it into 1+ 3528 sized packets
  with offset timestamps
  """
  def split_packet({timestamp, data} = _packet) do
    split_packet_data(timestamp, data, [])
  end

  defp split_packet_data(timestamp, <<>>, packets) do
    Enum.reverse packets
  end

  defp split_packet_data(timestamp, data, packets) when byte_size(data) < @packet_size do
    padding = :binary.copy(<<0>>, @packet_size - byte_size(data))
    padded_data = << data::binary, padding::binary >>
    IO.inspect byte_size(padded_data)
    [{timestamp, padded_data} | packets ] |> Enum.reverse
  end

  defp split_packet_data(timestamp, << packet_data::binary-size(@packet_size), rest::binary >> = data, packets) when byte_size(data) >= @packet_size do
    next_timestamp = calculate_timestamp(timestamp, byte_size(packet_data))
    split_packet_data(next_timestamp, rest, [{timestamp, packet_data} | packets ])
  end

  def calculate_timestamp(timestamp, bytes) do
    # number of bytes should in theory always be a whole number of frames
    frames = round Float.ceil(bytes / @frame_bytes)
    # don't want fractions of a microsecond...
    round(timestamp + (frames * @frame_duration_us))
  end

  defp load_driver do
    case :erl_ddll.load_driver("./priv_dir", @shared_lib) do
      :ok -> :ok
      {:error, :already_loaded} -> :ok
      {:error, reason} ->
        Logger.error("Unable to load portaudio driver #{inspect reason}: #{:erl_ddll.format_error(reason)}")
        :error
    end
  end

  defp audio_packet({timestamp, data}) do
    len = byte_size(data)
    # Logger.debug "Packet time: #{time}; len: #{len} data: #{inspect data}"
    << timestamp::size(64)-little-unsigned-integer, len::size(16)-little-unsigned-integer, data::binary >>
  end
end
