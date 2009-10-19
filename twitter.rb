# -*- coding: utf-8 -*-
#
# twitter.rb
#
# Twitterクライアントクラス
#
require 'net/http'
require 'rexml/document'

class Twitter
  attr_reader :user_id, :users, :res

  def initialize(user = nil, pass = nil)
    @user = user
    @pass = pass

    @users = Hash.new
  end

  # ログイン (verify_credentials)
  def login(user = nil, pass = nil)
    url = "http://twitter.com/account/verify_credentials.xml"

    @user = user if user != nil
    @pass = pass if pass != nil

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri.path)
    req.basic_auth(@user, @pass)

    res = Net::HTTP.start(uri.host) { |http|
      http.request(req)
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
    url = "http://twitter.com/statuses/update.xml"
    param = "status="

    uri = URI.parse(url)
    req = Net::HTTP::Post.new(uri.path)
    req.basic_auth(@user, @pass)
    req.body = param + msg

    res = Net::HTTP.start(uri.host) { |http|
      http.request(req)
    }

    p res
    @res = res
  end

  # friends timeline
  def friends_timeline(page = nil)
    url = "http://twitter.com/statuses/friends_timeline.xml"
    param = "?page="

    url += param + page.to_s if page != nil && page > 0

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri.path)
    req.basic_auth(@user, @pass)

    res = Net::HTTP.start(uri.host) { |http|
      http.request(req)
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
