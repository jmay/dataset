require File.dirname(__FILE__) + '/spec_helper'

require "yaml/syck"

# Table should be independent of the details of the pipeline output; glue code to construct
# a Table from the recipe runlog should be outside of this class.

describe "merging updates" do
  it "should replace old with new" do
    t1 = Dataset::Table.new(:nrows => 47, :columns => [{:label => 'Foo'}, {:label => 'Bar'}])
    t2 = Dataset::Table.new(:nrows => 48, :columns => [{}, {:label => 'Baz'}])
    t1.merge(t2)
    t1.nrows.should == 48
    t1.columns[0].label.should == 'Foo'
    t1.columns[1].label.should == 'Baz'
  end

  it "should add column metadata when missing" do
    t1 = Dataset::Table.new() # empty spec
    t2 = Dataset::Table.new(:columns => [{:label => 'Foo'}, {:label => 'Baz'}])
    t1.merge(t2)
    t1.columns.size.should == 2
  end

  it "should add column metadata when missing" do
    t1 = Dataset::Table.new(:columns => [{:label => 'Foo'}, {:label => 'Baz'}])
    t2 = Dataset::Table.new()
    t1.merge(t2)
    t1.columns.size.should == 2
  end

  it "should abort when merging mismatched non-empty column lists" do
    t1 = Dataset::Table.new(:columns => [{:label => 'Foo'}])
    t2 = Dataset::Table.new(:columns => [{:label => 'Bar'}, {:label => 'Baz'}])
    lambda {t1.merge(t2)}.should raise_error(RuntimeError)
  end
end

describe "role extraction" do
  it "should assign column numbers to columns" do
    table = Dataset::Table.new(:columns => [{}, {}, {}])
    table.nsf?.should be_false
    table.columns.size.should == 3
    table.columns[0].colnum.should == 0
    table.columns[1].colnum.should == 1
    table.columns[2].colnum.should == 2
  end

  it "should extract role info from column metadata" do
    table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Dollars'}])
    table.nsf?.should be_true

    table.columns.size.should == 2

    table.chron_columns.size == 1
    table.chron?.should be_true
    table.chron.should == Dataset::Chron::YYYYMM
    # table.chron_column.metadata[:chron].should == Dataset::Chron::YYYYMM

    table.dimension_columns.should be_empty
    table.dimensions.empty?.should be_true

    table.measure_columns.size == 1
    table.measures.any?.should be_true
    table.measure?.should be_true
    table.measure_column.number.should == Dataset::Number::Dollars

    table.measure.should == Dataset::Measure.new(:units => Dataset::Number::Dollars, :multiplier => nil)
    # table.measure_column.metadata[:number].should == Dataset::Number::Dollars
    # table.measure.multiplier.should == :ones
    # table.measure.units.should == Dataset::Units::Dollars
  end

  it "should handle label attributes for columns" do
    table = Dataset::Table.new(:columns => [
      {:label => 'State'},
      {:number => 'Units', :label => 'Population', :multiplier => 'thousands'}
      ])
    table.nsf?.should be_true
  end
end

describe "table construction from pipeline runlog" do
  it "should spit out nil for garbage in" do
    Dataset::Table.from_runlog(nil).should be_nil
    Dataset::Table.from_runlog({}).should be_nil
    Dataset::Table.from_runlog({ 'stagelogs' => nil }).should be_nil

    # pipeline stages, did run, but with no output, so give an empty tablespec
    spec = Dataset::Table.from_runlog({ 'stagelogs' => [] })
    spec.nrows.should == 0
    spec.columns.should be_empty
  end

  it "should find all the column metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    table = Dataset::Table.from_runlog(runlog)
    table.columns.size.should == 2

    table.nsf?.should be_true

    table.chron?.should be_true
    table.chron.should == Dataset::Chron::YYYYMM
    table.chron_column[:min].should == 23568
    table.chron_column[:max].should == 24097

    table.measure?.should be_true
    # table.measure_column[:colnum].should == 1
    table.measure.should == Dataset::Measure.new(:units => Dataset::Number::Quantity)
  end

  it "should interpret data from NSF according to the metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    datafile = File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/output'
    table = Dataset::Table.from_runlog(runlog)

    # process as stream
    table.read(datafile) do |row|
      row.size.should == 2
      row[0].should be_instance_of(Dataset::Chron::YYYYMM)
      row[1].should be_instance_of(Dataset::Number::Quantity)
    end

    # process entire file as batch
    rows = table.read(datafile)
    rows.size.should == 530
    rows.first[1].value == 7.79
    rows.each do |row|
      row[0].should be_instance_of(Dataset::Chron::YYYYMM)
      row[1].should be_instance_of(Dataset::Number::Quantity)
    end
  end
end

