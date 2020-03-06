defmodule Quantonex.DataPoint do
  @moduledoc """
  Contains the `Quantonex.DataPoint` type.
  """

  @typedoc """
  Represents a data point of an instrument.

  * `complete` - `true` if the data point is complete, otherwise `false`

  A data point is considered incomplete if not all data is known or final.
  This usually occurs if the current interval defined by `granularity` has not yet finished.

  * `close` - the close price
  * `granularity` - the granularity of the data point e.g. `H4`
  * `instrument` - an instrument e.g. `EURUSD`
  * `high` - the highest price
  * `low` - the lowest price
  * `open` - the open price
  * `datetime` - the datetime
  * `volume` - the volume
  """
  @type t :: %__MODULE__{
          complete: boolean(),
          close: Decimal.t(),
          granularity: String.t(),
          instrument: String.t(),
          high: Decimal.t(),
          low: Decimal.t(),
          open: Decimal.t(),
          datetime: DateTime.t(),
          volume: non_neg_integer()
        }

  defstruct [
    :granularity,
    :instrument,
    :datetime,
    complete: false,
    close: Decimal.new(0),
    high: Decimal.new(0),
    low: Decimal.new(0),
    open: Decimal.new(0),
    volume: 0
  ]
end
