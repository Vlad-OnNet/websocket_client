-module(echo_server).

% -behaviour(cowboy_websocket_handler).

-export([
         start/0,
         stop/0
        ]).

-export([
         init/2,
         websocket_init/3,
         websocket_handle/2,
         websocket_info/2,
         websocket_terminate/2
        ]).

-record(state, {}).

start() ->
    ct:pal("Starting ~p.~n", [?MODULE]),
    Dispatch = cowboy_router:compile([{'_', [
                                             {"/hello", ?MODULE, []},
                                             {'_', ?MODULE, []}
                                            ]}]),
    {ok, _} = cowboy:start_clear(echo_listener, [
                                                 {nodelay, true},
                                                 {port, 8080},
                                                 {max_connections, 100}
                                                ],
                                 #{env => #{dispatch => Dispatch}}).

stop() ->
    cowboy:stop_listener(echo_listener).

init(Req, Opts) ->
    {cowboy_websocket, Req, Opts}.

websocket_init(_Transport, Req, _Opts) ->
    case cowboy_req:qs_val(<<"code">>, Req) of
        {undefined, Req2} ->
            case cowboy_req:qs_val(<<"q">>, Req2) of
                {undefined, Req3} ->
                    {ok, Req3, #state{}};
                {Text, Req3} ->
                    self() ! {send, Text},
                    {ok, Req3, #state{}}
            end;
        {Code, Req2} ->
            IntegerCode = list_to_integer(binary_to_list(Code)),
            ct:pal("~p shuting down on init using '~p' status code~n", [?MODULE, IntegerCode]),
            {ok, Req3} = cowboy_req:reply(IntegerCode, Req2),
            {shutdown, Req3}
    end.

websocket_handle({ping, Payload}=_Frame, State) ->
    ct:pal("~p pingpong with size ~p~n", [?MODULE, byte_size(Payload)]),
    {ok, State};
websocket_handle({Type, Payload}=Frame, State) ->
    ct:pal("~p replying with ~p of size ~p~n", [?MODULE, Type, byte_size(Payload)]),
    {reply, Frame, State}.

websocket_info({send, Text}, State) ->
    timer:sleep(1),
    ct:pal("~p sent frame of size ~p ~n", [?MODULE, byte_size(Text)]),
    {reply, {text, Text}, State};

websocket_info(_Msg, State) ->
    ct:pal("~p received OoB msg: ~p~n", [?MODULE, _Msg]),
    {ok, State}.

websocket_terminate(Reason, _State) ->
    ct:pal("~p terminating with reason ~p~n", [?MODULE, Reason]),
    ok.
