%% Copyright 2016, OpenX.  All rights reserved.
%% Licensed under the conditions specified in the accompanying LICENSE file.

-module(ox_thrift_protocol_binary).

-include("ox_thrift_internal.hrl").

-export([ encode_call/4, encode_message/5, decode_message/2 ]).

-export([ encode_record/2, decode_record/2 ]).

-include("ox_thrift_protocol.hrl").

-compile({inline, [ write_message_begin/3
                  , write_field_begin/2
                  , write_field_stop/0
                  , write_map_begin/3
                  , write_list_or_set_begin/2
                  , write/2
                  , read_message_begin/1
                  , read_field_begin/1
                  , read_map_begin/1
                  , read_list_or_set_begin/1
                  , read/2 ]}).
%% -compile(inline_list_funcs).

-define(TYPE_BIN_STOP, 0).
-define(TYPE_BIN_VOID, 1).
-define(TYPE_BIN_BOOL, 2).
-define(TYPE_BIN_BYTE, 3).
-define(TYPE_BIN_DOUBLE, 4).
-define(TYPE_BIN_I16, 6).
-define(TYPE_BIN_I32, 8).
-define(TYPE_BIN_I64, 10).
-define(TYPE_BIN_STRING, 11).
-define(TYPE_BIN_STRUCT, 12).
-define(TYPE_BIN_MAP, 13).
-define(TYPE_BIN_SET, 14).
-define(TYPE_BIN_LIST, 15).

%% term_to_wire(field_stop)     -> ?TYPE_BIN_STOP;
term_to_wire(bool)              -> ?TYPE_BIN_BOOL;
term_to_wire(byte)              -> ?TYPE_BIN_BYTE;
term_to_wire(double)            -> ?TYPE_BIN_DOUBLE;
term_to_wire(i16)               -> ?TYPE_BIN_I16;
term_to_wire(i32)               -> ?TYPE_BIN_I32;
term_to_wire(i64)               -> ?TYPE_BIN_I64;
term_to_wire(string)            -> ?TYPE_BIN_STRING;
term_to_wire(struct)            -> ?TYPE_BIN_STRUCT;
term_to_wire(map)               -> ?TYPE_BIN_MAP;
term_to_wire(set)               -> ?TYPE_BIN_SET;
term_to_wire(list)              -> ?TYPE_BIN_LIST.

%% wire_to_term(?TYPE_BIN_STOP) -> field_stop;
wire_to_term(?TYPE_BIN_BOOL)    -> bool;
wire_to_term(?TYPE_BIN_BYTE)    -> byte;
wire_to_term(?TYPE_BIN_DOUBLE)  -> double;
wire_to_term(?TYPE_BIN_I16)     -> i16;
wire_to_term(?TYPE_BIN_I32)     -> i32;
wire_to_term(?TYPE_BIN_I64)     -> i64;
wire_to_term(?TYPE_BIN_STRING)  -> string;
wire_to_term(?TYPE_BIN_STRUCT)  -> struct;
wire_to_term(?TYPE_BIN_MAP)     -> map;
wire_to_term(?TYPE_BIN_SET)     -> set;
wire_to_term(?TYPE_BIN_LIST)    -> list.

%% -define(DEBUG_READ, true).

