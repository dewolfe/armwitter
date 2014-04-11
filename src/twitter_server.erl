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
-export([start_link/0, request_token/1, statuses_update/3, subscribe_to_term/1, get_token/3,params_to_string/1]).

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




request_token(Callback) ->
  gen_server:call(?MODULE, {call_request_token, Callback}, 50000).

get_token(Token, Secret, Pin) ->
  gen_server:call(?MODULE, {call_get_token, Token, Secret, Pin}, 50000).

subscribe_to_term(Term) ->
  gen_server:call(?MODULE, {call_subscribe_to_term, Term}, 50000).

statuses_update(#status_update{}=Params, Token, Secret) ->
  gen_server:call(?MODULE, {call_statuses_update, Params, Token, Secret}, 50000).


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


handle_call({call_request_token, Callback}, _From, State) ->
  Url = ?REQUESTTOKEN,
  {ok, Oauth_load} = load_settings(),
  {ok, TimeStamp, Once} = get_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_callback = Callback, oauth_token_secret = "", oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = build_oath_call(Oauth_setting, [], Url),
  io:format("O string is ~s~n", [Oauth_hstring]),
  {ok, {{Version, Code, ReasonPhrase}, Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "application/json"}, {"User-Agent", "Doms123"},
    {"Content-Type", "text/html; charset=utf-8"}], [], []},
    [{autoredirect, false}, {relaxed, true}], []),
  io:format("Rsponse is ~s~n", [Body]),

  case Code of
    200 ->
      Res = string:tokens(Body, "&"),
      Oauth_rtoken = string:substr(lists:nth(1, Res), string:str(lists:nth(1, Res), "=") + 1),
      Oauth_rtoken_secret = string:substr(lists:nth(2, Res), string:str(lists:nth(2, Res), "=") + 1),
      io:format("oauth_token=~s~n", [Oauth_rtoken]),
      ReturnUrl = "https://api.twitter.com/oauth/authenticate?oauth_token=" ++ Oauth_rtoken,
      {reply, {ok, {ReturnUrl, Oauth_rtoken, Oauth_rtoken_secret}}, State};
    _ ->
      {reply, {error, Body}, State}
  end;

handle_call({call_get_token, Token, Secret, Pin}, _From, State) ->
  Url = ?ACCESSTOKEN,
  Params = "oauth_verifier=" ++ Pin,
  {ok, Oauth_load} = load_settings(),
  {ok, TimeStamp, Once} = get_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_token = Token, oauth_token_secret = Secret, oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = build_oath_call(Oauth_setting, Params, Url),
  io:format("O string is: ~s~n", [Oauth_hstring]),
  {ok, {{Version, Code, ReasonPhrase}, Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"},
    {"User-Agent", "inets"}, {"Content-Type", "text/html; charset=utf-8"}],
    "application/x-www-form-urlencoded", Params}, [], []),
  case Code of
    200 ->
      Res = string:tokens(Body, "&"),
      Oauth_rtoken = string:substr(lists:nth(1, Res), string:str(lists:nth(1, Res), "=") + 1),
      Oauth_rtoken_secret = string:substr(lists:nth(2, Res), string:str(lists:nth(2, Res), "=") + 1),
      User_id = string:substr(lists:nth(3, Res), string:str(lists:nth(3, Res), "=") + 1),
      {reply, {ok, {Oauth_rtoken, Oauth_rtoken_secret, User_id}}, State};
    _ ->
      {reply, {error, Body}, State}
  end;

handle_call({call_subscribe_to_term, Term}, _From, State) ->
  spawn(fun() -> subscription(Term) end),
  {reply, ok, State};

handle_call({call_statuses_update, Params, Token, Secret}, _From, State) ->
  Url = ?STATUSUPDATE,

  [params_to_string(P)||P <- Params],
  {ok, Oauth_load} = load_settings(),
  {ok, TimeStamp, Once} = get_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_token = Token, oauth_token_secret = Secret, oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = build_oath_call(Oauth_setting, Params, Url),
  {ok, {{Version, Code, ReasonPhrase}, Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"}, {"User-Agent", "inets"},
    {"Content-Type", "text/html; charset=utf-8"}],
    "application/x-www-form-urlencoded", Params},
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


