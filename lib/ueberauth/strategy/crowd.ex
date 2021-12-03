defmodule Ueberauth.Strategy.Crowd do
  @moduledoc ~S"""
  Crowd OpenID for Überauth.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Extra

  @spec handle_request!(Plug.Conn.t()) :: Plug.Conn.t()
  def handle_request!(conn) do
    state = conn.private[:ueberauth_state_param]
    cb_url = custom_callback().(conn) || callback_url(conn)
    csrf_params = if is_nil(state), do: %{}, else: %{state: state}
    query = Map.take(conn.params, get_additional_param_list()) |> Map.merge(csrf_params) |> URI.encode_query()
    return_to = URI.merge(URI.parse(cb_url), %URI{query: query}) |> URI.to_string()

    query =
      %{
        "openid.mode" => "checkid_setup",
        "openid.realm" => cb_url,
        "openid.return_to" => return_to,
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
        |> assign_params_to(params)

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

  defp assign_params_to(conn, params) do
    get_additional_param_list()
    |> Enum.reduce(conn, fn p, acc ->
      val = Map.get(params, p)

      if val do
        assign(acc, String.to_atom(p), val)
      else
        acc
      end
    end)
  end

  defp get_additional_param_list do
    Application.get_env(:ueberauth, Ueberauth.Strategy.Crowd)
    |> Keyword.get(:additional_params, [])
  end

  defp endpoint do
    Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Crowd) |> Keyword.get(:endpoint)
  end

  defp custom_callback do
    Application.get_env(:ueberauth, Ueberauth.Strategy.Crowd)
    |> Keyword.get(:cb_func, fn _conn -> nil end)
  end
end
