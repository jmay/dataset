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

describe "dates (days, not months or years)" do
  it "should support strptime formats" do
    dt = Dataset::Chron::YYMMDD.new(Date.strptime('1-Jan-00', '%d-%b-%y'))
    dt.to_s.should == '2000-01-01'
    dt.index.should == 51544
  end

  it "should instantiate from index" do
    Dataset::Chron::YYMMDD.new(:index => 51544).to_s.should == '2000-01-01'
  end

  it "should support intervals spanning up to decades" do
    ymd = Dataset::Chron::YYMMDD
    ymd.intervals.first.should == 1
    ymd.next_interval_after(1).should == 7
    ymd.next_interval_after(7).should == 28
    ymd.next_interval_after(28).should == 90
    ymd.next_interval_after(90).should == 365
    ymd.next_interval_after(365).should == 365*2
    ymd.next_interval_after(365*2).should == 365*5
    ymd.next_interval_after(365*5).should == 365*10
    ymd.next_interval_after(365*10).should == 365*25
  end

  # it "should support prev & next" do
  #   now = Dataset::Chron::YYMMDD.new('2008-04-15')
  #   now.next.to_s.should == '2008-04-16'
  #   now.prev.to_s.should == '2008-04-14'
  # end
end
