require "opal"
require "opal-parser"
require "pp"
require "json"
require "two"
require "github"
require "browser"
require "rrobots/rrobots"

module Kernel
  def puts(*things)
    log = $document['log']
    log.inner_text = log.inner_text + "\n" + things * "\n"
  end
end

class String
  def classify
    Object.const_get self
  end

  def camelize
    scan(/[a-zA-Z0-9]+/).map(&:capitalize).join
  end
end

class Application
  attr_accessor :started

  def initialize
    @started = false
    if gist_ids.size > 1
      puts 'Loading robots'
      load_ducks
    else
      puts 'No robots'
    end
  end

  private

  def gist_ids
    @gist_ids ||= begin
      fragment = $document.location.fragment
      fragment.scan(/\d+/)
    end
  end

  def load_ducks
    @ducks = []
    gists.each { |gist| read_gist(gist) }
  end

  def gists
    @gists ||= gist_ids.map { |id| get_gist(id) }
  end

  def get_gist(id)
    github.getGist(id)
  end

  def github
    @github ||= Native `new Github({})`
  end

  def read_gist(gist)
    gist.read { |error, content| load_duck(json_from_object content) }
  end

  def load_duck(content)
    files = content[:files].values
    @ducks << eval_duck(files.first)

    mybot_code = opal_compile($document['brains'].inner_html)
    eval_js mybot_code
    @ducks << 'MyDuck'.classify

    start_battle @ducks unless started

    # start_battle_if_all_ducks_loaded
  end

  def json_from_object(content)
    JSON.from_object(content)
  end

  def start_battle_if_all_ducks_loaded
    if @ducks.size == gists.size
      start_battle @ducks
    end
  end

  def eval_duck(file)
    code = file[:content]
    code = opal_compile(code)
    eval_js code

    filename = file[:filename]
    filename
      .gsub('.rb', '')
      .camelize
      .classify
  end

  def opal_compile(code)
    Opal.compile(code)
  end

  def eval_js(code)
    `eval(code)`
  end

  def run_in_gui(battlefield, xres, yres, speed_multiplier)
    arena = TkArena.new(battlefield, xres, yres, speed_multiplier)
    game_over_counter = battlefield.teams.all?{|k,t| t.size < 2} ? 250 : 500
    outcome_printed = false
    arena.on_game_over{|battlefield|
      unless outcome_printed
        print_outcome(battlefield)
        outcome_printed = true
      end
      exit 0 if game_over_counter < 0
      game_over_counter -= 1
    }
    arena.run
  end

  def print_outcome(battlefield)
    winners = battlefield.robots.find_all{|robot| !robot.dead}
    puts
    if battlefield.robots.size > battlefield.teams.size
      teams = battlefield.teams.find_all{|name,team| !team.all?{|robot| robot.dead} }
      puts "winner_is:     { #{
        teams.map do |name,team|
          "Team #{name}: [#{team.join(', ')}]"
        end.join(', ')
      } }"
      puts "winner_energy: { #{
        teams.map do |name,team|
          "Team #{name}: [#{team.map do |w| ('%.1f' % w.energy) end.join(', ')}]"
        end.join(', ')
      } }"
    else
      puts "winner_is:     [#{winners.map{|w|w.name}.join(', ')}]"
      puts "winner_energy: [#{winners.map{|w|'%.1f' % w.energy}.join(', ')}]"
    end
    puts "elapsed_ticks: #{battlefield.time}"
    puts "seed :         #{battlefield.seed}"
    puts
    puts "robots :"
    battlefield.robots.each do |robot|
      puts "  #{robot.name}:"
      puts "    damage_given: #{'%.1f' % robot.damage_given}"
      puts "    damage_taken: #{'%.1f' % (100 - robot.energy)}"
      puts "    kills:        #{robot.kills}"
    end
  end

  def start_battle(ducks)
    @started = true
    xres = yres = 400
    seed = 0
    speed_multiplier = 1
    timeout = 50000

    battlefield = Battlefield.new xres * 2, yres * 2, timeout, seed

    ducks.each_with_index do |duck, index|
      battlefield << RobotRunner.new(duck.new, battlefield, index)
    end

    puts "Battle started between #{ducks.join(' and ')}"

    run_in_gui battlefield, xres, yres, speed_multiplier
  end
end

Application.new $document.body
