defmodule Janis.Mdns do
  use     GenServer
  require Logger

  @service_name "_peep-broadcaster._tcp.local"

  defmodule S do
    @moduledoc false

    defstruct [:browser, :broadcaster]
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Janis.set_logger_metadata
    case Application.get_env(:janis, __MODULE__) do
      true ->
        Logger.info "Starting mDNS Client..."
        Process.flag(:trap_exit, true)
        {:ok, client} = Mdns.Supervisor.start_link()
        :ok = GenEvent.add_mon_handler(Mdns.Client.Events, Janis.Mdns.Handler, nil)
        # Mdns.Client.add_handler(Janis.Mdns.Handler)
        Mdns.Client.query(@service_name)
        {:ok, client}
      false ->
        :ignore
    end
  end

  def terminate(reason, _state) do
    Logger.warn "Terminate #{inspect reason}"
    # :dnssd.stop(browser)
    :ok
  end

  defmodule Handler do
    use GenEvent

    def handle_event({:"_peep-broadcaster._tcp.local", _device, 0}, broadcaster) when not is_nil(broadcaster) do
      IO.inspect :OFFLINE
      GenEvent.notify(Janis.Broadcaster.Event, {:offline, :mdns, broadcaster})
      {:ok, nil}
    end
    def handle_event({:"_peep-broadcaster._tcp.local", device, ttl}, nil) when ttl > 0 do
      IO.inspect device
      config = Keyword.new(device.payload, &parse_text/1)
      port = String.to_integer(config[:sntp_port])
      broadcaster = struct(%Janis.Broadcaster{host: device.domain, ip: device.ip, port: port}, config)
      GenEvent.notify(Janis.Broadcaster.Event, {:online, :mdns, broadcaster})
      {:ok, broadcaster}
    end

    def handle_event(_event, broadcaster) do
      # IO.inspect {:event, event}
      # GenServer.cast(owner, event)
      {:ok, broadcaster}
    end

    @integer_keys ["ctrl_port", "data_port", "stream_interval", "packet_size"]

    defp parse_text({key, value})
    when key in @integer_keys do
      {String.to_atom(key), String.to_integer(value)}
    end
    defp parse_text({key, value}) do
      {String.to_atom(key), value}
    end
  end
end
