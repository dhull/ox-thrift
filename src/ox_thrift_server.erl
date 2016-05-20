-module(ox_thrift_server).

-include("ox_thrift.hrl").
-include("ox_thrift_internal.hrl").

-behaviour(ranch_protocol).

-export([ start_link/4, handle_request/2 ]).
-export([ init/4 ]).
-export([ parse_config/1 ]). %% Exported for unit tests.

-record(ts_state, {
          socket,
          transport,
          config :: #ts_config{},
          call_count = 0 :: non_neg_integer(),
          connect_time = os:timestamp() :: erlang:timestamp() }).


-type reply_options() :: 'undefined' | 'close'.

-callback handle_function(Function::atom(), Args::list()) ->
  'ok' | {'reply', Reply::term()} | {ok, reply_options()} | {'reply', Reply::term(), reply_options()}.

-callback handle_error(Function::atom(), Reason::term()) -> Ignored::term().


-define(RECV_TIMEOUT, infinity).

start_link (Ref, Socket, Transport, Opts) ->
  Pid = spawn_link(?MODULE, init, [ Ref, Socket, Transport, Opts ]),
  {ok, Pid}.


init (Ref, Socket, Transport, Config) ->
  ?LOG("ox_thrift_server:init ~p ~p ~p ~p\n", [ Ref, Socket, Transport, Config ]),
  ok = ranch:accept_ack(Ref),

  TSConfig = parse_config(Config),

  loop(#ts_state{socket = Socket, transport = Transport, config = TSConfig}).


-spec parse_config(#ox_thrift_config{}) -> #ts_config{}.
parse_config (#ox_thrift_config{service_module=ServiceModule, codec_module=CodecModule, handler_module=HandlerModule, options=Options}) ->
  Config0 = #ts_config{
               service_module = ServiceModule,
               codec_module = CodecModule,
               handler_module = HandlerModule},
  parse_options(Options, Config0).


parse_options ([ {stats_module, StatsModule} | Options ], Config) when is_atom(StatsModule) ->
  parse_options(Options, Config#ts_config{stats_module = StatsModule});
parse_options ([], Config) ->
  Config.


loop (State=#ts_state{socket=Socket, transport=Transport}) ->
  %% Implement thrift_framed_transport.

  %% Read the length, and then the request data.
  %% Result0 will be `{ok, Packet}' or `{error, Reason}'.
  case Transport:recv(Socket, 4, ?RECV_TIMEOUT) of
    {ok, LengthBin} ->
      <<Length:32/integer-signed-big>> = LengthBin,
      loop1(State#ts_state{call_count = State#ts_state.call_count + 1}, Length);
    {error, Reason} ->
      handle_error(State, undefined, Reason)
      %% Return from loop on error.
  end.

loop1 (State=#ts_state{socket=Socket, transport=Transport}, Length) ->
  RecvResult = Transport:recv(Socket, Length, ?RECV_TIMEOUT),
  ?LOG("server recv(~p, ~p) -> ~p\n", [ Socket, Length, RecvResult ]),
  case RecvResult of
    {ok, RequestData} ->
      loop2(State, RequestData);
    {error, Reason} ->
      handle_error(State, undefined, Reason)
      %% Return from loop on error.
  end.

loop2 (State=#ts_state{socket=Socket, transport=Transport, config=Config}, RequestData) ->
  {ReplyData, Function, ReplyOptions} = handle_request(Config, RequestData),
  case ReplyData of
    noreply ->
      %% Oneway void function.
      loop3(State, Function, ReplyOptions);
    _ ->
      %% Normal function.
      ReplyLen = iolist_size(ReplyData),
      Reply = [ <<ReplyLen:32/big-signed>>, ReplyData ],
      SendResult = Transport:send(Socket, Reply),
      ?LOG("server send(~p, ~p) -> ~p\n", [ Socket, Reply, SendResult ]),
      case SendResult of
        ok ->
          loop3(State, Function, ReplyOptions);
        {error, Reason} ->
          handle_error(State, Function, Reason)
          %% Return from loop on error.
      end
  end.

loop3 (State, Function, ReplyOptions) ->
  case ReplyOptions of
    undefined ->
      loop(State);
    close ->
      handle_error(State, Function, closed)
      %% Return from loop when server requests close.
  end.


-spec handle_request(Config::#ts_config{}, RequestData::binary()) -> {Reply::iolist()|'noreply', Function::atom(), ReplyOptions::reply_options()}.
handle_request (Config=#ts_config{handler_module=HandlerModule}, RequestData) ->
  %% Should do a try block around decode_message. @@
  {Function, CallType, SeqId, Args} = decode(Config, RequestData),

  {ResultMsg, ReplyOptions} =
    try
      ?LOG("call ~p:handle_function(~p, ~p)\n", [ HandlerModule, Function, Args ]),
      Result = HandlerModule:handle_function(Function, Args),
      ?LOG("result ~p ~p\n", [ CallType, Result ]),
      {Reply, ReplyOptions0} = reply_options(Result),
      R = case {CallType, Reply} of
            {call, Reply}            -> encode(Config, Function, reply_normal, SeqId, Reply);
            {call_oneway, undefined} -> noreply
          end,
      {R, ReplyOptions0}
    catch
      throw:Reason ->
        {encode(Config, Function, reply_exception, SeqId, Reason), undefined};
      error:Reason ->
        Message = ox_thrift_util:format_error_message(Reason),
        ExceptionReply = #application_exception{message = Message, type = ?tApplicationException_UNKNOWN},
        {encode(Config, Function, exception, SeqId, ExceptionReply), undefined}
    end,

  %% ?LOG("handle_request -> ~p\n", [ {ResultMsg, Function } ]),
  {ResultMsg, Function, ReplyOptions}.


reply_options ({reply, Reply})          -> {Reply, undefined};
reply_options (ok)                      -> {undefined, undefined};
reply_options ({reply, Reply, Options}) -> {Reply, Options};
reply_options ({ok, Options})           -> {undefined, Options}.


handle_error (State=#ts_state{socket=Socket, transport=Transport, config=#ts_config{handler_module=HandlerModule, stats_module=StatsModule}}, Function, Reason) ->
  StatsModule =/= undefined andalso
    begin
      StatsModule:handle_stat(Function, connect_time, timer:now_diff(os:timestamp(), State#ts_state.connect_time)),
      StatsModule:handle_stat(Function, call_count, State#ts_state.call_count)
    end,
  HandlerModule:handle_error(Function, Reason),
  Transport:close(Socket).


decode(#ts_config{service_module=ServiceModule, codec_module=CodecModule, stats_module=undefined}, RequestData) ->
  %% Decode, not collecting stats.
  CodecModule:decode_message(ServiceModule, RequestData);
decode(#ts_config{service_module=ServiceModule, codec_module=CodecModule, stats_module=StatsModule}, RequestData) ->
  %% Decode, collecting stats.
  {Elapsed, Result} = timer:tc(CodecModule, decode_message, [ ServiceModule, RequestData ]),
  Function = element(1, Result),
  StatsModule:handle_stat(Function, decode_time, Elapsed),
  Result.


encode(#ts_config{service_module=ServiceModule, codec_module=CodecModule, stats_module=undefined}, Function, MessageType, SeqId, Args) ->
  %% Encode, not collecting stats.
  CodecModule:encode_message(ServiceModule, Function, MessageType, SeqId, Args);
encode(#ts_config{service_module=ServiceModule, codec_module=CodecModule, stats_module=StatsModule}, Function, MessageType, SeqId, Args) ->
  %% Encode, collecting stats.
  {Elapsed, Result} = timer:tc(CodecModule, encode_message, [ ServiceModule, Function, MessageType, SeqId, Args ]),
  StatsModule:handle_stat(Function, encode_time, Elapsed),
  Result.
