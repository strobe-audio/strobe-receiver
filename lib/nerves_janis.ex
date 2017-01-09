defmodule NervesJanis do
  use Application
  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      worker(NervesJanis.Settings, []),
      supervisor(Janis.Supervisor, []),
      worker(NervesJanis.ConfigurationEvents, []),
      worker(NervesJanis.WLAN, []),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesJanis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
