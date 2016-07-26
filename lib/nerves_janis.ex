defmodule NervesJanis do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # worker(NervesJanis.Worker, [arg1, arg2, arg3]),
    ]

    start_networking(:os.type, :eth0)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesJanis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_networking({:unix, :darwin}, _iface), do: :ok
  defp start_networking(_os, iface) when os in  do
    {:ok, _} = Nerves.Networking.setup iface
  end
end
