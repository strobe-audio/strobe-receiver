defmodule Janis.Audio do

  @name Janis.Audio
  @implementation Janis.Audio.PortAudio

  def start_link do
    @implementation.start_link(@name)
  end

  @doc "Sends a timestamped audio packet to the audio system"
  def play({_timestamp, _data} = packet) do
    GenServer.cast(@name, {:play, packet})
  end

  def test do
    {:ok, data} = File.open "../audio/song.raw", [:read], fn(file) ->
      IO.binread file, 3528
    end
    play({Janis.microseconds + 100, data})
  end
end
