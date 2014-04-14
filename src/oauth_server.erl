%%%-------------------------------------------------------------------
%%% @author Dominic DeWolfe
%%% @doc
%%%
%%% @end
%%% Created : 11. Apr 2014 9:29 PM
%%%-------------------------------------------------------------------
-module(oauth_server).
-author("Dominic DeWolfe").
-include("awr.hrl").

-behaviour(gen_server).

%% API
-export([start_link/0, request_token/1, get_token/3, load_settings/0, get_time_once/0, get_oauth_string/3]).

%% gen_server callbacks
-export([init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2,
  code_change/3]).
-ifdef(TEST).
-include("../test/oauth_server_test.hrl").
-endif.
-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================
request_token(Callback) ->
  gen_server:call(?MODULE, {call_request_token, Callback}, 50000).

get_token(Token, Secret, Pin) ->
  gen_server:call(?MODULE, {call_get_token, Token, Secret, Pin}, 50000).

load_settings() ->
  gen_server:call(?MODULE, {call_load_setting}, 50000).

get_time_once() ->
  gen_server:call(?MODULE, {call_get_time_once}, 50000).

get_oauth_string(Oauth_setting, Params, Url) ->
  gen_server:call(?MODULE, {call_get_oauth_string, Oauth_setting, Params, Url}, 50000).


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
  {ok, Oauth_load} = load_config_file(),
  {ok, TimeStamp, Once} = gen_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_callback = Callback, oauth_token_secret = "", oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = build_oauth_call(Oauth_setting, [], Url),
  {ok, {{_Version, Code, _ReasonPhrase}, _Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "application/json"}, {"User-Agent", "Doms123"},
    {"Content-Type", "text/html; charset=utf-8"}], [], []},
    [{autoredirect, false}, {relaxed, true}], []),
  case Code of
    200 ->
      Res = string:tokens(Body, "&"),
      Oauth_rtoken = string:substr(lists:nth(1, Res), string:str(lists:nth(1, Res), "=") + 1),
      Oauth_rtoken_secret = string:substr(lists:nth(2, Res), string:str(lists:nth(2, Res), "=") + 1),
      ReturnUrl = "https://api.twitter.com/oauth/authenticate?oauth_token=" ++ Oauth_rtoken,
      {reply, {ok, {ReturnUrl, Oauth_rtoken, Oauth_rtoken_secret}}, State};
    _ ->
      {reply, {error, Body}, State}
  end;

handle_call({call_get_token, Token, Secret, Pin}, _From, State) ->
  Url = ?ACCESSTOKEN,
  Params = "oauth_verifier=" ++ Pin,
  {ok, Oauth_load} = load_config_file(),
  {ok, TimeStamp, Once} = gen_time_once(),
  Oauth_setting = Oauth_load#oauth{oauth_token = Token, oauth_token_secret = Secret, oauth_timestamp = TimeStamp, oauth_nonce = Once},
  {ok, Oauth_hstring} = build_oauth_call(Oauth_setting, Params, Url),
  {ok, {{_Version, Code, _ReasonPhrase}, _Headers, Body}} = httpc:request(post, {Url, [{"Authorization", Oauth_hstring}, {"Accept", "*/*"},
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

handle_call({call_load_setting}, _From, State) ->
  {reply, load_config_file(), State};

handle_call({call_get_time_once}, _From, State) ->
  {reply, gen_time_once(), State};

handle_call({call_get_oauth_string, Oauth_setting, Params, Url}, _From, State) ->
  {reply, build_oauth_call(Oauth_setting, Params, Url), State}.
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
build_oauth_call(Oauth_setting, Params, Url) ->
  Url_en = http_uri:encode(Url),
  {ok, Param_string} = build_oauth_string(Oauth_setting, Params),
  Signature_base_string = string:join([Oauth_setting#oauth.oauth_http_method, Url_en, http_uri:encode(Param_string)], "&"),
  Sign_key = string:join([http_uri:encode(Oauth_setting#oauth.oauth_api_secret), http_uri:encode(Oauth_setting#oauth.oauth_token_secret)],
    "&"),
  OAuth_signature = base64:encode_to_string(crypto:hmac(sha, Sign_key, Signature_base_string)),
  Oauth_hstring = "OAuth oauth_callback=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_callback) ++ "\", " ++
    "oauth_consumer_key=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_consumer_key) ++ "\", " ++
    "oauth_nonce=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_nonce) ++ "\", " ++
    "oauth_signature=\"" ++ http_uri:encode(OAuth_signature) ++ "\", " ++
    "oauth_signature_method=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_signature_method) ++ "\", " ++
    "oauth_timestamp=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_timestamp) ++ "\", " ++
    "oauth_token=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_token) ++ "\", " ++
    "oauth_version=\"" ++ http_uri:encode(Oauth_setting#oauth.oauth_version) ++ "\"",
  {ok, Oauth_hstring}.

build_oauth_string(#oauth{oauth_http_method = "GET"} = Oauth_setting, Params) ->
  Param_string = string:join([
    Params,
      "oauth_callback=" ++ Oauth_setting#oauth.oauth_callback,
      "oauth_consumer_key=" ++ Oauth_setting#oauth.oauth_consumer_key,
      "oauth_nonce=" ++ Oauth_setting#oauth.oauth_nonce,
      "oauth_signature_method=" ++ Oauth_setting#oauth.oauth_signature_method,
      "oauth_timestamp=" ++ Oauth_setting#oauth.oauth_timestamp,
      "oauth_token=" ++ Oauth_setting#oauth.oauth_token,
      "oauth_version=" ++ Oauth_setting#oauth.oauth_version
  ], "&"),
  {ok, Param_string};

build_oauth_string(#oauth{oauth_callback = []} = Oauth_setting, Params) ->
  Param_string = string:join([
      "oauth_callback=" ++ Oauth_setting#oauth.oauth_callback,
      "oauth_consumer_key=" ++ Oauth_setting#oauth.oauth_consumer_key,
      "oauth_nonce=" ++ Oauth_setting#oauth.oauth_nonce,
      "oauth_signature_method=" ++ Oauth_setting#oauth.oauth_signature_method,
      "oauth_timestamp=" ++ Oauth_setting#oauth.oauth_timestamp,
      "oauth_token=" ++ Oauth_setting#oauth.oauth_token,
      "oauth_version=" ++ Oauth_setting#oauth.oauth_version,
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

load_config_file() ->
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

gen_time_once() ->
  TimeStamp = integer_to_list(calendar:datetime_to_gregorian_seconds(calendar:now_to_universal_time(now())) - 719528 * 24 * 3600),
  Once = get_random_string(32, "qwertyQWERTASDFASEasdfsdfg123456798"),
  {ok, TimeStamp, Once}.

