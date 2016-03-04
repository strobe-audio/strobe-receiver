defmodule Janis.Player.Socket.Data do
  use Janis.Player.Socket

  @stop_command << "STOP" >>

  def handle_info({:tcp, _socket, data}, state) do
    state = state |> data_in(data)
    {:noreply, state}
  end

  defp data_in(state, @stop_command) do
    Janis.Player.Buffer.stop(state.buffer)
    state
  end

  defp data_in(state, data) do
    << _c        ::size(64)-little-unsigned-integer,
       timestamp ::size(64)-little-signed-integer,
       audio     ::binary
    >> = data

    put(state, {timestamp, audio})
  end

  defp put(state, packet) do
    Janis.Player.Buffer.put(state.buffer, packet)
    # This is a good time to clean up -- we've just received some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self)
    state
  end

  def port(%Janis.Broadcaster{data_port: port}) do
    port
  end

  def registration_params(broadcaster, latency) do
    %{ id: id, latency: latency }
  end
end
