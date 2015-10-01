defmodule Janis.Audio.PortAudio do
  require Logger
  use     GenServer

  @shared_lib  "portaudio"
  @packet_size 3528

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

  def handle_cast({:play, {_timestamp, _data} = packet}, {port} = state) do
    play_packet(packet, state)
    {:noreply, state}
  end

  defp play_packet(packet, {port} = _state) do
    Port.control(port, @play_command, audio_packet(packet))
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

  defp convert_timestamp(timestamp) do
    timestamp + :erlang.time_offset(:micro_seconds)
  end

  defp audio_packet({timestamp, data}) do
    time = convert_timestamp(timestamp)
    len = byte_size(data)
    Logger.debug "Packet time: #{time}; len: #{len} data: #{inspect data}"
    << time::size(64)-little-unsigned-integer, len::size(16)-little-unsigned-integer, data::binary >>
  end
end
