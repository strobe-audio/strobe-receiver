defmodule Janis.DNSSD do
  use     GenServer
  require Logger

  @name         Otis.DNSSD
  @service_name "_peep-broadcaster._tcp"

  defmodule S do
    @moduledoc false

    defstruct [:browser, :broadcaster]
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, browser} = :dnssd.browse(@service_name)
    {:ok, %S{browser: browser}}
  end

  def terminate(reason, %{browser: browser} = _state) do
    Logger.warn "Terminate #{inspect reason}"
    :dnssd.stop(browser)
    :ok
  end

  def handle_info({:dnssd, _ref, msg}, state) do
    state = case dnssd_resolve(msg, state) do
      {:ok, broadcaster} ->
        Logger.info "Broadcaster up #{ inspect broadcaster}"
        %S{ state | broadcaster: broadcaster }
      :down ->
        Logger.warn "Broadcaster service offline"
        state
      {:conflict, event} ->
        Logger.warn "Multiple broadcasters on network, ignoring #{ to_string(event) }..."
        state
    end
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, broadcaster, reason}, %S{broadcaster: broadcaster} = state) do
    Logger.warn "Broadcaster terminated #{ inspect reason }"
    {:noreply, %S{state | broadcaster: nil}}
  end

  defp dnssd_resolve({:browse, :add, {service_name, service_type, domain} = service}, %S{broadcaster: nil}) do
    :dnssd.resolve_sync(service_name, service_type, domain)
    |> resource(service)
  end
  defp dnssd_resolve({:browse, :add, _service}, _state) do
    {:conflict, :add}
  end

  defp dnssd_resolve({:browse, :remove, _service}, %S{broadcaster: nil}) do
    :down
  end
  # We're getting a service removal message when our broadcaster is still alive
  # so it's likely a case of multiple broadcasters on the same network.
  defp dnssd_resolve({:browse, :remove, _service}, %S{broadcaster: broadcaster}) do
    case Process.alive?(broadcaster) do
      true  -> {:conflict, :remove}
      false -> :down
    end
  end

  defp resource({:ok, {address, port, texts}}, _service) do
    config = parse_texts(texts)
    Logger.info "Got resource #{address}:#{port} #{inspect config}"
    start_and_link_broadcaster(address, port, config)
  end

  defp resource({:error, :timeout}, service) do
    Logger.warn "Timed out getting resource #{inspect service}"
  end

  defp start_and_link_broadcaster(address, port, config) do
    pid = case Janis.Broadcaster.start_broadcaster(address, port, config) do
      {:ok, pid} ->
        Process.monitor(pid)
        pid
      {:error, {:already_started, pid}} ->
        pid
    end
    {:ok, pid}
  end

  defp parse_texts(texts) do
    Keyword.new texts, &parse_text/1
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
