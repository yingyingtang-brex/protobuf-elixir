defmodule Protobuf.RustNif do
  use Rustler, otp_app: :protobuf, crate: "protobuf_rustnif"

  def parse_bin(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
