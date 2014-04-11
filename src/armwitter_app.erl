-module(armwitter_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start(_StartType, _StartArgs) ->
    inets:start(),
    ssl:start(),
    armwitter_sup:start_link().

stop(_State) ->
    ok.
