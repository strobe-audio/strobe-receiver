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

  def time do
    GenServer.call(@name, :time)
  end

  def test(n \\ 5) do
    c = Enum.min [50, n]
    {:ok, data} = File.open "../audio/176400-shubert-piano-quintet.raw", [:read], fn(file) ->
      IO.binread file, :all
    end
    now = monotonic_microseconds
    Enum.each 0..c, fn(i) ->
      skip_bytes = 3528*i
      << _skip::binary-size(skip_bytes), packet::binary-size(3528), data::binary >> = data
      play({now + (i * 2000), packet})
    end
  end
end
