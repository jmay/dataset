require File.dirname(__FILE__) + '/spec_helper'

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
        :label => 'Sales'}
       ])
    @calc.target(table)
    # table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    # table.
    @calc.should be_ready
    @calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 1, :percent => true }}]
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
    calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 3, :percent => true }}]
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
      {:number => 'Count',
        :label => 'Sales'}
       ])
    calc.target(table)
    calc.should be_ready
    calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 12, :percent => false }}]
    newtable = calc.resultspec
    newtable.columns.size.should == 2
    newtable.chron.should == Dataset::Chron::YYYYMM
    newtable.measure_column.label.should == 'Annual change in Sales'
    calc.should respond_to(:execute)

    # TODO: validate calc.tablespec
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

    calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYYMM)

    calc.should_not be_ready
  end

  it "should work when target has the right chron" do
    calc = Dataset::Calculation.find("baseline-1995")
    calc.should_not be_ready
    calc.should be_terminal

    calc.target(table = mock)
    table.stubs(:chron).returns(Dataset::Chron::YYYY)
    table.stubs(:chrons).returns([ Dataset::Chron::YYYY.new('1995') ])

    calc.should be_ready
    calc.recipe.should == [{:command => 'baseline', :args => { :chroncol => 0, :basechron => 1995 }}]

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
    table = Dataset::Table.new(:columns => [{:name => 'State'}, {:units => Dataset::Number::Count}])
    calc.target(table)
    # table.stubs(:dimensions).returns([dim = mock])
    # dim.stubs(:name).returns('State')
    calc.should be_ready

    calc.recipe.should == [{:command => 'filter', :args => { :column => 0, :value => 'California' }}]

    # TODO: validate calc.tablespec
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

# describe 'Calculations' do
#   it "should round-trip descriptors" do
#     Calculation.new('changes-percent-monthly').should == Calculation.MonthlyDeltas
#     Calculation.new(Calculation.AnnualDiffs.descriptor).should == Calculation.AnnualDiffs
#     Calculation.new(Calculation.Baseline.descriptor).should == Calculation.Baseline
#     Calculation.new(Calculation.Ratio.descriptor).should == Calculation.Ratio
#   end
# 
#   it "should contain readable descriptions" do
#     Calculation.MonthlyDeltas.description.should == 'Monthly Deltas'
#     Calculation.AnnualDeltas.description.should == 'Annual Deltas'
#     Calculation.MonthlyDiffs.description.should == 'Monthly Changes'
#     Calculation.Baseline.description.should == 'Normalized based on...'
#   end
# 
#   it "should ..." do
#     calc = Calculation.new(:baseline, :at => '1995')
#     calc.description.should == 'Normalized to 1995=100'
#   end
# end
# 
# describe "simple unary calculations" do
#   it "should take no parameters" do
#     Calculation.AnnualDiffs.param?.should be_false
#   end
# end
# 
# describe "baseline calculation (unary with param based on target)" do
#   it "should require a parameter" do
#     Calculation.Baseline.param?.should be_true
#   end
# 
#   it "should get set of possible value from the target" do
#     target = mock
#     target.expects(:chrons).returns(['2000', '2001', '2002'])
#     Calculation.Baseline.values(target).should == ['2000', '2001', '2002']
#   end
# end
# 
# describe "adjust multiplier (unary with fixed param)" do
#   it "should require a parameter" do
#     Calculation.Multiply.param?.should be_true
#   end
# 
#   it "should get set of possible value from the target" do
#     target = mock
#     target.expects(:chrons).returns(['2000', '2001', '2002'])
#     Calculation.Baseline.values(target).should == ['2000', '2001', '2002']
#   end
# end
# 
# describe "ratio (binary calculation)" do
#   it "should know that it needs a targets" do
#     Calculation.Ratio.param?.should be_true
#   end
# end
