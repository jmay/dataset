require File.dirname(__FILE__) + '/test_helper'

# require "util"
# require "parser"
# require "source"
# require "extractor"
# require "series"
# require "dimension"
# require "measure"
# require "unit"
# require "chron"

class TestParser < Test::Unit::TestCase

  @@text1 = <<_EOT_
1999  47
2000  83
2001  112
_EOT_

  @@text2 = <<_EOT_
1998-99	473,182
1999-00	506,222
2000-01	559,001
2001-02	601,987
_EOT_

  @@text3 = <<_EOT_
Year	Amount
1998	473,182
1999	506,222
_EOT_

  @@text4 = <<_EOT_
1998  23.15
1999  62.7
_EOT_

  @@text5 = <<_EOT_
2006.09  end             1.2660           117.96           1.5449           1.8680           1.1166
2006.08  end             1.2851           117.16           1.5219           1.9064           1.1073
2006.07  end             1.2767           114.22           1.5319           1.8656           1.1237

2006.06  end             1.2713           114.65           1.5384           1.8370           1.1116
2006.05  end             1.2868           112.15           1.5199           1.8762           1.0963


_EOT_

  @@text6 = <<_EOT_
1999  47  22  62
2000  83  35  107
2001  112 na  146
_EOT_

  @@text7 = <<_EOT_
2000	blue	100
2000	blue	200
2000	blue	300
2001	red	400
2001	red	500
2001	red	600
2002	green	700
2002	green	800
2002	green	900
_EOT_

  @@text8 = <<_EOT_
Data  Important
Year  Quantity

----  --------
___ _______   
1999  47    
2000  83    
2001  112  
_EOT_

  @@text9 = <<_EOT_
1999  47
2000  83
2001  112
2001  112
2002  200
2003  300
_EOT_

  @@text10 = <<_EOT_
Color 2000  2001  2002
blue  42  17  36
red 107 82  90
green 14  253 8
_EOT_

  @@text11 = <<_EOT_

"1999","47"
"2000","83"
"2001","112"
_EOT_

  @@text12 = <<_EOT_
2006.3  e             11432.900   1.58%           13308.300   3.41%             116.403   1.79% 
2006.2  e             11388.100   2.56%           13197.300   5.94%             115.887   3.30% 
2006.1  e             11316.400   5.58%           13008.400   9.02%             114.951   3.26% 
2005.4  e             11163.800   1.76%           12730.500   5.09%             114.034   3.27% 
2005.3  e             11115.100   4.18%           12573.500   7.57%             113.121   3.25% 
2005.2  e             11001.800   3.26%           12346.100   5.80%             112.219   2.46% 
2005.1  e             10913.800   3.40%           12173.200   6.95%             111.539   3.44% 
2004.4  e             10822.900   2.61%           11970.300   5.92%             110.601   3.22% 
2004.3  e             10753.300   3.10%           11799.400   5.25%             109.728   2.09% 
2004.2  e             10671.500   4.04%           11649.300   7.86%             109.162   3.67% 
2004.1  e             10566.300   3.85%           11430.900   7.75%             108.183   3.76% 
2003.4  e             10467.000   2.65%           11219.500   4.90%             107.190   2.19% 
2003.3  e             10398.700   7.49%           11086.100   9.73%             106.611   2.09% 
2003.2  e             10212.700   3.47%           10831.800   4.80%             106.062   1.28% 
2003.1  e             10126.000   1.20%           10705.600   4.40%             105.724   3.15% 
2002.4  e             10095.800   0.20%           10591.100   2.44%             104.907   2.24% 
2002.3  e             10090.700   2.38%           10527.400   3.92%             104.328   1.51% 
2002.2  e             10031.600   2.19%           10426.600   3.66%             103.938   1.44% 
2002.1  e              9977.300   2.74%           10333.300   4.25%             103.568   1.47% 
2001.4  r              9910.000   1.59%           10226.300   3.65%             103.191   2.03% 
2001.3  r              9871.100  -1.40%           10135.100   0.25%             102.675   1.67% 
2001.2  r              9905.900   1.23%           10128.900   4.36%             102.252   3.09% 
2001.1  r              9875.600  -0.49%           10021.500   2.76%             101.478   3.27% 
2000.4  e              9887.700   2.09%            9953.600   3.76%             100.666   1.63% 
2000.3  e              9836.600  -0.46%            9862.100   1.61%             100.259   2.08% 
2000.2  e              9847.900   6.43%            9822.800   8.28%              99.745   1.73%
_EOT_

  @@text13 = <<_EOT_
Region  Widgets Gadgets
North 42  196
South 17  64
East  83  43
West  60  105
_EOT_

  @@text14 = <<_EOT_
