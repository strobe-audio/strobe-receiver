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
      IO.binread file, :all
    end
    now = Janis.microseconds
    << packet::binary-size(3528), data::binary >> = data
    play({now + 10000, packet})
    << packet::binary-size(3528), data::binary >> = data
    play({now + 12000, packet})
    << packet::binary-size(3528), data::binary >> = data
    play({now + 14000, packet})
    << packet::binary-size(3528), data::binary >> = data
    play({now + 16000, packet})
    << packet::binary-size(3528), data::binary >> = data
    play({now + 18000, packet})
  end
end
