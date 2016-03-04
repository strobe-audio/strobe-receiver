defmodule Janis.Player.Socket.Ctrl do
  use Janis.Player.Socket.Base

  def handle_info({:tcp, _socket, data}, state) do
    state = data |> Poison.decode! |> handle_message(state)
    {:noreply, state}
  end

  def handle_message(%{ "volume" => volume }, state) do
    :ok = Janis.Audio.volume(volume)
    state
  end

  def port(%Janis.Broadcaster{ctrl_port: port}) do
    port
  end
end