1901	588	525	63	588	525	63	..........	..........	..........
1902	562	485	77	562	485	77	..........	..........	..........
1903	562	517	45	562	517	45	..........	..........	..........
1904	541	584	-43	541	584	-43	..........	..........	..........
1936	3,923	8,228	-4,304	3,923	8,228	-4,304	..........	..........	..........
1937	5,387	7,580	-2,193	5,122	7,582	-2,460	265	-2	267
1938	6,751	6,840	-89	6,364	6,850	-486	387	-10	397
1976	298,060	371,792	-73,732	231,671	301,098	-69,427	66,389	70,695	-4,306
TQ	81,232	95,975	-14,744	63,216	77,281	-14,065	18,016	18,695	-679
1977	355,559	409,218	-53,659	278,741	328,675	-49,933	76,817	80,543	-3,726
_EOT_

  @@text15 = <<_EOT_
  Year	Receipts	Outlays	Surplus or Deficit	Receipts	Outlays	Surplus or Deficit	Receipts	Outlays	Surplus or Deficit
  1901	588	525	63	588	525	63	..........	..........	..........
_EOT_

  @@text16 = <<_EOT_
  Year	Category	Value One	Value Two
  1901	red	525	63
  1902	light blue	400	127
  1903	orange	1525	263
_EOT_

  @@text17 = <<_EOT_

  1998  473,182
 1999    506,222

_EOT_

  @@text18 = <<_EOT_
2005 01 123
2005 02 234
2005 03 345
2005 04 456
2005 05 567
2005 06 678
_EOT_

  @@text19 = <<_EOT_
IGNORE ALL THIS JUNK AT THE TOP
HERE'S ANOTHER LINE TO IGNORE
1999,47
2000,83
2001,112
_EOT_

  @@text20 = <<_EOT_
2004-06-01,293805
2004-07-01,294056
2004-08-01,294323
2004-09-01,294587
_EOT_


  @@classname = self.name
  def fixture_path(name)
    File.dirname(__FILE__) + "/fixtures/" + name
  end
  def fixture(name)
    File.open(fixture_path(name))
  end

  def testdata(name)
    File.open(File.dirname(__FILE__) + "/testdata/#{name}").read
  end

  def test_yyyy_nnn
    parser = Dataset::Parser.new(:input => testdata("simple_source.txt"))
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    # assert_equal(Dataset::Measure::Units, parser.measure)
    assert_equal(1, parser.measure_columns.size)
    assert_equal(Dataset::Units::Discrete, parser.measure_columns[0].role.units)
    parser.measure_columns[0].role.name = "Key Measure"
    parser.measure_columns[0].role.multiplier = :thousand

    # should spit back numbers as they came in (don't convert to Floats if there are no decimals)
    assert_equal("47", parser.measure_columns[0].values[0].number.to_s)

    data, results = parser.commit
    assert_equal(3, results.nrows)
    series = data.make_series
    assert_equal(3, series.data.size)
    assert_equal(Dataset::Units::Discrete, series.measure.units)
    assert_equal(:thousand, series.measure.multiplier)
  end

  def test_school_year
    parser = Dataset::Parser.new(:input => @@text2)
    assert_equal(Dataset::Chron::SchoolYear, parser.chron)
    # assert_equal(Dataset::Measure::Units, parser.measure)
    assert_equal(Dataset::Units::Discrete, parser.columns[1].role.units)
    # assert_equal(4, parser.records.size)
    # assert_equal(473182, parser.records[0][1])

    data, results = parser.commit
    assert_equal(4, results.nrows)
    assert_equal(473182, data.records[0][1])
  end

  def test_should_ignore_header_row
    parser = Dataset::Parser.new(:input => @@text3)
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    assert parser.columns[1].measure?
    assert_equal(Dataset::Units::Discrete, parser.columns[1].role.units)
    # assert_equal(2, parser.records.size)
    assert_equal(1, parser.extractor.headerlines)
    assert_equal("Amount", parser.columns[1].label)
#     assert_raise(RuntimeError) { parser.headers[1] = "New Header" }
    parser.columns[1].label = "Annual Sales"
