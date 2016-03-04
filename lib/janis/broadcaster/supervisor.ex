defmodule Janis.Broadcaster.Supervisor do
  use Supervisor

  @name Janis.Broadcaster.Supervisor

  def start_link(broadcaster) do
    Supervisor.start_link(__MODULE__, broadcaster)
  end

  def init(broadcaster) do
    children = [
      worker(Janis.Broadcaster.Monitor, [broadcaster], []),
      worker(Janis.Broadcaster.SNTP,    [broadcaster], []),
    ]
    supervise(children, strategy: :one_for_all)
  end
end


