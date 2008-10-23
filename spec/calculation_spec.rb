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

    Dataset::Calculation.find("extract-1").should be_terminal
    Dataset::Calculation.find("extract-1-California").should be_terminal
  end

  it "should require a target" do
    calc = Dataset::Calculation.find("extract-State-California")
    calc.should be_terminal
    calc.should_not be_ready

    calc = Dataset::Calculation.find("extract-1-California")
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

  it "should be OK when referring to dimension column by colnum" do
    calc2 = Dataset::Calculation.find("extract-0-California")
    calc2.target(table = Dataset::Table.new(:columns => [:values => ['Oregon', 'Arizona']]))
    calc2.should be_ready
  end

  it "should insist on a dimension column when descriptor refers by colnum" do
    calc = Dataset::Calculation.find("extract-0-California")
    calc.target(table = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:values => ['Alabama', 'Alaska']}]))
    calc.should_not be_ready

    calc = Dataset::Calculation.find("extract-1-California")
    calc.target(table = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:values => ['Alabama', 'Alaska']}]))
    calc.should be_ready

    calc = Dataset::Calculation.find("extract-1-California")
    calc.target(table = Dataset::Table.new(:columns => [{:values => ['Alabama', 'Alaska']}, {:number => 'Units'}]))
    calc.should_not be_ready
  end

  it "should barf when dimension value is missing" do
    calc = Dataset::Calculation.find("extract-State")
    table = Dataset::Table.new(:columns => [{:name => 'State', :values => []}])
    calc.target(table)
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
    calc.should be_ready

    calc.recipe.should == [{:command => 'select_where.pl', :args => { :column => 0, :value => 'California', :invert => 0 }}]

    spec = calc.resultspec
    spec = calc.resultspec # test to make sure that calc#resultspec is not destructive
    spec.columns.size.should == 1
    spec.columns.first.units.should == Dataset::Number::Count
    spec.constraints.should == {'State' => 'California'}
  end

  it "should work when target has a dimension in the right place" do
    calc = Dataset::Calculation.find("extract-1-California")
    table = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:values => ['California', 'Arizona']}, {:number => 'Units'}])
    calc.target(table)
    calc.should be_ready

    calc.recipe.should == [{:command => 'select_where.pl', :args => { :column => 1, :value => 'California', :invert => 0 }}]

    spec = calc.resultspec
    spec = calc.resultspec # test to make sure that calc#resultspec is not destructive
    spec.columns.size.should == 2
    spec.measure_column.units.should == Dataset::Number::Count
    spec.constraints.should == {nil => 'California'}
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
    spec.constraints.should == {'school district' => 'Los Altos Elementary'}
  end

  it "should allow dimension values with dashes" do
    calc = Dataset::Calculation.find("extract-Age+Range-25-39")
    table = Dataset::Table.new(:columns =>
      [{:name => 'Age Range', :values => []}, {:name => 'Population', :number => 'People'}])
    calc.target(table)

    calc.should be_ready

    calc.recipe.should == [{:command => 'select_where.pl', :args => { :column => 0, :value => '25-39', :invert => 0 }}]
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

    calc.recipe.should == [{:command => 'columns.pl', :args => { :columns => "0,1" }}, {:command => 'filter_out.rb', :args => { :column => 1, :match => ''}}]
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

describe "coalesce calculation" do
  it "should require target, constituents and spec" do
    calc = Dataset::Calculation.find("coalesce")
    calc.should be_terminal
    calc.should_not be_ready

    calc.target(table = mock)
    calc.should_not be_ready
    calc.constituents = [1,2,3]
    calc.should be_ready
  end

  it "should construct resultspec from the constituent specs" do
    calc = Dataset::Calculation.find("coalesce")
    calc.target(table = mock)
    t1 = Dataset::Table.new(:nrows => 100, :columns => [ {:chron => 'YYYYMM', :min => 24000, :max => 24023}, {:name => 'Region'}, {:number => 'Units', :min => 200, :max => 600}])
    t2 = Dataset::Table.new(:nrows => 200, :columns => [ {:chron => 'YYYYMM', :min => 24024, :max => 24047}, {:name => 'Region'}, {:number => 'Units', :min => 400, :max => 800}])
    t3 = Dataset::Table.new(:nrows => 300, :columns => [ {:chron => 'YYYYMM', :min => 24048, :max => 24071}, {:name => 'Region'}, {:number => 'Units', :min => 300, :max => 900}])
    calc.constituents = [t1, t2, t3]
    calc.recipe.should == [{ :command => 'coalesce', :args => {:files => [t1, t2, t3]}}]

    spec = calc.resultspec
    spec.nrows.should == 600
    spec.columns[0].should be_chron
    spec.columns[0].min.index.should == 24000
    spec.columns[0].max.index.should == 24071
    spec.columns[2].should be_measure
    spec.columns[2].min.value.should == 200
    spec.columns[2].max.value.should == 900
  end
end

describe "difference between two tables" do
  it "should be defined" do
    calc = Dataset::Calculation.find("aminusb")
    calc.should be_terminal
    calc.should_not be_ready
  end

  it "should require 2 targets" do
    calc = Dataset::Calculation.find("aminusb")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}])
    calc.target(table1)
    calc.should_not be_ready
    calc.target2(table2)
    calc.should be_ready
  end

  it "should check for mismatched chrons" do
    calc = Dataset::Calculation.find("aminusb")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:number => 'Units'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYYMM'}, {:number => 'Units'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should_not be_ready
  end

  it "should reject dimension columns" do
    calc = Dataset::Calculation.find("aminusb")
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

  it "should produce recipe & spec" do
    calc = Dataset::Calculation.find("aminusb")
    table1 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:name => "LIBOR", :number => 'Percent'}])
    table2 = Dataset::Table.new(:columns => [{:chron => 'YYYY'}, {:name => "Fed", :number => 'Percent'}])
    calc.target(table1)
    calc.target2(table2)
    calc.should be_ready

    calc.recipe.should == [{:command => 'subtract.rb', :args => { :input => "1", :group1 => "0", :group2 => "0", :pick1 => 1, :pick2 => 1 }}]

    spec = calc.resultspec
    spec.columns.size.should == 2
    spec.columns[0].chron.should == Dataset::Chron::YYYY
    spec.columns[1].units.label.should == 'Percent'
    spec.columns[1].name.should == "LIBOR minus Fed"
  end
end
