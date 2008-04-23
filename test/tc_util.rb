require File.dirname(__FILE__) + '/test_helper'

class TestUtil < Test::Unit::TestCase
  def test_array_sampling
    t = testdata("fed_cp.csv")
    e = Extractor::CustomExtractor.new(testdata("custom_fed.rb"))
    e.run(t)
    coldata = e.data.map{|row| row[5]}
    assert_equal(2449, coldata.size)
    sampling = coldata.sample
    assert sampling.size < coldata.size
    assert sampling.size <= 300 # could be lower if random function hits & rejects duplicates
    assert sampling.size > 290 # but unlikely to be too much lower
  end
end

