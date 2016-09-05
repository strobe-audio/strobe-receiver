# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config


config :logger, :console,
  level: :info,
  format: "$date $time $metadata [$level]$levelpad $message\n",
  sync_threshold: 1_000_000,
  metadata: [:module, :line],
  colors: [info: :green]

# TODO: make the additions configurable per DAC
config :nerves, :firmware,
  rootfs_additions: "config/rootfs"
  # fwup_conf: "config/fwup.conf"

# Tell janis to use pure Elixir mDNS client
config :janis, Janis.Mdns, true

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.Project.config[:target]}.exs"
