require File.dirname(__FILE__) + '/spec_helper'

# TODO: baseline
# TODO: ratio
# TODO: adjust-multiplier (multiply dataset by N)

describe 'calculations' do
  it "should return nil on invalid descriptors" do
    Dataset::Calculation.find('bogus').should be_nil
    Dataset::Calculation.find('chg-foo').should be_nil
    Dataset::Calculation.find('chg-pct-xyz').should be_nil
    Dataset::Calculation.find('chg-abs-xyz').should be_nil
  end

  it "should return non-terminal Calculations for partial descriptors" do
    calc = Dataset::Calculation.find('')
    calc.should_not be_nil
    calc.should_not be_terminal

    Dataset::Calculation.find('chg').should_not be_terminal
  end

  it "should return terminal Calculations for valid descriptors" do
    Dataset::Calculation.find('chg-pct-mon').should be_terminal
    Dataset::Calculation.find('chg-abs-ann').should_not be_nil
    Dataset::Calculation.find('baseline-1995').should_not be_nil
  end
end

describe "monthly deltas calculation" do
  before(:all) do
    @calc = Dataset::Calculation.find("chg-pct-mon")
  end

  it "should give the right class" do
    @calc.class.should == Dataset::MonthlyDeltas
  end

  it "should build recipe & run" do
    @calc.should respond_to(:target)
    @calc.should_not be_ready

    table = Dataset::Table.new(:columns => [
      {:chron => 'YYYYMM'},
      {:number => 'Count',
        :name => 'Sales'}
       ])
    @calc.target(table)
    # table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    # table.
    @calc.should be_ready
    @calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 1, :percent => "1" }}]
    newtable = @calc.resultspec
    newtable.columns.size.should == 2
    newtable.chron.should == Dataset::Chron::YYYYMM
    newtable.measure.units.should == Dataset::Number::Percentage
    newtable.measure_column.label.should == 'Monthly change in Sales'
    @calc.should respond_to(:execute)

    # TODO: validate calc.tablespec
  end

  it "should require a target with a chron" do
    @calc.target(table = mock)
    table.expects(:chron).returns(nil)
    @calc.should_not be_ready
  end

  it "should require a target with a monthly chron" do
    @calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYY)
    @calc.should_not be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYYQ)
    @calc.should_not be_ready
  end
end

describe "quarterly deltas calculation" do
  it "should require target to have monthly or quarterly chron" do
    calc = Dataset::Calculation.find("chg-pct-qtr")
    calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    calc.should be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYYQ)
    calc.should be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYY)
    calc.should_not be_ready
  end

  it "should build recipe & run" do
    calc = Dataset::Calculation.find("chg-pct-qtr")
    calc.should respond_to(:target)
    calc.should_not be_ready

    table = Dataset::Table.new(:columns => [
      {:chron => 'YYYYMM'},
      {:number => 'Unspecified Measure',
        :label => 'CPI'}
       ])
    calc.target(table)
    calc.should be_ready
    calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 3, :percent => '1' }}]
    newtable = calc.resultspec
    newtable.columns.size.should == 2
    newtable.chron.should == Dataset::Chron::YYYYMM
    newtable.measure.units.should == Dataset::Number::Percentage
    newtable.measure_column.label.should == 'Quarterly change in CPI'
    calc.should respond_to(:execute)
  end
end

describe "annual diffs calculation" do
  it "should require target to have monthly or quarterly or annual chron" do
    calc = Dataset::Calculation.find("chg-abs-ann")
    calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    calc.should be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYYQ)
    calc.should be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYY)
    calc.should be_ready
  end

  it "should build recipe & run" do
    calc = Dataset::Calculation.find("chg-abs-ann")
    calc.should respond_to(:target)
    calc.should_not be_ready

    table = Dataset::Table.new(:columns => [
      {:chron => 'YYYYMM'},
      {:number => 'People',
        :label => 'Employment',
        :multiplier => :thousand}
       ])
    calc.target(table)
    calc.should be_ready
    calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 12, :percent => "0" }}]
    newtable = calc.resultspec
    newtable.columns.size.should == 2
    newtable.chron.should == Dataset::Chron::YYYYMM
    newtable.measure_column.label.should == 'Annual change in Employment'
    newtable.measure.multiplier.should == :thousand
    newtable.measure.units.should == Dataset::Number::People
    calc.should respond_to(:execute)
  end
