defmodule MobileAppBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :mobile_app_backend,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: LcovEx],
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    extra_applications = [:logger, :runtime_tools]

    extra_applications =
      if(Mix.env() == :prod,
        do: extra_applications ++ [:diskusage_logger, :ehmon],
        else: extra_applications
      )

    [
      mod: {MobileAppBackend.Application, []},
      extra_applications: extra_applications
    ]
  end

  def cli do
    [preferred_envs: [update_test_data: :test]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:absinthe_client, "~> 0.1.0"},
      {:bandit, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:decorator, "~> 1.4"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:diskusage_logger, "~> 0.2", only: :prod},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.0"},
      {:ehmon, github: "mbta/ehmon", only: :prod},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:ex_aws, "== 2.5.1"},
      {:ex_aws_rds, "== 2.0.2"},
      {:ex_aws_sts, "~> 2.3"},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:gettext, "~> 0.20"},
      {:google_api_fcm, "~> 0.14.0"},
      {:google_api_iam_credentials, "~> 0.15.0"},
      {:google_api_sts, "~> 0.9.2"},
      {:goth, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:jose, "~> 1.11"},
      {:lazy_html, ">= 0.0.0", only: :test},
      {:lcov_ex, "~> 0.3", only: [:test], runtime: false},
      {:logster, "~> 1.1"},
      {:mox, "~> 1.0", only: :test},
      {:nebulex, "~>2.6.3"},
      {:oban, "~> 2.20"},
      {:oban_web, "~> 2.11"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix, "~> 1.8.0"},
      {:polyline, "~> 1.4", only: :test},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.3"},
      {:sentry, "~> 11.0"},
      {:server_sent_event_stage, "~> 1.2"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:tailwind, "~> 0.3.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:timex, "~> 3.7"},
      {:typed_ecto_schema, "~> 0.4.3"},
      {:uniq, "~> 0.6", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build", "ecto.setup"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
