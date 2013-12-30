require 'bundler'
Bundler.require

server = Opal::Server.new do |s|
  s.append_path 'app'
  s.main = 'application'
end

run server
