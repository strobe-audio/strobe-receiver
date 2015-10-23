defmodule Janis.Audio do
  use Monotonic

  @name           Janis.Audio
  @implementation Janis.Audio.PortAudio

  def start_link do
    @implementation.start_link(@name)
  end

  @doc "Sends a timestamped audio packet to the audio system"
  def play({_timestamp, _data} = packet) do
    GenServer.cast(@name, {:play, packet})
  end

  def volume do
    GenServer.call(@name, :get_volume)
  end

  def volume(volume) do
    GenServer.cast(@name, {:set_volume, volume})
  end

  def time do
    GenServer.call(@name, :time)
  end
end
