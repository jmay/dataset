require File.dirname(__FILE__) + '/test_helper'

# require "yaml"
# require "open-uri"
# 
# require "util"
# require "extractor"
# require "unit"
# require "measure"

# $KCODE = "UTF8"

class TestExtractor < Test::Unit::TestCase
  def test_whitespace
    e = Extractor::WhitespaceExtractor.new
    # puts e.class
    # puts e.class.methods - Object.methods
    # e.class.dumpme
    assert_match(/Raw ASCII/, e.desc)
    data = e.extract(fixture("whitespace.txt").read)
    assert_equal(2, data.size)
    assert_equal(2, data[0].size)
  end

  def test_csv
    e = Extractor::CSVExtractor.new
    data = e.extract(fixture("test.csv").read)
    assert_nil(e.title)
    assert_equal(3, data.size)
    assert_equal(2, data[0].size)
    assert_equal("text", data[2][1])
  end

  def test_economagic
    e = Extractor::EconomagicExtractor.new
    data = e.extract(fixture("economagic.html").read)
    assert_equal("Civilian Labor Force; (Thousands): SA", e.title)
    assert_equal(:thousand, e.multiplier)
    assert_equal("Civilian Labor Force", e.measure)
    assert_equal(709, data.size)
    assert_equal(3, data[100].size)
  end

  def test_econstats
    e = Extractor::EconstatsExtractor.new
    data = e.run(fixture("econstats.html").read)
    assert_equal(434, data.size)
    assert_equal(7, data[100].size)
  end

  def test_whitespace_with_headers
    e = Extractor::WhitespaceExtractor.new(:headerlines => 2)
    e.run(fixture("whitespace2.txt").read)
    assert_equal(2, e.data.size)
    assert_equal(2, e.data[0].size)
    assert_equal(2, e.headers.size)
    
    e2 = Extractor::WhitespaceExtractor.new
    e2.run(fixture("whitespace2.txt").read)
    assert_equal(4, e2.data.size)
    e2.headerlines = 2
    e2.run(fixture("whitespace2.txt").read)
    assert_equal(2, e2.data.size)
  end

  def test_gdp
    e = Extractor::EconomagicExtractor.new
    data = e.extract(fixture("gdp.html").read)
    assert_equal("Gross domestic product: Gross Domestic Product: Billions of dollars (annual)", e.title)
    assert_equal(:billion, e.multiplier)
    assert_equal("Gross domestic product", e.measure)
    assert_equal(78, data.size)
    assert_equal(3, data[50].size)
  end

  def test_co2
    e = Extractor::CSVExtractor.new
    data = e.extract(fixture("co2.csv").read)
    assert_nil(data.find {|row| row.size != 8}) # all rows should have 8 columns
  end

  def test_should_reset_on_rerun
    e = Extractor::WhitespaceExtractor.new(:headerlines=>2)
    e.run(fixture("whitespace2.txt").read)
    assert_equal(2, e.headers.size)
    e.run(fixture("whitespace2.txt").read)
    assert_equal(2, e.headers.size)
  end

  def test_yaml_should_only_have_params
    e = Extractor::WhitespaceExtractor.new(:headerlines=>2)
    e.run(fixture("whitespace2.txt").read)
    e2 = YAML.load(e.to_yaml)
    assert_nil(e2.data)
  end

  # tab-separated columns, allows spaces within the columns values (e.g. in the headers)
  def test_tsv
    e = Extractor::TSVExtractor.new(:headerlines=>1)
    e.run(fixture("tsv.txt").read)
    assert_equal("The Big Number", e.headers[1])
  end

  def test_bls
    e = Extractor::BLSExtractor.new
    e.run(testdata("bls_cpi.html"))
    assert_match(/SUUR0000SA0/, e.title)
    assert_match(/: Consumer Price Index/, e.title)
    assert e.data.find_all {|row| row[2] == "Annual"}.empty?
    assert_equal(5, e.headers.size)
    assert_equal("Series Id", e.headers[0])
    assert_match(/Not Seasonally Adjusted/, e.columns[3][:notes])
    assert_match(/Area:\s+U.S./, e.columns[3][:notes])
    assert_equal("Consumer Price Index", e.columns[3][:label])
    assert_equal(:ones, e.columns[3][:multiplier])
    assert_equal(86, e.data.size)
    assert_equal(12, e.notes.size)
  end

  def test_bea5
    # e = Extractor::BEAExtractor.new
    e = Extractor::CustomExtractor.new(testdata("custom_bea.rb"))
    e.run(fixture("bea_table5.csv").read)
    assert_equal("Table 1.1.5. Gross Domestic Product", e.title)
    assert !e.notes.empty?
    assert_equal(80, e.headers.size)
    assert_equal("1929", e.headers[2])
    assert_equal(24, e.data.size)
    assert_equal(:billion , e.multiplier)
    assert_equal(Dataset::Units::Dollars, e.units)
  end

  def test_gs10
    e = Extractor::FedExtractor.new
    e.run(fixture("fed_gs10.txt").read)
    assert_equal("10-Year Treasury Constant Maturity Rate", e.title)
    assert !e.notes.empty?
    assert_equal(2, e.headers.size)
    assert_equal(647, e.data.size)
    assert_equal(2, e.data[0].size)
  end

  def test_array_of_hashes
    aoh = ArrayOfHashes.new
    assert_equal({}, aoh[4])
  end

  def test_aluminium
    e = Extractor::EconstatsExtractor.new
    e.run(fixture("aluminium.html").read)
    assert_equal("Exchange Aluminium Futures Volume London  Data Prices Metals . LME Open", e.title)
    assert_not_nil(e.notes)
    assert_equal("LME : Aluminium Cash", e.columns[1][:label])
    assert_equal(218, e.data.size)
    assert_equal(9, e.data[100].size)
  end

  def test_unknown_html_source
    e = Extractor::HTMLExtractor.new
    e.run(fixture("wikipedia.html").read)
    assert_equal("Gross domestic product - Wikipedia, the free encyclopedia", e.title)
    assert_nil(e.data)
  end

  def test_bea6
    # e = Extractor::BEAExtractor.new
    e = Extractor::CustomExtractor.new(testdata("custom_bea.rb"))
    e.run(fixture("bea_table6.csv").read)
    assert_equal("Table 1.1.6. Real Gross Domestic Product, Chained Dollars", e.title)
    # puts e.data.map {|line| line.join(',')}
    assert_equal(25, e.data.size)
    assert_equal(8, e.notes.split("\n").size)
  end

  # test HTML Table extraction, both with the built-in and custom modules
  def test_html_tables
    e = Extractor::HTMLTableExtractor.new(:headerlines => 1)
    e.run(fixture("infoplease.html").read)
    assert_match(/Per Capita Personal Income by State .* Infoplease.com/, e.title)
    assert_equal(52, e.data.size)
    assert_equal(11, e.data[0].size)
    assert_equal("State", e.headers[0])
    assert_equal("1990", e.headers[2])
    assert_equal(2, e.properties.size)

    # should skip blank rows
    e = Extractor::HTMLTableExtractor.new(:headerlines => 1)
    e.run(testdata("worldpop.html"))
    assert_equal(101, e.data.size)

    ce = Extractor::CustomExtractor.new(testdata("html_table_with_header.rb"))
    ce.run(testdata("cia_oil.html"))
    assert_equal(209, ce.data.size) # rows
    assert_equal(4, ce.data[0].size) # columns
    assert_equal("Oil - production (bbl/day)", ce.headers[2])
  end

  def test_all
    labels = Extractor.all
    assert_equal(11, labels.size)
  end

  def test_find_by_desc
    assert_equal(Extractor::HTMLTableExtractor, Extractor.find_by_desc("HTML table inside a web page"))
    assert_equal(Extractor::WhitespaceExtractor, Extractor.find_by_desc("Raw ASCII text, fields delimited by whitespace"))
    assert_equal(Extractor::TSVExtractor, Extractor.find_by_desc("Raw ASCII text, fields delimited by single tabs"))
  end

  def test_tcsdaily
    e = Extractor::HTMLTableExtractor.new(:headerlines => 1)
    e = YAML.load(e.to_yaml)
    e.run(fixture("tcsdaily.html").read)
    assert_equal(14, e.data.size)
  end

  def test_guess
    assert_kind_of(Extractor::HTMLTableExtractor, Extractor.choose("text/html", fixture("infoplease.html").read))
    assert_kind_of(Extractor::WhitespaceExtractor, Extractor.choose("text/plain", fixture("whitespace.txt").read))
    assert_kind_of(Extractor::CSVExtractor, Extractor.choose("text/plain", fixture("test.csv").read))
    assert_kind_of(Extractor::TSVExtractor, Extractor.choose("text/plain", fixture("tsv.txt").read))
    assert_kind_of(Extractor::HTMLTableExtractor, Extractor.choose("text/html", fixture("tcsdaily.html").read))
    assert_nil(Extractor.choose("text/html", fixture("wikipedia.html").read))
  end

  def test_tables_with_th
    data = fixture("infoplease_health.html").read
    e = Extractor.choose("text/html", data)
    e.headerlines = 1
    e = YAML.load(e.to_yaml)
    e.run(data)
    assert_equal(8, e.headers.size)
    assert_equal(20, e.data.size)
  end

  def test_custom1
    code = <<_EOT_
