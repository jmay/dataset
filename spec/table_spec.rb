require File.dirname(__FILE__) + '/spec_helper'

require "yaml/syck"

# Table should be independent of the details of the pipeline output; glue code to construct
# a Table from the recipe runlog should be outside of this class.

describe "role extraction" do
  it "should assign column numbers to columns" do
    table = Dataset::Table.new([{}, {}, {}])
    table.columns.size.should == 3
    table.columns[0].colnum.should == 0
    table.columns[1].colnum.should == 1
    table.columns[2].colnum.should == 2
  end

  it "should extract role info from column metadata" do
    table = Dataset::Table.new([{:chron => 'YYYYMM'}, {:number => 'Dollars'}])

    table.columns.size.should == 2

    table.chron_columns.size == 1
    table.chron?.should be_true
    table.chron.should == Dataset::Chron::YYYYMM
    table.chron_column.metadata[:chron].should == Dataset::Chron::YYYYMM

    table.dimension_columns.size == 1
    table.dimensions.empty?.should be_true

    table.measure_columns.size == 1
    table.measures.any?.should be_true
    table.measure?.should be_true
    table.measure_column.metadata[:number].should == Dataset::Number::Dollars
    # table.measure.multiplier.should == :ones
    # table.measure.units.should == Dataset::Units::Dollars
  end
end

describe "table construction from pipeline runlog" do
  it "should find all the column metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    table = Dataset::Table.from_runlog(runlog)
    table.columns.size.should == 2
    # table.columns[0].metadata.should == { :colnum => 0, :chron => Dataset::Chron::YYYYMM }
    # table.columns[1].metadata.should == { :colnum => 1, :number => Dataset::Number::Quantity }

    table.chron?.should be_true
    # table.chron_column[:colnum].should == 0
    table.chron.should == Dataset::Chron::YYYYMM
    table.chron_column[:min].should == 23568
    table.chron_column[:max].should == 24097

    table.measure?.should be_true
    # table.measure_column[:colnum].should == 1
    table.measure.should == Dataset::Number::Quantity
  end

  it "should interpret data from NSF according to the metadata" do
    runlog = YAML.load_file(File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/runlog')
    table = Dataset::Table.from_runlog(runlog)
    table.datafile = File.dirname(__FILE__) + '/../../pipeline/test/bls-parse/output'
    table.load
    table.columns[0].data.size.should == 530
    table.columns[0].data.each {|v| v.should be_instance_of(Dataset::Chron::YYYYMM)}
    table.columns[1].data.size.should == 530
    table.columns[1].data.first.value.should == 7.79
    table.columns[1].data.each {|v| v.should be_instance_of(Dataset::Number::Quantity)}
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
