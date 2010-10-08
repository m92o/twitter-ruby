# -*- coding: utf-8 -*-
#
# requesttoken.rb
#  Twitterのリクエストトークン取得ユーティリティ
#
require "oauth"

if (ARGV.length != 2)
  STDERR.puts("usage: #{$0} consumer_key consumer_secret")
  exit 1
end

consumer_key = ARGV[0]
consumer_secret = ARGV[1]

oauth = OAuth.new(consumer_key, consumer_secret)
token = oauth.request_token
puts token
puts "OAuth Virifier URL = " + oauth.oauth_verifier_url(token)
