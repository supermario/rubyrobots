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