describe "runlog vs user column labeling" do
  it "should pull column headings from pipeline runlog" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-extraction/runlog')
    table = Dataset::Table.from_runlog(runlog)
    table.nsf?.should be_false
    table.nrows.should == 530
    table.columns.size.should == 4
    table.columns.each {|col| col.metadata.should include(:heading)}
  end

  it "should use default column labeling if nothing else provided" do
    ts = Dataset::Table.new(:columns => [{:heading => '', :chron => 'YYYY'}])
    ts.columns[0].name_or_default.should == 'Year'
  end
end

describe "column range metadata" do
  it "should reformat min & max chron ranges" do
    table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM', :min => 23364, :max => 24096}, {:label => 'State'}, {:number => 'Unspecified Measure', :min => 123, :max => 987.6}])
    table.chron_column.min.to_s.should == '01/1947'
    table.chron_column.max.to_s.should == '01/2008'
    table.measure_columns.first.min.to_s.should == "123.00"
    table.measure_columns.first.max.to_s.should == "987.60"
    table.columns[1].min.should be_nil
    table.columns[1].max.should be_nil
  end
end

describe "table with constraints" do
  it "should retain constraints independent of column info" do
    table = Dataset::Table.new(:constraints => {'Category' => 'Groceries'})
    table.constraints.size.should == 1
  end

  it "should be able to add constraints" do
    table = Dataset::Table.new
    table.constraints.size.should == 0
    table.constraints['Department'] = 'Defense'
    table.constraints.size.should == 1
  end

  it "should be able to modify constraints" do
    table = Dataset::Table.new(:constraints => {'Category' => 'Groceries'})
    table.constraints['Category'] = 'Food'
    table.constraints.size.should == 1
    table.constraints.values.should == ['Food']
  end

  it "should be able to delete constraints" do
    table = Dataset::Table.new(:constraints => {'Category' => 'Groceries'})
    table.constraints.delete('Category')
    table.constraints.should be_empty
  end

  it "should have empty default constraints when loaded from YAML" do
    table = YAML.load("--- !ruby/object:Dataset::Table \ncolumns: []\n\nnrows: \n")
    table.constraints.should == {}
    table.constraints['foo'] = 'bar'
    table.constraints.should_not be_empty
  end
end

describe "table metadata updates" do
  it "should handle measure updates" do
    table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units', :label => 'Widgets'}])
    table.measure.name.should == 'Widgets'
    table.measure.units.should == Dataset::Number::Count

    table.measure = Dataset::Measure.new(:name => 'Gadgets', :multiplier => :thousand, :units => Dataset::Number::Quantity)
    table.columns[1].name.should == 'Gadgets'
    table.columns[1].label.should == 'Widgets'
    table.columns[1].metadata[:multiplier].should == :thousand
    table.columns[1].units.label.should == 'Unspecified Measure'

    table.measure = {:name => 'Doodads', :number => 'Units'}
    table.columns[1].name.should == 'Doodads'
    table.columns[1].number.label.should == 'Units'
    table.measure.name.should == 'Doodads'

    table.measure = {'name' => 'Thingies', 'units' => 'Dollars'}
    table.measure_column.name.should == 'Thingies'
    table.measure_column.units.should == Dataset::Number::Dollars
  end

  it "should not allow measure-setting when there's no singular number column" do
    table = Dataset::Table.new(:columns => [{:label => 'Name'}, {:label => 'Abbrev'}])
    table.measure.should be_nil
    lambda {
      table.measure = Dataset::Measure.new(:name => 'Gadgets', :multiplier => :thousand, :units => Dataset::Number::Quantity)
    }.should raise_error
  end

  it "should support override of column auto-label by user-provided name" do
    table = Dataset::Table.new(:columns => [{:label => 'Name'}, {:label => 'Abbrev'}])
    table.columns[1].name.should == 'Abbrev'
    table.columns[1].metadata[:name] = 'Abbreviation'
    table.columns[1].name.should == 'Abbreviation'
    table.columns[1].label.should == 'Abbrev'
  end

  it "should support override of column auto-number by user-provided units" do
    table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Unspecified Measure'}])
    table.measure_column.units.should == Dataset::Number::Quantity
    table.measure = {'units' => 'Dollars'}
    table.measure_column.units.should == Dataset::Number::Dollars
  end
end

