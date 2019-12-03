defmodule Quantonex do
  @moduledoc """
  Documentation for Quantonex.
  """

  def sma(data) do
    data |> sma(length(data))
  end

  def sma(data, _period) when length(data) < 2,
    do: {:error, "There must be at least 2 data points."}

  def sma(_data, period) when period < 2, do: {:error, "Period must be at least 2."}

  def sma(data, period) do
    try do
      value =
        data
        |> Enum.reverse()
        |> Enum.take(period)
        |> Enum.map(&create_decimal/1)
        |> Enum.reduce(fn x, acc -> Decimal.add(x, acc) end)
        |> Decimal.div(period)

      {:ok, value}
    rescue
      _e in Decimal.Error ->
        {:error, "One of the data points is non-numeric."}
    end
  end

  defp create_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp create_decimal(value), do: Decimal.new(value)
end