%% There is an asymmetry to the `write/1' and `read/2' interfaces.  `write/1'
%% returns an iolist for the converted data, which is expected to be
%% integrated into a larger iolist for the entire message, while `read/2'
%% parses the data from a binary buffer and returns the parsed data and the
%% remaining buffer.

-define(VERSION_0, <<0, 0>>).
-define(VERSION_1, <<16#80, 16#01>>).

write_message_begin (Name, Type, SeqId) ->
  %% Write a version 1 message header.
  NameLen = size(Name),
  <<?VERSION_1/binary, 0, Type, NameLen:32/big-signed, Name/binary, SeqId:32/big-signed>>.

write_field_begin (Type, Id) ->
  TypeWire = term_to_wire(Type),
  <<TypeWire:8/big-signed, Id:16/big-signed>>.

write_field_stop () ->
  ?TYPE_BIN_STOP.

write_map_begin (KType, VType, Size) ->
  KTypeWire = term_to_wire(KType),
  VTypeWire = term_to_wire(VType),
  <<KTypeWire:8/big-signed, VTypeWire:8/big-signed, Size:32/big-signed>>.

write_list_or_set_begin (EType, Size) ->
  ETypeWire = term_to_wire(EType),
  <<ETypeWire:8/big-signed, Size:32/big-signed>>.


write (bool, true) ->
  1;

write (bool, false) ->
  0;

write (byte, Byte) ->
  <<Byte:8/big-signed>>;

write (i16, I16) ->
  <<I16:16/big-signed>>;

write (i32, I32) ->
  <<I32:32/big-signed>>;

write (i64, I64) ->
  <<I64:64/big-signed>>;

write (double, Double) ->
  <<Double:64/big-signed-float>>;

write (string, Str) when is_list(Str) ->
  Bin = list_to_binary(Str),
  BinLen = size(Bin),
  [ <<BinLen:32/big-signed>>, Bin ];

write (string, Bin) when is_binary(Bin) ->
  BinLen = size(Bin),
  [ <<BinLen:32/big-signed>>, Bin ].


-ifdef(DEBUG_READ).
read(DataIn, Type) ->
  io:format("read(~p, ~p) ->\n", [ DataIn, Type ]),
  Ret = {DataOut, Val} = read_real(DataIn, Type),
  io:format("  {~p, ~p}\n", [ DataOut, Val ]),
  Ret.
-define(READ, read_real).
-else. %% ! DEBUG_READ
-define(READ, read).
-endif. %% ! DEBUG_READ


-spec read_message_begin(IData::binary()) -> {OData::binary(), Name::binary(), Type::integer(), SeqId::integer()}.
read_message_begin (Data0) ->
  Version = binary_part(Data0, {0, 2}),
  case Version of
    ?VERSION_1 ->
      <<_:3/binary, Type, NameSize:32/big-signed, Name:NameSize/binary, SeqId:32/big-signed, Data1/binary>> = Data0,
      {Data1, Name, Type, SeqId};
    ?VERSION_0 ->
      %% No version header; read the old way.
      <<_:2/binary, NameSize:16/big-signed, Name:NameSize/binary, Type, SeqId:32/big-signed, Data1/binary>> = Data0,
      {Data1, Name, Type, SeqId};
    _  ->
      %% Unexpected version number.
      error({bad_binary_protocol_version, Version})
  end.

-spec read_field_begin (IData::binary()) -> {OData::binary(), Type::proto_type(), Id::integer()}
                                          | {OData::binary(), field_stop, 'undefined'}.
read_field_begin (Data0) ->
  case Data0 of
    <<?TYPE_BIN_STOP:8/big-signed, Data1/binary>>  ->
      {Data1, field_stop, undefined};
    <<Type:8/big-signed, Id:16/big-signed, Data1/binary>> ->
      {Data1, wire_to_term(Type), Id}
  end.

%% This isn't necessary, since we never explicitly read a `field_stop', we
%% just find it when trying to read a `field_begin'.
%%
%% ?READ (field_stop, Data0) ->
%%   {?TYPE_BIN_STOP, Data1} = read(?TYPE_BIN_BYTE, Data0),
%%   {ok, Data1};

-spec read_map_begin(IData::binary()) -> {OData::binary(), KType::proto_type(), VType::proto_type(), Size::integer()}.
read_map_begin (Data0) ->
  <<KType:8/big-signed, VType:8/big-signed, Size:32/big-signed, Data1/binary>> = Data0,
  {Data1, wire_to_term(KType), wire_to_term(VType), Size}.

-spec read_list_or_set_begin(IData::binary()) -> {OData::binary(), EType::proto_type(), Size::integer()}.
read_list_or_set_begin (Data0) ->
  <<EType:8/big-signed, Size:32/big-signed, Data1/binary>> = Data0,
  {Data1, wire_to_term(EType), Size}.


?READ (Data0, bool) ->
  <<Bool:8/big-signed, Data1/binary>> = Data0,
  {Data1, Bool =/= 0};

?READ (Data0, byte) ->
  <<Val:8/integer-signed-big, Data1/binary>> = Data0,
  {Data1, Val};

?READ (Data0, i16) ->
  <<Val:16/integer-signed-big, Data1/binary>> = Data0,
  {Data1, Val};

?READ (Data0, i32) ->
  <<Val:32/integer-signed-big, Data1/binary>> = Data0,
  {Data1, Val};

?READ (Data0, i64) ->
  <<Val:64/integer-signed-big, Data1/binary>> = Data0,
  {Data1, Val};

?READ (Data0, double) ->
  <<Val:64/float-signed-big, Data1/binary>> = Data0,
  {Data1, Val};

?READ (Data0, string) ->
  <<Size:32/big-signed, String:Size/binary, Data1/binary>> = Data0,
  {Data1, String}.


%% -spec read_data(DataIn::binary(), Size::non_neg_integer()) -> {DataOut::binary(), Value::binary()}.
%% read_data (Data0, Size) ->
%%   case Size of
%%     0 -> {Data0, <<>>};
%%     _ -> <<Val:Size/binary, Data1/binary>> = Data0,
%%          {Data1, Val}
%%   end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-ifdef(EUNIT).

message_test () ->
  Name = <<"test">>,
  NameLen = size(Name),
  Type = ?tMessageType_CALL,
  SeqId = 16#7FFFFFF0,
  ?assertEqual({<<>>, Name, Type, SeqId},
               read_message_begin(iolist_to_binary(write_message_begin(Name, Type, SeqId)))),

  %% New-style message header.
  ?assertEqual({<<>>, Name, Type, SeqId},
               read_message_begin(<<?VERSION_1/binary, 0, Type, NameLen:32/big, Name/binary, SeqId:32/big>>)),

  %% Old-style message header.
  ?assertEqual({<<>>, Name, Type, SeqId},
               read_message_begin(<<NameLen:32/big, Name/binary, Type, SeqId:32/big>>)).

field_test () ->
  Type = i32,
  Id = 16#7FF0,
  %% Name is not sent in binary protocol.
  ?assertMatch({<<>>, Type, Id}, read_field_begin(iolist_to_binary(write_field_begin(Type, Id)))).

map_test () ->
  KType = byte,
  VType = string,
  Size = 16#7FFFFFF1,
  ?assertEqual({<<>>, KType, VType, Size}, read_map_begin(iolist_to_binary(write_map_begin(KType, VType, Size)))).

list_or_set_test () ->
  EType = byte,
  Size = 16#7FFFFFF2,
  ?assertEqual({<<>>, EType, Size}, read_list_or_set_begin(iolist_to_binary(write_list_or_set_begin(EType, Size)))).

basic_test () ->
  B = 16#7F,
  ?assertEqual({<<>>, B}, read(iolist_to_binary(write(byte, B)), byte)),

  S = 16#7FFF,
  ?assertEqual({<<>>, S}, read(iolist_to_binary(write(i16, S)), i16)),

  I = 16#7FFFFFFF,
  ?assertEqual({<<>>, I}, read(iolist_to_binary(write(i32, I)), i32)),

  F = 1234.25,
  ?assertEqual({<<>>, F}, read(iolist_to_binary(write(double, F)), double)),

  SB = <<"hello, world">>,
  ?assertEqual({<<>>, SB}, read(iolist_to_binary(write(string, SB)), string)),

  SL = "hello, world",
  ?assertEqual({<<>>, SB}, read(iolist_to_binary(write(string, SL)), string)).

-endif. %% EUNIT