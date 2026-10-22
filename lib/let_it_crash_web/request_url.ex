defmodule LetItCrashWeb.RequestURL do
  @moduledoc """
  Absolute URLs on the host the visitor actually used (localhost, a tunnel, …),
  so shared links and badge QR codes work wherever the app is reached from.
  """

  @doc "Replaces the path of `request_uri` (as given to `handle_params/3`) with `path`."
  def build(request_uri, path) do
    request_uri
    |> URI.parse()
    |> Map.merge(%{path: path, query: nil, fragment: nil})
    |> URI.to_string()
  end
end
