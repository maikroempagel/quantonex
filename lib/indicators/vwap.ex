# defmodule Quantonex.Indicators do
#  alias Quantonex.DataPoint
#
#  @typedoc """
#  Represents a volume weighted average price.
#
#    * `value` - the volume weighted average price.
#    * `cumulative_volume` - the previous volume plus the current volume.
#    * `cumulative_volume_price` - the previous volume price plus the current volume price.
#  """
#  @type vwap :: %__MODULE__{
#          value: Decimal.t(),
#          cumulative_volume: integer(),
#          cumulative_volume_price: Decimal.t()
#        }
#
#  defstruct value: Decimal.new(0),
#            cumulative_volume: 0,
#            cumulative_volume_price: Decimal.new(0)
#
#  @doc """
#  Calculates a volume weighted average price.
#  """
#  @spec vwap(DataPoint.t(), integer(), Decimal.t()) ::
#          {:error, String.t()} | {:ok, vwap()}
#  def vwap(
#        %DataPoint{} = data_point,
#        cumulative_volume \\ 0,
#        cumulative_volume_price \\ Decimal.new(0)
#      ) do
#    try do
#      average_price =
#        data_point.high
#        |> Decimal.add(data_point.low)
#        |> Decimal.add(data_point.close)
#        |> Decimal.div(3)
#
#      volume_price = Decimal.mult(average_price, data_point.volume)
#
#      new_cumulative_volume = cumulative_volume + data_point.volume
#      new_cumulative_volume_price = Decimal.add(cumulative_volume_price, volume_price)
#
#      value = Decimal.div(new_cumulative_volume_price, new_cumulative_volume)
#
#      {
#        :ok,
#        %__MODULE__{
#          value: value,
#          cumulative_volume: new_cumulative_volume,
#          cumulative_volume_price: new_cumulative_volume_price
#        }
#      }
#    rescue
#      _ in Decimal.Error ->
#        {:error, "An error occured while calculating the VWAP value."}
#    end
#  end
# end
