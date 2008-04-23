require File.dirname(__FILE__) + '/test_helper'

class TestDimension < Test::Unit::TestCase
  def test_empty_dim
    dim = Dataset::Dimension.new(:name => "color")
    assert dim.values.empty?
  end
end
