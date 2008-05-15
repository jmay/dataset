require File.dirname(__FILE__) + '/spec_helper'

require "dataset/number"

describe 'percentages' do
  it "should give value as N/100" do
    Dataset::Number::Percentage.new(4.3).value.should == 0.043
  end

  it "should by default display with no decimals" do
    Dataset::Number::Percentage.new(4.3).to_s.should == "4%"
  end

  it "should support formatting control" do
    Dataset::Number::Percentage.new(12.8, :format => "%0.2f%%").to_s.should == "12.80%"
  end
end
