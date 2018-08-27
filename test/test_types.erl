%%
%% Autogenerated by Thrift Compiler (0.10.0)
%%
%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
%%

-module(test_types).

-include("test_types.hrl").

-export([struct_info/1, struct_info_ext/1, enum_info/1, enum_names/0, struct_names/0, exception_names/0]).

struct_info('AllTypes') ->
  {struct, [{1, bool},
          {2, byte},
          {6, i16},
          {5, i32},
          {4, i64},
          {3, double},
          {7, string},
          {8, {list, i32}},
          {9, {set, string}},
          {10, {map, string, i32}},
          {11, {list, bool}},
          {12, {list, byte}},
          {13, {list, double}},
          {14, {list, string}}]}
;

struct_info('Integers') ->
  {struct, [{1, i32},
          {2, {list, i32}},
          {3, {set, i32}}]}
;

struct_info('Container') ->
  {struct, [{1, i32},
          {2, {struct, {'test_types', 'Integers'}}},
          {3, i32}]}
;

struct_info('MissingFields') ->
  {struct, [{1, i32},
          {3, i32},
          {5, double},
          {7, {list, i32}},
          {9, string},
          {10, {struct, {'test_types', 'AllTypes'}}},
          {12, bool},
          {14, {map, string, {struct, {'test_types', 'Container'}}}},
          {15, byte},
          {100, bool},
          {200, byte},
          {16, byte}]}
;

struct_info('SimpleException') ->
  {struct, [{1, string},
          {2, i32}]}
;

struct_info('UnusedException') ->
  {struct, [{1, bool}]}
;

struct_info(_) -> erlang:error(function_clause).

struct_info_ext('AllTypes') ->
  {struct, [{1, optional, bool, 'bool_field', undefined},
          {2, optional, byte, 'byte_field', undefined},
          {6, optional, i16, 'i16_field', undefined},
          {5, optional, i32, 'i32_field', undefined},
          {4, optional, i64, 'i64_field', undefined},
          {3, optional, double, 'double_field', undefined},
          {7, optional, string, 'string_field', undefined},
          {8, optional, {list, i32}, 'int_list', []},
          {9, optional, {set, string}, 'string_set', sets:new()},
          {10, optional, {map, string, i32}, 'string_int_map', dict:new()},
          {11, optional, {list, bool}, 'bool_list', []},
          {12, optional, {list, byte}, 'byte_list', []},
          {13, optional, {list, double}, 'double_list', []},
          {14, optional, {list, string}, 'string_list', []}]}
;

struct_info_ext('Integers') ->
  {struct, [{1, undefined, i32, 'int_field', undefined},
          {2, undefined, {list, i32}, 'int_list', []},
          {3, undefined, {set, i32}, 'int_set', sets:new()}]}
;

struct_info_ext('Container') ->
  {struct, [{1, undefined, i32, 'first_field', undefined},
          {2, undefined, {struct, {'test_types', 'Integers'}}, 'second_struct', #'Integers'{}},
          {3, undefined, i32, 'third_field', undefined}]}
;

struct_info_ext('MissingFields') ->
  {struct, [{1, optional, i32, 'first', undefined},
          {3, optional, i32, 'second_skip', undefined},
          {5, optional, double, 'third', undefined},
          {7, optional, {list, i32}, 'fourth_skip', []},
          {9, optional, string, 'fifth', undefined},
          {10, optional, {struct, {'test_types', 'AllTypes'}}, 'sixth_skip', #'AllTypes'{}},
          {12, optional, bool, 'seventh', undefined},
          {14, optional, {map, string, {struct, {'test_types', 'Container'}}}, 'eighth_skip', dict:new()},
          {15, optional, byte, 'ninth', undefined},
          {100, optional, bool, 'tenth', undefined},
          {200, optional, byte, 'eleventh_skip', undefined},
          {16, optional, byte, 'twelveth', undefined}]}
;

struct_info_ext('SimpleException') ->
  {struct, [{1, undefined, string, 'message', undefined},
          {2, undefined, i32, 'line_number', undefined}]}
;

struct_info_ext('UnusedException') ->
  {struct, [{1, undefined, bool, 'unused', undefined}]}
;

struct_info_ext(_) -> erlang:error(function_clause).

struct_names() ->
  ['AllTypes', 'Integers', 'Container', 'MissingFields'].

enum_info('ThrowType') ->
  [
    {'NormalReturn', 0},
    {'DeclaredException', 1},
    {'UndeclaredException', 2},
    {'Error', 3},
    {'BadThrow', 4}
  ];

enum_info('MapRet') ->
  [
    {'ReturnDict', 0},
    {'ReturnProplist', 1},
    {'ReturnMap', 2}
  ];

enum_info(_) -> erlang:error(function_clause).

enum_names() ->
  ['ThrowType', 'MapRet'].

exception_names() ->
  ['SimpleException', 'UnusedException'].

