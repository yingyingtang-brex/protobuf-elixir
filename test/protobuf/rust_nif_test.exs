defmodule Protobuf.RustNifTest do
  use ExUnit.Case, async: true

  test "parse_bin" do
    # assert {300, 2} == Protobuf.RustNif.parse_bin(<<0b1010110000000010::16>>, 0)
    # assert {8, 1} = Protobuf.RustNif.parse_bin(<<8, 150, 01>>, 0)
    # assert {val, 10} = Protobuf.RustNif.parse_bin(<<128, 128, 128, 128, 248, 255, 255, 255, 255, 1>>, 0)
    # <<n::signed-32>> = <<val::32>>
    # assert n == -2_147_483_648
    assert [{1, 0, 150}] == Protobuf.RustNif.parse_bin(<<8, 150, 01>>, 0)
  end
end
