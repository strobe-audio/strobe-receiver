defmodule Janis.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Janis.DNSSD, []),
      worker(Janis.Audio, []),
      supervisor(Janis.Player, []),
      supervisor(Janis.Broadcasters, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
