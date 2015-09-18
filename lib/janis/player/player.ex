defmodule Janis.Player.Player do
  @moduledoc """
  Reads audio packets from Janis.Player.Buffer and writes them to the audio hardware
  """

  use     GenServer
  require Logger

  defmodule S do
    defstruct buffer:      nil,
              timer:       nil,
              stream_info: nil
  end

  def start_link(stream_info, buffer) do
    GenServer.start_link(__MODULE__, [stream_info, buffer], [name: Janis.Player.Player])
  end

  def start_playback(player) do
    GenServer.cast(player, :start_playback)
  end

  def init([stream_info, buffer]) do
    Logger.debug "Player.Player up #{inspect stream_info}"
    Process.flag(:trap_exit, true)
    Janis.Player.Buffer.link_player(buffer, self)
    {:ok, %S{buffer: buffer, stream_info: stream_info}}
  end

  def handle_cast(:start_playback, %S{timer: nil} = state) do
    state = launch_timer(state)
    {:noreply, state}
  end

  def handle_cast(:start_playback, %S{timer: timer} = state) do
    Process.exit(timer, :kill)
    state = launch_timer(state)
    {:noreply, state}
  end

  def handle_cast(:start_playback, state) do
    {:noreply, state}
  end

  def handle_cast({:play, data}, state) do
    # Logger.debug "Play #{inspect data}"
    Janis.Audio.play(data)
    {:noreply, state}
  end

  defp launch_timer(%S{buffer: buffer, stream_info: {interval, size}} = state) do
    {:ok, timer} = Janis.Looper.start_link(buffer, interval, size)
    %S{ state | timer: timer }
  end

  def terminate(reason, state) do
    Logger.info "Stopping #{__MODULE__}"
    :ok
  end
end
