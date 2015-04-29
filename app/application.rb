# require 'opal'
# require 'opal-parser'

require 'two'
require 'browser'
require 'browser/interval'
require 'native'
require 'core_extensions/kernel'

require 'rubyrobots'
require 'robots/dummy'
require 'robots/nervous_duck'
require 'robots/sitting_duck'


editor = Native(`ace`).edit 'editor'
editor.setTheme 'ace/theme/solarized_dark'
editor.getSession.setMode 'ace/mode/ruby'

a = RubyRobots.new(editor)

$document['run'].on :click do
  a.load_robots
end

editor.commands.addCommand({
  name: 'execute',
  bindKey: { win: 'Ctrl-S',  mac: 'Command-S' },
  exec: ->(editor) {
    a.load_robots
  },
  readOnly: true
})
