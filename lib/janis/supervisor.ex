defmodule Janis.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      supervisor(Janis.Broadcaster, []),
      supervisor(Janis.Broadcaster.Monitor.Collector, []),
      worker(Janis.Audio, []),
      worker(Janis.DNSSD, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