end

describe "monthly diffs calculation" do
  it "should require target to have monthly chron" do
    calc = Dataset::Calculation.find("chg-abs-mon")
    calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    calc.should be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYYQ)
    calc.should_not be_ready
    table.stubs(:chron).returns(Dataset::Chron::YYYY)
    calc.should_not be_ready
  end

  it "should build recipe & run" do
    calc = Dataset::Calculation.find("chg-abs-mon")
    calc.should respond_to(:target)
    calc.should_not be_ready

    table = Dataset::Table.new(:columns => [
      {:chron => 'YYYYMM'},
      {:number => 'Units',
        :name => 'Total Sales',
        :multiplier => :million}
       ])
    calc.target(table)
    calc.should be_ready
    calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 1, :percent => "0" }}]
    newtable = calc.resultspec
    newtable.columns.size.should == 2
    newtable.chron.should == Dataset::Chron::YYYYMM
    newtable.measure_column.label.should == 'Monthly change in Total Sales'
    newtable.measure.multiplier.should == :million
    newtable.measure.units.should == Dataset::Number::Count
    calc.should respond_to(:execute)
  end
end
# describe "deltas calculation, with time period omitted" do
#   it "should ask for more info" do
#     calc = Calculation.find("changes-percent")
#     calc.should_not respond_to(:target)
#     calc.should_not respond_to(:execute)
# 
#     calc.expects?.should == 'period'
#     calc.choices?.should == ['changes-percent-annual', 'changes-percent-monthly']
#   end
# end

describe "baseline calculation" do
  it "should require a chron parameter to baseline with" do
    calc = Dataset::Calculation.find("baseline")
    calc.should_not be_terminal
  end

  it "should require a target" do
    calc = Dataset::Calculation.find("baseline-1995")
    calc.should be_terminal
    calc.should_not be_ready
  end

  it "should barf when target missing chron column" do
    calc = Dataset::Calculation.find("baseline-1995")

    calc.target(table = mock)
    table.stubs(:chron).returns(nil)

    calc.should_not be_ready
  end

  it "should barf when target has incompatible chron" do
    calc = Dataset::Calculation.find("baseline-1995")

    table_wrong_chron = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    table_no_measure = Dataset::Table.new(:columns => [{:chron => 'YYYY'}])
    table_no_chron = Dataset::Table.new(:columns => [{:name => 'State'}, {:number => 'People'}])
    table_extra_column = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:name => 'Department'}, {:number => 'Units'}])
    table_no_minmax = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}])
    table_ok = Dataset::Table.new(:columns => [{:chron => 'YYYY', :min => 1980, :max => 2007}, {:number => 'Units'}])
    table_2_measures = Dataset::Table.new(:columns => [{:chron => 'YYYY', :min => 1980, :max => 2007}, {:number => 'Units'}, {:number => 'Dollars'}])

    calc.target(table_wrong_chron)
    calc.should_not be_ready
    calc.target(table_no_measure)
    calc.should_not be_ready
    calc.target(table_no_chron)
    calc.should_not be_ready
    calc.target(table_extra_column)
    calc.should_not be_ready
    calc.target(table_no_minmax)
    calc.should_not be_ready
    calc.target(table_ok)
    calc.should be_ready
    calc.target(table_2_measures)
    calc.should be_ready
  end

  it "should work when target has the right chron" do
    calc = Dataset::Calculation.find("baseline-1995")
    calc.should_not be_ready
    calc.should be_terminal

    table = Dataset::Table.new(:columns => [{:chron => 'YYYY', :min => 1980, :max => 2007}, {:number => 'Dollars'}])
    calc.target(table)

    calc.recipe.should == [{:command => 'baseline.rb', :args => { :chroncol => 0, :baseline => 1995, :datacols => '1' }}]

    spec = calc.resultspec
    spec.columns.size.should == 2
    spec.columns[0].should be_chron
    spec.chron.should == table.chron
    spec.columns[1].units.should == Dataset::Number::Index
    spec.columns[1].name.should == 'Baselined Dollars'
    # TODO: validate calc.tablespec
  end
