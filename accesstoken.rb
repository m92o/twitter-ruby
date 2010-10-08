# -*- coding: utf-8 -*-
#
# accesstoken.rb
#  Twitterのアクセストークン取得ユーティリティ
#
require "oauth"

if (ARGV.length != 5)
  STDERR.puts("usage: #{$0} consumer_key consumer_secret oauth_token oauth_token_secret oauth_verifier")
  exit 1
end

consumer_key = ARGV[0]
consumer_secret = ARGV[1]
oauth_token = ARGV[2]
oauth_token_secret = ARGV[3]
oauth_verifier = ARGV[4]

oauth = OAuth.new(consumer_key, consumer_secret)
puts oauth.access_token(oauth_token, oauth_token_secret, oauth_verifier)
