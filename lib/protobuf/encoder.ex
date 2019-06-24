defmodule Protobuf.Encoder do
  import Protobuf.WireTypes
  import Bitwise, only: [bsr: 2, band: 2, bsl: 2, bor: 2]

  alias Protobuf.{MessageProps, FieldProps}
  require Logger

  @spec encode(atom, struct, keyword) :: iodata
  def encode(mod, struct, opts) do
    case struct do
      %{__struct__: _} ->
        encode(struct, opts)
      _ ->
        encode(mod.new(struct), opts)
    end
  end

  @spec encode(struct, keyword) :: iodata
  def encode(%mod{} = struct, opts \\ []) do
    res = encode!(struct, mod.__message_props__())

    case Keyword.fetch(opts, :iolist) do
      {:ok, true} -> res
      _ -> IO.iodata_to_binary(res)
    end
  end

  @spec encode!(struct, MessageProps.t()) :: iodata
  def encode!(struct, %{field_props: field_props} = props) do
    syntax = props.syntax
    oneofs = oneof_actual_vals(props, struct)

    encode_fields(Map.values(field_props), syntax, struct, oneofs, [])
    |> Enum.reverse()
  catch
    {e, msg, st} ->
      reraise e, msg, st
  end

  def encode_fields([], _, _, _, acc) do
    acc
  end
  def encode_fields([prop|tail], syntax, struct, oneofs, acc) do
    %{name_atom: name, oneof: oneof, enum?: is_enum, type: type, encode_func: encode_func, repeated?: is_repeated, encoded_fnum: encoded_fnum, skip_func: skip_func} = prop

    val =
      if oneof do
        oneofs[name]
      else
        case struct do
          %{^name => v} ->
            v
          _ ->
            nil
        end
      end

    if skip_field?(syntax, val, prop) || (is_enum && is_enum_default(type, val)) do
      encode_fields(tail, syntax, struct, oneofs, acc)
    else
      if encode_func do
        acc = if Function.info(encode_func, :arity) == {:arity, 2} do
          [encode_func.(val, prop) | acc]
        else
          if is_repeated do
            [Enum.map(val, fn v -> [encoded_fnum, encode_func.(v)] end) | acc]
          else
            [[encoded_fnum, encode_func.(val)] | acc]
          end
        end
        encode_fields(tail, syntax, struct, oneofs, acc)
      # Deprecated
      else
        acc = [encode_field(class_field(prop), val, prop) | acc]
        encode_fields(tail, syntax, struct, oneofs, acc)
      end
    end
  rescue
    error ->
      stacktrace = System.stacktrace()

      msg =
        "Got error when encoding #{inspect(struct.__struct__)}##{prop.name_atom}: #{
          inspect(error)
        }"

      throw {Protobuf.EncodeError, [message: msg], stacktrace}
  end

  def cal_encode_func(%{wire_type: wire_delimited(), embedded?: true, map?: true}) do
    &Protobuf.Encoder.encode_map/2
  end
  def cal_encode_func(%{wire_type: wire_delimited(), embedded?: true}) do
    &Protobuf.Encoder.encode_embedded/2
  end
  def cal_encode_func(%{repeated?: true, packed?: true}) do
    &Protobuf.Encoder.encode_packed/2
  end
  def cal_encode_func(%{type: type}) do
    case type do
      t when t in [:int32, :int64, :uint32, :uint64] ->
        &Protobuf.Encoder.encode_varint/1
      t when t in [:sint32, :sint64] ->
        &Protobuf.Encoder.encode_type_zigzag/1
      :bool ->
        &Protobuf.Encoder.encode_type_bool/1
      :string ->
        &Protobuf.Encoder.encode_type_bytes/1
      :bytes ->
        &Protobuf.Encoder.encode_type_bytes/1
      # TODO
      {:enum, _} ->
        &Protobuf.Encoder.encode_type_enum/2
      :fixed64 ->
        &Protobuf.Encoder.encode_type_fixed64/1
      :sfixed64 ->
        &Protobuf.Encoder.encode_type_sfixed64/1
      :double ->
        &Protobuf.Encoder.encode_type_double/1
      :float ->
        &Protobuf.Encoder.encode_type_float/1
      :fixed32 ->
        &Protobuf.Encoder.encode_type_fixed32/1
      :sfixed32 ->
        &Protobuf.Encoder.encode_type_sfixed32/1
      _ ->
        nil
    end
  end

  def encode_type_varint(v, _) do
    encode_varint(v)
  end

  def encode_type_bytes(v) do
    bin = IO.iodata_to_binary(v)
    len = bin |> byte_size |> encode_varint
    <<len::binary, bin::binary>>
  end

  def encode_type_zigzag(v) do
    v |> encode_zigzag |> encode_varint
  end

  def encode_type_bool(true), do: <<1>>
  def encode_type_bool(false), do: <<0>>
  def encode_type_fixed64(v), do: <<v::64-little>>
  def encode_type_sfixed64(v), do: <<v::64-signed-little>>
  def encode_type_double(v), do: <<v::64-float-little>>
  def encode_type_float(v), do: <<v::32-float-little>>
  def encode_type_fixed32(v), do: <<v::32-little>>
  def encode_type_sfixed32(v), do: <<v::32-signed-little>>

  def encode_type_enum(val, %{type: {:enum, type}, repeated?: is_repeated, encoded_fnum: fnum}) when is_atom(val) do
    if is_repeated do
      Enum.map(val, fn v ->
        encoded = v |> type.value() |> encode_varint()
        [fnum, encoded]
      end)
    else
      encoded = val |> type.value() |> encode_varint()
      [fnum, encoded]
    end
  end
  def encode_type_enum(v, %{repeated?: is_repeated, encoded_fnum: fnum}) do
    if is_repeated do
      Enum.map(v, fn v -> [fnum, encode_varint(v)] end)
    else
      [fnum, encode_varint(v)]
    end
  end

  def encode_embedded(val, %{type: type, encoded_fnum: fnum, repeated?: is_repeated}) do
    if is_repeated do
      Enum.map(val, fn v ->
        # so that oneof {:atom, v} can be encoded
        encoded = encode(type, v, [])
        byte_size = byte_size(encoded)
        [fnum, encode_varint(byte_size), encoded]
      end)
    else
      # so that oneof {:atom, v} can be encoded
      encoded = encode(type, val, [])
      byte_size = byte_size(encoded)
      [fnum, encode_varint(byte_size), encoded]
    end
  end

  def encode_map(val, %{type: type, encoded_fnum: fnum}) do
    Enum.map(val, fn v ->
      v = struct(type, %{key: elem(v, 0), value: elem(v, 1)})
      # so that oneof {:atom, v} can be encoded
      encoded = encode(type, v, [])
      byte_size = byte_size(encoded)
      [fnum, encode_varint(byte_size), encoded]
    end)
  end

  def encode_packed(val, %{type: type, encoded_fnum: fnum}) do
    encoded = Enum.map(val, fn v -> encode_type(type, v) end)
    |> IO.iodata_to_binary()
    byte_size = byte_size(encoded)
    [fnum, encode_varint(byte_size), encoded]
  end
