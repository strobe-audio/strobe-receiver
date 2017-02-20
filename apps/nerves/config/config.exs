# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config


multicast_backend_config = [level: :debug, metadata: [:module, :line, :receiver_id], format: "$metadata [$level]$levelpad $message\n"]

config :logger,
  backends: [:console, {LoggerMulticastBackend, multicast_backend_config}],
  level: :info,
  metadata: [:module, :line]

config :logger, :console,
  level: :info,
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green],
  format: "$date $time $metadata [$level]$levelpad $message\n"


# config :logger, :logger_papertrail_backend,
#   host: "logs5.papertrailapp.com:21266",
#   level: :debug,
#   system_name: System.get_env |> Map.get("PAPERTRAIL_SYSTEM_NAME", "kirkliston"),
#   format: "$date $time $metadata [$level]$levelpad $message\n",
#   metadata: [:module, :line]

# config :logger,
#   backends: [:console, LoggerPapertrailBackend.Logger],
#   level: :debug

# TODO: make the additions configurable per DAC
config :nerves, :firmware,
  rootfs_additions: "config/rootfs"
  # fwup_conf: "config/fwup.conf"

# Tell janis to use pure Elixir mDNS client
config :janis, Janis.Mdns, true

config :persistent_storage, NervesJanis.Settings,
  path: "/root/_settings"


config :nerves_firmware_http,
  version: System.get_env("JANIS_FIRMWARE_VERSION") || "unknown",
  system: NervesJanis.Mixfile.target

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: "eu-west-1"

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.Project.config[:target]}.exs"
