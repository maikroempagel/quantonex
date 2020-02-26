defmodule Quantonex.DataPoint do
  @typedoc """
  Represents a data point of an instrument.

  * `complete` - true if the data point is complete, otherwise false.
  * `close` - the close price.
  * `granularity` - the granularity of the data point e.g. `H4`.
  * `instrument` - an instrument e.g. `EURUSD`.
  * `high` - the highest price.
  * `low` - the lowest price.
  * `open` - the open price.
  * `datetime` - the datetime.
  * `volume` - the volume.
  """
  @type data_point :: %__MODULE__{
          complete: boolean(),
          close: Decimal.t(),
          granularity: String.t(),
          instrument: String.t(),
          high: Decimal.t(),
          low: Decimal.t(),
          open: Decimal.t(),
          datetime: DateTime.t(),
          volume: integer()
        }

  defstruct [
    :complete,
    :close,
    :high,
    :low,
    :open,
    :granularity,
    :instrument,
    :datetime,
    :volume
  ]
end