#     parser.analyze_columns
    assert_equal("Annual Sales", parser.columns[1].label)
    assert_equal("Amount", parser.columns[1].source_label)
  end
  
  def test_continuous_measure
    parser = Dataset::Parser.new(:input => @@text4)
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    assert_equal(Dataset::Units::Continuous, parser.columns[1].role.units)
    # assert_equal(2, parser.records.size)
  end

  def test_multicol
    source = Dataset::Source.new(:text => @@text5)
    parser = Dataset::Parser.new(:source => source)
    # assert_equal(5, parser.records.size)
    assert_equal(7, parser.columns.size)
    assert_equal("1.2767", parser.raw[2][2])
    # assert(parser.columns.last.active?)
    col1 = parser.columns[0]
    # ruby 1.8.6 Date is recognizing "20006.05" as a YYMMDD, so we're getting two possible chron roles
    assert col1.possible_roles.include?(Dataset::Chron::YYYYMM)
    col1.role = Dataset::Chron::YYYYMM
    # assert_equal(Dataset::Chron, parser.columns[0])
    # assert_equal(Dataset::Chron::YYYYMM, parser.columns[0].detail)
    assert_equal(Dataset::Chron::YYYYMM, parser.chron)
    assert_equal(Dataset::Chron::YYYYMM, col1.role)
    # assert_equal(parser.chron, col1.detail)
    assert_equal(:ignore, parser.columns[1].role)
    assert_kind_of(Dataset::Measure, parser.columns[2].role)
    # assert_kind_of(Dataset::Measure, parser.columns[2].detail)
    # parser.measure_columns.each {|c| c.active = false }
    # parser.columns[2].active = true
    # assert(parser.columns[2].active?)
    # assert_equal(1.2767, parser.records[2].last)
    data,results = parser.parse(source)
    assert_equal(7, data.columns.size)
  end

  # "na" values should be transparently ignored in numeric sources
  def test_should_ignore_na
    parser = Dataset::Parser.new(:input => @@text6)
    # parser.measure_columns.each {|c| c.active = false }
    # parser.measure_columns[1].active = true
    # p parser.measure_columns[1]
    # assert_equal(2, parser.records.size)
    # parser.measures[0].units = Dataset::Units::Continuous
    # series = parser.make_series
    # assert_equal(2, series[0].data.size)
  end

  def test_multiply
    parser = Dataset::Parser.new(:input => @@text1)
    # s1 = parser.make_series
    # assert_equal(47, s1[0].data[0][:measure].value)
    # s2 = parser.make_series(:multiplier => :million)
    # assert_equal(47_000_000, s2[0].data[0][:measure].value)
  end

  def test_cat_dims
    parser = Dataset::Parser.new(:input => @@text7)
    # s1 = parser.make_series.first
    # assert_equal(1, s1.dimensions.size)
    # assert_equal(3, s1.dimensions[0].values.size)
  end

  def test_headings
    parser = Dataset::Parser.new(:input => @@text8)
    assert_equal(2, parser.headers.size)
    assert_equal(1, parser.measure_columns.size)
    assert_equal(3, parser.columns[0].distinct_text_values.size)
    assert_equal(Dataset::Chron::YYYY, parser.chron)
  end

  # dup detection no longer throws exceptions, now it records errors
  def test_dup_detection
    parser = Dataset::Parser.new(:input => testdata("duplicate_chrons.txt"))
    data, results = parser.commit
    assert !results.errors.empty?
    series = data.make_series
    assert_not_nil(series)
    assert series.errors.any?
  end

  def test_headerness
    line = "Category  2000  2001  2002"
    values = line.split.map {|v| Dataset::ParsedValue.new(v)}
    assert values.all_satisfy?{|v| !v.number or !v.chron.empty?}
  end

  # TODO: support sources with chrons across the columns; get fixed chron dimension into the DataColumn,
  # or unroll the structure so that the DataColumns represent actual sequences?
  # def test_chrons_in_columns
  #   parser = Dataset::Parser.new(:input => @@text10)
  #   # assert parser.clean?
  #   data, results = parser.commit
  #   p data.columns
  #   # s = parser.make_series.first
  #   # assert_equal(9, s.data.size)
  # end

  def test_csv
    parser = Dataset::Parser.new(:input => @@text11)
    # assert parser.clean?
    assert_equal(Extractor::CSVExtractor, parser.extractor.class)
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    assert_equal(1, parser.measure_columns.size)
    assert_equal(Dataset::Units::Discrete, parser.columns[1].role.units)
    # assert_equal(3, parser.records.size)
    # series = parser.make_series
    # assert_equal(1, series.size)
    # assert_equal(3, series[0].data.size)
    # assert_equal(Dataset::Units::Discrete, series[0].measure.units)

    p2 = Dataset::Parser.new(:input => @@text20)
    assert_equal(Extractor::CSVExtractor, p2.extractor.class)

  end

  def test_multicol2
    parser = Dataset::Parser.new(:input => @@text12)
    # assert_equal(26, parser.records.size)
  end

  def test_nochron
    parser = Dataset::Parser.new(:input => @@text13)
    data, results = parser.commit
    # s1 = parser.make_series.first
    # assert_equal(nil, s1.chron)
    # # p s1.data
    # assert_equal(8, s1.data.size)
    # assert_equal(1, s1.dimensions.size)
  end

  def test_budget
    parser = Dataset::Parser.new(:input => @@text14)
    # assert(parser.clean?, "Should parse cleanly.")
    assert(parser.has_chron?, "Should have a chron column.")
    assert_equal(10, parser.ncolumns)
    # assert(parser.columns.last.active?)
    # p parser.records
    # s1 = parser.make_series.first
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    # assert_equal(4, s1.data.size) # only 4 of the source records are legitimate
  end

  def test_headers_to_columns
    parser = Dataset::Parser.new(:input => @@text15)
  end

  def test_should_ignore_leading_whitespace
    parser = Dataset::Parser.new(:input => @@text17, :extractor => Extractor::WhitespaceExtractor.new)
    assert_equal(Dataset::Chron::YYYY, parser.chron)
    # assert_equal(2, parser.records.size)
    assert_equal(2, parser.columns.size)
  end

  def test_year_month_measure
    source = Dataset::Source.new(:text => @@text18)
    parser = Dataset::Parser.new(:source => source)
    assert_equal(3, parser.columns.size)
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
    assert_equal(Dataset::Chron::Month, parser.columns[1].role)
    assert_kind_of(Dataset::Measure, parser.columns[2].role)
    parser.columns[2].label = "Important Number"
    data, results = parser.commit
    assert_equal(1, data.measures.size)
    s1 = data.make_series
    assert_equal(Dataset::Chron::YYYYMM, s1.chron)
  end

  def test_yaml
    p1 = Dataset::Parser.new(:input => @@text1)
    p2 = YAML.load(p1.to_yaml)
    assert_kind_of(p1.class, p2)
    assert_nil(p2.raw)
    assert_equal(p1.columns.size, p2.columns.size)
    assert_nil(p2.columns[0].distinct_text_values)
    # stuff = { "basicparser" => p1 }
    # File.open("parsers.yml", "w") {|f| f<<stuff.to_yaml}
  end

  def test_parse_results
    s1 = Dataset::Source.new(:text => @@text1)
    p1 = Dataset::Parser.new(:source => s1)
    p2 = YAML.load(p1.to_yaml)
    data, results = p2.parse(s1)
    assert_kind_of(Dataset::SourceData, data)
    assert_equal(Dataset::Chron::YYYY, data.columns[0].role)
    assert_kind_of(Dataset::Measure, data.columns[1].role)
    assert_kind_of(Dataset::ParseResults, results)
    assert_equal(3, results.nrows)
    assert_equal(2, results.ncolumns)
    assert_equal("2000", data.columns[0].values[1].to_s)
    assert_equal(83, data.columns[1].values[1])
    assert_equal(3, data.records.size)
  end

  def test_quarters
    source = Dataset::Source.new(:text => @@text18)
    parser = Dataset::Parser.new(:source => source)
    assert_equal(Dataset::Chron::Month, parser.columns[1].role)
    data, results = parser.commit #parse(source)
    assert_equal(Dataset::Chron::Month, data.columns[1].role)
    assert_equal(results.nrows, data.columns[1].values.compact.size)
    # redefine the column role as Quarter instead
    parser.columns[1].role = Dataset::Chron::Quarter
    data, results = parser.parse(source)
    assert_equal(Dataset::Chron::Quarter, data.columns[1].role)
    assert_equal(4, data.columns[1].values.compact.size)
  end

  def test_bls
    source = Dataset::Source.new(:text => testdata("bls_cpi.html"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::BLSExtractor.new)
    notes = parser.extractor.columns[3][:notes]
    assert_not_nil(notes)
    parser = YAML.load(parser.to_yaml)  # make sure useful info passes unscathed through caching
    assert_equal(4, parser.columns.size)
    assert_equal("Series Id", parser.columns[0].label)
    assert_equal("Year", parser.columns[1].label)
    assert_equal("Period", parser.columns[2].label)
    assert_equal("Consumer Price Index", parser.columns[3].label)
    assert_equal("Consumer Price Index", parser.columns[3].role.name)
    assert_equal(:ones, parser.columns[3].role.multiplier)
    assert_equal(notes, parser.columns[3].role.notes)
    data, results = parser.parse(source)
    assert_equal(notes, data.columns[3].role.notes)
    assert_equal(:ones, data.measures[0].multiplier)
  end

  def test_fed_funds
    source = Dataset::Source.new(:text => fixture("TestParser/fedfunds.txt").read)
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::FedExtractor.new)
    assert_equal(10, parser.extractor.notes.size)
    assert_equal(2, parser.extractor.headers.size)
    assert_equal(631, parser.extractor.data.size)
  end

  def test_horizontal_chrons
    # parser = Dataset::Parser.new(:input => fixture("TestParser/bea_table5.csv").read, :extractor => Extractor::BEAExtractor.new)
    parser = Dataset::Parser.new(:input => fixture("TestParser/bea_table5.csv").read, :extractor => Extractor::CustomExtractor.new(testdata("custom_bea.rb")))
    assert_equal(80, parser.columns.size)

    # assert_equal(2, parser.columns[0].possible_roles.size) # ignore, measure
    # assert_equal(3, parser.columns[1].possible_roles.size) # ignore, dimension, measure-dimension
    # assert_equal(3, parser.columns[2].possible_roles.size) # ignore, measure, chron=

    assert_kind_of(Dataset::Chron::Base, parser.columns[5].role)
    parser.columns[0].role = :ignore
    parser.columns[1].role = :measure
    data, results = parser.commit
    assert_equal(24, data.measures.size)
    assert_equal(:billion, data.measures[0].multiplier)
    data.measures[0].notes = "some notes here"
    assert_not_nil(data.chron)
    assert_raise(RuntimeError) { data.make_series }
    assert_raise(RuntimeError) { data.make_series(:measure => "bogusmeasure") }
    series = data.make_series(:measure => data.measures[0].name)
    assert_equal(78, series.data.size)
    series = YAML.load(series.to_yaml)
    assert_equal(data.measures[0].name, series.measure.name)
    assert_equal(data.measures[0].notes, series.measure.notes)
    assert_equal(Dataset::Chron::YYYY, series.chron)
    assert_equal(:billion, series.measure.multiplier)
    assert_equal(Dataset::Units::Dollars, series.measure.units)
  end

  def test_aluminium
    source = Dataset::Source.new(:text => fixture("TestExtractor/aluminium.html").read)
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::EconstatsExtractor.new)
    assert_equal(9, parser.columns.size)
    [1,3,5,7].each do |i|
      parser.columns[i].role = parser.columns[i].possible_roles.find {|r| r.is_a?(Dataset::Measure)}
    end
    data, results = parser.commit
    assert_equal(218, results.nrows)
    assert_equal("LME : Aluminium Cash", data.measures[0].name)
    series = data.make_series(:measure => data.measures[3].name)
    # verify that #make_series filters out null measures
    assert_equal(188, series.data.size)
    # p series.data
  end

  # def test_nondata_source
  #   source = Dataset::Source.new(:url => "http://en.wikipedia.org/wiki/Gdp")
  #   assert_raise(RuntimeError) { Dataset::Parser.new(:source => source) }
  #   assert_equal("Gross domestic product - Wikipedia, the free encyclopedia", source.title)
  # end

  def test_csv_gwot
    source = Dataset::Source.new(:text => fixture("TestParser/gwot.csv").read)
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::CSVExtractor.new(:headerlines => 1))
    assert_equal(3, parser.columns.size)
    assert_kind_of(Dataset::Dimension, parser.columns[0].role)
    assert_equal("General Purpose", parser.columns[0].role.name)
    assert_kind_of(Dataset::Dimension, parser.columns[1].role)
    assert_kind_of(Dataset::Measure, parser.columns[2].role)
    data, results = parser.commit
    ser = data.make_series
    assert_equal(93, ser.data.size)
    assert_equal("General Purpose", ser.dimensions[0].name)
    assert_nil(ser.chron)
  end

  def test_usda_corn
    source = Dataset::Source.new(:text => fixture("TestParser/usda_corn.csv").read)
    parser = Dataset::Parser.new(:source => source)
    assert_equal(Extractor::CSVExtractor, parser.extractor.class)
    assert_equal("State", parser.columns[3].label)
    assert_equal(:ignore, parser.columns[3].role)
  end

  def test_infoplease
    source = Dataset::Source.new(:text => fixture("TestExtractor/infoplease.html").read)
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::HTMLTableExtractor.new(:headerlines => 1))

    # assert_equal(3, parser.columns[0].possible_roles.size) # ignore, dimension, measure-dimension
    assert_equal("1980", parser.columns[1].label)
    # assert_equal(3, parser.columns[1].possible_roles.size) # ignore, measure, chron=

    data, results = parser.commit
    assert_equal(Dataset::Chron::YYYY, data.chron)
    # assert_nil(data.measures) # parser is now setting a placeholder measure if it can't find one
    parser.measure = Dataset::Measure.new(:name => parser.extractor.title)
    data, results = parser.commit
    assert_equal(parser.measure, data.measures[0])

    series = data.make_series(:measure => parser.extractor.title)
    assert_equal(Dataset::Chron::YYYY, series.chron)
    assert_equal("State", series.dimensions[0].name)
    assert_equal(parser.extractor.title, series.measure.name)
    assert_equal(520, series.data.size)
  end

  def test_bribery
    source = Dataset::Source.new(:text => fixture("TestParser/bribery.html").read)
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::HTMLTableExtractor.new)
    parser = YAML.load(parser.to_yaml)
    assert_equal(5, parser.columns.size)
    
    roles0 = parser.columns[0].possible_roles
    assert roles0.include?(:ignore)
    assert_not_nil roles0.find {|role| role.is_a?(Dataset::Measure)}

    roles1 = parser.columns[1].possible_roles
    assert roles1.include?(:ignore)
    assert roles1.find {|role| role.is_a?(Dataset::Dimension)}
    assert roles1.find {|role| role == :measure}

    roles3 = parser.columns[3].possible_roles
    assert roles3.include?(:ignore)
    assert roles3.find {|role| role.is_a?(Dataset::Measure)}
    assert roles3.find {|role| role.respond_to?(:label)}
  end

  def test_custom2
    code = fixture("TestExtractor/custom2.rb").read
    data = fixture("TestExtractor/m3series.txt").read
    ce = Extractor::CustomExtractor.new(code)
    source = Dataset::Source.new(:text => data)
    parser = Dataset::Parser.new(:source => source, :extractor => ce)
    parser = YAML.load(parser.to_yaml)
