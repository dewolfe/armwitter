%%%-------------------------------------------------------------------
%%% @author Dominic DeWolfe
%%% @copyright (C) 2014, Painted Turtle Software
%%% @doc
%%%
%%% @end
%%% Created : 10. Apr 2014 12:42 PM
%%%-------------------------------------------------------------------
-author("Dominic DeWolfe").

-define(REQUESTTOKEN, "https://api.twitter.com/oauth/request_token").
-define(ACCESSTOKEN, "https://api.twitter.com/oauth/access_token").


-record(oauth, {oauth_callback = [],
  oauth_consumer_key = [],
  oauth_nonce = [],
  oauth_signature = [],
  oauth_signature_method = "HMAC-SHA1",
  oauth_timestamp = [],
  oauth_token = [],
  oauth_version = "1.0",
  oauth_api_secret = [],
  oauth_token_secret = []
}
).