# (is_enum && is_enum_default(type, val))
  def cal_skip_func(%{repeated?: true}, _) do
    &Protobuf.Encoder.skip_list/2
  end
  def cal_skip_func(%{map?: true}, _) do
    &Protobuf.Encoder.skip_map/2
  end
  def cal_skip_func(%{optional?: true}, :proto2) do
    &Protobuf.Encoder.skip_nil/2
  end
  def cal_skip_func(%{embedded?: true}, :proto3) do
    &Protobuf.Encoder.skip_nil/2
  end
  def cal_skip_func(%{type: type, oneof: nil}, :proto3) do
    case type do
      t when t in [:int32, :int64, :uint32, :uint64, :sint32, :sint64, :fixed32, :fixed64, :sfixed32, :sfixed64, :float, :double] ->
        &Protobuf.Encoder.skip_number/2
      :bool ->
        &Protobuf.Encoder.skip_bool/2
      t when t in [:string, :bytes] ->
        &Protobuf.Encoder.skip_bytes/2
      # TODO
      {:enum, _} ->
        &Protobuf.Encoder.skip_enum/2
      _ ->
        nil
    end
  end
  def cal_skip_func(_, _) do
    nil
  end

  def skip_list(val, _), do: val == []
  def skip_map(val, _), do: val == %{}
  def skip_nil(val, _), do: val == nil
  def skip_number(val, _), do: val == 0
  def skip_bytes(val, _), do: val == ""
  def skip_bool(val, _), do: val == false

  def skip_enum(val, %{type: {:enum, type}}) when is_atom(val) do
    type.value(val) == 0
  end
  def skip_enum(val, _) do
    val == 0
  end

  @doc false
  def skip_field?(syntax, val, prop)
  def skip_field?(_, [], _), do: true
  def skip_field?(_, v, _) when map_size(v) == 0, do: true
  def skip_field?(:proto2, nil, %{optional?: true}), do: true
  def skip_field?(:proto3, nil, _), do: true
  def skip_field?(:proto3, 0, %{oneof: nil}), do: true
  def skip_field?(:proto3, 0.0, %{oneof: nil}), do: true
  def skip_field?(:proto3, "", %{oneof: nil}), do: true
  def skip_field?(:proto3, false, %{oneof: nil}), do: true
  def skip_field?(_, _, _), do: false

  @spec encode_field(atom, any, FieldProps.t()) :: iodata
  def encode_field(:normal, val, %{encoded_fnum: fnum, type: type, repeated?: is_repeated}) do
    repeated_or_not(val, is_repeated, fn v ->
      [fnum, encode_type(type, v)]
    end)
  end

  def encode_field(
        :embedded,
        val,
        %{encoded_fnum: fnum, repeated?: is_repeated, map?: is_map, type: type} = prop
      ) do
    repeated = is_repeated || is_map

    repeated_or_not(val, repeated, fn v ->
      v = if is_map, do: struct(prop.type, %{key: elem(v, 0), value: elem(v, 1)}), else: v
      # so that oneof {:atom, v} can be encoded
      encoded = encode(type, v, [])
      byte_size = byte_size(encoded)
      [fnum, encode_varint(byte_size), encoded]
    end)
  end

  def encode_field(:packed, val, %{type: type, encoded_fnum: fnum}) do
    encoded = Enum.map(val, fn v -> encode_type(type, v) end)
    byte_size = IO.iodata_length(encoded)
    [fnum, encode_varint(byte_size), encoded]
  end

  @spec class_field(map) :: atom
  def class_field(%{wire_type: wire_delimited(), embedded?: true}) do
    :embedded
  end

  def class_field(%{repeated?: true, packed?: true}) do
    :packed
  end

  def class_field(_) do
    :normal
  end

  @spec encode_fnum(integer, integer) :: iodata
  def encode_fnum(fnum, wire_type) do
    fnum
    |> bsl(3)
    |> bor(wire_type)
    |> encode_varint
  end

  @spec encode_type(atom, any) :: iodata
  def encode_type(:int32, n), do: encode_varint(n)
  def encode_type(:int64, n), do: encode_varint(n)
  def encode_type(:uint32, n), do: encode_varint(n)
  def encode_type(:uint64, n), do: encode_varint(n)
  def encode_type(:sint32, n), do: n |> encode_zigzag |> encode_varint
  def encode_type(:sint64, n), do: n |> encode_zigzag |> encode_varint
  def encode_type(:bool, true), do: encode_varint(1)
  def encode_type(:bool, false), do: encode_varint(0)
  def encode_type({:enum, type}, n) when is_atom(n), do: n |> type.value() |> encode_varint()
  def encode_type({:enum, _}, n), do: encode_varint(n)
  def encode_type(:fixed64, n), do: <<n::64-little>>
  def encode_type(:sfixed64, n), do: <<n::64-signed-little>>
  def encode_type(:double, n), do: <<n::64-float-little>>

  def encode_type(:bytes, n) do
    bin = IO.iodata_to_binary(n)
    len = bin |> byte_size |> encode_varint
    <<len::binary, bin::binary>>
  end

  def encode_type(:string, n), do: encode_type(:bytes, n)
  def encode_type(:fixed32, n), do: <<n::32-little>>
  def encode_type(:sfixed32, n), do: <<n::32-signed-little>>
  def encode_type(:float, n), do: <<n::32-float-little>>

  @spec encode_zigzag(integer) :: integer
  def encode_zigzag(val) when val >= 0, do: val * 2
  def encode_zigzag(val) when val < 0, do: val * -2 - 1

  @spec encode_varint(integer) :: iodata
  def encode_varint(n) when n < 0 do
    <<n::64-unsigned-native>> = <<n::64-signed-native>>
    encode_varint(n)
  end

  def encode_varint(n) when n <= 127 do
    <<n>>
  end

  def encode_varint(n) do
    [<<1::1, band(n, 127)::7>> | encode_varint(bsr(n, 7))] |> IO.iodata_to_binary
  end

  @spec wire_type(atom) :: integer
  def wire_type(:int32), do: wire_varint()
  def wire_type(:int64), do: wire_varint()
  def wire_type(:uint32), do: wire_varint()
  def wire_type(:uint64), do: wire_varint()
  def wire_type(:sint32), do: wire_varint()
  def wire_type(:sint64), do: wire_varint()
  def wire_type(:bool), do: wire_varint()
  def wire_type({:enum, _}), do: wire_varint()
  def wire_type(:enum), do: wire_varint()
  def wire_type(:fixed64), do: wire_64bits()
  def wire_type(:sfixed64), do: wire_64bits()
  def wire_type(:double), do: wire_64bits()
  def wire_type(:string), do: wire_delimited()
  def wire_type(:bytes), do: wire_delimited()
  def wire_type(:fixed32), do: wire_32bits()
  def wire_type(:sfixed32), do: wire_32bits()
  def wire_type(:float), do: wire_32bits()
  def wire_type(mod) when is_atom(mod), do: wire_delimited()

  defp repeated_or_not(val, repeated, func) do
    if repeated do
      Enum.map(val, func)
    else
      func.(val)
    end
  end

  defp is_enum_default({_, type}, v) when is_atom(v), do: type.value(v) == 0
  defp is_enum_default({_, _}, v) when is_integer(v), do: v == 0
  defp is_enum_default({_, _}, _), do: false

  defp oneof_actual_vals(
         %{field_tags: field_tags, field_props: field_props, oneof: oneof},
         struct
       ) do
    Enum.reduce(oneof, %{}, fn {field, index}, acc ->
      case Map.get(struct, field, nil) do
        {f, val} ->
          %{oneof: oneof} = field_props[field_tags[f]]

          if oneof != index do
            raise Protobuf.EncodeError,
              message: ":#{f} doesn't belongs to #{inspect(struct.__struct__)}##{field}"
          else
            Map.put(acc, f, val)
          end

        nil ->
          acc

        _ ->
          raise Protobuf.EncodeError,
            message: "#{inspect(struct.__struct__)}##{field} should be {key, val} or nil"
      end
    end)
  end
end
