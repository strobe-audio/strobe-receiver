defmodule Janis.Broadcaster.Supervisor do
  use Supervisor

  @name Janis.Broadcaster.Supervisor

  def start_link(service, address, port, config) do
    Supervisor.start_link(__MODULE__, {service, address, port, config})
  end

  def init({service, address, port, config}) do
    children = [
      worker(Janis.Broadcaster.Monitor, [service, address, port, config], []),
      worker(Janis.Broadcaster.Socket, [service, address, port, config], [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end


