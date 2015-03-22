require 'bundler'
Bundler.require

server = Opal::Server.new(debug: false) do |s|
  s.append_path 'app'
  s.append_path 'lib'
  s.append_path 'public'
  s.main = 'application'
  s.index_path = 'index.html.slim'
end

run server
