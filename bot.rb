# 
# Memebot for Convore
# just mention @memebot in your topic and he'll respond
# 
# by Chris Ledet
# 
# 
require 'rubygems'
require 'curb'
require 'json'
require 'yaml'

config = YAML::load(File.read('conf.yml'))

GROUP_ID = 7750
BOTNAME = config["username"]
BOTPWD  = config["password"]

class Convore

  BASE_URL = 'https://convore.com/api'
  AGENT = "MemeBot/Ruby"

  class << self
    
    def unread
      c = Curl::Easy.new("#{BASE_URL}/account/mentions.json") do |curl|
        curl.headers["User-Agent"] = AGENT
        curl.http_auth_types = :basic
        curl.username = BOTNAME
        curl.password = BOTPWD
      end
      c.perform
      body = JSON c.body_str
      # return int
      body["unread"]
    end
    
    def mentions
      c = Curl::Easy.new("#{BASE_URL}/account/mentions.json") do |curl|
        curl.headers["User-Agent"] = AGENT
        curl.http_auth_types = :basic
        curl.username = BOTNAME
        curl.password = BOTPWD
      end
      c.perform
      body = JSON c.body_str
      # return array of mentions
      body['mentions'].collect! { |m| m['message']['message'].gsub("@#{BOTNAME} ", "") }
    end
    
    def latest_mention
      mentions.first
    end
    
    def post_message(topic_id, message)
      options = [
        Curl::PostField.content("message", message),
        Curl::PostField.content(topic_id,  topic_id),
      ]
      c = Curl::Easy.http_post("#{BASE_URL}/topics/#{topic_id}/messages/create.json", *options) do |curl|
        curl.headers["User-Agent"] = AGENT
        curl.http_auth_types = :basic
        curl.username = BOTNAME
        curl.password = BOTPWD
      end
    end
    
  end
  
end

class Bot
  # pings Convore for latest messages
  TIMER = 5
  
  def initialize
    p "I don't listen but when I do, I post on convore." # intro needs work
    while true
      process
      sleep TIMER
    end
  end
  
  private
  
  def process
    
    return if Convore::unread == 0
    
    p "i am famouz! posting now!"
    message = case Convore::latest_mention
      when /love/
        "aaaawwh, i haz love!"
      when /cool/
        "what's cooler than being cool? ICE COLD!"
      when /hai/
          "OH HAI!"
      when /kevin/
        "http://www.popcritics.com/wp-content/uploads/2008/07/kevin_the_office.jpg"
      else
        "Wait...what!?"
    end
    topic_id = "15300" # TODO Grab from latest_mention
    Convore::post_message topic_id, message
  end
  
end


# start it up!
Bot.new
