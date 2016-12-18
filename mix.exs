defmodule SimpleMemCache.Mixfile do
  use Mix.Project

  def project do
    [app: :simple_mem_cache,
     version: "0.1.1",
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
      {:ex_doc,  "~> 0.14", only: :dev},
      {:credo,  "~> 0.5", only: :dev}
    ]
  end

  defp description do
    """
    ETS backed in-memory key-value cache with entry expiration after creation (TTL) or last access (idle-timout) and automatic value loading.
    Expired entries are automatically purged. Supports time travel.

    Trade memory for performance.
    """
  end

  defp package do
    [
     name: :simple_mem_cache,
     maintainers: ["Nico Hoogervorst"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/nico-amsterdam/simple_mem_cache"}
    ]
  end

end
