defmodule Events.MessageOptions do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          is_event: boolean
        }

  defstruct [:is_event]

  field :is_event, 1, optional: true, type: :bool
end

defmodule Events.PbExtension do
  @moduledoc false
  use Protobuf, syntax: :proto2

  extend Google.Protobuf.MessageOptions, :message, 65009,
    optional: true,
    type: Events.MessageOptions
end
