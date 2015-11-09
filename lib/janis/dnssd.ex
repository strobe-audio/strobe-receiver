defmodule Janis.DNSSD do
  use     GenServer
  require Logger

  @name Otis.DNSSD

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, ref} = :dnssd.browse(service_name)
    {:ok, %{ref: ref}}
  end

  def terminate(reason, %{ref: ref} = _state) do
    Logger.warn "Terminate #{__MODULE__} #{inspect reason}"
    :dnssd.stop(ref)
    :ok
  end

  defp service_name do
    "_peep-broadcaster._tcp"
  end

  def handle_info({:dnssd, _ref, msg}, state) do
    dnssd_resolve(msg)
    {:noreply, state}
  end

  defp dnssd_resolve({:browse, :add, {service_name, service_type, domain} = service}) do
    Logger.info "Add resource #{inspect service}"
    :dnssd.resolve_sync(service_name, service_type, domain) |> resource(service)
  end

  defp dnssd_resolve({:browse, :remove, {_service_name, _service_type, _domain} = service}) do
    Janis.broadcaster_disconnect(service)
  end

  defp resource({:ok, {address, port, texts}}, service) do
    Logger.info "Got resource #{inspect address}:#{port} / #{inspect texts}"
    config = parse_texts(texts)
    Janis.broadcaster_connect(service, address, port, config)
  end

  defp resource({:error, :timeout}, service) do
    Logger.warn "Timed out getting resource #{inspect service}"
  end

  defp parse_texts(texts) do
    Keyword.new texts, fn({k, v}) ->
      {String.to_atom(k), v}
    end
  end
end