end


describe "extract calculation" do
  it "should require extra parameters" do
    Dataset::Calculation.find("extract").should_not be_terminal
    Dataset::Calculation.find("extract-State").should be_terminal
    Dataset::Calculation.find("extract-State-California").should be_terminal
  end

  it "should require a target" do
    calc = Dataset::Calculation.find("extract-State-California")
    calc.should be_terminal
    calc.should_not be_ready
  end

  it "should barf when target has no dimensions" do
    calc = Dataset::Calculation.find("extract-State-California")

    calc.target(table = Dataset::Table.new(:columns => [{:chron => Dataset::Chron::YYYY}, {:units => Dataset::Number::Count}]))
    calc.should_not be_ready

    calc.target(table = Dataset::Table.new(:columns => [:name => 'Department']))
    calc.should_not be_ready
  end

  it "should barf when target has no matching dimension" do
    calc = Dataset::Calculation.find("extract-State-California")
    calc.target(table = Dataset::Table.new(:columns => [:name => 'Department']))
    calc.should_not be_ready
  end

  it "should barf when dimension value is missing" do
    calc = Dataset::Calculation.find("extract-State")
    calc.target(table = mock)
    table.stubs(:dimensions).returns([ dim = mock ])
    dim.stubs(:name).returns('State')
    calc.should_not be_ready
  end

  it "should work when target has the right dimension" do
    calc = Dataset::Calculation.find("extract-State-California")
    table = Dataset::Table.new(:columns => [{:name => 'State', :values => ['California', 'Arizona']}, {:number => 'Units'}])
    calc.target(table)
    # table.stubs(:dimensions).returns([dim = mock])
    # dim.stubs(:name).returns('State')
    calc.should be_ready

    calc.recipe.should == [{:command => 'select_where.pl', :args => { :column => 0, :value => 'California', :invert => 0 }}]

    spec = calc.resultspec
    spec = calc.resultspec # test to make sure that calc#resultspec is not destructive
    spec.columns.size.should == 1
    spec.columns.first.units.should == Dataset::Number::Count
    # (0..spec.columns.size-1).each do |n|
    #   spec.columns[n].metadata.should == table.columns[n].metadata
    # end
  end

  it "should allow spaces and other characters in either the column name or value" do
    calc = Dataset::Calculation.find("extract-school+district-Los+Altos+Elementary")
    table = Dataset::Table.new(:columns =>
      [{:name => 'school code'}, {:name => 'school name'}, {:name => 'school district', :values => []}])
    calc.target(table)

    calc.should be_ready

    calc.recipe.should == [{:command => 'select_where.pl', :args => { :column => 2, :value => 'Los Altos Elementary', :invert => 0 }}]

    spec = calc.resultspec
    spec.columns.size.should == 2
    spec.columns.last.name.should == 'school name'
  end
end