build_oath_call(#oauth{} = OauthParams, Params, Url) ->
  Url_en = http_uri:encode(Url),

  {ok, Param_string} = build_oauth_string(OauthParams, Params),
  io:format("Params String is: ~s~n", [Param_string]),
  Signature_base_string = string:join(["POST&", Url_en, "&", http_uri:encode(Param_string)], ""),
  Sign_key = string:join([http_uri:encode(OauthParams#oauth.oauth_api_secret), http_uri:encode(OauthParams#oauth.oauth_token_secret)], "&"),
  OAuth_signature = base64:encode_to_string(crypto:sha_mac(Sign_key, Signature_base_string)),
  Oauth_hstring = "OAuth oauth_callback=\"" ++ http_uri:encode(OauthParams#oauth.oauth_callback) ++ "\", " ++
    "oauth_consumer_key=\"" ++ http_uri:encode(OauthParams#oauth.oauth_consumer_key) ++ "\", " ++
    "oauth_nonce=\"" ++ http_uri:encode(OauthParams#oauth.oauth_nonce) ++ "\", " ++
    "oauth_signature=\"" ++ http_uri:encode(OAuth_signature) ++ "\", " ++
    "oauth_signature_method=\"" ++ http_uri:encode(OauthParams#oauth.oauth_signature_method) ++ "\", " ++
    "oauth_timestamp=\"" ++ http_uri:encode(OauthParams#oauth.oauth_timestamp) ++ "\", " ++
    "oauth_token=\"" ++ http_uri:encode(OauthParams#oauth.oauth_token) ++ "\", " ++
    "oauth_version=\"" ++ http_uri:encode(OauthParams#oauth.oauth_version) ++ "\"",
  {ok, Oauth_hstring}.

build_oauth_string(#oauth{oauth_callback = []} = OauthParams, Params) ->
  Param_string = string:join([
      "oauth_callback=" ++ OauthParams#oauth.oauth_callback,
      "oauth_consumer_key=" ++ OauthParams#oauth.oauth_consumer_key,
      "oauth_nonce=" ++ OauthParams#oauth.oauth_nonce,
      "oauth_signature_method=" ++ OauthParams#oauth.oauth_signature_method,
      "oauth_timestamp=" ++ OauthParams#oauth.oauth_timestamp,
      "oauth_token=" ++ OauthParams#oauth.oauth_token,
      "oauth_version=" ++ OauthParams#oauth.oauth_version,
    Params], "&"),
  {ok, Param_string};

build_oauth_string(#oauth{} = OauthParams, []) ->
  Param_string = string:join([
      "oauth_callback=" ++ OauthParams#oauth.oauth_callback,
      "oauth_consumer_key=" ++ OauthParams#oauth.oauth_consumer_key,
      "oauth_nonce=" ++ OauthParams#oauth.oauth_nonce,
      "oauth_signature_method=" ++ OauthParams#oauth.oauth_signature_method,
      "oauth_timestamp=" ++ OauthParams#oauth.oauth_timestamp,
      "oauth_token=" ++ OauthParams#oauth.oauth_token,
      "oauth_version=" ++ OauthParams#oauth.oauth_version], "&"),
  {ok, Param_string}.



load_settings() ->
  {ok, Settings} = file:consult('twitter.config'),
  Oauth_consumer_key = proplists:get_value(api_key, Settings),
  Oauth_token = proplists:get_value(access_token, Settings),
  Oauth_api_secret = proplists:get_value(api_secret, Settings),
  Oauth_token_secret = proplists:get_value(access_token_secret, Settings),
  OauthParams = #oauth{oauth_consumer_key = Oauth_consumer_key,
    oauth_token = Oauth_token,
    oauth_api_secret = Oauth_api_secret,
    oauth_token_secret = Oauth_token_secret},
  {ok, OauthParams}.

get_random_string(Length, AllowedChars) ->
  lists:foldl(fun(_, Acc) ->
    [lists:nth(random:uniform(length(AllowedChars)),
      AllowedChars)]
    ++ Acc
  end, [], lists:seq(1, Length)).

receive_chunk(RequestId) ->
  receive
    {http, {RequestId, {error, Reason}}} when (Reason =:= etimedout) orelse (Reason =:= timeout) ->
      io:format("thiss"),
      {error, timeout};
    {http, {RequestId, {{_, 401, _} = Status, Headers, _}}} ->
      io:format("unauthroized~n"),
      timer:sleep(8000);


    {http, {RequestId, Result}} ->
      io:format("fucking erroer ~p~n", [Result]),
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
      io:format("Streaming data end ~p ~n", [Headers]),
      {ok, RequestId};

%% timeout
    _ ->
      io:format("dont know what the fuck we got"),
      receive_chunk(RequestId)
  end.

params_to_string(Param) ->
  {K,V}=Param,
  atom_to_list(K)++"="++V.

get_text(Data) ->
  Decoded = mochijson2:decode(Data),
  {struct, Jdata} = Decoded,
  Text = proplists:get_value(<<"text">>, Jdata, <<"Nada~n">>),
  file:write_file("/home/dewolfe/Dropbox/Erlang/armwitter/log/test.txt", binary_to_list(Text)).

get_time_once() ->
  TimeStamp = integer_to_list(calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(now())) - 719528 * 24 * 3600),
  Once = get_random_string(32, "qwertyQWERTASDFASEasdfsdfg123456798"),
  {ok, TimeStamp, Once}.