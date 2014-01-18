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
