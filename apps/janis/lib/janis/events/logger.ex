defmodule Janis.Events.Logger do
  use     GenEvent
  require Logger

  def init(id) do
    Janis.set_logger_metadata
    IO.inspect __MODULE__
    {:ok, %{id: id}}
  end

  def handle_event(event, state) do
    log_event(event, state)
    {:ok, state}
  end

  def log_event(event, _state) do
    Logger.info "EVENT: #{ inspect event }"
  end
end
