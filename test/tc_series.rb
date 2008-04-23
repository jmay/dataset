require File.dirname(__FILE__) + '/test_helper'

# require "util"
# require "source"
# require "parser"
# require "extractor"
# require "series"
# require "chron"
# require "measure"
# require "unit"
# require "dimension"

# Foreign Enrollment dataset from http://opendoors.iienetwork.org/?p=89192
$text1 = <<_EOT_
1954/55	34,232
1959/60	48,486
1964/65	82,045
1969/70	134,959
1974/75	154,580
1979/80	286,343
1984/85	342,113
1985/86	343,777
1986/87	349,609
1987/88	356,187
1988/89	366,354
1989/90	386,851
1990/91	407,529
1991/92	419,585
1992/93	438,618
1993/94	449,749
1994/95	452,635
1995/96	453,787
1996/97	457,984
1997/98	481,280
1998/99	490,933
1999/00	514,723
2000/01	547,867
2001/02	582,996
2002/03	586,323
2003/04	572,509
2004/05	565,039
2005/06	564,766
_EOT_

class TestSeries < Test::Unit::TestCase
  def test_new_with_only_chron
    series = Dataset::Series.new()
    assert_equal(Dataset::Chron::YYYY, series.chron)
    # assert_equal(Dataset::Measure::Units, series.measure)
    assert_instance_of(Dataset::Measure, series.measure)
    assert_equal(0, series.dimensions.size)
    series.add([ 1990, "427"])
    series.add([ 1991, "592"])
    series.add([ 1992, "603"], [ 1993, "572"], [ 1994, "637"])
    assert(series.data.size == 5, "Wrong number of records")
    chosenrows = series.data.select { |e| e[:chron].to_s == "1990" }
    assert_equal(1, chosenrows.size)
#     assert_equal(637, series.max_measure.value)
    assert_equal(637, series.max_measure)
    assert_equal(Dataset::Units::Discrete, series.measure.units)
#     assert_equal(Dataset::Units::Discrete, series.data[0][:measure].class)
    series.units = Dataset::Units::Dollars
    assert_equal(Dataset::Units::Dollars, series.measure.units)
