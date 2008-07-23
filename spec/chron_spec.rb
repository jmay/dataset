require File.dirname(__FILE__) + '/spec_helper'

require "dataset/chron"

describe 'quarters' do
  it "should accept YYYY-QQ" do
    Dataset::Chron::YYYYQ.new('2008-01').to_s.should == '2008Q1'
    lambda {Dataset::Chron::YYYYQ.new('2008-05')}.should raise_error(RuntimeError)
  end

  it "should accept YYYY-MM-DD syntax, with MM=01/02/03/04, DD=01" do
    Dataset::Chron::YYYYQ.new('2008-01-01').to_s.should == '2008Q1'

    lambda {Dataset::Chron::YYYYQ.new('2008-04-02')}.should raise_error(RuntimeError)
    lambda {Dataset::Chron::YYYYQ.new('2008-05-01')}.should raise_error(RuntimeError)
  end
end

describe "school year" do
  it "should be handled internally as the end year of the pair" do
    Dataset::Chron::SchoolYear.new('2006-07').to_s.should == '2007'
    Dataset::Chron::SchoolYear.new('2006-2007').to_s.should == '2007'
    Dataset::Chron::SchoolYear.new('2007').to_s.should == '2007'
  end

  it "should index same as regular year" do
    Dataset::Chron::SchoolYear.new('2006-07').index.should == Dataset::Chron::YYYY.new('2007').index
  end

  it "should instantiate from index" do
    Dataset::Chron::SchoolYear.new(:index => 2007).to_s.should == '2007'
  end
end
