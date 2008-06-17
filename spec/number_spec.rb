require File.dirname(__FILE__) + '/spec_helper'

require "dataset/number"

describe "regular counts" do
  it "should know its name" do
    Dataset::Number.find('Units').should == Dataset::Number::Count
    Dataset::Number::Count.label.should == 'Units'
    Dataset::Number::Count.should be_generic
  end

  it "should convert strings" do
    Dataset::Number::Count.new("27").value.should == 27
  end

  it "should strip trailing alphas" do
    Dataset::Number::Count.new("27b").value.should == 27
  end

  it "should handle sign" do
    Dataset::Number::Count.new("-142").value.should == -142
    Dataset::Number::Count.new("+93").value.should == 93
    Dataset::Number::Count.new("+07").value.should == 7
  end

  it "should strip commas" do
    Dataset::Number::Count.new("12,123").value.should == 12123
    Dataset::Number::Count.new("-1,234,123").value.should == -1234123
  end

  it "should display with commas" do
    Dataset::Number::Count.new("12345").to_s.should == "12,345"
    Dataset::Number::Count.new("-1234567").to_s.should == "-1,234,567"
  end
end

describe "float quantities" do
  it "should know its name" do
    Dataset::Number.find('Unspecified Measure').should == Dataset::Number::Quantity
    Dataset::Number::Quantity.label.should == 'Unspecified Measure'
    Dataset::Number::Quantity.should be_generic
  end

  it "should convert strings" do
    Dataset::Number::Quantity.new("4.3").value.should == 4.3
    Dataset::Number::Quantity.new("+14.3").value.should == 14.3
    Dataset::Number::Quantity.new("-91").value.should == -91
  end
  
  it "should display with consistent number of decimals" do
    Dataset::Number::Quantity.new("4.3").to_s.should == "4.30"
    Dataset::Number::Quantity.new("+14.3").value.should == 14.3
    Dataset::Number::Quantity.new("-91").value.should == -91
  end

  it "should put commas in output" do
    Dataset::Number::Quantity.new("12345.6789").to_s.should == "12,345.68"
  end

  it "should not put commas after the decimal" do
    pending "because commaize isn't working properly"
    Dataset::Number::Quantity.new("12345.6789", :format => '%.4f').to_s.should == "12,345.6789"
  end
end

describe 'percentages' do
  it "should know its name" do
    Dataset::Number.find('Percent').should == Dataset::Number::Percentage
    Dataset::Number::Percentage.label.should == 'Percent'
    Dataset::Number::Percentage.should_not be_generic
  end

  it "should handle string conversions" do
    Dataset::Number::Percentage.new("4.3").value.should == 0.043
    Dataset::Number::Percentage.new("4.3%").value.should == 0.043
    Dataset::Number::Percentage.new("+14.3%").value.to_s.should == "0.143"  # float == issue
    Dataset::Number::Percentage.new("-91%").value.should == -0.91
  end

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

describe "dollars" do
  it "should know its name" do
    Dataset::Number.find('Dollars').should == Dataset::Number::Dollars
    Dataset::Number::Dollars.label.should == 'Dollars'
    Dataset::Number::Dollars.should be_generic
  end

  it "should convert strings" do
    Dataset::Number::Dollars.new("4.3").value.should == 4.3
    Dataset::Number::Dollars.new("+14.3").value.should == 14.3
    Dataset::Number::Dollars.new("-91").value.should == -91
  end
  
  it "should display with two decimals and dollar sign" do
    Dataset::Number::Dollars.new("4.3").to_s.should == "$4.30"
    Dataset::Number::Dollars.new("+1234.3").to_s.should == "$1,234.30"
    Dataset::Number::Dollars.new("-91.6").to_s.should == "-$91.60"
  end
end
