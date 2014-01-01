require './robot'
require './ducks/NervousDuck'
require './ducks/SittingDuck'
require './ducks/Ente'
require './tkarena'

class Numeric
   TO_RAD = Math::PI / 180.0
   TO_DEG = 180.0 / Math::PI
   def to_rad
     self * TO_RAD
   end
   def to_deg
     self * TO_DEG
   end
end

class Battlefield
   attr_reader :width
   attr_reader :height
   attr_reader :robots
   attr_reader :teams
   attr_reader :bullets
   attr_reader :explosions
   attr_reader :time
   attr_reader :seed
   attr_reader :timeout  # how many ticks the match can go before ending.
   attr_reader :game_over

  def initialize width, height, timeout, seed
    @width, @height = width, height
    @seed = seed
    @time = 0
    @robots = []
    @teams = Hash.new{|h,k| h[k] = [] }
    @bullets = []
    @explosions = []
    @timeout = timeout
    @game_over = false
    srand @seed
  end

  def << object
    case object
    when RobotRunner
      @robots << object
      @teams[object.team] << object
    when Bullet
      @bullets << object
    when Explosion
      @explosions << object
    end
  end

  def tick
    explosions.delete_if{|explosion| explosion.dead}
    explosions.each{|explosion| explosion.tick}

    bullets.delete_if{|bullet| bullet.dead}
    bullets.each{|bullet| bullet.tick}

    robots.each do |robot|
      begin
        robot.send :internal_tick unless robot.dead
      rescue Exception => bang
        puts "#{robot} made an exception:"
        puts "#{bang.class}: #{bang}", bang.backtrace
        robot.instance_eval{@energy = -1}
      end
    end

    @time += 1
    live_robots = robots.find_all{|robot| !robot.dead}
    @game_over = (  (@time >= timeout) or # timeout reached
                    (live_robots.length == 0) or # no robots alive, draw game
                    (live_robots.all?{|r| r.team == live_robots.first.team})) # all other teams are dead
    not @game_over
  end

  def state
    {:explosions => explosions.map{|e| e.state},
     :bullets    => bullets.map{|b| b.state},
     :robots     => robots.map{|r| r.state}}
  end

end


class Explosion
  attr_accessor :x
  attr_accessor :y
  attr_accessor :t
  attr_accessor :dead

  def initialize bf, x, y
    @x, @y, @t = x, y, 0
    @battlefield, dead = bf, false
  end

  def state
    {:x => x, :y => y, :t => t}
  end

  def tick
    @t += 1
    @dead ||= t > 15
  end
end

class Bullet
  attr_accessor :x
  attr_accessor :y
  attr_accessor :heading
  attr_accessor :speed
  attr_accessor :energy
  attr_accessor :dead
  attr_accessor :origin

  def initialize bf, x, y, heading, speed, energy, origin
    @x, @y, @heading, @origin = x, y, heading, origin
    @speed, @energy = speed, energy
    @battlefield, dead = bf, false
  end

  def state
    {:x => x, :y => y, :energy => energy}
  end

  def tick
    return if @dead
    @x += Math::cos(@heading.to_rad) * @speed
    @y -= Math::sin(@heading.to_rad) * @speed

    @dead ||= (@x < 0) || (@x >= @battlefield.width)
    @dead ||= (@y < 0) || (@y >= @battlefield.height)

    @battlefield.robots.each do |other|
      if (other != origin) && (Math.hypot(@y - other.y, other.x - @x) < 40) && (!other.dead)
        explosion = Explosion.new(@battlefield, other.x, other.y)
        @battlefield << explosion
        damage = other.hit(self)
        origin.damage_given += damage
        origin.kills += 1 if other.dead
        @dead = true
      end
    end
  end
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

xres = yres = 400
seed = 0
speed_multiplier = 1
timeout = 50000

battlefield = Battlefield.new xres * 2, yres * 2, timeout, seed
battlefield << RobotRunner.new(NervousDuck.new, battlefield, 0)
battlefield << RobotRunner.new(SittingDuck.new, battlefield, 1)

run_in_gui(battlefield, xres, yres, speed_multiplier)
