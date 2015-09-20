defmodule Janis.Player.Supervisor do
  use Supervisor

  def start_link({_ip, _port} = address, stream_info) do
    Supervisor.start_link(__MODULE__, {address, stream_info}, [])
  end

  def init({address, {_packet_interval, _packet_size} = stream_info}) do

    pool_options = [
      name: {:local, Janis.Player.EmitterPool},
      worker_module: Janis.Player.Emitter,
      size: 6,
      max_overflow: 2
    ]

    children = [
      :poolboy.child_spec(Janis.Player.EmitterPool, pool_options, [
        interval: _packet_interval,
        packet_size: _packet_size
      ]),
      worker(Janis.Player.Buffer, [stream_info, Janis.Player.Buffer]),
      worker(Janis.Player.Socket, [address, stream_info, Janis.Player.Buffer]),
    ]

    supervise(children, strategy: :one_for_all, max_restarts: 10, max_seconds: 1)
  end
end