describe "row processing with full tablespec" do
  before(:all) do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    @datafile = File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/output'
    @table = Dataset::Table.from_runlog(runlog)
  end

  it "should support row count limit on file processing" do
    rows = []
    @table.read(@datafile, :limit => 20) do |row|
      rows << row
    end
    rows.size.should == 20
  end

  it "should support starting line offset on file processing" do
    rows = []
    @table.read(@datafile, :offset => 100) do |row|
      rows << row
    end
    rows.size.should == 430
  end

  it "should support limit & offset on file processing" do
    rows = []
    @table.read(@datafile, :offset => 250, :limit => 40) do |row|
      rows << row
    end
    rows.size.should == 40
    rows.first[0].to_s.should == "11/1984"
  end

  it "should load into memory if requested, for column processing" do
    @table.read(@datafile).size.should == 530
    @table.chrondata.each {|v| v.should  be_instance_of(Dataset::Chron::YYYYMM)}
    @table.measuredata.each {|v| v.should  be_instance_of(Dataset::Number::Quantity)}
  end

  it "should support tmin-only on file processing" do
    @table.read(@datafile, :tmin => Dataset::Chron::YYYYMM.new("10/1995")) do |row|
      (row.first >= Dataset::Chron::YYYYMM.new("10/1995")).should be_true
    end
  end

  it "should support tmax-only on file processing" do
    @table.read(@datafile, :tmax => Dataset::Chron::YYYYMM.new("4/2001")) do |row|
      (row.first <= Dataset::Chron::YYYYMM.new("4/2001")).should be_true
    end
  end

  it "should support both tmin & tmax on file processing" do
    @table.read(@datafile, :tmin => Dataset::Chron::YYYYMM.new("6/1998"), :tmax => Dataset::Chron::YYYYMM.new("3/2003")) do |row|
      (row.first >= Dataset::Chron::YYYYMM.new("6/1998")).should be_true
      (row.first <= Dataset::Chron::YYYYMM.new("3/2003")).should be_true
    end
  end

  it "should allow measure interpretation to be turned off" do
    rows = @table.read(@datafile)
    rows.each {|row| row.last.should be_instance_of(Dataset::Number::Quantity)}

    rows = @table.read(@datafile, :skip_number_formatting => true)
    rows.each {|row| row.last.should be_kind_of(String)}
  end

  it "should be able to give rows in reverse order" do
    rows = @table.read(@datafile, :reverse => true)
    rows.size.should == 530
    rows.first[0].should == Dataset::Chron::YYYYMM.new("2/2008")
    rows.last[0].should == Dataset::Chron::YYYYMM.new("1/1964")
  end

  it "should be able to give rows in reverse order, with limit" do
    rows = @table.read(@datafile, :reverse => true, :limit => 20)
    rows.size.should == 20
    rows.first[0].should == Dataset::Chron::YYYYMM.new("2/2008")
    rows.last[0].should == Dataset::Chron::YYYYMM.new("7/2006")
  end

  it "should handle reverse, with offset" do
    rows = @table.read(@datafile, :reverse => true, :limit => 20, :offset => 50)
    rows.size.should == 20
    rows.first[0].should == Dataset::Chron::YYYYMM.new("12/2003")
    rows.last[0].should == Dataset::Chron::YYYYMM.new("5/2002")
  end

  it "should handle reverse, with streaming" do
    nrows = 0
    @table.read(@datafile, :reverse => true, :limit => 30, :offset => 100) do |row|
      row.first.should <= Dataset::Chron::YYYYMM.new("10/1999")
      row.first.should >= Dataset::Chron::YYYYMM.new("5/1997")
      nrows += 1
    end
    nrows.should == 30
  end
end

# for a tablespec that has no column metadata, #read must still work
describe "row processing with incomplete tablespec" do
  before(:all) do
    @datafile = File.dirname(__FILE__) + '/../../pipeline/test/bea-extraction/output'
    @table = Dataset::Table.new()
  end

  it "should output all the columns" do
    rows = @table.read(@datafile)
    rows.size.should == 25
    rows.each {|row| [2,247].should include(row.size)}
  end
end

describe "column labels" do
  before(:all) do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    @datafile = File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/output'
    @table = Dataset::Table.from_runlog(runlog)
  end

  it "should pull default labels from the roles determined from the runlog" do
    @table.column_labels.should == ["Year & Month", "Unspecified Measure"]
  end

  it "should use user labels if provided" do
    @table.measure_column.metadata[:label] = "Widgets"
    @table.column_labels.should == ["Year & Month", "Widgets"]
  end
end

describe "table with dimension columns" do
  it "should understand dimension names and value-sets" do
    t1 = Dataset::Table.new(:columns => [{:label => 'id code'}, {:label => 'thing name'}, {:label => 'group'}])
    t1.dimension_columns.should be_empty
    t1.other_columns.size.should == 3

    t1.columns[2][:values] = [ 'group1', 'group2', 'group3']
    t1.dimension_columns.should == [t1.columns[2]]
    t1.dimension_column('group').should_not be_nil
    t1.dimensions.first.name.should == 'group'
    t1.dimensions.first.values.size.should == 3

    t1.other_columns.size.should == 2
  end
end

describe "reading table from file" do
  it "should pull all the columns" do
    table = Dataset::Table.new(:columns => [{:label => 'Year'}])
    rows = table.read(File.dirname(__FILE__) + "/testdata/dummy.tsv")
    rows.each {|row| row.size.should == 3}
  end
end
