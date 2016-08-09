defmodule SimpleMemCache.Mixfile do
  use Mix.Project

  def project do
    [app: :simple_mem_cache,
     version: "0.1.0",
     elixir: "~> 1.3",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:earmark,  "~> 0.1", only: :dev},
      {:ex_doc,  "~> 0.11", only: :dev},
      {:credo,  "~> 0.4", only: :dev}
    ]
  end

  defp description do
    """
    Trade memory for performance.

    In-memory key-value cache with expiration-time after creation/modification/access (a.k.a. entry time-to-live and entry idle-timeout), automatic value loading and time travel support.
    Uses ETS table.
    """
  end

  defp package do
    [# These are the default files included in the package
     name: :simple_mem_cache,
     maintainers: ["Nico Hoogervorst"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/nico-amsterdam/simple_mem_cache"}]
  end

end
