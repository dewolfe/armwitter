-module(armwitter_sup).

-behaviour(supervisor).

%% API
-export([start_link/0,start_in_shell/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_in_shell()->
  {ok,Pid}=supervisor:start_link({local, ?MODULE}, ?MODULE, _Args=[]),
  unlink(Pid).
%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
  Twitter_server={
    twitter_server,
    {twitter_server,start_link,[]},
    permanent,
    5000,
    worker,
    [twitter_server]},
    {ok, { {one_for_one, 5, 10}, [Twitter_server]} }.

