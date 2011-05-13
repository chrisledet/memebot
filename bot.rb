# Memebot for Convore
# just mention @memebot in your topic and he'll respond
# 
# by Chris Ledet
# 
require 'rubygems'
require 'curb'
require 'json'
require 'yaml'
require 'meme'

class Convore
  # wrapper client for Convore (https://convore.com/)
  
  BASE_URL = 'https://convore.com/api'
  AGENT = "MemeBot/Ruby"
  
  def initialize(username, password)
    @username = username
    @password = password
  end
  
  # returns number of new mentions
  def unread
    body = JSON( get "#{BASE_URL}/account/mentions.json" )
    body["unread"]
  end
  
  # returns ALL mentions! => [message, topic_id]
  def mentions
    body = JSON( get "#{BASE_URL}/account/mentions.json" )
    body['mentions'].collect do |m| 
      { 
        # strip out the @reference so we only the message
        :message  => m['message']['message'].gsub("@#{@username} ", ""), 
        :topic_id => m['topic']['id'] 
      } 
    end
  end
  
  # returns array of mentions {:message, :topic_id}
  def latest_mentions
    unread_mentions = unread
    unread_mentions > 0 ? mentions[0..unread_mentions-1] : []
  end
  
  def post_message(topic_id, message)
    options = [
      Curl::PostField.content("message", message),
      Curl::PostField.content("topic_id",  topic_id)
    ]
    post("#{BASE_URL}/topics/#{topic_id}/messages/create.json", options)
  end
  
  private
  
  def post(url, options)
    c = Curl::Easy.http_post(url, *options) do |curl|
      curl.headers["User-Agent"] = AGENT
      curl.http_auth_types = :basic
      curl.username = @username
      curl.password = @password
    end
  end
  
  def get(url)
    c = Curl::Easy.new(url) do |curl|
      curl.headers["User-Agent"] = AGENT
      curl.http_auth_types = :basic
      curl.username = @username
      curl.password = @password
    end
    c.perform
    c.body_str
  end
  
end

class Bot
  
  TIMER = 5 # secs...DUH!
  NO_MEME_IMAGE = "http://i.imgur.com/huDHF.jpg"

  def initialize
    # exit if no config.yml file
    abort("No config.yml file. Get to work!") unless File.exist? "config.yml"
    # shall we?
    config = YAML::load File.read("config.yml")
    @convore = Convore.new config["username"], config["password"]
    start!
  end
  
  private
  
  def start!
    log "I don’t always listen, but when I do, I convore."
    loop {
      check_mentions
      sleep TIMER      
    }
  end
  
  def check_mentions
    mentions = @convore.latest_mentions
    mentions.each do |mention|
      log "unread mention found"
      message_body = mention[:message]
      topic_id = mention[:topic_id]
      Thread.new { 
        message = generate_meme message_body
        @convore.post_message(topic_id, message)
        log "Posting #{message} in topic: #{topic_id}"
      }
    end
  end
  
  # Look away! I'm hideous...
  # Seinfeld reference - http://www.youtube.com/watch?v=S-kIxa0fDM0
  def generate_meme(message_body)
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
          # meme not found
          message = NO_MEME_IMAGE
        end
      end
    rescue NoMethodError => boom
      # incomplete query
      message = "Need moar!"
    rescue => boom
      # what is this...I don't even...
      message = "Wait...what?!"
    end
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


# start it up! BOOM!
Bot.new