split_by_newline
split_by_tabs
headerlines(1)
_EOT_

    data = fixture("tsv.txt").read
    ce = Extractor::CustomExtractor.new(code)
    ce = YAML.load(ce.to_yaml)
    ce.run(data)
    assert_equal("The Big Number", ce.headers[1])
    assert_equal(3, ce.data.size)
    assert_equal(2, ce.data[0].size)
  end

  def test_custom2
    code = fixture("custom2.rb").read
    data = fixture("m3series.txt").read
    ce = Extractor::CustomExtractor.new(code)
    ce = YAML.load(ce.to_yaml)
    ce.run(data)
    assert_equal("Dec", ce.headers.last)
    assert_equal(6, ce.data.size)
    assert_equal(14, ce.data[3].size)
    assert_equal("AMTMNO - Adjusted New Orders - Total Manufacturing", ce.data[0][0])
  end

  def test_custom_transformation
    code = fixture("custom3.rb").read
    source = fixture("../rows_and_columns.txt").read
    ce = Extractor::CustomExtractor.new(code)
    ce = YAML.load(ce.to_yaml)
    ce.run(source)
    assert_equal(36, ce.data.size)
    assert_equal(0, ce.headers.size)
  end

  def test_custom_m3
    code = fixture("../custom_m3.rb").read
    source = fixture("../m3series_full.txt").read
    ce = Extractor::CustomExtractor.new
    ce.code = code
    ce = YAML.load(ce.to_yaml)
    assert_equal(1, ce.properties.size)
    ce.run(source)
    assert_equal(104 + 2, ce.headers.size)  # 104 series codes, plus Year, Month
    assert_equal("AMTMNO", ce.headers[2])
    assert_equal(192, ce.data.size) # 16 years * 12 months
    assert_equal(ce.headers.size, ce.data[-1].size)
  end

  def test_custom_fed
    ce = Extractor::CustomExtractor.new(testdata("custom_fed.rb"))
    ce.run(testdata("fed_cp.csv"))
    assert_equal(31, ce.columns.size)
    assert_equal(2449, ce.data.size)
    ce.columns[1..-1].each {|col| assert_match(/^CP\/VOL\//, col[:notes])}

    ce.run(testdata("fed_g17_summary.csv"))
    assert_equal(Dataset::Units::Artificial, ce.columns[1][:units])
    assert_equal(Dataset::Units::Percentage, ce.columns.last[:units])
  end

  def test_oil_price_extractor
    ce = Extractor::CustomExtractor.new(testdata("oil_price_extractor.rb"))
    ce.run(testdata("world_oil_prices.html"))
    assert_equal("All Countries Spot Price FOB Weighted by Estimated Export Volume (Dollars per Barrel)", ce.title)
    assert_equal(571, ce.data.size)
    assert_equal("1978/01/06", ce.data.first[0])
    assert_equal("2007/09/28", ce.data.last[0])
  end

  def test_xls_extraction
    ce = Extractor::CustomExtractor.new(testdata("budget_history_xls_extractor.rb"))
    ce.run(testdata("hist01z2.xls"))
    assert_equal(86, ce.data.size) # rows
    assert_equal(11, ce.data[5].size)  # columns
    assert_equal(11, ce.headers.size)
    assert_equal("Outlays", ce.headers[3])
  end

  def test_custom_html_table_chooser
    ce = Extractor::CustomExtractor.new("html\nchoose_table")
    ce.run(testdata("world_oil_prices2.html"))
    assert_equal(45, ce.data.size)
  end
end
