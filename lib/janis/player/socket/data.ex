defmodule Janis.Player.Socket.Data do
  use Janis.Player.Socket

  @stop_command << "STOP" >>

  def handle_data(state, @stop_command) do
    Janis.Player.Buffer.stop(state.buffer)
    state
  end

  def handle_data(state, <<_c::size(64), timestamp::size(64)-little-signed-integer, audio::binary >>) do
    put(state, {timestamp, audio})
  end

  defp put(state, packet) do
    Janis.Player.Buffer.put(state.buffer, packet)
    # This is a good time to clean up -- we've just received some packets
    # so we have > 20 ms before this has to happen again
    :erlang.garbage_collect(self())
    state
  end

  def port(%Janis.Broadcaster{data_port: port}) do
    port
  end

  def registration_params(_broadcaster, latency) do
    %{ id: id(), latency: latency }
  end
end