#     parser.parse(source)
    assert_equal(Dataset::Chron::YYYY, parser.columns[1].role)
    assert_equal(Dataset::Chron::Month.new(12), parser.columns.last.role)
  end

  def test_rows_and_columns
    source = Dataset::Source.new(:text => fixture("rows_and_columns.txt").read)
    ce = Extractor::CustomExtractor.new(fixture("TestExtractor/custom3.rb").read)
    parser = Dataset::Parser.new(:source => source, :extractor => ce)
    parser = YAML.load(parser.to_yaml) # vanish all but the configuration
    assert_equal(3, parser.columns.size)
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
    assert_equal(Dataset::Chron::Month, parser.columns[1].role)
    source_data, results = parser.parse(source)
    assert_equal(1, source_data.measures.size)
    series = source_data.make_series(:measure => source_data.measures.first.name)
    assert_equal(34, series.data.size)
  end

  def test_custom_m3
    ce = Extractor::CustomExtractor.new(fixture("custom_m3.rb").read)
    source = Dataset::Source.new(:text => fixture("m3series_full.txt").read)
    parser = Dataset::Parser.new(:source => source, :extractor => ce)
    assert_equal(106, parser.columns.size)
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
    assert_equal(Dataset::Chron::Month, parser.columns[1].role)
    assert_kind_of(Dataset::Measure, parser.columns[2].role)
    parser = YAML.load(parser.to_yaml) # vanish all but the configuration
    
    source_data, results = parser.parse(source) #commit
    assert_equal(104, source_data.measures.size)
    series = source_data.make_series(:measure => "AMTMNO")
    assert_equal(182, series.data.size) # not 192, because Jan 1992 and Apr-Dec 2007 are blank
  end

  def test_partial_m3
    ce = Extractor::CustomExtractor.new(fixture("custom_m3.rb").read)
    source = Dataset::Source.new(:text => fixture("m3series_partial.txt").read)
    parser = Dataset::Parser.new(:source => source, :extractor => ce)
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
    assert_equal(Dataset::Chron::Month, parser.columns[1].role)
    assert_kind_of(Dataset::Measure, parser.columns[2].role)
    assert_equal(14, parser.columns.size)
    parser = YAML.load(parser.to_yaml) # vanish all but the configuration
    
    source_data, results = parser.parse(source) #commit
    assert_equal(12, source_data.measures.size)
    many_series = source_data.all_series
    assert_equal(12, many_series.size)
    many_series.each {|s| assert s.data.empty?}
  end

  def test_ignore_rows_with_no_data
    # parser = Dataset::Parser.new(:input => testdata("bea_table2.csv"), :extractor => Extractor::BEAExtractor.new)
    parser = Dataset::Parser.new(:input => testdata("bea_table2.csv"), :extractor => Extractor::CustomExtractor.new(testdata("custom_bea.rb")))
    parser.columns[0].role = :ignore
    parser.columns[1].role = :measure
    data, results = parser.commit
    # p data.measure_dimension_column.values.map {|v| v.name}
    # puts data.measure_dimension_column.values.size
    assert_equal(24, data.measures.size)
  end

  # in BEA table 1.1.6 (real GDP), there are fields containing "---" which should be ignored
  def test_ignore_junk_values
    # parser = Dataset::Parser.new(:input => testdata("../fixtures/TestExtractor/bea_table6.csv"), :extractor => Extractor::BEAExtractor.new)
    parser = Dataset::Parser.new(:input => testdata("../fixtures/TestExtractor/bea_table6.csv"), :extractor => Extractor::CustomExtractor.new(testdata("custom_bea.rb")))
    parser.columns[0].role = :ignore
    parser.columns[1].role = :measure
