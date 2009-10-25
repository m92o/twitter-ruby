# -*- coding: utf-8 -*-
#
# twitter.rb
#
# Twitterクライアントクラス
#
require 'net/https'
require 'cgi'
require 'rexml/document'

class Twitter
  HOST = "twitter.com"
  HTTP_PORT = 80
  HTTPS_PORT = 443
  GET = :get
  POST = :post

  attr_reader :user_id, :users

  def initialize(user, pass, enable_ssl = false)
    @user = user
    @pass = pass
    @enable_ssl = enable_ssl

    @port = (enable_ssl == true) ? HTTPS_PORT : HTTP_PORT
    @users = Hash.new
  end

  # ログイン (verify_credentials)
  def login()
    path = "/account/verify_credentials.xml"

    res = request(GET, path)

    doc = REXML::Document.new(res.body)
    doc.elements.each('user') { |user|
      my = User.parse(user)
      @user_id = my.id
      @users[@user_id] = my if @users[@user_id] == nil
    }

    # 保存しておくけど、クッキーで再認証は出来ないっぽいな
    @cookie = res.get_fields('set-cookie')
  end

  # アップデート (つぶやく)
  def update(message)
    path = "/statuses/update.xml"
    param = "status="

    return if message.length > 140  # 例外の方がいいかな？

    res = request(POST, path, param + CGI.escape(message))
  end

  # friends timeline
  def friends_timeline(page = nil)
    path = "/statuses/friends_timeline.xml"
    param = "?page="

    path += param + page.to_s if page != nil && page > 0

    res = request(GET, path)

    statuses = []
    doc = REXML::Document.new(res.body)
    doc.elements.each('statuses/status') { |status|
      user = User.parse(status.elements['user'])
      @users[user.id] = user if @users[user.id] == nil
      statuses << Status.parse(status, user.id)
    }
 
    return statuses
  end

  def request(method, path, body = nil)
    case method
    when :get
      req = Net::HTTP::Get.new(path)
    when :post
      req = Net::HTTP::Post.new(path)
    else
      return nil # 例外の方がいいかな？
    end
    req.basic_auth(@user, @pass)
    req.body = body if body != nil

    http = Net::HTTP.new(HOST, @port)
    http.use_ssl = @enable_ssl
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @enable_ssl == true # とりあえず未チェック

    response = http.start { |h|
      h.request(req)
    }

    if response.class != Net::HTTPOK
      return nil # 例外の方がいいかな？
    end

    return response
  end
  private :request

  # ステータス情報
  #  まだ一部の情報しか保持していない
  class Status
    attr_reader :created_at, :status_id, :text
    attr_accessor :user_id

    def initialize(id, created_at, text, user_id = nil)
      @id = id
      @created_at = created_at
      @text = text
      @user_id = user_id
    end

    def self.parse(message, user_id)
      elements = message.elements
      id = elements['id'].text
      create = elements['created_at'].text
      text = elements['text'].text

      return Status.new(id, create, text, user_id)
    end
  end

  # ユーザ情報
  #  まだ一部の情報しか保持していない
  class User
    attr_reader :id, :name, :screen_name, :location, :description, :image_url, :url
 
    def initialize(id, name, screen_name, location, description, image_url, url)
      @id = id
      @name = name
      @screen_name = screen_name
      @location = location
      @description = description
      @image_url = image_url
      @url = url
    end

    def self.parse(message)
      elements = message.elements
      id = elements['id'].text
      name = elements['name'].text
      sname = elements['screen_name'].text
      loc = elements['location'].text
      desc = elements['description'].text
      image = elements['profile_image_url'].text
      url = elements['url'].text

      return User.new(id, name, sname, loc, desc, image, url)
    end
  end
end
