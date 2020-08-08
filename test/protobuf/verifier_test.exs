defmodule Protobuf.VerifierTest do
  use ExUnit.Case, async: true

  alias Protobuf.Verifier

  test "verifies int32s" do
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: 42))
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: nil))
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: -42))
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: 0))
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(a: "candle"))
    assert err =~ ~s("candle" is invalid for type int32)
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(a: 111_111_111_111))
    assert err =~ ~s(111111111111 is invalid for type int32)
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(a: 3.14))
    assert err =~ ~s(3.14 is invalid for type int32)
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(a: false))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(a: :enum_value))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(a: TestMsg.Foo))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(a: TestMsg.Foo.new()))
  end

  # TestMsg.Scalars has a bunch of fields with the same name as their types
  test "verifies int64s" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(int64: -200))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(int64: 140))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(int64: 0))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(int64: 9_223_372_036_854_775_807))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(int64: nil))
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(int64: :test))
    assert err =~ ~s(:test is invalid for type int64)
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(int64: "broom"))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(int64: TestMsg.Foo.Bar.new()))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(int64: ["chair"]))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(int64: {:pillow}))
  end

  test "verifies uint32s" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(uint32: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(uint32: 4_294_967_295))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(uint32: 0))
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(uint32: -11))
    assert err =~ ~s(-11 is invalid for type uint32)
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(uint32: 4_294_967_296))
    assert err =~ ~s(4294967296 is invalid for type uint32)
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(uint32: 0.5))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(uint32: "shoe"))
  end

  test "verifies uint64s" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(uint64: 11))
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(uint64: -11))
    assert err =~ ~s(-11 is invalid for type uint64)
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(uint64: 1.5))
    assert err =~ ~s(1.5 is invalid for type uint64)
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(uint64: :blah))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(uint64: "book"))
  end

  test "verifies floats and doubles" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(float: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(double: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(float: 11.333))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(double: 11.333))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(float: :infinity))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(double: :infinity))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(float: :negative_infinity))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(double: :negative_infinity))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(float: :nan))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(double: :nan))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(float: "rug"))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(double: "table"))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(float: true))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(double: false))
  end

  test "verifies other numeric types" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(sint32: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(sint64: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(fixed32: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(sfixed32: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(fixed64: 11))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(sfixed64: 11))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed32: -11))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed64: -11))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(sint32: 1.5))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(sint64: 1.5))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed32: 1.5))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed64: 1.5))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed32: 111_111_111_111))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(sint32: 111_111_111_111))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(sint32: "jack"))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(sint64: :jill))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed32: <<117, 112>>))
    assert {:error, _err} = Verifier.verify(TestMsg.Scalars.new(fixed64: %{"the" => "hill"}))
  end

  test "verifies bools" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(bool: true))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(bool: false))
    assert :ok == Verifier.verify(TestMsg.Scalars.new(bool: nil))
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(bool: -11))
    assert err =~ ~s(-11 is invalid for type bool)
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(bool: "vase"))
    assert err =~ ~s("vase" is invalid for type bool)
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(bool: :yarrrr))
    assert err =~ ~s(:yarrrr is invalid for type bool)
  end

  test "verifies strings" do
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: 42, b: 100, c: "", d: 123.5))
    assert :ok == Verifier.verify(TestMsg.Foo.new(a: 42, b: 100, c: "str", d: 123.5))
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(a: 42, b: 100, c: false, d: 123.5))
    assert err =~ ~s(false is invalid for type string)
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(a: 42, b: 100, c: 555, d: 123.5))
    assert err =~ ~s(555 is invalid for type string)
  end

  test "verifies bytes" do
    assert :ok == Verifier.verify(TestMsg.Scalars.new(bytes: "foo"))
    assert {:error, err} = Verifier.verify(TestMsg.Scalars.new(bytes: 5.5))
    assert err =~ ~s(5.5 is invalid for type bytes)
  end

  test "verifies enums" do
    assert :ok == Verifier.verify(TestMsg.Foo.new(j: 2))
    assert :ok == Verifier.verify(TestMsg.Foo.new(j: :A))
    assert :ok == Verifier.verify(TestMsg.Foo.new(j: :B))

    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(j: :HELLO))
    assert err =~ ~s(:HELLO is not a valid value in enum Elixir.TestMsg.EnumFoo)
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(j: false))
    assert err =~ ~s(false is not a valid value in enum Elixir.TestMsg.EnumFoo)
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(j: Non.Existent.Module))
    assert err =~ ~s(Non.Existent.Module is not a valid value in enum Elixir.TestMsg.EnumFoo)
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(j: "test"))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(j: 200))
  end

  test "verifies enum with lowercase atoms" do
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(a: :unknown))
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(a: :A))
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(a: :a))
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(b: :B))
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(b: :b))
    assert :ok == Verifier.verify(TestMsg.Atom.Bar2.new(a: nil, b: nil))
    assert {:error, err} = Verifier.verify(TestMsg.Atom.Bar2.new(a: :abcdef))

    # This error message isn't ideal, but I'm not sure it's worth threading through the uncapitalized value
    assert err =~ ~s(:ABCDEF is not a valid value in enum Elixir.TestMsg.EnumFoo)
    assert {:error, err} = Verifier.verify(TestMsg.Atom.Bar2.new(b: :abcdef))
    assert err =~ ~s(:ABCDEF is not a valid value in enum Elixir.TestMsg.EnumFoo)
  end

  test "verifies repeated enum fields" do
    assert :ok == Verifier.verify(TestMsg.Foo.new(o: [:A, :B]))
    assert :ok == Verifier.verify(TestMsg.Foo.new(o: []))
    assert :ok == Verifier.verify(TestMsg.Foo.new(o: nil))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(o: [:bob, :B]))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(o: [:A, :bob]))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(o: [:bob, :bob]))
  end

  test "verifies map types" do
    assert :ok == Verifier.verify(TestMsg.Foo.new(l: %{"foo_key" => 213}))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(l: "boo"))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(l: ["hoo"]))
    # the field "l" is a map from string to int32
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(l: %{"foo_key" => "blah"}))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(l: %{123 => "blah"}))
    assert {:error, _err} = Verifier.verify(TestMsg.Foo.new(l: %{"foo_key" => 111_111_111_111}))
  end

  test "verifies oneof fields" do
    assert :ok ==
             Verifier.verify(
               TestMsg.Oneof.new(%{first: {:a, 42}, second: {:d, "abc"}, other: "other"})
             )

    assert :ok ==
             Verifier.verify(
               TestMsg.Oneof.new(%{first: {:b, "abc"}, second: {:c, 123}, other: "other"})
             )

    assert {:error, err} =
             Verifier.verify(
               TestMsg.Oneof.new(%{first: "not-in-a-tuple", second: {:c, 123}, other: "other"})
             )

    assert err ==
             "TestMsg.Oneof#first has the wrong structure: the value of a oneof field should be nil or {key, val} where key = atom of a field name inside the oneof and val = its value"

    assert {:error, _err} =
             Verifier.verify(
               TestMsg.Oneof.new(%{first: {:b, "abc"}, second: false, other: "other"})
             )
  end

  test "verifies map with oneof" do
    assert :ok ==
             Verifier.verify(
               Google.Protobuf.Struct.new(
                 fields: %{"valid" => Google.Protobuf.Value.new(kind: {:bool_value, true})}
               )
             )

    assert {:error, _err} =
             Verifier.verify(
               Google.Protobuf.Struct.new(
                 fields: %{"valid" => Google.Protobuf.Value.new(kind: 555)}
               )
             )
  end

  test "supports map syntax for submessages" do
    assert :ok ==
             Verifier.verify(
               Google.Protobuf.Struct.new(fields: %{"valid" => %{kind: {:bool_value, true}}})
             )

    assert {:error, err} =
             Verifier.verify(Google.Protobuf.Struct.new(fields: %{"valid" => %{kind: "foobar"}}))

    assert err =~ "value of a oneof field should be nil or {key, val}"
  end

  test "verifies embedded messages" do
    assert :ok ==
             Verifier.verify(TestMsg.Foo.new(a: 42, e: %TestMsg.Foo.Bar{a: 12, b: "abc"}, f: 13))

    assert {:error, err} =
             Verifier.verify(
               TestMsg.Foo.new(a: 42, e: %TestMsg.Foo.Bar{a: true, b: "abc"}, f: 13)
             )

    assert err =~ ~s(true is invalid for type int32)

    assert {:error, err} =
             Verifier.verify(TestMsg.Foo.new(a: 42, e: %TestMsg.Foo.Bar{a: 12, b: 55.5}, f: 13))

    assert err =~ ~s(55.5 is invalid for type string)

    # wrong type of embedded message
    assert {:error, err} = Verifier.verify(TestMsg.Foo.new(e: TestMsg.Foo2.new()))

    assert err =~ ~s(got Elixir.TestMsg.Foo2 but expected Elixir.TestMsg.Foo.Bar)
  end

  test "verifies repeated embedded fields" do
    assert :ok ==
             Verifier.verify(
               TestMsg.Foo.new(h: [%TestMsg.Foo.Bar{a: 12, b: "abc"}, TestMsg.Foo.Bar.new(a: 13)])
             )

    assert :ok ==
             Verifier.verify(TestMsg.Foo.new(h: [TestMsg.Foo.Bar.new(), TestMsg.Foo.Bar.new()]))

    # wrong type of embedded message
    assert {:error, _err} =
             Verifier.verify(TestMsg.Foo.new(h: [TestMsg.Foo2.new(), TestMsg.Foo.Bar.new()]))

    assert {:error, _err} =
             Verifier.verify(TestMsg.Foo.new(h: [TestMsg.Foo.Bar.new(), TestMsg.Foo2.new()]))

    # wrong field inside one of the embedded messages
    assert {:error, _err} =
             Verifier.verify(
               TestMsg.Foo.new(h: [TestMsg.Foo.Bar.new(a: "bob"), TestMsg.Foo.Bar.new()])
             )

    assert {:error, _err} =
             Verifier.verify(
               TestMsg.Foo.new(h: [TestMsg.Foo.Bar.new(), TestMsg.Foo.Bar.new(b: 555)])
             )
  end

  test "verifies fields with extype annotation" do
    assert :ok == Verifier.verify(TestMsg.Ext.DualUseCase.new(a: "s1"))

    assert :ok ==
             Verifier.verify(
               TestMsg.Ext.DualUseCase.new(
                 a: "s1",
                 b: Google.Protobuf.StringValue.new(value: "s2")
               )
             )

    assert {:error, _err} = Verifier.verify(TestMsg.Ext.DualUseCase.new(a: false))
    assert {:error, _err} = Verifier.verify(TestMsg.Ext.DualUseCase.new(a: 123))

    # NOTE: maybe we can phase out the "When extype option is present, new
    # expects unwrapped value, not struct" warning now that we have new_and_verify!
    assert_raise RuntimeError, fn ->
      Verifier.verify(
        TestMsg.Ext.DualUseCase.new(a: Google.Protobuf.StringValue.new(value: "s1"))
      )
    end
  end

  describe "new_and_verify!/1" do
    test "new_and_verify!/1 builds struct" do
      result = TestMsg.Foo.Bar.new_and_verify!(a: 20, b: "test")
      assert result.a == 20
      assert result.b == "test"
    end

    test "raises on invalid value" do
      assert_raise Protobuf.VerificationError, fn ->
        TestMsg.Foo.new_and_verify!(j: :invalid_value)
      end
    end
  end
end
