defmodule Ueberauth.Strategy.Crowd do
  @moduledoc ~S"""
  Crowd OpenID for Überauth.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Extra

  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(conn) do
    return_url = Map.get(conn.params, "return_url")
    cb_url = callback_url(conn)
    return_url = cb_url <> "?return_url=#{return_url}"

    query =
      %{
        "openid.mode" => "checkid_setup",
        "openid.realm" => cb_url,
        "openid.return_to" => return_url,
        "openid.ns" => "http://specs.openid.net/auth/2.0",
        "openid.claimed_id" => "http://specs.openid.net/auth/2.0/identifier_select",
        "openid.identity" => "http://specs.openid.net/auth/2.0/identifier_select"
      }
      |> URI.encode_query()

    redirect!(conn, endpoint() <> "?" <> query)
  end

  @spec handle_callback!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_callback!(%Plug.Conn{params: %{"openid.mode" => "id_res"}} = conn) do
    params = conn.params

    case validate(params) do
      true ->
        user_name =
          params
          |> Map.fetch!("openid.identity")
          |> String.split("/")
          |> List.last()

        conn
        |> assign(:crowd_user, user_name)
        |> assign(:return_url, Map.get(params, "return_url", "/"))

      false ->
        set_errors!(conn, [error("invalid_user", "Invalid user")])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("invalid_openid", "Invalid openid response received")])
  end

  @doc false
  @spec handle_cleanup!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_cleanup!(conn) do
    conn
    |> assign(:crowd_user, nil)
  end

  @spec uid(Plug.Conn.t()) :: pos_integer
  def uid(conn) do
    conn.assigns[:crowd_user]
  end

  @spec info(Plug.Conn.t()) :: Info.t()
  def info(conn) do
    %Info{
      name: conn.assigns[:crowd_user] |> String.split("/") |> List.last()
    }
  end

  @spec extra(Plug.Conn.t()) :: Extra.t()
  def extra(conn) do
    %Extra{
      raw_info: %{
        user: conn.assigns[:crowd_user]
      }
    }
  end

  @spec validate(map) :: boolean
  defp validate(params) do
    body = create_body_for_verify_req(params)
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(endpoint(), body, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        String.contains?(body, "is_valid:true\n")

      _ ->
        false
    end
  end

  # Block undocumented function
  @doc false
  @spec default_options :: []
  def default_options

  @doc false
  @spec credentials(Plug.Conn.t()) :: Ueberauth.Auth.Credentials.t()
  def credentials(_conn), do: %Ueberauth.Auth.Credentials{}

  @doc false
  @spec auth(Plug.Conn.t()) :: Ueberauth.Auth.t()
  def auth(conn)

  defp create_body_for_verify_req(params) do
    params
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "openid.") end)
    |> Enum.into(%{})
    |> Map.put("openid.mode", "check_authentication")
    |> URI.encode_query()
  end

  defp endpoint do
    Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Crowd) |> Keyword.get(:endpoint)
  end
end
