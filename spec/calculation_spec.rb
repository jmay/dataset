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

  it "should build recipe & run" do
    @calc.should respond_to(:target)
    @calc.should_not be_ready

    table = Dataset::Table.new([
      {:chron => Dataset::Chron:: YYYYMM},
      {:units => Dataset::Number::Count}
       ])
    @calc.target(table)
    # table.stubs(:chron).returns(Dataset::Chron::YYYYMM)
    # table.
    @calc.should be_ready
    @calc.recipe.should == [{ :command => 'deltas', :args => {:ordercol => 0, :datacol => 1, :interval => 1, :percent => true }}]
    @calc.should respond_to(:execute)
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

    calc.target(table = Dataset::Table.new([{:chron => Dataset::Chron::YYYY}, {:units => Dataset::Number::Count}]))
    calc.should_not be_ready

    calc.target(table = Dataset::Table.new([:name => 'Department']))
    calc.should_not be_ready
  end

  it "should barf when target has no matching dimension" do
    calc = Dataset::Calculation.find("extract-State-California")
    calc.target(table = Dataset::Table.new([:name => 'Department']))
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
    table = Dataset::Table.new([{:name => 'State'}, {:units => Dataset::Number::Count}])
    calc.target(table)
    # table.stubs(:dimensions).returns([dim = mock])
    # dim.stubs(:name).returns('State')
    calc.should be_ready

    calc.recipe.should == [{:command => 'filter', :args => { :column => 0, :value => 'California' }}]
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
