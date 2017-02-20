defmodule NervesJanis.Network.Wlan do
  use GenServer
  require Logger

  defmodule Handler do
    use GenEvent

    def handle_event({:configure, :wifi, config}, parent) do
      GenServer.cast(parent, {:configure, config})
      {:ok, parent}
    end

    def handle_event(_evt, parent) do
      {:ok, parent}
    end
  end

  ### API

  def enable do
    GenServer.cast(__MODULE__, :enable)
  end

  def disable do
    GenServer.cast(__MODULE__, :disable)
  end

  def start_link(dev) do
    GenServer.start_link(__MODULE__, dev, name: __MODULE__)
  end

  ### Callbacks

  def init(dev) do
    Logger.info "Starting #{__MODULE__}:#{dev}"
    Janis.Events.add_handler(Handler, self())
    {:ok, %{dev: dev, configured: false, enabled: false}}
  end

  def handle_cast(:disable, state) do
    {:noreply, %{ state | enabled: false }}
  end
  def handle_cast(:enable, state) do
    state = %{ state | enabled: true } |> configure_from_settings
    {:noreply, state}
  end
  def handle_cast({:configure, _config}, %{enabled: false} = state) do
    {:noreply, state}
  end
  def handle_cast({:configure, config}, %{enabled: true} = state) do
    state = config |> configure_wifi(state)
    {:noreply, state}
  end

  def configure_from_settings(state) do
    NervesJanis.Settings.get_wifi_config |> configure_wifi(state)
  end

  defp configure_wifi(nil, state) do
    Logger.warn "No WiFi settings saved"
    state
  end
  defp configure_wifi(settings, %{configured: true} = state) do
    Logger.info "Ignoring configuration request #{ inspect settings }"
    state
  end
  defp configure_wifi(settings, state) do
    config  = settings |> Enum.into([]) |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
    {regulatory_domain, config} = Keyword.pop(config, :regulatory_domain, "00")
    Nerves.InterimWiFi.set_regulatory_domain(regulatory_domain)
    Logger.info "Configuring wifi #{state.dev}: #{inspect config} (#{regulatory_domain})"
    Nerves.InterimWiFi.setup(state.dev, config)
    %{ state | configured: true }
  end
end

