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
require 'meme'

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
    
    # returns all mentions => [message, topic_id]
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
      body['mentions'].collect! { |m| [ m['message']['message'].gsub("@#{BOTNAME} ", ""), m['topic']['id'] ] }
    end
    
    # returns latest [message, topic_id]
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
    message_body, topic_id  = Convore::latest_mention
    
    # user types help, brings up list of available memes
    if "help".include? message_body
      message = ["Memes Available\n"] << Meme::GENERATORS.collect { |g| g.first }.sort.join("\n")
    # parse mention's message
    else
      meme_name, message_body = message_body.split " ", 2 # assuming memename text to write
      line_one, line_two = message_body.split ","         # if string contains comma (,) then add another line
      begin
        meme = Meme.new meme_name.upcase
        message = meme.generate line_one, line_two
      rescue Error => boom
        message = boom.message
      end      
    end

    Convore::post_message topic_id, message
  end
  
end


# start it up!
Bot.new
