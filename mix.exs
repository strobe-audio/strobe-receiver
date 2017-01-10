defmodule NervesJanis.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [app: :nerves_janis,
     version: "0.0.1",
     target: @target,
     archives: [nerves_bootstrap: "~> 0.1.4"],
     deps_path: "deps/#{@target}",
     build_path: "_build/#{@target}",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases,
     deps: deps ++ system(@target)
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
        :nerves_interim_wifi,
        :persistent_storage,
        :logger_papertrail_backend,
        # :janis,
      ],
      included_applications: [
        :janis
      ],
    ]
  end

  def deps do
    [{:nerves, "~> 0.3.0"},
     {:nerves_lib, github: "nerves-project/nerves_lib"},
     {:nerves_networking, github: "nerves-project/nerves_networking"},
     {:janis, git: "git@gitlab.com:magnetised/janis.git", branch: "master"},
     # {:janis_init, git: "git@gitlab.com:magnetised/janis_init.git"},
     {:janis_init, path: "/home/garry/janis_init"},
     {:nerves_interim_wifi, "~> 0.1.0"},
     {:persistent_storage, github: "cellulose/persistent_storage"},
     {:logger_papertrail_backend, "~> 0.1.0"},
    ]
  end

  def system(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

end
