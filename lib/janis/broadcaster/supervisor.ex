defmodule Janis.Broadcaster.Supervisor do
  use Supervisor

  @name Janis.Broadcaster.Supervisor

  def start_link(service, address, port, config) do
    Supervisor.start_link(__MODULE__, {service, address, port, config})
  end

  def init({service, address, port, config}) do
    args = [service, address, port, config]
    children = [
      worker(Janis.Broadcaster.SNTP,    args, []),
      worker(Janis.Broadcaster.Socket,  args, []),
      worker(Janis.Broadcaster.Monitor, args, [])
    ]
    supervise(children, strategy: :one_for_all)
  end
end


