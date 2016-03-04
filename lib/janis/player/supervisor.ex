defmodule Janis.Player.Supervisor do
  use Supervisor

  def start_link(broadcaster, latency) do
    Supervisor.start_link(__MODULE__, {broadcaster, latency}, [])
  end

  def init({broadcaster, latency}) do
    children = [
      worker(Janis.Player.Buffer, [broadcaster, Janis.Player.Buffer]),
      worker(Janis.Player.Socket, [broadcaster, latency, Janis.Player.Buffer]),
    ]

    supervise(children, strategy: :one_for_all, max_restarts: 10, max_seconds: 1)
  end
end
