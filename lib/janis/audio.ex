defmodule Janis.Audio do

  @name Janis.Audio
  @implementation Janis.Audio.PulseAudioTCP

  def start_link do
    @implementation.start_link(@name)
  end

  def play(data) do
    GenServer.cast(@name, {:play, data})
  end
end
