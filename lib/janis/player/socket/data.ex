defmodule Janis.Player.Socket.Data do
  use Janis.Player.Socket

  @stop_command << "STOP" >>
  @ping_command << "PING" >>

  def handle_data(state, @ping_command) do
    state |> reset_timeout
  end

  def handle_data(state, @stop_command) do
    Janis.Player.Buffer.stop(state.buffer)
    state |> reset_timeout
  end

  def handle_data(state, <<_c::size(64), timestamp::size(64)-little-signed-integer, audio::binary >>) do
    state |> reset_timeout |> put({timestamp, audio})
  end

  def handle_data(state, data) do
    Logger.warn "#{__MODULE__} Invalid data packet #{inspect data}"
    state |> reset_timeout
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
