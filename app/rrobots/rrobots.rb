require 'math'
require 'rrobots/robot'
require 'rrobots/ducks/NervousDuck'
require 'rrobots/ducks/SittingDuck'
require 'rrobots/ducks/Ente'
require 'rrobots/tkarena'

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
  attr_reader :width, :height, :robots, :teams, :bullets, :explosions, :time, :seed, :timeout, :game_over

  def initialize(width, height, timeout, seed)
    @width, @height = width, height
    @seed = seed
    @time = 0
    @robots = []
    @teams = Hash.new { |h, k| h[k] = [] }
    @bullets = []
    @explosions = []
    @timeout = timeout
    @game_over = false
    srand @seed
  end

  def <<(object)
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
    explosions.delete_if(&:dead)
    explosions.each(&:tick)

    bullets.delete_if(&:dead)
    bullets.each(&:tick)

    robots.each do |robot|
      begin
        robot.send :internal_tick unless robot.dead
      rescue => bang
        puts "#{robot} made an exception:"
        puts "#{bang.class}: #{bang}", bang.backtrace
        robot.instance_eval { @energy = -1 }
      end
    end

    @time += 1
    live_robots = robots.select { |robot| !robot.dead }
    @game_over = ((@time >= timeout) || # timeout reached
                    (live_robots.length == 0) || # no robots alive, draw game
                    (live_robots.all? { |r| r.team == live_robots.first.team })) # all other teams are dead
    !@game_over
  end

  def state
    { explosions: explosions.map(&:state),
      bullets: bullets.map(&:state),
      robots: robots.map(&:state) }
  end
end

class Explosion
  attr_accessor :x, :y, :t, :dead

  def initialize(bf, x, y)
    @x, @y, @t = x, y, 0
    @battlefield, dead = bf, false
  end

  def state
    { x: x, y: y, t: t }
  end

  def tick
    @t += 1
    @dead ||= t > 15
  end
end

class Bullet
  attr_accessor :x, :y, :heading, :speed, :energy, :dead, :origin

  def initialize(bf, x, y, heading, speed, energy, origin)
    @x, @y, @heading, @origin = x, y, heading, origin
    @speed, @energy = speed, energy
    @battlefield, dead = bf, false
  end

  def state
    { x: x, y: y, energy: energy }
  end

  def tick
    return if @dead
    @x += Math.cos(@heading.to_rad) * @speed
    @y -= Math.sin(@heading.to_rad) * @speed

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
