defmodule NervesJanis.WLAN do
  use GenServer
  require Logger

  defmodule Handler do
    use GenEvent

    def handle_event({:configure, :wifi, config}, state) do
      GenServer.cast(NervesJanis.WLAN, {:configure, config})
      {:ok, state}
    end
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    IO.inspect [__MODULE__]
    Janis.Events.add_handler(Handler, [])
    Process.send_after(self(), :configure, 1000)
    # GenServer.cast(self(), :configure)
    {:ok, %{configured: false}}
  end

  def handle_info(:configure, state) do
    state = configure_from_settings(state)
    {:noreply, state}
  end

  def handle_cast(:configure, state) do
    state = configure_from_settings(state)
    {:noreply, state}
  end
  def handle_cast({:configure, config}, state) do
    state = state |> configure_wifi(config)
    {:noreply, state}
  end

  def configure_from_settings(state) do
    case NervesJanis.Settings.get_wifi_config do
      nil    -> state
      config -> state |> configure_wifi(config)
    end
  end


  def configure_wifi(%{configured: true} = state, config) do
    Logger.info "Ignoring configuration request #{ inspect config }"
    state
  end
  def configure_wifi(state, settings) do
    config  = settings |> Enum.into([]) |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    {regulatory_domain, config} = Keyword.pop(config, :regulatory_domain, "00")
    Nerves.InterimWiFi.set_regulatory_domain(regulatory_domain)
    Logger.info "Configuring wifi #{inspect config} (#{regulatory_domain})"
    Nerves.InterimWiFi.setup("wlan0", config)
    %{ state | configured: true }
  end
end
