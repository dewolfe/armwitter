%%%-------------------------------------------------------------------
%%% @author Dominic DeWolfe
%%% @doc
%%%
%%% @end
%%% Created : 10. Apr 2014 12:42 PM
%%%-------------------------------------------------------------------
-author("Dominic DeWolfe").

-define(REQUESTTOKEN, "https://api.twitter.com/oauth/request_token").
-define(ACCESSTOKEN, "https://api.twitter.com/oauth/access_token").
-define(STATUSUPDATE,"https://api.twitter.com/1.1/statuses/update.json" ).
-define(STATUSRETWEETS, "https://api.twitter.com/1.1/statuses/retweets/").
-define(STATUSESDESTROY, "https://api.twitter.com/1.1/statuses/destroy/").
-define(STATUSESSHOW, "https://api.twitter.com/1.1/statuses/show.json").
-define(MENTIONS, "https://api.twitter.com/1.1/statuses/mentions_timeline.json").
-define(USERTIMELINE, "https://api.twitter.com/1.1/statuses/user_timeline.json").
-define(HOMETIMELINE, "https://api.twitter.com/1.1/statuses/home_timeline.json").
-define(RETWEETSOFME, "https://api.twitter.com/1.1/statuses/retweets_of_me.json").
-define(STATUSESRETWEET, "https://api.twitter.com/1.1/statuses/retweet/").
-define(STATUSESUPDATEWITHMEDIA, "https://api.twitter.com/1.1/statuses/update_with_media.json").

-define(STREAMFILTER, "https://stream.twitter.com/1.1/statuses/filter.json").
-define(STREAMUSER, "https://userstream.twitter.com/1.1/user.json").
-record(oauth, {
  oauth_callback = [],
  oauth_consumer_key = [],
  oauth_nonce = [],
  oauth_signature = [],
  oauth_signature_method = "HMAC-SHA1",
  oauth_timestamp = [],
  oauth_token = [],
  oauth_version = "1.0",
  oauth_api_secret = [],
  oauth_token_secret = [],
  oauth_http_method = "POST"
}
).

