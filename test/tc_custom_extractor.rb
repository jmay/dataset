require File.dirname(__FILE__) + '/test_helper'

# require "yaml"
# require "open-uri"
# require "English"

require "util"
require "extractor"
require "unit"
require "measure"

class TestExtractor < Test::Unit::TestCase
  def test_html
    ce = Extractor::CustomExtractor.new("html")
    ce.run(testdata("world_oil_prices.html"))
    assert_equal("All Countries Spot Price FOB Weighted by Estimated Export Volume (Dollars per Barrel)", ce.title)
  end

  def test_title
    ce = Extractor::CustomExtractor.new("self.title = 'xyz'")
    ce.run("dummy")
    assert_equal("xyz", ce.title)
  end

  def test_notes
    ce = Extractor::CustomExtractor.new("self.notes = 'xyz'")
    ce.run("dummy")
    assert_equal("xyz", ce.notes)
  end

  def test_bls_cpi
    ce = Extractor::CustomExtractor.new(testdata("custom_bls_cpi.rb"))
    ce.run(testdata("bls_cpi.html"))
    assert_equal("SUUR0000SA0 Consumer Price Index - Chained Consumer Price Index", ce.title)
    assert_equal(5, ce.headers.size)
    assert_equal(4, ce.data.first.size)
    assert_equal(86, ce.data.size)
  end

  def test_bls_spending
    ce = Extractor::CustomExtractor.new(testdata("custom_bls_cex.rb"))
    ce.run(testdata("bls_consumer_spending.html"))
    assert_equal("CXUHCI002A2 - Health insurance - Total complete income reporters", ce.title)
    assert_equal(4, ce.headers.size)
    assert_equal("Series Id", ce.headers[0])
    assert_equal("Health insurance", ce.columns[3][:label])
    assert_equal(4, ce.data.first.size)
    assert_equal(20, ce.data.size)
  end

  def test_csv_parsing
    ce = Extractor::CustomExtractor.new("csv")
    txt = testdata("csv_test_data.txt")
    ce.run(txt)
    assert !ce.data.empty?
    assert !ce.errors.empty?

    csv = []
    assert_raise(CSV::IllegalFormatError) { CSV.parse(txt) } # this throws an exception
    assert_raise(FasterCSV::MalformedCSVError) { FasterCSV.parse(txt) } # so does this
    txt.each_line {|line| csv << CSV.parse_line(line)} # CSV.parse_line ignores the exceptions

    ce.run(testdata("csv_test_data2.txt").gsub!(/\n/, "\r"))
    assert_equal(3, ce.data.size) # not skipping empty lines
    assert_equal("42", ce.data[0][1]) # should strip leading/trailing blanks
    assert_equal("37.0", ce.data[0][2]) # stripping again
  end

  def test_bls_spending_should_indicate_measure
    ce = Extractor::CustomExtractor.new(testdata("custom_bls_cex.rb"))
    ce.run(testdata("bls_cex_notmonths.html"))
    assert_kind_of(Dataset::Measure, ce.columns.last[:role])
  end

  def test_custom_bea
    ce = Extractor::CustomExtractor.new(testdata("custom_bea.rb"))
    ce.run(testdata("bea_gdp.csv"))
    assert_equal("Table 1.1.5. Gross Domestic Product", ce.title)
    assert_match(/Downloaded on/, ce.notes)
    assert_equal(245, ce.headers.size)
    assert_equal("1947Q1", ce.headers[2])
    assert_equal(24, ce.data.size)
    assert_equal(:billion , ce.multiplier)
    assert_equal(Dataset::Units::Dollars, ce.units)
  end

  def test_bea_115
    e = Extractor::CustomExtractor.new(testdata("custom_bea.rb"))
    e.run(testdata("bea_115.csv"))
    assert_equal("Table 1.15. Price, Costs, and Profit Per Unit of Real Gross Value Added of Nonfinancial Domestic Corporate Business", e.title)
    assert_equal(9, e.data.size)
    assert_equal(Dataset::Units::Dollars, e.data[2][1].units)
    assert_equal(:ignore, e.columns.first[:role])
  end

  def test_fred_housing_starts
    e = Extractor::CustomExtractor.new(testdata("custom_fred.rb"))
    e.run(testdata("fred_houst.txt"))
    assert_equal("Housing Starts: Total: New Privately Owned Housing Units Started", e.title)
    assert_equal(:thousand, e.multiplier)
    assert_equal(Dataset::Units::Discrete, e.units)
    assert_equal(587, e.data.size)
  end

  def test_tsv_should_strip_whitespace
    e = Extractor::CustomExtractor.new("tsv")
    e.run("2001  \t  42\n2002  \t 123\n")
    assert_equal([["2001", "42"], ["2002", "123"]], e.data)
  end

  def test_autoheaders_should_pass_silently_if_it_does_not_recognize_any_headers
    ce = Extractor::CustomExtractor.new("csv\nautoheaders")
    ce.run("")
    assert ce.headers.empty?
    ce.run("2001,10\n2002,20\n2003,30\n")
    assert ce.headers.empty?
  end
end
