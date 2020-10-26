# UeberauthCrowd

![Elixir CI](https://github.com/Murkiness/ueberauth_crowd/workflows/Elixir%20CI/badge.svg)

> Crowd OpenID strategy for Überauth.

## Installation

1. Add `:ueberauth_crowd` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ueberauth_crowd, "~> 0.1"}]
    end
    ```

1. Add the strategy to your applications:

    ```elixir
    def application do
      [extra_applications: [:ueberauth_crowd]]
    end
    ```

1. Add Crowd to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        crowd: {Ueberauth.Strategy.Crowd, []}
      ]
    ```

1.  Update your provider configuration:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Crowd,
      endpoint: System.get_env("CROWD_ENDPOINT")
    ```

1.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

1.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

1. Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured URL you can initialize the request through:

    /auth/crowd

## License

Please see [LICENSE](LICENSE) for licensing details.
