#   Copyright 2017 Zendesk, Inc
#   
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#   
#       http://www.apache.org/licenses/LICENSE-2.0
#   
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


require 'net/http'
require 'json'
require 'io/console'

SUBDOMAIN="subdomain"
EMAIL='your@email.com'
PASSWORD='password'

def url(endpoint)
  URI("https://#{SUBDOMAIN}.zendesk.com/api/v2/#{endpoint}")
end

def get(endpoint)
  uri = url(endpoint)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    request = Net::HTTP::Get.new(uri)
    request.basic_auth EMAIL, PASSWORD
    response = http.request request
  end
end

def put(endpoint, body)
  uri = url(endpoint)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    request = Net::HTTP::Put.new(uri)
    request.basic_auth EMAIL, PASSWORD
    request.body = body
    request.content_type = "application/json"
    response = http.request request
  end
end

def sections
  sections_response = JSON.parse(get('help_center/sections.json').body)
  sections_response["sections"].collect do |section|
    "#{section["id"]} -> #{section["name"]}"
  end
end

def articles(section_id)
  articles = JSON.parse(get("help_center/en-us/sections/#{section_id}/articles.json").body)
  articles["articles"].collect do |article|
    [article['id'], article['title'], article['label_names']]
  end
end

def article(article_id)
  article = JSON.parse(get("help_center/en-us/articles/#{article_id}.json").body)['article']
  [article['id'], article['title'], article['label_names']]
end

def add_answer_bot_label_to_section(section_id, label)
  index = 0
  articles(section_id).each do |id, title, label_names|
    sleep 10 if (index%7) == 0
    puts "about to update #{id}, #{title}, #{label_names}"
    data = "{\"article\": {\"label_names\": #{label_names +["#{label}"]}}}"
    response = put("help_center/articles/#{id}.json", data)
    puts "unable to update #{id}, #{title}, #{label_names}" unless response.is_a?(Net::HTTPSuccess)
    index+=1
  end
end

def add_answer_bot_label_to_articles(articles, label)
  index = 0
  articles.each do |article_id|
    sleep 10 if (index%7) == 0
    id, title, label_names = article(article_id)
    next if id.nil?
    puts "about to update #{id}, #{title}, #{label_names}"
    data = "{\"article\": {\"label_names\": #{label_names +["#{label}"]}}}"
    response = put("help_center/articles/#{id}.json", data)
    puts "unable to update #{id}, #{title}, #{label_names}" unless response.is_a?(Net::HTTPSuccess)
    index+=1
  end
end

loop do
  puts "Please choose one of the following options"
  puts "1. List Sections"
  puts "2. Choose Section and add answer-bot label to the articles in that section"
  puts "3. Update individual articles"
  puts "4. Exit"

  input = gets.chomp.to_i

  case input
    when 1
      puts sections
    when 2
      puts "Alright, give me the section_id"
      section_id = gets.chomp.to_i
      puts "Alright, whats the name of your label? example: answer-bot"
      label = gets.chomp
      add_answer_bot_label_to_section(section_id, label)
    when 3
      puts "Alright, give me the article_ids of the format 1,2,3,4 ( an comma separated list of article_ids)"
      articles = gets.chomp.split(',').map(&:lstrip)
      puts "Alright, whats the name of your label? example: answer-bot"
      label = gets.chomp
      add_answer_bot_label_to_articles(articles, label)
    when 4
      exit
  end
end
