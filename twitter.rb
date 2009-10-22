# -*- coding: utf-8 -*-
#
# twitter.rb
#
# Twitterクライアントクラス
#
require 'net/https'
require 'rexml/document'

HOST = "twitter.com"
GET = "GET"
POST = "POST"

class Twitter
  attr_reader :user_id, :users, :res

  def initialize(user = nil, pass = nil, ssl = false)
    @user = user
    @pass = pass
    @ssl = ssl

    @port = (ssl == true) ? 443 : 80
    @users = Hash.new
  end

  # ログイン (verify_credentials)
  def login(user = nil, pass = nil)
    path = "/account/verify_credentials.xml"

    @user = user if user != nil
    @pass = pass if pass != nil

    req = request(GET, path)
    res = http.start { |h|
      h.request(req)
    }

    @res = res
    if res.class != Net::HTTPOK
      return
    end

    doc = REXML::Document.new(res.body)
    doc.elements.each('user') { |u|
      my = User.parse(u)
      @user_id = my.user_id
      @users[@user_id] = my if @users[@user_id] == nil
    }

    # 保存しておくけど、クッキーで再認証は出来ないっぽいな
    @cookie = res.get_fields('set-cookie')
  end

  # つぶやく (update) 
  def update(msg)
    path = "/statuses/update.xml"
    param = "status="

    return if msg.length > 140


    req = request(POST, path)
    req.body = param + msg
    res = http.start { |h|
      h.request(req)
    }

    @res = res
  end

  # friends timeline
  def friends_timeline(page = nil)
    path = "/statuses/friends_timeline.xml"
    param = "?page="

    path += param + page.to_s if page != nil && page > 0

    req = request(GET, path)
    res = http.start { |h|
      h.request(req)
    }

    @res = res
    if res.class != Net::HTTPOK
      return nil
    end

    statuses = []
    doc = REXML::Document.new(res.body)
    doc.elements.each('statuses/status') { |s|
      u = User.parse(s.elements['user'])
      @users[u.user_id] = u if @users[u.user_id] == nil
      statuses << Status.parse(s, u.user_id)
    }
 
    return statuses
  end

  def request(method, path)
    case method
    when GET
      req = Net::HTTP::Get.new(path)
    when POST
      req = Net::HTTP::Post.new(path)
    else
      return nil
    end
    req.basic_auth(@user, @pass)

    return req
  end
  private :request

  def http
    h = Net::HTTP.new(HOST, @port)
    h.use_ssl = @ssl
    h.verify_mode = OpenSSL::SSL::VERIFY_NONE if @ssl == true # とりあえず未チェック

    return h
  end
  private :http

  # ステータス情報
  #  まだ一部の情報しか保持していない
  class Status
    attr_reader :created_at, :status_id, :text
    attr_accessor :user_id

    def initialize(sid, create, text, uid = nil)
      @created_at = create
      @status_id = sid
      @text = text
      @user_id = uid
    end

    def self.parse(msg, uid = nil)
      sid = msg.elements['id'].text
      create = msg.elements['created_at'].text
      text = msg.elements['text'].text

      return Status.new(sid, create, text, uid)
    end
  end

  # ユーザ情報
  #  まだ一部の情報しか保持していない
  class User
    attr_reader :user_id, :name, :screen_name, :location, :description, :image_url, :url
 
    def initialize(uid, name, sname, loc, desc, image, url)
      @user_id = uid
      @name = name
      @screen_name = sname
      @location = loc
      @description = desc
      @image_url = image
      @url = url
    end

    def self.parse(msg)
      uid = msg.elements['id'].text
      name = msg.elements['name'].text
      sname = msg.elements['screen_name'].text
      loc = msg.elements['location'].text
      desc = msg.elements['description'].text
      image = msg.elements['profile_image_url'].text
      url = msg.elements['url'].text

      return User.new(uid, name, sname, loc, desc, image, url)
    end
  end
end
