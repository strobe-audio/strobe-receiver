defmodule Janis.Player.Supervisor do
  use Supervisor

  def start_link({_broadcaster, _port} = address, {_packet_interval, _packet_size} = stream_info) do
    Supervisor.start_link(__MODULE__, {address, stream_info}, [])
  end

  def init({address, stream_info}) do
    children = [
      worker(Janis.Player.Buffer, [stream_info, Janis.Player.Buffer]),
      worker(Janis.Player.Socket, [address, stream_info, Janis.Player.Buffer]),
    ]

    supervise(children, strategy: :one_for_all, max_restarts: 10, max_seconds: 1)
  end
end
