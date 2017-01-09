defmodule NervesJanis.Settings do
  use     GenServer
  require Logger

  @wifi_config_key :wifi

  def put_wifi_config(config) do
    put(@wifi_config_key, config)
  end

  def get_wifi_config do
    get(@wifi_config_key)
  end

  def put(values) when is_list(values) do
    GenServer.call(__MODULE__, {:put, values})
  end
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, key, value})
  end

  def get(key, default \\ nil)
  def get(key, default) do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:persistent_storage, __MODULE__)
    Logger.info "Setting up persistent storage #{ inspect config }"
    PersistentStorage.setup(config)
    {:ok, []}
  end

  def handle_call({:put, values}, _from, state) do
    {:reply, PersistentStorage.put(values), state}
  end
  def handle_call({:put, key, value}, _from, state) do
    IO.inspect [:put, key, value]
    {:reply, PersistentStorage.put(key, value), state}
  end
  def handle_call({:get, key, default}, _from, state) do
    {:reply, PersistentStorage.get(key, default), state}
  end
end
