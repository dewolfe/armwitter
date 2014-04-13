%%%-------------------------------------------------------------------
%%% @author Dominic DeWolfe
%%% @copyright (C) 2014, Painted Turtle Software
%%% @doc
%%%
%%% @end
%%% Created : 13. Apr 2014 10:30 AM
%%%-------------------------------------------------------------------
-author("Dominic DeWolfe").

-include_lib("eunit/include/eunit.hrl").

params_to_string_test() ->
  A=[{key1,"value1"},{key2,"value2"}],
  ?assert(twitter_server:params_to_string(A) =:=  "key1=value1&key2=value2").

length_test() -> ?assert(length([1,2,3]) =:= 3).