describe "measure-column extraction calculation" do
  it "should require column number to extract" do
    Dataset::Calculation.find("column").should_not be_terminal
    Dataset::Calculation.find("column-2").should be_terminal
  end

  it "should require a target" do
    calc = Dataset::Calculation.find("column-2")
    calc.should_not be_ready
  end

  it "should barf when target has no measure columns" do
    calc = Dataset::Calculation.find("column-1")

    calc.target(table = Dataset::Table.new())
    calc.should_not be_ready

    calc.target(table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:label => 'indeterminate'}]))
    calc.should_not be_ready

    calc.target(table = Dataset::Table.new(:columns => [{:name => 'Department'}, {:name => 'Manager'}]))
    calc.should_not be_ready
  end

  it "should barf when target has no measure in the specified column" do
    calc0 = Dataset::Calculation.find("column-0")
    calc2 = Dataset::Calculation.find("column-2")

    table = Dataset::Table.new(:columns => [{:chron => Dataset::Chron::YYYY}, {:number => Dataset::Number::Count}])
    calc0.target(table)
    calc0.should_not be_ready
    calc2.target(table)
    calc2.should_not be_ready
  end

  it "should pass when target has measure in the specified column" do
    calc = Dataset::Calculation.find("column-1")

    calc.target(table = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Unspecified Measure'}]))
    calc.should be_ready

    calc.recipe.should == [{:command => 'columns.pl', :args => { :columns => "0,1" }}]
    spec = calc.resultspec
    spec.columns.size.should == 2
    spec.columns[0].metadata[:chron].should == 'YYYYMM'
    spec.columns[1].metadata[:number].should == 'Unspecified Measure'
  end
end

describe "simple table merge" do
  it "should require no parameters" do
    Dataset::Calculation.find("merge").should be_terminal
  end

  it "should require two targets" do
    calc = Dataset::Calculation.find("merge")
    calc.target(table = mock)
    calc.should_not be_ready
  end

  it "should check for mismatched chrons" do
    calc = Dataset::Calculation.find("merge")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should_not be_ready
  end

  it "should reject dimension columns" do
    calc = Dataset::Calculation.find("merge")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:name => 'State'}, {:number => 'Units'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should_not be_ready

    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:name => 'State'}, {:number => 'Units'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should_not be_ready
  end

  it "should require identical chrons" do
    calc = Dataset::Calculation.find("merge")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units', :name => 'Shipments'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units', :name => 'Backlog'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should be_ready

    calc.recipe.should == [{:command => 'merge.rb', :args => { :input => "1", :group1 => "0", :group2 => "0", :pick2 => "1" }}]

    spec = calc.resultspec
    spec.columns.size.should == 3
    spec.columns.each do |col|
      col.metadata.should be_instance_of(Hash)
    end
    spec.columns[0].metadata[:chron].should == 'YYYY'
    spec.columns[1].metadata[:number].should == 'Units'
    spec.columns[1].name.should == 'Shipments'
    spec.columns[2].metadata[:number].should == 'Units'
    spec.columns[2].name.should == 'Backlog'
  end
end

describe "rollup calculation" do
  it "should take a chron cycle and how-to-rollup algorithm" do
    Dataset::Calculation.find("rollup").should_not be_terminal
    Dataset::Calculation.find("rollup-mon").should_not be_terminal
    Dataset::Calculation.find("rollup-mon-last").should be_terminal
  end
end

describe "monthly rollup of daily data based on end-of-month value" do
  it "should require a target with necessary signature" do
    calc = Dataset::Calculation.find("rollup-mon-last")

    oktable = Dataset::Table.new(:columns => [{:chron => 'YYMMDD'}, {:number => 'Dollars'}])

    badtables = [
      Dataset::Table.new(:columns => []),
      Dataset::Table.new(:columns => [{:chron => 'YYMMDD'}, {:name => 'Category'}, {:number => 'Dollars'}]),
      Dataset::Table.new(:columns => [{:chron => 'YYMMDD'}, {:number => 'Dollars'}, {:number => 'Dollars'}]),
      Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}]),
      Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    ]

    calc.target(oktable)
    calc.should be_ready

    badtables.each {|tbl| calc.target(tbl); calc.should_not be_ready}
  end

  it "should produce rollup recipe and spec" do
    calc = Dataset::Calculation.find("rollup-mon-last")
    table = Dataset::Table.new(:columns => [{:chron => 'YYMMDD'}, {:number => 'Dollars'}])
    calc.target(table)
    calc.should be_ready

    calc.recipe.should == [{:command => 'rollup.rb', :args => { :chron => 'YYMMDD', :level => 'month', :formula => 'last', :chroncol => 0, :datacol => 1 }}]
    spec = calc.resultspec
    spec.columns.size.should == 2
    spec.columns[0].chron.should == Dataset::Chron::YYYYMM
    spec.columns[1].name == table.columns[1].name
    spec.columns[1].units == table.columns[1].units
  end
end
