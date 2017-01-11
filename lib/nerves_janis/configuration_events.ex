defmodule NervesJanis.ConfigurationEvents do
  use GenServer

  defmodule Handler do
    use GenEvent

    def handle_event({:configure, :wifi, config}, state) do
      :ok = NervesJanis.Settings.put_wifi_config(config)
      {:ok, state}
    end
    def handle_event(_evt, state) do
      {:ok, state}
    end
  end

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_opts) do
    Janis.Events.add_handler(Handler, [])
    {:ok, %{}}
  end
end
