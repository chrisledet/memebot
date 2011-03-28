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
    
    # returns int
    def unread
      body = JSON( get "#{BASE_URL}/account/mentions.json" )
      body["unread"]
    end
    
    # returns all mentions => [message, topic_id]
    def mentions
      body = JSON( get "#{BASE_URL}/account/mentions.json" )
      # return array of mentions
      body['mentions'].collect! { |m| [ m['message']['message'].gsub("@#{BOTNAME} ", ""), m['topic']['id'] ] }
    end
    
    # returns latest [message, topic_id]
    def latest_mention
      mentions.first
    end
    
    def post_message(topic_id, message)
      options = 
        [
          Curl::PostField.content("message", message),
          Curl::PostField.content("topic_id",  topic_id),
        ]
      
      post("#{BASE_URL}/topics/#{topic_id}/messages/create.json", options)
    end
    
    private
    
    def post(url, options)
      c = Curl::Easy.http_post(url, *options) do |curl|
        curl.headers["User-Agent"] = AGENT
        curl.http_auth_types = :basic
        curl.username = BOTNAME
        curl.password = BOTPWD
      end
    end
    
    def get(url)
      c = Curl::Easy.new(url) do |curl|
        curl.headers["User-Agent"] = AGENT
        curl.http_auth_types = :basic
        curl.username = BOTNAME
        curl.password = BOTPWD
      end
      c.perform
      c.body_str
    end
    
  end
  
end

class Bot
  # pings Convore for latest messages
  TIMER = 5 #secs
  NO_MEME_IMAGE = "http://i.imgur.com/huDHF.jpg"
  
  def initialize
    log "Started. I don't listen but when I do, I post on convore." # intro needs work
    while true
      process
      sleep TIMER
    end
  end
  
  private
  
  def process
    
    return if Convore::unread == 0
    
    message_body, topic_id  = Convore::latest_mention
    log "Unread mentions found in Topic #{topic_id}"
    
    Thread.new {
      begin
        # if user types help, list all available memes
        if "help".include? message_body
          log "Listing all memes available."
          message = ["Memes Available\n"] << available_memes.join("\n")
        # parse mention's message
        else
          meme_name, message_body = message_body.split(" ", 2) # assuming memename text to write
          if available_memes.include? meme_name
            line_one, line_two = message_body.split ","       # if string contains comma (,) then add another line
            log "Generating MEME: #{meme_name} with #{line_one} #{line_two}"
            meme = Meme.new meme_name.upcase
            message = meme.generate(line_one, line_two)
          else
            log "Meme #{meme_name} not found!"
            message = NO_MEME_IMAGE
          end
          log "Message #{message} Posted in Topic #{topic_id}"
        end
      rescue NoMethodError => boom
        log "Error occurr: '#{boom.class} - #{boom.message}' message_body:'#{message_body}' | Topic:'#{topic_id}'"
        message = "Need moar!"
      rescue => boom
        log "Unknown Error occurr: '#{boom.class} - #{boom.message}' message_body:'#{message_body}' | Topic:'#{topic_id}'"
        message = "Wait...what?!"
      end
      
      # now post the message
      Convore::post_message topic_id, message      
    }

  end
  
  def available_memes
    Meme::GENERATORS.collect { |g| g.first.downcase }.sort
  end
  
  def log(message)
    p "#{timestamp_it} - #{message}"
  end

  def timestamp_it
    Time.now.strftime "%m-%d-%Y%l:%M%p %Ss" # M-D-Y H:S(AM/PM)
  end
  
end


# start it up!
Bot.new
