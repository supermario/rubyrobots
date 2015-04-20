# require 'browser'

TkRobot = Struct.new(:body, :gun, :radar, :speech, :info, :status, :health)

class Arena
  attr_reader :battlefield, :xres, :yres
  attr_accessor :speed_multiplier, :on_game_over_handlers
  attr_accessor :canvas, :boom, :robots, :bullets, :explosions, :colors, :team_colors
  attr_accessor :default_skin_prefix

  def initialize(battlefield, xres, yres, speed_multiplier)
    @battlefield = battlefield
    @xres, @yres = xres, yres
    @speed_multiplier = speed_multiplier
    @explosion_colors = [
      '#f7c511',
      '#f1b800',
      '#ee9500',
      '#e88302',
      '#e67504',
      '#db6903',
      '#333',
      '#222'
    ]

    @team_colors = [['#d00', '#900'], ['#77f', '#337']]
    @text_colors = ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#00ffff', '#ff00ff', '#ffffff', '#777777']
    @default_skin_prefix = 'images/red_'
    @on_game_over_handlers = []
    init_canvas
    init_simulation
  end

  def on_game_over(&block)
    @on_game_over_handlers << block
  end

  def init_canvas
    @two = `new Two({width: #{xres}, height: #{yres}})`
    @two = Native(@two)
    arena = $document['arena']
    $document['arena'].inner_html = ""
    @two.appendTo arena
  end

  def init_simulation
    @robots, @bullets, @explosions = {}, {}, {}
  end

  def draw_frame
    simulate(@speed_multiplier)
    draw_battlefield
  end

  def simulate(ticks = 1)
    @explosions = @explosions.reject { |e, tko| tko.remove if e.dead; e.dead }
    @bullets = @bullets.reject { |b, tko| tko.remove if b.dead; b.dead }
    @robots = @robots.reject do |ai, tko|
      if ai.dead
        # tko.status.configure(:text => "#{ai.name.ljust(20)} dead")
        tko.body.fill = '#777'
        tko.gun.fill = '#777'
        tko.radar.remove
        # tko.each{|part| part.remove if part != tko.status}
        true
      end
    end
    ticks.times do
      if @battlefield.game_over
        @interval.stop
        @on_game_over_handlers.each { |h| h.call(@battlefield) }
      end
      @battlefield.tick
    end
  end

  def draw_battlefield
    draw_robots
    draw_bullets
    draw_explosions

    @two.update
  end

  def draw_robots
    @battlefield.robots.each_with_index do |ai, i|
      next if ai.dead

      if @robots[ai]
        robot = @robots[ai]
      else
        robot = TkRobot.new
        @robots[ai] = robot

        size = ai.size / 2
        scale = size / 16.0
        width = 16.0 / size
        longest_line = xres * xres + yres * yres
        primary_color = @team_colors[ai.team].first
        secondary_color = @team_colors[ai.team].last

        radar = @two.makeLine 0, 0, 0, longest_line
        radar.translation.set 0, -longest_line / 2

        radar_group = @two.makeGroup radar
        radar_group.stroke = secondary_color # '#ddd'
        radar_group.linewidth = 2

        left_track = @two.makeRectangle -6, 0, 4, 16
        right_track = @two.makeRectangle 6, 0, 4, 16
        left_track.fill = right_track.fill = '#aaa'

        body = @two.makePolygon -4, -7,
                                0, -9,
                                4, -7,
                                4, 7,
                                -4, 7
        body.fill = secondary_color

        body_group = @two.makeGroup left_track, right_track, body
        body_group.scale = scale
        body_group.linewidth = 2 * width

        turret = @two.makePolygon -4, -4,
                                  0, -6,
                                  4, -4,
                                  4, 4,
                                  -4, 4
        turret.fill = primary_color

        gun = @two.makeRectangle 0, -10, 2, 8
        gun.fill = '#ddd'

        gun_group = @two.makeGroup turret, gun
        gun_group.scale = scale
        gun_group.linewidth = 2 * width

        robot.body = body_group
        robot.gun = gun_group
        robot.radar = radar_group
      end

      robot.body.rotation = (90 - ai.heading) / 180.0 * Math::PI
      robot.body.translation.set ai.x / 2, ai.y / 2

      robot.gun.rotation = (90 - ai.gun_heading) / 180.0 * Math::PI
      robot.gun.translation.set ai.x / 2, ai.y / 2

      robot.radar.translation.set ai.x / 2, ai.y / 2
      robot.radar.rotation = (90 - ai.radar_heading) / 180.0 * Math::PI

      # Robot health bars
      @two.remove robot.health if robot.health
      health = @two.makeRectangle 0, ai.size / 2, ai.energy / 2, 4
      health.fill = '#1e8ad1'
      health_bg = @two.makeRectangle 0, ai.size / 2, 50, 4
      health_bg.fill = '#666'

      robot.health = @two.makeGroup health_bg, health
      robot.health.translation.set ai.x / 2, ai.y / 2

    end
  end

  def draw_bullets
    @battlefield.bullets.each do |bullet|
      if @bullets[bullet]
        bullet_circle = @bullets[bullet]
      else
        bullet_circle = @two.makeCircle 0, 0, 2
        bullet_circle.fill = '#FF8000'
        bullet_circle.stroke = '#FF4500'
        bullet_circle.linewidth = 2

        @bullets[bullet] = bullet_circle
      end

      bullet_circle.translation.set bullet.x / 2, bullet.y / 2
    end
  end

  def draw_explosions
    @battlefield.explosions.each do |explosion|

      if @explosions[explosion]
        explosion_circle = @explosions[explosion]
      else
        explosion_circle = @two.makeCircle 0, 0, 24
        explosion_circle.opacity = 0.5
        explosion_circle.fill = '#FF8000'
        explosion_circle.linewidth = 0

        @explosions[explosion] = explosion_circle
      end

      explosion_circle.translation.set explosion.x / 2, explosion.y / 2
      explosion_circle.scale = (2 - Math.cos(explosion.t / 16.0 * Math::PI)) / 3
      explosion_circle.fill = @explosion_colors[(explosion.t / 2).to_i]
    end
  end

  def run
    @interval = every(1 / 25) { draw_frame }
  end
end