#     assert_equal(Dataset::Units::Dollars, series.data[0][:measure].class)
  end

  def test_category_dimension_and_extraction
    series = Dataset::Series.new(:dimensions => ["Department"])
    assert_not_nil(series)
    assert_not_nil(series.chron)
    assert_not_nil(series.measure)
    assert_not_nil(series.dimensions)
    series.add()  # adding blank rows should be a no-op
    series.add([ 1990, "Defense", 427])
    series.add([ 1990, "Education", 36])
    series.add([ 1991, "Defense", 592])
    series.add([ 1991, "Education", 41])
    series.commit
    assert_equal(4, series.data.size)
    chosenrows = series.data.select { |e| e[:chron].to_s == "1990" }
    assert_equal(2, chosenrows.size)

    e = assert_raise(RuntimeError) { series.extract(:dimension => 1) }
    assert_equal("Invalid dimension specification", e.message)
    e = assert_raise(RuntimeError) { series.extract(:dimension => -1) }
    assert_equal("Invalid dimension specification", e.message)

    e = assert_raise(RuntimeError) { series.extract(:dimension => 0, :value => "Health") }
    assert_equal("There is no 'Department' = 'Health' in the source data", e.message)

    s2 = series.extract(:dimension => 0, :value => "Education")
    assert s2.dimensions.empty?
    assert_equal({ "Department" => "Education" }, s2.constraints)

    assert s2.measure.notes.nil? # don't put the constraint in the notes
    assert_equal(2, s2.data.size)
    assert_equal(series.chron, s2.chron)
  end

  def test_add
    series = Dataset::Series.new()
    series.add([ 1990, 427], [ 1991, 592]).add([ 1992, 603], [ 1993, 572], [ 1994, 637])
    assert_equal(5, series.data.size)
  end

  def test_deltas
    series = Dataset::Series.new()
    series.add([ 1990, 427], [ 1991, 592], [ 1992, 603], [ 1993, 572], [ 1994, 637])
    s2 = series.deltas
    # assert_equal((592.0-427)/427, s2.data.first[:measure].value)
    # assert_equal((637.0-572)/572, s2.data.last[:measure].value)
    assert_equal((592.0-427)/427 * 100, s2[s2.chron.new(1991)][:measure])
    assert_equal((637.0-572)/572 * 100, s2[s2.chron.new(1994)][:measure])
    assert_equal("Percent", s2.measure.units.label)

    s3 = series.deltas(Dataset::Chron::YYYY)
    assert_equal(s2.data, s3.data)

    e = assert_raise(RuntimeError) { series.deltas(Dataset::Chron::YYYYMM) }
    assert_equal("Invalid step Year & Month", e.message)

    e = assert_raise(NoMethodError) { series.deltas('monthly') }
  end

  def test_monthly_series_should_allow_monthly_and_annual_diffs_and_deltas
    series = Dataset::Series.new(:chron => Dataset::Chron::YYYYMM)
    series.add(
      [ "200001", 10], [ "200002", 20], [ "200003", 30], [ "200004", 40],
      [ "200005", 50], [ "200006", 60], [ "200007", 70], [ "200008", 80],
      [ "200009", 90], [ "200010", 100], [ "200011", 110], [ "200012", 120],
      [ "200101", 20], [ "200102", 25], [ "200103", 45], [ "200104", 120],
      [ "200105", 55], [ "200106", 63], [ "200107", 75], [ "200108", 100],
      [ "200109", 45], [ "200110", 10], [ "200111", 11], [ "200112", 1200])
    s2 = series.deltas
    assert_equal((20.0-120)/120 * 100, s2[s2.chron.new("200101")][:measure])
    assert_equal((25.0-20)/20 * 100, s2[s2.chron.new("200102")][:measure])
    assert_equal("-83.3%", s2.format(s2[s2.chron.new("200101")][:measure], :sign => true))

    s3 = series.deltas(Dataset::Chron::YYYYMM)
    assert_equal(s2.data, s3.data)

    s4 = series.diffs
    assert_equal(45-25, s4[s4.chron.new("200103")][:measure])

    s5 = series.diffs(Dataset::Chron::YYYY)
    assert_equal(20-10, s5[s5.chron.new("200101")][:measure])
  end

  def test_diffs
    series = Dataset::Series.new()
    series.add([ 1990, 427], [ 1991, 592], [ 1992, 603], [ 1993, 572], [ 1994, 637])
    s2 = series.diffs
    # assert_equal(592-427, s2.data[0][:measure].value)
    # assert_equal(637-572, s2.data[-1][:measure].value)
    assert_equal(592-427, s2[s2.chron.new(1991)][:measure])
    assert_equal(637-572, s2[s2.chron.new(1994)][:measure])
