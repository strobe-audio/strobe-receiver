defmodule NervesJanis.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [app: :nerves_janis,
     version: "0.0.1",
     target: @target,
     config_path: "config/config.exs",
     deps_path: "../../deps/#{@target}",
     build_path: "../../_build/#{@target}",
     lockfile: "../../mix.lock",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     archives: archives(),
     aliases: aliases(),
     deps: deps() ++ system(@target)
   ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [ mod: {NervesJanis, []},
      applications: [
        :logger,
        :nerves,
        :nerves_lib,
        :"nerves_system_#{@target}",
        :janis_init,
        :nerves_network_interface,
        :nerves_networking,
        :nerves_interim_wifi,
        :persistent_storage,
        :logger_papertrail_backend,
        :nerves_firmware_http,
      ],
      included_applications: [
        :janis,
        :ex_aws,
        :poison,
        :hackney,
        :sweet_xml,
      ],
    ]
  end

  def deps do
    [{:nerves, "~> 0.3.0"},
     {:nerves_lib, github: "nerves-project/nerves_lib"},
     {:nerves_networking, github: "nerves-project/nerves_networking"},
     {:nerves_network_interface, "~> 0.3.2"},
     # {:janis, git: "git@gitlab.com:magnetised/janis.git", branch: "master"},
     {:janis, in_umbrella: true},
     # {:janis_init, git: "git@gitlab.com:magnetised/janis_init.git"},
     # {:janis_init, path: "/home/garry/janis_init"},
     {:janis_init, in_umbrella: true},
     {:nerves_interim_wifi, "~> 0.1.0"},
     {:persistent_storage, github: "cellulose/persistent_storage", tag: "v0.9.0"},
     {:logger_papertrail_backend, "~> 0.1.0"},
     {:nerves_firmware_http, github: "magnetised/nerves_firmware_http"},
     {:ex_aws, "~> 1.0"},
     {:poison, "~> 1.5"},
     {:hackney, "~> 1.6"},
     {:sweet_xml, "~> 0.6"},
    ]
  end

  def system(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

  def archives do
     [nerves_bootstrap: "~> 0.1.4"]
  end

  def target do
    @target
  end
end
