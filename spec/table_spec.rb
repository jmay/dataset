require File.dirname(__FILE__) + '/spec_helper'

require "yaml/syck"

# Table should be independent of the details of the pipeline output; glue code to construct
# a Table from the recipe runlog should be outside of this class.

describe "role extraction" do
  it "should determine column roles from pipeline runlog" do
  end

  it "should extract role info from column metadata" do
    table = Dataset::Table.new([{:chron => Dataset::Chron::YYYYMM}, {:units => Dataset::Number::Dollars}])

    table.columns.size.should == 2

    table.chron_columns.size == 1
    table.chron?.should be_true
    table.chron.should == Dataset::Chron::YYYYMM

    table.dimension_columns.size == 1
    table.dimensions.empty?.should be_true

    table.measure_columns.size == 1
    table.measures.any?.should be_true
    table.measure?.should be_true
    # table.measure.multiplier.should == :ones
    # table.measure.units.should == Dataset::Units::Dollars
  end
end

describe "table construction from pipeline runlog" do
  it "should find all the column metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    table = Dataset::Table.from_runlog(runlog)
    table.columns.size.should == 2
    table.columns[0].metadata.should == { :colnum => 0, :chron => Dataset::Chron::YYYYMM }
    table.columns[1].metadata.should == { :colnum => 1, :measure => 'Discrete' }
  end

  it "should interpret data from NSF according to the metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    table = Dataset::Table.from_runlog(runlog)
    datafile = File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/output'
    table.generate(datafile)
    table.columns[0].data.size.should == 530
    table.columns[0].data.each {|v| v.should be_instance_of(Dataset::Chron::YYYYMM)}
    table.columns[1].data.size.should == 530
  end
end

# given a Table, we can:
# * ask what operations is supports (so we can present options to the user)
# * ask if supports a particular operation (verify against users trying to break the system)
# * construct the recipe for an operation (for validation)
# * execute an operation
# 
# describe "with YYYYMM/measure" do
#   before(:all) do
#     @table = Table.new([{:chron => Dataset::Chron::YYYYMM}, {:units => Dataset::Number::Dollars}])
#   end
# 
#   it "should give list of available calculations" do
#     calcs = @table.calculations
#     calcs.should include(Calculation.MonthlyDeltas)
#     calcs.should include(Calculation.QuarterlyDeltas)
#     calcs.should include(Calculation.AnnualDeltas)
#     calcs.should include(Calculation.MonthlyDiffs)
#     calcs.should include(Calculation.QuarterlyDiffs)
#     calcs.should include(Calculation.AnnualDiffs)
# 
#     calcs.should include(Calculation.Baseline)
# 
#     calcs.should include(Calculation.Ratio)
#   end
# 
#   it "should know about unary operations" do
#     table.supports?(Calculation.MonthlyDeltas)
#     table.supports?(Calculation.Baseline)
#   end
# 
#   it "should support binary operations" do
#     table.supports?(Calculation.Ratio)
#   end
# end
