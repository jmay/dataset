require File.dirname(__FILE__) + '/test_helper'

# require "fileutils"
# 
# require "caching"
# require "source"
# require "parser"
# require "extractor"
# require "chron"
# require "measure"
# require "unit"
# # require "dataset"
# require "series"
# # require "caching"


class TestSource < Test::Unit::TestCase
  @@text1 = <<_EOT_
1999  47
2000  83
2001  112
_EOT_

  def test_new
    source = Dataset::Source.new(:text => @@text1)
    parser = source.analyze
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    assert_equal(Dataset::Units::Discrete, parser.columns[1].role.units)
  end
  
  # def test_dataset
  #   source = Dataset::Source.new(:text => @@text1, :primary_url => "http://www.source.com/foobar")
  #   source.parse
  #   dataset = Dataset::Dataset.new(:source => source)
  #   assert_equal(3, dataset.series.first.data.size)
  # end

  # def test_save
  #   # Dataset::Source.cachedir = cachedir = "/tmp/cache"
  #   @s1.save
  #   assert(File.exist?(@s1.cachefile), "Failed to save source.")
  #   s2 = Dataset::Source.load(@s1.name)
  #   assert_equal(@s1.primary_url, s2.primary_url)
  #   Dataset::Source.purge(@s1.name)
  # end

  def test_analyze
    s = Dataset::Source.new(:text => @@text1)
    parser = s.analyze
    assert_not_nil(parser)
#     assert_equal(/\s+/, parser.column_delimiter)
    assert_equal(2, parser.columns.size)
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
    assert_kind_of(Dataset::Measure, parser.columns[1].role)
  end
end
