defmodule SimpleMemCache.Mixfile do
  use Mix.Project

  def project do
    [app: :simple_mem_cache,
     version: "1.0.1",
     elixir: "~> 1.3",

     # Hex
     description: description(),
     package: package(),

     # Docs
     docs: [source_ref: "master", main: "SimpleMemCache",
            canonical:  "http://hexdocs.pm/simple_mem_cache",
            source_url: "https://github.com/nico-amsterdam/simple_mem_cache"
           ],

     build_embedded: Mix.env == :prod,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger]]
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
      {:ex_doc, "~> 0.31.2", only: :dev},
      {:credo,  "~> 1.7"   , only: :dev}
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
