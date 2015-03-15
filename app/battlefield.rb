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