#     assert_equal("+165", s2.data[0][:measure].format(:sign => true))
    assert_equal("+165", s2.format(s2[s2.chron.new(1991)][:measure], :sign => true))
  end

  def test_diffs2
    # d1 = Dataset::Dataset.new(:source => Dataset::Source.new(:text => $text1))
    # s1 = d1.series[0]

    source = Dataset::Source.new(:text => $text1)
    parser = Dataset::Parser.new(:source => source)
    parser.columns[1].label = "Numbers"
    assert_equal(Dataset::Chron::SchoolYear, parser.columns[0].role)
    data, results = parser.parse(source)
    assert_equal(Dataset::Chron::SchoolYear, data.chron)
    s1 = data.make_series
    s2 = s1.diffs
    assert_equal("Change in Numbers", s2.measure.name)
    assert_nil(s2[s1.chron.new("1984-85")])
    assert_not_nil(s2[s1.chron.new("2000-01")])
  end

  def test_long_series
    long_series = Dataset::Series.new
    ary = (1950..2000).map {|n| [ n, n-1900 ]}
    long_series.add(*ary)
  end

  def test_baseline
    series = Dataset::Series.new(:chron => Dataset::Chron::YYYYMM)
    series.measure.name = "Widgets"
    series.add(
      [ "200001", 10], [ "200002", 20], [ "200003", 30], [ "200004", 40],
      [ "200005", 50], [ "200006", 60], [ "200007", 70], [ "200008", 80],
      [ "200009", 90], [ "200010", 100], [ "200011", 110], [ "200012", 120],
      [ "200101", 20], [ "200102", 25], [ "200103", 45], [ "200104", 120],
      [ "200105", 55], [ "200106", 63], [ "200107", 75], [ "200108", 100],
      [ "200109", 45], [ "200110", 10], [ "200111", 11], [ "200112", 1200])
    s2 = series.baseline(series.chron.new("200010"))
    assert_equal(Dataset::Units::Percentage, s2.measure.units)
    assert_match(/Widgets \(baseline/, s2.measure.name)
    # assert_equal(1.0, s2.data[9][:measure].value)
    # assert_equal(0.5, s2.data[4][:measure].value)
    # assert_equal(12.0, s2.data.last[:measure].value)
    assert_equal(1.0 * 100, s2[Dataset::Chron::YYYYMM.new("200010")][:measure])
    assert_equal(0.5 * 100, s2[Dataset::Chron::YYYYMM.new("200005")][:measure])
    assert_equal(12.0 * 100, s2[Dataset::Chron::YYYYMM.new("200112")][:measure])
  end

  def test_ratio
    s1 = Dataset::Series.new(
      :chron => Dataset::Chron::YYYY,
      :measure => Dataset::Measure.new(:name => "Sales", :units => Dataset::Units::Dollars))
    s1.add([2000, 100],[2001, 200],[2002, 300],[2003, 400])
    s1.commit
    s2 = Dataset::Series.new(:chron => Dataset::Chron::YYYY,
      :measure => Dataset::Measure.new(:name => "Employees", :units => Dataset::Units::People))
    s2.add([2001, 20],[2002, 25],[2003, 30],[2004,40])
    s2.commit
    s3 = s1.ratio(s2)
    assert_equal(2001, s3.chrons.min.value)
    assert_equal(2003, s3.chrons.max.value)
#     assert_equal(12.0, s3.data[1][:measure].value)
    assert_equal(12.0, s3.data[1][:measure])
#     assert_equal(400.0/30, s3.hashdata[s3.chron.new(2003)].value)
    assert_equal(400.0/30, s3.hashdata[s3.chron.new(2003)])
    assert_equal(Dataset::Units::Dollars, s3.measure.units)
    assert_equal("Sales / Employees", s3.measure.name)
  end

  def test_hash
    s1 = Dataset::Series.new(:chron => Dataset::Chron::YYYY)
    s1.add([2000, 100],[2001, 200],[2002, 300],[2003, 400])
    s1.commit
#     assert_equal(300, s1.hashdata[s1.chron.new(2002)].value)
    assert_equal(300, s1.hashdata[s1.chron.new(2002)])
  end

  def test_multiplier
    s1 = Dataset::Series.new(:multiplier => :million)
    s1.add([2000, 100],[2001, 200],[2002, 300],[2003, 400])
#     assert_equal(200, s1.data[1][:measure].value)
    assert_equal(200, s1.data[1][:measure])
    assert_equal(:million, s1.measure.multiplier)
  end

  def test_include
    s1 = Dataset::Series.new
    s1.add([2000, 100],[2001, 200],[2002, 300],[2003, 400])
    assert(s1[Dataset::Chron::YYYY.new(2002)], "expected to find matching chron")
    assert_raise(TypeError) { s1[2002] }
    assert_nil(s1[Dataset::Chron::YYYY.new(2004)], "expected not to find matching chron")
    assert_raise(TypeError) { s1[Dataset::Chron::YYYYMM.new("200101")] }
    assert_equal(2000, s1.chrons.min.value)
  end

  def test_nochron
    dim = Dataset::Dimension.new(:name => "color")
    s1 = Dataset::Series.new(:chron => nil,
      :dimensions => [ dim ],
      :measure => Dataset::Measure.new(:units => Dataset::Units::Discrete))
    s1.add(["red", 42], ["blue", 107], ["green", 15])
    s1.commit
    assert_equal(nil, s1.chron)
    assert_equal(3, s1.data.size)
    assert_equal(1, s1.dimensions.size)
    # check that the sorting worked (largest-to-smallest)
    assert_equal(107, s1.data.first[:measure])
    assert_equal(15, s1.data.last[:measure])
  end

  def test_should_check_chron
    series = Dataset::Series.new()
    assert_equal(Dataset::Chron::YYYY, series.chron)
    series.add([ Dataset::Chron::YYYY.new(1990), 427])
    assert_raise(RuntimeError) { series.add([ Dataset::Chron::YYYYMM.new("199102"), 598]) }
  end

  def test_deltas_should_skip_zero_values
    s1 = Dataset::Series.new
    s1.add([2000,100], [2001, 200], [2002, 0], [2003, 400], [2004, 500])
    s2 = s1.deltas
    assert_equal([2001, 2002, 2004], s2.chrons.sort.map{|c| c.value})  # see, 2003 is skipped
  end

  def test_adjust_multiplier
    s1 = Dataset::Series.new(:multiplier => :thousand)
    s1.add([2000,100.thousand], [2001, 200.thousand], [2002, 42.thousand], [2003, 400.thousand])
    assert_equal(:thousand, s1.measure.multiplier)
    s2 = s1.adjust_multiplier(:million)
    assert_equal(:million, s2.measure.multiplier)
#     assert_equal(100, s2.data[0][:measure].value)
    assert_equal(100, s2.data[0][:measure])
    assert_equal(:thousand, s1.measure.multiplier)
#     assert_equal(100.thousand, s1.data[0][:measure].value)
    assert_equal(100.thousand, s1.data[0][:measure])
  end

  # once a series has been committed, you shouldn't be able to add anything further to it
  # to "extend" a series, you need to create a new one, copy the data, and then add rows.
  # passing series through YAML should also lock it
  # def test_series_locking
  #   s1 = Dataset::Series.new(:multiplier => :thousand)
  #   s1.add([2000,100], [2001, 200], [2002, 42], [2003, 400])
  #   s1.commit
  #   assert_raise(RuntimeError) { s1.add([2004,500])}
  # end

  def test_can_do
    s1 = Dataset::Series.new(:chron => Dataset::Chron::YYYYMM)
    assert !s1.can_diffs?(Dataset::Chron::YYMMDD)
    assert s1.can_diffs?(Dataset::Chron::YYYYMM)
    assert s1.can_diffs?(Dataset::Chron::YYYYQ)
    assert s1.can_diffs?(Dataset::Chron::YYYY)
    assert !s1.can_deltas?(Dataset::Chron::YYMMDD)
    assert s1.can_deltas?(Dataset::Chron::YYYYMM)
    assert s1.can_deltas?(Dataset::Chron::YYYYQ)
    assert s1.can_deltas?(Dataset::Chron::YYYY)
    s2 = Dataset::Series.new(:chron => Dataset::Chron::YYMMDD)
    assert !s2.can_diffs?(Dataset::Chron::YYMMDD)
    assert !s2.can_deltas?(Dataset::Chron::YYMMDD)
    s3 = Dataset::Series.new(:chron => nil)
    assert !s2.can_diffs?(Dataset::Chron::YYYY)
    assert !s2.can_deltas?(Dataset::Chron::YYYY)
    s4 = Dataset::Series.new(:chron => Dataset::Chron::YYYY)
    assert s4.can_diffs?(Dataset::Chron::YYYY)
    assert !s4.can_diffs?(Dataset::Chron::YYYYMM)
    assert s4.can_deltas?(Dataset::Chron::YYYY)
    assert !s4.can_deltas?(Dataset::Chron::YYYYMM)

    s5 = Dataset::Series.new(:dimensions => ["Color"])
    s5.add([2002, "blue", 42.7], [2002, "red", 100.5], [2003, "blue", 83.0], [2003, "red", 173.2])
    assert !s5.can_diffs?(Dataset::Chron::YYYY)
    assert !s5.can_deltas?(Dataset::Chron::YYYY)

    s6 = Dataset::Series.new(:chron => Dataset::Chron::YYMMDD)
  end

  def test_available_operations
    measure = Dataset::Measure.new(:name => "Sales", :units => Dataset::Units::Dollars)
    s1 = Dataset::Series.new(:chron => Dataset::Chron::YYYY, :measure => measure)
    ops = s1.operations
    # response should be array of items with :method, :invocation, :label
    assert_equal(2, ops.size)
    assert_not_nil(ops.find {|op| op[:method] == :diff_annual})
    assert_not_nil(ops.find {|op| op[:method] == :delta_annual})
    # assert_not_nil(ops.find {|op| op[:method] == :ratio})
    # assert_not_nil(ops.find {|op| op[:method] == :adjust})
    
    s2 = Dataset::Series.new(:chron => Dataset::Chron::YYYYMM, :measure => measure)
    ops = s2.operations
    assert_equal(4, ops.size)
    assert_not_nil(ops.find {|op| op[:method] == :diff_monthly})
    assert_not_nil(ops.find {|op| op[:method] == :diff_annual})
    assert_not_nil(ops.find {|op| op[:method] == :delta_monthly})
    assert_not_nil(ops.find {|op| op[:method] == :delta_annual})
    # assert_not_nil(ops.find {|op| op[:method] == :ratio})
    # assert_not_nil(ops.find {|op| op[:method] == :adjust})
  end

  # def test_formatting
  #   s1 = Dataset::Series.new(:chron => Dataset::Chron::YYYY)
  #   s1.add(["2005", "123"])
  #   s1.commit
  #   assert_equal("987", s1.format("987"))
  # 
  #   s2 = Dataset::Series.new(:chron => Dataset::Chron::YYYY, :measure => Dataset::Measure.new(:units => Dataset::Units::Percentage))
  #   s2.add(["2005", "12.3"])
  #   s2.commit
  #   assert_equal("54.0%", s2.format("54"))
  #   assert_equal("6.8%", s2.format("6.84"))
  # 
  #   s3 = Dataset::Series.new(:chron => Dataset::Chron::YYYY, :measure => Dataset::Measure.new(:units => Dataset::Units::Percentage))
  #   s3.add(["2005", "8"], ["2006", "12"], ["2007", "16"])
  #   s3.commit
  #   assert_equal("54%", s3.format("54"))
  #   assert_equal("7%", s3.format("6.84"))
  # end

  def test_range
    series = Dataset::Series.new
    ary = (1950..2007).map {|n| [ n, rand(100) ]}
    series.add(*ary)
    assert_equal(58, series.data.size)
    assert_raise(RuntimeError) { series.range() }
    assert_raise(TypeError) { series.range(Dataset::Chron::YYYYMM.new("01/1980")) }
    assert_raise(TypeError) { series.range(nil, Dataset::Chron::YYYYMM.new("01/1980")) }
    s2 = series.range(Dataset::Chron::YYYY.new(1980))
    assert_equal(28, s2.data.size)
    assert_equal(Dataset::Chron::YYYY.new(1980), s2.chrons.min)
    assert_equal(Dataset::Chron::YYYY.new(2007), s2.chrons.max)
  end

  def test_csv
    series = Dataset::Series.new
    series.add([ 1990, 427], [ 1991, 592]).add([ 1992, 603], [ 1993, 572], [ 1994, 637])
    series.commit
    csv = series.csv
    assert_equal(6, csv.split(/\n/).size) # 5 lines
    assert_equal("Year,Unspecified", csv.split(/\n/).first) # header line
    assert_equal(6, csv.scan(/,/).size) # 5 commas
    assert_equal(0, csv.scan(/ /).size) # no whitespace
    assert_equal(0, csv.scan(/"/).size) # no quotes
  end

  def test_duplicate_dimensions_should_not_throw_exceptions
    # test on a bare series
    s1 = Dataset::Series.new
    s1.add([2000,100])
    s1.add([2001, 200])
    assert s1.errors.empty?
    s1.add([2001, 200]) # no error
    assert s1.errors.any?
    s1.commit
    assert s1.errors.any?

    # now test when building from a source
    source = Dataset::Source.new(:text => testdata("labor_force.csv"))
    parser = Dataset::Parser.new(:source => source, :extractor => Extractor::CSVExtractor.new(:headerlines => 1))
    data, results = parser.parse(source)
    s1 = data.make_series
    assert_not_nil(s1)
    assert s1.errors.any?
  end

  def test_series_constraints
    s1 = Dataset::Series.new
    assert s1.constraints.empty?
    s1.constraints["Country"] = "China"
    s1.add([2000, 100])
    s1.add([2001, 200])
    s1.commit
    assert s1.constraints.any?

    s2 = YAML.load(s1.to_yaml)
    assert s2.constraints.any?
    s2.constraints["Gender"] = "Male"
    assert_equal(2, s2.constraints.size)

    s3 = YAML.load(s1.to_yaml.gsub(/constraints:.*data/sm, 'data'))
    # make sure this doesn't break because constraints wasn't in the yaml
    assert s3.constraints.empty?
  end

  def test_series_should_ignore_junk
    s1 = Dataset::Series.new
    s1.add([2000,10])
    s1.add([12346789, 20])
    s1.add([2001, 30])
    s1.add(["junk", 40])
    s1.add([2002, 50])
    s1.add([nil, nil])
    s1.commit
    assert_equal(3, s1.data.size)
  end

  def test_should_handle_nils_in_dimension_columns
    s1 = Dataset::Series.new(:dimensions => ["Category"])
    s1.add([2001, "Red", 100], [2002, nil, 200], [2003, "Blue", 300])
    s1.commit
    assert_equal(3, s1.data.size)
    assert_equal(2, s1.dimensions.first.values.size)
  end
end