#     p parser.columns.map{|col| col.values[6]}
    data, results = parser.commit
    assert_equal(25, data.measures.size)
#     p data.chron_data_columns.map {|col| col.values[6]}
    series = data.make_series(:measure => data.measures[6].name)
    assert_equal(17, series.data.size)
  end

  def test_custom_fed
    ce = Extractor::CustomExtractor.new(testdata("custom_fed.rb"))
    parser = Dataset::Parser.new(:input => testdata("fed_h3_weekly.csv"), :extractor => ce)
    assert_kind_of(Dataset::Measure, parser.columns[7].role)

    ce = Extractor::CustomExtractor.new(testdata("custom_fed.rb"))
    parser = Dataset::Parser.new(:input => testdata("fed_g17_summary.csv"), :extractor => ce)
    assert_equal(Dataset::Units::Artificial, parser.columns[1].role.units)
    assert_equal(Dataset::Units::Percentage, parser.columns.last.role.units)
  end

  def test_null_parser
    ce = Extractor::CustomExtractor.new(testdata("custom_csv.rb"))
    parser = Dataset::Parser.new(:extractor => ce)
    assert_not_nil(parser)
    source = Dataset::Source.new(:text => "2004,123\n2005,987\n")
    parser.analyze(source)
  end

  def test_measure_dimensions
    ce = Extractor::CustomExtractor.new(testdata("csv_md_rules.rb"))
    parser = Dataset::Parser.new(:input => testdata("wfmi_income.csv"), :extractor => ce)
    assert_equal(:measure, parser.columns[0].role)
    assert_equal(Dataset::Units::Dollars, parser.columns[0].values[3].units)
