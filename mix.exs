defmodule ElixirEmailReplyParser.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_email_reply_parser,
     version: "0.1.1",
     description: description(),
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     deps: deps(),

     # Docs
     name: "Elixir Email Reply Parser",
     source_url: "https://github.com/hellogustav/elixir_email_reply_parser",
     docs: [main: "readme",
            extras: ["README.md", "LICENSE.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp description do
    """
    Email reply parser for retrieval of the last reply from email message.
    Originally an Elixir port of https://github.com/github/email_reply_parser
    as well as its port https://github.com/zapier/email-reply-parser
    enhanced by e.g. an ability to handle emails with German.
    """
  end

  defp package do
    [name: :elixir_email_reply_parser,
    maintainers: ["elixir.email.reply.parser@gmail.com"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/hellogustav/elixir_email_reply_parser"}]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:earmark, "~> 1.2.0", only: :dev},
      {:ex_doc, "~> 0.15", only: :dev}
    ]
  end
end
