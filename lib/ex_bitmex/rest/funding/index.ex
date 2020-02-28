defmodule ExBitmex.Rest.Funding.Index do
  alias ExBitmex.Rest

  @type credentials :: ExBitmex.Credentials.t()
  @type params :: map
  @type funding :: ExBitmex.Funding.t()
  @type rate_limit :: ExBitmex.RateLimit.t()
  @type auth_error_response :: Rest.Request.auth_error_response()

  @spec get(params) :: {:ok, [funding], rate_limit} | auth_error_response
  def get(params \\ %{}) do
    "/funding"
    |> Rest.HTTPClient.non_auth_get(params)
    |> parse_response
  end

  defp parse_response({:ok, data, rate_limit}) when is_list(data) do
    fundings =
      data
      |> Enum.map(&to_struct/1)
      |> Enum.map(fn {:ok, p} -> p end)

    {:ok, fundings, rate_limit}
  end

  defp parse_response({:error, _, _} = error), do: error

  defp to_struct(data) do
    data
    |> Mapail.map_to_struct(
      ExBitmex.Funding,
      transformations: [:snake_case]
    )
  end
end