#     puts parser.columns[0].values.map {|v| v.inspect}
    data, results = parser.commit
    assert_equal(:measure, data.columns[0].role)
#     p data.columns[0]
    assert_equal(:thousand, data.measures[3].multiplier)
    assert_equal(:ones, data.measures[11].multiplier)
    assert_equal(Dataset::Units::Discrete, data.measures[12].units)
    assert_equal(:thousand, data.measures[12].multiplier)
    assert_equal(Dataset::Units::Dollars, data.measures.last.units)
    assert_equal(:ones, data.measures.last.multiplier)
  end

  def test_labels_should_flow_from_parser_to_sourcedata
    source = Dataset::Source.new(:text => @@text3)
    parser = Dataset::Parser.new(:source => source)
    assert_equal("Amount", parser.columns[1].label)
    sd, summary = parser.parse(source)
    assert_equal("Amount", sd.columns[1].label) # label should transfer
    parser.columns[1].label = "Net Revenue"
    sd, summary = parser.parse(source)
    assert_equal("Net Revenue", sd.columns[1].label) # revised label should transfer
  end

  def test_to_number
    assert_equal("0.105", "0.105".to_number.to_s)
    assert_equal("0.105", ".105".to_number.to_s)
    assert_equal(-3.7, "- 3.7".to_number)
    assert_equal(200, "$200".to_number)
    assert_equal(4_000_000, "   $ 4,000,000 ".to_number)
    assert_equal(-1234, "- $1,234".to_number)
  end

  # if the SourceData has one measure that applies to all the columns & rows, then
  # #make_series ought to pick that one by default
  def test_make_series_should_work_without_param_for_global_measure
    source = Dataset::Source.new(:text => testdata("imports.txt"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::TSVExtractor.new(:headerlines => 1))
    parser.measure = m = Dataset::Measure.new(:name => "US Imports")
    sd, summary = parser.parse(source)
    assert_equal(m, sd.measure)
    assert_not_nil(sd.make_series)
  end

  def test_should_handle_large_source_not_too_slowly
    start_ts = Time.now
    source = Dataset::Source.new(:text => testdata("fed_cp.csv"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::CustomExtractor.new(testdata("custom_fed.rb")))
    analyzed_ts = Time.now
    assert(analyzed_ts - start_ts < 15) # this should take less than 15 seconds
    sd, summary = parser.parse(source)
    parsed_ts = Time.now
    assert(parsed_ts - analyzed_ts < 5)
    assert_equal(2449, sd.columns[3].values.size)
  end

  def test_should_not_allow_both_column_and_global_measures
    source = Dataset::Source.new(:text => testdata("worldpop.html"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::HTMLTableExtractor.new(:headerlines => 1))

    # column measures
    assert parser.measures.any?
    assert_raise(RuntimeError) { parser.measure = Dataset::Measure.new(:name => "Population (should break)") }
    assert_nothing_raised(RuntimeError) { parser.measure = nil }

    # row measures
    parser.columns.each {|col| col.role = :ignored}
    parser.columns.first.role = :measure
    assert_raise(RuntimeError) { parser.measure = Dataset::Measure.new(:name => "Population (should break)") }
    assert_nothing_raised(RuntimeError) { parser.measure = nil }

    # no column or rows measures, should be OK to set a global measure
    parser.columns.each {|col| col.role = :ignored}
    assert_nothing_raised(RuntimeError) { parser.measure = Dataset::Measure.new(:name => "Population (should break)") }
  end

  def test_should_offer_dimension_role_for_ovarian_cancer_data
    source = Dataset::Source.new(:text => testdata("ovarian_cancer.tsv"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::TSVExtractor.new(:headerlines => 1))
    parser.columns[0].label = "Age Range"
    assert_not_nil dimrole = parser.columns[0].possible_roles.find {|role| role.is_a?(Dataset::Dimension)}
    parser.columns[0].role = dimrole
    assert_equal("Age Range", dimrole.name)

    # make sure that dimension name is passed through to the source_data
    sd, summary = parser.parse(source)
    dim = sd.dimension_columns.first.role
    assert_equal("Age Range", dim.name)
  end

  def test_dimension_across_columns
    source = Dataset::Source.new(:text => testdata("dim_across_columns.tsv"))
    parser = Dataset::Parser.new(:extractor => Extractor::TSVExtractor.new(:headerlines => 1))

    parser.analyze(source)
    assert_equal(5, parser.columns.size)
    assert_nil(parser.dimension)

    parser.dimension = Dataset::Dimension.new(:name => "Animal")
    parser.columns[0].role = Dataset::Dimension.new(:name => "Farm")
    parser.columns[1..-1].each do |col|
      col.role = :value
    end
    parser.measure = Dataset::Measure.new(:name => "Number of Animals")

    sd, sumry = parser.parse(source)
    assert_equal("Number of Animals", sd.measure.name)
    assert_equal(2, sd.dimensionality.size)
    ser = sd.make_series
    assert_equal(16, ser.data.size)
    assert_equal(2, ser.dimensions.size)
  end

  def test_global_dimension_and_chron
    source = Dataset::Source.new(:text => testdata("new_home_sales.csv"))
    parser = Dataset::Parser.new(:extractor => Extractor::CSVExtractor.new(:headerlines => 1))
    parser.analyze(source)
    parser.dimension = Dataset::Dimension.new(:name => "Region")
    parser.columns[1..-1].each {|col| col.role = :value}
    parser.measure = Dataset::Measure.new(:name => "New Home Sales")
    sd,sumry = parser.parse(source)
    ser = sd.make_series
    assert_equal(Dataset::Chron::YYYY, ser.chron)
    assert_equal(220, ser.data.size)
  end

  def test_attaching_constraints_to_columns
    source = Dataset::Source.new(:text => testdata("diabetes_by_age.html"))
    parser = Dataset::Parser.new(:extractor => Extractor::HTMLTableExtractor.new(:headerlines => 3))
    parser.analyze(source)
    parser.columns[1].constraints["Age Range"] = "0-44"
    parser.columns[1].label = "Diabetes Incidence Rate per 1000 People"
    parser.columns[3].constraints["Age Range"] = "45-64"
    parser.columns[5].constraints["Age Range"] = "65-74"
    parser.columns[7].constraints["Age Range"] = "75+"
    sd, summary = parser.parse(source)
    assert_equal(parser.columns[1].constraints, sd.measure_columns[0].constraints)
    assert sd.measure_columns[1].constraints.empty?
    ser = sd.make_series(:measure => "Diabetes Incidence Rate per 1000 People")
    assert ser.constraints.any?
  end

  def test_global_constraints_should_attach_to_all_measure_columns
    # construct the data
    data = [["a", "1"], ["b", "2"]]
    # mock the source
    s = mock
    s.expects(:content_type).returns("text/plain")
    s.stubs(:text).returns("")
    # mock the extractor
    e = mock
    e.stubs(:run).with("").returns(data)
    e.stubs(:data).returns(data)
    e.stubs(:constraints).returns({ "label" => "value" })
    e.stubs(:headers).returns([])
    e.stubs(:columns).returns([{},{}])

    p = Dataset::Parser.new(:extractor => e)
    p.analyze(s)
    p.columns[1].role = Dataset::Measure.new
    sd, summary = p.parse(s)
    assert sd.columns[1].constraints.any?
  end

  def test_bad_rows_should_be_silently_ignored
    source = Dataset::Source.new(:text => testdata("hist01z2.xls"))
    parser = Dataset::Parser.new(:extractor => Extractor::CustomExtractor.new(testdata("budget_history_xls_extractor.rb")))
    parser.analyze(source)
    sd, summary = parser.parse(source)
    ser = sd.make_series(:measure => sd.measures.first.name)
    assert_equal(Dataset::Chron::YYYY, ser.chron)
    assert_equal(1930, ser.chrons.min.value)
    assert_equal(2012, ser.chrons.max.value)
  end

  def test_chron_check
    parser = Dataset::Parser.new(:input => [17891849, 18501900, 1901, 1902, 1903, 1904, 1905, 1906, 1907, nil, nil].map{|v| v.to_s}.join("\n"))
    assert_equal(Dataset::Chron::YYYY, parser.columns[0].role)
  end

  def test_parser_should_honor_role_tips_from_extractor
    source = Dataset::Source.new(:text => testdata("bls_cex_notmonths.html"))
    parser = Dataset::Parser.new(:extractor => Extractor::CustomExtractor.new(testdata("custom_bls_cex.rb")))
    parser.analyze(source)
    assert_kind_of(Dataset::Measure, parser.columns.last.role)
  end

  def test_should_detect_split_chrons_automatically
    source = Dataset::Source.new(:text => testdata("years_and_months.txt"))
    parser = Dataset::Parser.new(:extractor => Extractor::CustomExtractor.new("tsv\nheaderlines(1)"))
    parser.analyze(source)
    parser.measure = Dataset::Measure.new(:name => "Value of Residential Construction")
    sd,sumry = parser.parse(source)
    assert_equal(Dataset::Chron::Month, sd.spanning_role)
    assert_equal(Dataset::Chron::YYYYMM, sd.chron)
    assert_equal(14 * 12, sd.flatten_columns.size)
    ser = sd.make_series
    assert_equal(14 * 12, ser.data.size)
  end

  def test_parser_should_create_placeholder_global_measure_if_needed
    source = Dataset::Source.new(:text => testdata("student_enrollment.csv"))
    parser = Dataset::Parser.new(:extractor => Extractor::CustomExtractor.new("csv\nheaderlines(1)"))
    parser.analyze(source)
    assert_equal('Unknown', parser.measure.name)
    sd, sumry = parser.parse(source)
    assert_equal('Unknown', sd.measures.first.name)
    assert_not_nil(sd.make_series)
  end
end
