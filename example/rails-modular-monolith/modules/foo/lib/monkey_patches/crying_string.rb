class String
  def +(other)
    decorated = dup
    decorated.concat(" ༼;´༎ຶ ۝ ༎ຶ༽ ")
    decorated.concat(other.to_s)
    decorated
  end
end
