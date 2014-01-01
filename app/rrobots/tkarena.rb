TkRobot = Struct.new(:body, :gun, :radar, :speech, :info, :status)

class TkArena

  attr_reader :battlefield, :xres, :yres
  attr_accessor :speed_multiplier, :on_game_over_handlers
  attr_accessor :canvas, :boom, :robots, :bullets, :explosions, :colors, :team_colors
  attr_accessor :default_skin_prefix

  def initialize battlefield, xres, yres, speed_multiplier
    @native_window ||= Native `window`
    @battlefield = battlefield
    @xres, @yres = xres, yres
    @speed_multiplier = speed_multiplier
    @team_colors = [['#d00', '#900'], ['#77f', '#337']]
    @text_colors = ['#ff0000', '#00ff00', '#0000ff', '#ffff00', '#00ffff', '#ff00ff', '#ffffff', '#777777']
    @default_skin_prefix = "images/red_"
    @on_game_over_handlers = []
    init_canvas
    init_simulation
  end

  def on_game_over(&block)
    @on_game_over_handlers << block
  end

  def read_gif name, c1, c2, c3
    data = nil
    open(name, 'rb') do |f|
      data = f.read()
      ncolors = 2**(1 + data[10][0] + data[10][1] * 2 + data[10][2] * 4)
      ncolors.times do |j|
        data[13 + j * 3 + 0], data[13 + j * 3 + 1], data[13 + j * 3 + 2] =
          data[13 + j * 3 + c1], data[13 + j * 3 + c2], data[13 + j * 3 + c3]
      end
    end
    TkPhotoImage.new(:data => Base64.encode64(data))
  end

  def usage
    puts "usage: rrobots.rb <FirstRobotClassName[.rb]> <SecondRobotClassName[.rb]> <...>"
    puts "\tthe names of the rb files have to match the class names of the robots"
    puts "\t(up to 8 robots)"
    puts "\te.g. 'ruby rrobots.rb SittingDuck NervousDuck'"
    exit
  end

  def init_canvas
    options = {
      width: xres,
      height: yres
    }
    @two = Native `new Two(#{options})`
    @two.appendTo $document.body
    # rect = @two.makeRectangle 200, 200, 20, 30
    # rect.fill = '#00f'
    # rect.rotation = (60.0 / 180.0) * Math::PI
    # circle = two.makeCircle 72, 100, 50
    # circle.fill = '#ff8000'
    # circle.stroke = 'orangered'
    # circle.linewidth = 5
    # two.update
  end

  def init_simulation
    @robots, @bullets, @explosions = {}, {}, {}
  end

  def draw_frame
    simulate(@speed_multiplier)
    draw_battlefield
  end

  def simulate(ticks=1)
    @explosions = @explosions.reject{|e,tko| tko.remove if e.dead; e.dead }
    @bullets = @bullets.reject{|b,tko| tko.remove if b.dead; b.dead }
    @robots = @robots.reject do |ai,tko|
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
        @native_window.clearInterval @interval
        @on_game_over_handlers.each{|h| h.call(@battlefield) }
        unless true # @game_over
          winner = @robots.keys.first
          whohaswon = if winner.nil?
            "Draw!"
          elsif @battlefield.teams.all?{|k,t|t.size<2}
            "#{winner.name} won!"
          else
            "Team #{winner.team} won!"
          end
          text_color = winner ? winner.team : 7
          @game_over = TkcText.new(canvas,
            :fill => @text_colors[text_color],
            :anchor => 'c', :coords => [400, 400], :font => 'courier 36', :justify => 'center',
            :text => "GAME OVER\n#{whohaswon}")
        end
      end
      @battlefield.tick
    end
  end

  def draw_battlefield
    draw_robots
    draw_bullets
    # draw_explosions

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
        longest_line = Math::hypot(xres, yres)
        primary_color = @team_colors[ai.team].first
        secondary_color = @team_colors[ai.team].last

        radar = @two.makeLine 0, 0, 0, longest_line
        radar.translation.set 0, -longest_line / 2

        radar_group = @two.makeGroup radar
        radar_group.stroke = '#ddd'
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

      # robot.body.rotation = 0
      # robot.body.translation.set 0, 0
      robot.body.rotation = (90 - ai.heading) / 180.0 * Math::PI
      robot.body.translation.set ai.x / 2, ai.y / 2

      robot.gun.rotation = (90 - ai.gun_heading) / 180.0 * Math::PI
      robot.gun.translation.set ai.x / 2, ai.y / 2

      robot.radar.translation.set ai.x / 2, ai.y / 2
      robot.radar.rotation = (90 - ai.radar_heading) / 180.0 * Math::PI

      if false

      # Struct.new(:body, :gun, :radar, :speech, :info, :status)
      @robots[ai] ||= TkRobot.new(
        TkcImage.new(@canvas, 0, 0),
        TkcImage.new(@canvas, 0, 0),
        TkcImage.new(@canvas, 0, 0),
        TkcText.new(@canvas,
        :fill => @text_colors[ai.team],
        :anchor => 's', :justify => 'center', :coords => [ai.x / 2, ai.y / 2 - ai.size / 2]),
        TkcText.new(@canvas,
        :fill => @text_colors[ai.team],
        :anchor => 'n', :justify => 'center', :coords => [ai.x / 2, ai.y / 2 + ai.size / 2]),
        TkcText.new(@canvas,
        :fill => @text_colors[ai.team],
        :anchor => 'nw', :coords => [10, 15 * i + 10], :font => TkFont.new("courier 9")))

      @robots[ai].body.configure( :image => @colors[ai.team].body[(ai.heading+5) / 10],
                                  :coords => [ai.x / 2, ai.y / 2])
      @robots[ai].gun.configure(  :image => @colors[ai.team].gun[(ai.gun_heading+5) / 10],
                                  :coords => [ai.x / 2, ai.y / 2])
      @robots[ai].radar.configure(:image => @colors[ai.team].radar[(ai.radar_heading+5) / 10],
                                  :coords => [ai.x / 2, ai.y / 2])
      @robots[ai].speech.configure(:text => "#{ai.speech}",
                                   :coords => [ai.x / 2, ai.y / 2 - ai.size / 2])
      @robots[ai].info.configure(:text => "#{ai.name}\n#{'|' * (ai.energy / 5)}",
                                 :coords => [ai.x / 2, ai.y / 2 + ai.size / 2])
      @robots[ai].status.configure(:text => "#{ai.name.ljust(20)} #{'%.1f' % ai.energy}")

      end
    end
  end

  def draw_bullets
    @battlefield.bullets.each do |bullet|
      if @bullets[bullet]
        bullet_circle = @bullets[bullet]
      else
        bullet_circle = @two.makeCircle 0, 0, 2.5
        bullet_circle.fill = '#FF8000'
        bullet_circle.stroke = '#FF4500'
        bullet_circle.linewidth = 2

        @bullets[bullet] = bullet_circle
      end

      bullet_circle.translation.x = bullet.x / 2
      bullet_circle.translation.y = bullet.y / 2

      if false
      @bullets[bullet] ||= TkcOval.new(
        @canvas, [-2, -2], [3, 3],
        :fill=>'#'+("%02x" % (128+bullet.energy*14).to_i)*3)
      @bullets[bullet].coords(
        bullet.x / 2 - 2, bullet.y / 2 - 2,
        bullet.x / 2 + 3, bullet.y / 2 + 3)
      end
    end
  end

  def draw_explosions
    @battlefield.explosions.each do |explosion|
      @explosions[explosion] ||= TkcImage.new(@canvas, explosion.x / 2, explosion.y / 2)
      @explosions[explosion].image(boom[explosion.t])
    end
  end

  def run
    @interval = @native_window.setInterval proc { draw_frame }, 40
  end

end
