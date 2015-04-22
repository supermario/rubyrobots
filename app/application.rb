require 'opal'
require 'opal-parser'
require 'two'
require 'browser'
require 'browser/interval'
require 'native'
require 'monkey_patches'

require 'rubyrobots'
require 'robots/dummy'
require 'robots/nervous_duck'
require 'robots/sitting_duck'

class Application
  attr_accessor :started

  def initialize(e)
    @e = e
    @started = false
  end

  def load_robots
    stop_battle
    # return if started
    @robots = []
    @robots << Dummy
    load_text_bot
    start_battle
  end

  private

  def load_text_bot
    eval @e.getValue
    @robots << MyBot
  end

  def run_in_gui(battlefield, xres, yres, speed_multiplier)
    arena = Arena.new(battlefield, xres, yres, speed_multiplier)
    game_over_counter = battlefield.teams.all? { |_k, t| t.size < 2 } ? 250 : 500
    outcome_printed = false
    arena.on_game_over do |battlefield|
      unless outcome_printed
        print_outcome(battlefield)
        outcome_printed = true
      end
      exit 0 if game_over_counter < 0
      game_over_counter -= 1
    end
    arena.run
  end

  def game_over_counter
    @game_over_counter ||= 0
  end

  def print_outcome(battlefield)
    winners = battlefield.robots.select { |robot| !robot.dead }
    puts
    if battlefield.robots.size > battlefield.teams.size
      teams = battlefield.teams.select { |_name, team| !team.all?(&:dead) }
      puts "winner_is:     { #{
        teams.map do |name, team|
          "Team #{name}: [#{team.join(', ')}]"
        end.join(', ')
      } }"
      puts "winner_energy: { #{
        teams.map do |name, team|
          "Team #{name}: [#{team.map { |w| ('%.1f' % w.energy) }.join(', ')}]"
        end.join(', ')
      } }"
    else
      puts "winner_is:     [#{winners.map(&:name).join(', ')}]"
      puts "winner_energy: [#{winners.map { |w|'%.1f' % w.energy }.join(', ')}]"
    end
    puts "elapsed_ticks: #{battlefield.time}"
    puts "seed :         #{battlefield.seed}"
    puts
    puts 'robots :'
    battlefield.robots.each do |robot|
      puts "  #{robot.name}:"
      puts "    damage_given: #{'%.1f' % robot.damage_given}"
      puts "    damage_taken: #{'%.1f' % (100 - robot.energy)}"
      puts "    kills:        #{robot.kills}"
    end
  end

  def start_battle
    @started = true
    xres = yres = 400
    seed = 0
    speed_multiplier = 1
    timeout = 50_000

    @battlefield = Battlefield.new xres * 2, yres * 2, timeout, seed

    @robots.each_with_index do |robot, index|
      @battlefield << RobotRunner.new(robot.new, @battlefield, index)
    end

    puts "Battle started between #{@robots.join(' and ')}"

    run_in_gui @battlefield, xres, yres, speed_multiplier
  end

  def stop_battle
    @battlefield.stop if !@battlefield.nil?
  end
end

editor = Native(`ace`).edit 'editor'
editor.setTheme 'ace/theme/solarized_dark'
editor.getSession.setMode 'ace/mode/ruby'

a = Application.new(editor)

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
