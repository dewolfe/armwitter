%%%-------------------------------------------------------------------
%%% @author Dominic DeWolfe
%%% @doc
%%%
%%% @end
%%% Created : 10. Apr 2014 12:42 PM
%%%-------------------------------------------------------------------
-module(twitter_server).
-author("dewolfe").
-include("awr.hrl").
-behaviour(gen_server).

%% API
-export([start_link/0, statuses_update/3,
  subscribe_to_term/1, params_to_string/1,
  statuses_mentions_timeline/3]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).
-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
subscribe_to_term(Term) ->
  gen_server:call(?MODULE, {call_subscribe_to_term, Term}, 50000).

-spec statuses_update(Params :: list(), Token :: list(), Secret :: list()) -> {atom(), list()}.

statuses_update(Params, Token, Secret) ->
  gen_server:call(?MODULE, {call_statuses_update, Params, Token, Secret}, 50000).

statuses_mentions_timeline(Params, Token, Secret) ->
  gen_server:call(?MODULE, {call_statuses_mentions_timeline, Params, Token, Secret}, 50000).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, State :: #state{}} | {ok, State :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term()} | ignore).
init([]) ->

  {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #state{}) ->
  {reply, Reply :: term(), NewState :: #state{}} |
  {reply, Reply :: term(), NewState :: #state{}, timeout() | hibernate} |
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), Reply :: term(), NewState :: #state{}} |
  {stop, Reason :: term(), NewState :: #state{}}).





handle_call({call_subscribe_to_term, Term}, _From, State) ->
  spawn(fun() -> subscription(Term) end),
  {reply, ok, State};

handle_call({call_statuses_update, Params, Token, Secret}, _From, State) ->
  Url = ?STATUSUPDATE,
  Params_string = string:join([params_to_string(P) || P <- Params], "&"),
  {ok, Oauth_load} = oauth_server:load_settings(),
  {ok, TimeStamp, Once} = oauth_server:get_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_token = Token, oauth_token_secret = Secret, oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = oauth_server:get_oauth_string(Oauth_setting, Params_string, Url),
  {ok, {{_Version, Code, _ReasonPhrase}, _Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"}, {"User-Agent", "inets"},
    {"Content-Type", "text/html; charset=utf-8"}],
    "application/x-www-form-urlencoded", Params_string},
    [{autoredirect, false}, {relaxed, true}], []),
  case Code of
    200 ->
      {reply, {ok, Body}, State};
    _ ->
      {reply, {error, Body}, State}

  end;
handle_call({call_statuses_mentions_timeline, Params, Token, Secret}, _Form, State) ->
  Url = ?MENTIONS,
  Params_string = string:join([params_to_string(P) || P <- Params], "&"),
  {ok, Oauth_load} = oauth_server:load_settings(),
  {ok, TimeStamp, Once} = oauth_server:get_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_http_method = "GET", oauth_token = Token, oauth_token_secret = Secret, oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = oauth_server:get_oauth_string(Oauth_setting, Params_string, Url),
  {ok, {{_Version, Code, _ReasonPhrase}, _Headers, Body}} = httpc:request(get, {Url ++ "?" ++ Params_string, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"}, {"User-Agent", "inets"},
    {"Content-Type", "text/html; charset=utf-8"}]},
    [{autoredirect, false}, {relaxed, true}], []),
  case Code of
    200 ->
      {reply, {ok, Body}, State};
    _ ->
      {reply, {error, Body}, State}

  end.
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_cast(_Request, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #state{}) ->
  {noreply, NewState :: #state{}} |
  {noreply, NewState :: #state{}, timeout() | hibernate} |
  {stop, Reason :: term(), NewState :: #state{}}).
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #state{}) -> term()).
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #state{},
    Extra :: term()) ->
  {ok, NewState :: #state{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


subscription(Term) ->
%%   Url = "https://stream.twitter.com/1.1/statuses/filter.json",
%%   Params = "track=" ++ Term,
%%   {ok, {Oauth_hstring}} = build_oath_call(Url, Params),
%%   io:format("Oauth_hstring = ~s~n", [Oauth_hstring]),
%%   case httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"}, {"User-Agent", "Doms123"}, {"Content-Type", "text/html; charset=utf-8"}], "application/x-www-form-urlencoded", Params}, [{autoredirect, false}, {relaxed, true}], [{sync, false}, {stream, self}]) of
%%     {ok, RequestId} ->
%%       io:format("starting~n"),
%%       receive_chunk(RequestId);
%%     _ ->
%%       io:format("no work good ~n")
%%   end.
  {ok}.




receive_chunk(RequestId) ->
  receive
    {http, {RequestId, {error, Reason}}} when (Reason =:= etimedout) orelse (Reason =:= timeout) ->
      {error, timeout};
    {http, {RequestId, {{_, 401, _} = Status, Headers, _}}} ->
      io:format("unauthroized~n"),
      timer:sleep(8000);


    {http, {RequestId, Result}} ->
      {error, Result};

    {http, {RequestId, stream_start, Headers}} ->
      io:format("Streaming data start ~p ~n", [Headers]),
      receive_chunk(RequestId);

    {http, {RequestId, stream, Data}} ->
      if
        Data /= <<"\r\n">> ->
          get_text(Data);


        true ->
          receive_chunk(RequestId)
      end,
      receive_chunk(RequestId);

%% end of streaming data
    {http, {RequestId, stream_end, Headers}} ->
      {ok, RequestId};

%% timeout
    _ ->
      receive_chunk(RequestId)
  end.

params_to_string(Param) ->
  {K, V} = Param,
  atom_to_list(K) ++ "=" ++ http_uri:encode(V).

get_text(Data) ->
  Decoded = mochijson2:decode(Data),
  {struct, Jdata} = Decoded,
  Text = proplists:get_value(<<"text">>, Jdata, <<"Nada~n">>),
  file:write_file("/home/dewolfe/Dropbox/Erlang/armwitter/log/test.txt", binary_to_list(Text)).

