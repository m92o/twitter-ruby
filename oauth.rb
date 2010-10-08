# -*- coding: utf-8 -*-
#
# oauth.rb
#  Twitter用OAuthライブラリ
#
require "OpenSSL"
require "base64"
require "uri"
require "net/http"

class OAuth
  URL = "http://twitter.com"
  REQUEST_TOKEN_PATH = "/oauth/request_token"
  ACCESS_TOKEN_PATH = "/oauth/access_token"
  OAUTH_VERIFIER_PATH = "/oauth/authorize"

  # OAuth spec escape
  def escape(str)
    URI.escape(str, /[^a-zA-Z0-9\-\.\_\~]/)
  end
  private :escape

  # パラメータをエンコードした key=value の形にして separator で繋げる
  def encode_params(hash, separator)
    array = []
    hash.each do |key, value|
      array.push escape(key) + "=" + escape(value)
    end
    array.join(separator)
  end
  private :encode_params

  # キーを元に message で hmac-digest を作成し base64 でエンコード
  def signature(key, message)
    Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, key, message)).strip
  end
  private :signature

  # nonce word
  def nonce
    OpenSSL::Digest::Digest.hexdigest("MD5", "#{Time.now.to_f}#{rand}")
  end
  private :nonce

  # timestamp
  def timestamp
    Time.now.tv_sec.to_s
  end
  private :timestamp

  # parse
  def parse_body(body)
    hash = {}
    body.split("&").each do |param|
      key, value = param.split("=", 2)
      hash[key] = value
    end
    hash
  end
  private :parse_body

  def request_get(path, header = nil)
    http = Net::HTTP.new(URI.parse(URL).host)
    http.request_get(path, header)
  end
  private :request_get

  def initialize(consumer_key, consumer_secret, oauth_token = nil, oauth_token_secret = nil)
    @consumer_key = consumer_key
    @consumer_secret = consumer_secret

    # 必須パラメータ
    @params = {
      "oauth_consumer_key" => consumer_key,
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_version" => "1.0",
    }

    if oauth_token != nil && oauth_token_secret != nil
      @params["oauth_token"] = oauth_token
      @oauth_token = oauth_token
      @oauth_token_secret = oauth_token_secret
    end
  end

  # Request Token取得
  def request_token
    params = @params.dup
    params["oauth_timestamp"] = timestamp
    params["oauth_nonce"] = nonce

    # パラメータをソートし，エンコードした key=value の形にして & で繋げる
    params_str = encode_params(params.sort, "&")

    # メソッド, エンコードした URL, 上で作ったパラメータ文字列を & で繋げる
    message = "GET&" + escape(URL + REQUEST_TOKEN_PATH) + "&" + escape(params_str)

    # consumer_secret を元にキーを作成
    key = @consumer_secret + "&"

    # キーを元に message で hmac-digest を作成
    sig = signature(key, message)

    # 作成したダイジェストをパラメータに追加
    params["oauth_signature"] = sig

    # 作成したパラメータを GET のパラメータとして追加
    path = REQUEST_TOKEN_PATH + "?" + encode_params(params, "&")

    res = request_get(path)
    parse_body(res.body)
  end

  # Access Token取得
  def access_token(oauth_token, oauth_token_secret, oauth_verifier)
    params = @params.dup
    params["oauth_token"] = oauth_token
    params["oauth_token_secert"] = oauth_token_secret
    params["oauth_verifier"] = oauth_verifier
    params["oauth_timestamp"] = timestamp
    params["oauth_nonce"] = nonce

    # パラメータをソートし，エンコードした key=value の形にして & で繋げる
    params_str = encode_params(params.sort, "&")

    # メソッド, エンコードした URL, 上で作ったパラメータ文字列を & で繋げる
    message = "GET&" + escape(URL + ACCESS_TOKEN_PATH) + "&" + escape(params_str)

    # consumer_secret を元にキーを作成
    key = @consumer_secret + "&" + oauth_token_secret

    # キーを元に message で hmac-digest を作成
    sig = signature(key, message)

    # 作成したダイジェストをパラメータに追加
    params["oauth_signature"] = sig

    # 作成したパラメータを GET のパラメータとして追加
    path = ACCESS_TOKEN_PATH + "?" + encode_params(params, "&")

    # ヘッダに Authorization:OAuth を追加
    header = {"Authorization" => "OAuth"}

    res = request_get(path, header)
    parse_body(res.body)
  end

  # OAuth Verifier URL
  def oauth_verifier_url(token)
    URL + OAUTH_VERIFIER_PATH + "?oauth_token=" + token["oauth_token"]
  end

  # Authorization Header
  def auth_header(method, url, option = nil)
    params = @params.dup
    params["oauth_timestamp"] = timestamp
    params["oauth_nonce"] = nonce

    # option をパラメータに追加
    opt_key = nil
    if option != nil
      opt_key, value = option.split("=", 2)
      params[opt_key] = value
    end

    # パラメータをソートし，エンコードした key=value の形にして & で繋げる
    params_str = encode_params(params.sort, "&")

    # メソッド, エンコードした URL, 上で作ったパラメータ文字列を & で繋げる
    message = method.to_s.upcase + "&" + escape(url) + "&" + escape(params_str)

    # consumer_secret を元にキーを作成
    key = @consumer_secret + "&" + @oauth_token_secret

    # キーを元に message で hmac-digest を作成
    sig = signature(key, message)

    # 作成したダイジェストをパラメータに追加
    params["oauth_signature"] = sig

    # header に不要なパラメータを削除
    if option != nil
      params.delete(opt_key)
    end

    header = {"Authorization" => "OAuth " + encode_params(params, ",")}
  end
end
