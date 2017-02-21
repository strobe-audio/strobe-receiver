defmodule Janis.Mixfile do
  use Mix.Project

  def project do
    [app: :janis,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     compilers: [:make, :elixir, :app],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     aliases: aliases(),
   ]
  end


  defp aliases do
    # Execute the usual mix clean and our Makefile clean task
    [clean: ["clean", "clean.make"]]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [ applications: [
        :logger,
        :monotonic,
        :uuid,
        :poison,
        :dnssd,
        :nerves_ssdp_client,
        :logger_multicast_backend,
      ],
      included_applications: [
        :mdns,
      ],
      mod: {Janis, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:dnssd, git: "https://github.com/benoitc/dnssd_erlang.git"},
      {:poison, "~> 1.5"},
      {:monotonic, git: "https://github.com/magnetised/monotonic.ex.git"},
      {:nerves_ssdp_client, "~> 0.1.3"},
      {:mdns, github: "magnetised/mdns", branch: "master"},
      {:logger_multicast_backend, github: "magnetised/logger_multicast_backend", branch: "master"},
    ]
  end
end

# mix compile.make
defmodule Mix.Tasks.Compile.Make do
  @doc "Compiles c port driver"

  def run(_) do
    {result, _error_code} = System.cmd("make", [], stderr_to_stdout: true)
    Mix.shell.info result
    :ok
  end
end

# mix clean.make
defmodule Mix.Tasks.Clean.Make do
  @doc "Cleans helper in c_src"

  def run(_) do
    {result, _error_code} = System.cmd("make", ['clean'], stderr_to_stdout: true)
    Mix.shell.info result
    :ok
  end
end
