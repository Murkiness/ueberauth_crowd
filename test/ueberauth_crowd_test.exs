defmodule UeberauthCrowdTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Ueberauth.Strategy.Crowd

  describe "handle_request!" do
    setup do
      Application.put_env(:ueberauth, Ueberauth.Strategy.Crowd,
        endpoint: "https://crowd.example.com/openidserver/op"
      )

      :ok
    end

    test "redirects" do
      conn = conn(:get, "http://example.com/path")
      conn = Crowd.handle_request!(conn)

      assert conn.state == :sent
      assert conn.status == 302
    end

    test "redirects to the right url" do
      conn = Crowd.handle_request!(conn(:get, "http://example.com/path"))

      {"location", location} = List.keyfind(conn.resp_headers, "location", 0)

      assert location ==
               "https://crowd.example.com/openidserver/op?openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.realm=http%3A%2F%2Fexample.com&openid.return_to=http%3A%2F%2Fexample.com%3Freturn_url%3D"
    end
  end

  describe "handle_callback!" do
    setup do
      Application.put_env(:ueberauth, Ueberauth.Strategy.Crowd,
        endpoint: "https://crowd.example.com/openidserver/op"
      )

      :meck.new(HTTPoison, [:passthrough])

      on_exit(fn -> :meck.unload() end)

      :ok
    end

    defp callback(params \\ %{}) do
      conn = %{conn(:get, "http://example.com/path/callback") | params: params}

      Crowd.handle_callback!(conn)
    end

    test "error for invalid callback parameters" do
      conn = callback()

      assert conn.assigns == %{
               ueberauth_failure: %Ueberauth.Failure{
                 errors: [
                   %Ueberauth.Failure.Error{
                     message: "Invalid openid response received",
                     message_key: "invalid_openid"
                   }
                 ],
                 provider: nil,
                 strategy: nil
               }
             }
    end

    test "error for missing user valid information" do
      :meck.expect(HTTPoison, :post, fn
        "https://crowd.example.com/openidserver/op", _, _ ->
          {:ok, %HTTPoison.Response{body: "", status_code: 200}}
      end)

      conn =
        callback(%{
          "openid.mode" => "id_res"
        })

      assert conn.assigns == %{
               ueberauth_failure: %Ueberauth.Failure{
                 errors: [
                   %Ueberauth.Failure.Error{message: "Invalid user", message_key: "invalid_user"}
                 ],
                 provider: nil,
                 strategy: nil
               }
             }
    end

    test "error for invalid user callback" do
      :meck.expect(HTTPoison, :post, fn
        "https://crowd.example.com/openidserver/op", _, _ ->
          {:ok, %HTTPoison.Response{body: "is_valid:false\n", status_code: 200}}
      end)

      conn =
        callback(%{
          "openid.mode" => "id_res"
        })

      assert conn.assigns == %{
               ueberauth_failure: %Ueberauth.Failure{
                 errors: [
                   %Ueberauth.Failure.Error{message: "Invalid user", message_key: "invalid_user"}
                 ],
                 provider: nil,
                 strategy: nil
               }
             }
    end

    test "success for valid user" do
      :meck.expect(HTTPoison, :post, fn
        "https://crowd.example.com/openidserver/op", _, _ ->
          {:ok, %HTTPoison.Response{body: "is_valid:true\n", status_code: 200}}
      end)

      conn =
        callback(%{
          "openid.mode" => "id_res",
          "openid.identity" => "someone"
        })

      assert conn.assigns == %{crowd_user: "someone", return_url: "/"}
    end
  end
end
