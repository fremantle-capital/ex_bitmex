defmodule ExBitmex.Rest.RequestTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  import Mock
  doctest ExBitmex.Rest.Request

  @credentials %ExBitmex.Credentials{
    api_key: System.get_env("BITMEX_API_KEY"),
    api_secret: System.get_env("BITMEX_API_SECRET")
  }

  setup_all do
    HTTPoison.start()
    :ok
  end

  describe ".auth_request/4" do
    test "returns the current rate limit" do
      use_cassette "rest/request/auth_request_with_rate_limit" do
        assert {:ok, _, rate_limit} =
                 ExBitmex.Rest.Request.auth_request(:post, "/order", @credentials, %{})

        assert rate_limit == %ExBitmex.RateLimit{
                 limit: 300,
                 remaining: 299,
                 reset: 1_543_383_854
               }
      end
    end

    test "returns an error tuple with no rate limits when the request times out" do
      with_mock HTTPoison, request: fn _url -> {:error, %HTTPoison.Error{reason: :timeout}} end do
        assert ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{}) ==
                 {:error, :timeout, nil}
      end
    end

    test "returns an error tuple with no rate limits when the request has a connect timeout" do
      with_mock HTTPoison,
        request: fn _url -> {:error, %HTTPoison.Error{reason: :connect_timeout}} end do
        assert ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{}) ==
                 {:error, :connect_timeout, nil}
      end
    end

    test "returns an error tuple when the params are invalid" do
      use_cassette "rest/request/auth_request_error_bad_request" do
        assert {:error, reason, _} =
                 ExBitmex.Rest.Request.auth_request(:post, "/order", @credentials, %{})

        assert reason ==
                 {:bad_request,
                  %{
                    "error" => %{
                      "message" => "'symbol' is a required arg.",
                      "name" => "HTTPError"
                    }
                  }}
      end
    end

    test "returns an error tuple with no rate limits when the IP address is forbidden" do
      use_cassette "rest/request/auth_request_error_ip_forbidden" do
        assert {:error, :ip_forbidden, nil} =
                 ExBitmex.Rest.Request.auth_request(:post, "/order", @credentials, %{})
      end
    end

    test "returns an error tuple with no rate limits when the signature is invalid" do
      use_cassette "rest/request/auth_request_error_invalid_signature" do
        assert {:error, :invalid_signature, nil} =
                 ExBitmex.Rest.Request.auth_request(:post, "/order", @credentials, %{})
      end
    end

    test "returns an error tuple when the resource is not found" do
      use_cassette "rest/request/auth_request_not_found" do
        assert {:error, :not_found, _} =
                 ExBitmex.Rest.Request.auth_request(
                   :delete,
                   "/stats",
                   @credentials,
                   %{orderID: "a9b0996e-72bf-1db1-0630-483375da71ec"}
                 )
      end
    end

    test "returns an error tuple when overloaded" do
      use_cassette "rest/request/auth_request_overloaded" do
        assert {:error, :overloaded, _} =
                 ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{})
      end
    end

    test "returns an error tuple when the nonce is not increasing" do
      use_cassette "rest/request/auth_request_nonce_not_increasing" do
        assert {:error, {:nonce_not_increasing, msg}, _} =
                 ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{})

        assert msg ==
                 "Nonce is not increasing. This nonce: 62279790258940, last nonce: 62279790258995"
      end
    end

    test "returns an error tuple when the request response is a bad gateway" do
      use_cassette "rest/request/auth_request_bad_gateway" do
        assert {:error, :bad_gateway, _} =
                 ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{})
      end
    end

    test "returns an error tuple when rate limited" do
      use_cassette "rest/request/auth_request_rate_limited" do
        assert {:error, :rate_limited, rate_limit} =
                 ExBitmex.Rest.Request.auth_request(:get, "/stats", @credentials, %{})

        assert rate_limit == %ExBitmex.RateLimit{
                 limit: 300,
                 remaining: 0,
                 reset: 1_551_300_384
               }
      end
    end
  end

  describe ".non_auth_request/3" do
    test "returns an ok tuple with json" do
      use_cassette "rest/request/non_auth_request_ok" do
        assert {:ok, [_ | _], _} = ExBitmex.Rest.Request.non_auth_request(:get, "/stats", %{})
      end
    end

    test "returns the current rate limit" do
      use_cassette "rest/request/non_auth_request_with_rate_limit" do
        assert {:ok, _, rate_limit} = ExBitmex.Rest.Request.non_auth_request(:get, "/stats", %{})

        assert rate_limit == %ExBitmex.RateLimit{
                 limit: 150,
                 remaining: 149,
                 reset: 1_543_467_798
               }
      end
    end
  end
end
