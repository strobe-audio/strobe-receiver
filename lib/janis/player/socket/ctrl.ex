defmodule Janis.Player.Socket.Ctrl do
  use     Janis.Player.Socket
  require Logger

  def handle_info({:tcp, _socket, data}, state) do
    state = data |> Poison.decode! |> handle_message(state)
    {:noreply, state}
  end
  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :tcp_closed, state}
  end

  def handle_message(%{ "volume" => volume }, state) do
    :ok = Janis.Audio.volume(volume)
    state
  end

  def handle_message(%{ "ping" => ping }, state) do
    params = %{ id: id(), pong: ping } |> Poison.encode!
    :gen_tcp.send(state.socket, params)
    state
  end

  def handle_message(%{"configure" => config}, state) do
    Enum.each(config, fn({key, value}) ->
      configure(String.to_atom(key), value)
    end)
    state
  end

  def configure(key, settings) do
    Janis.Events.notify({:configure, key, settings})
  end

  def port(%Janis.Broadcaster{ctrl_port: port}) do
    port
  end
end
