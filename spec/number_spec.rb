require File.dirname(__FILE__) + '/spec_helper'

require "dataset/number"

describe Dataset::Number do
  it "should know all the available types" do
    Dataset::Number.all.should == ["Dollars", "Index", "People", "Percent", "Units", "Unspecified Measure"]

    # make sure that custom subtypes don't pollute the "all" list
    Dataset::Number::find('Percent', :decimals => 4).should_not be_nil
    Dataset::Number.all.should == ["Dollars", "Index", "People", "Percent", "Units", "Unspecified Measure"]
  end

  it "should know names" do
    Dataset::Number.find(nil).should be_nil
  end
end

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

  it "should round decimals if no multiplier" do
    Dataset::Number::Count.new("47.9").to_s.should == "48"
    Dataset::Number::Count.new("47.1").to_s.should == "47"
  end

  it "should display with decimals if multiplier > 1" do
    n = Dataset::Number::Count.new("47.9", :multiplier => 1000)
    n.to_s.should == "47.9"
    n.adjusted_value.should == 47_900
    n = Dataset::Number::Count.new("47.9", :multiplier => :thousand)
    n.to_s.should == "47.9"
    n.adjusted_value.should == 47_900
  end

  it "should raise error on unacceptable input" do
    lambda {Dataset::Number::Count.new("n/a")}.should raise_error(RuntimeError, "Invalid number value 'n/a'")
    lambda {Dataset::Number::Count.new("---")}.should raise_error(RuntimeError, "Invalid number value '---'")
    lambda {Dataset::Number::Count.new("NA")}.should raise_error(RuntimeError, "Invalid number value 'NA'")
    lambda {Dataset::Number::Count.new("()")}.should raise_error(RuntimeError, "Invalid number value '()'")
    lambda {Dataset::Number::Count.new("")}.should raise_error(RuntimeError, "Invalid number value ''")
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

  it "should support format override, not put commas after the decimal" do
    Dataset::Number::Quantity.new("12345.6789", :format => '%.4f').to_s.should == "12,345.6789"
  end

  it "should reject bad input" do
    lambda {Dataset::Number::Quantity.new("n/a")}.should raise_error(RuntimeError, "Invalid number value 'n/a'")
    lambda {Dataset::Number::Quantity.new("ND")}.should raise_error(RuntimeError, "Invalid number value 'ND'")
    lambda {Dataset::Number::Quantity.new("")}.should raise_error(RuntimeError, "Invalid number value ''")
  end
end

describe "floats with custom formats" do
  it "should be able to create on demand" do
    n = Dataset::Number.find('%.4f')
    n.new('12.34567').to_s.should == '12.3457'
    n.label.should == '%.4f'
  end

  it "should not create duplicate dynamic number classes" do
    n1 = Dataset::Number.find('%.4f')
    n2 = Dataset::Number.find('%.4f')
    n1.should == n2
  end
end

describe 'percentages' do
  it "should know its name" do
    Dataset::Number.find('Percent').should == Dataset::Number::Percentage
    Dataset::Number::Percentage.label.should == 'Percent'
    Dataset::Number::Percentage.should_not be_generic
  end

  it "should handle string conversions" do
    Dataset::Number::Percentage.new("4.3").value.should == 4.3
    Dataset::Number::Percentage.new("4.3%").value.should == 4.3
    Dataset::Number::Percentage.new("+14.3%").value.to_s.should == "14.3"  # float == issue
    Dataset::Number::Percentage.new("-91%").value.should == -91.0
  end

  it "should by default display with one decimal" do
    Dataset::Number::Percentage.new(4.3).to_s.should == "4.3%"
    Dataset::Number::Percentage.new('4').to_s.should == "4.0%"
    Dataset::Number::Percentage.new(42.28).to_s.should == "42.3%"
  end

  it "should support formatting control" do
    Dataset::Number::Percentage.new(12.8, :decimals => 2).to_s.should == "12.80%"

    k = Dataset::Number.find('Percent', :decimals => 2)
    k.new(12.8).to_s.should == '12.80%'
    k.label.should == 'Percent'
  end
end

describe "dollars" do
  it "should know its name" do
    Dataset::Number.find('Dollars').should == Dataset::Number::Dollars
    Dataset::Number::Dollars.label.should == 'Dollars'
    Dataset::Number::Dollars.should_not be_generic
  end

  it "should convert strings" do
    Dataset::Number::Dollars.new("4.3").value.should == 4.3
    Dataset::Number::Dollars.new("+14.3").value.should == 14.3
    Dataset::Number::Dollars.new("-91").value.should == -91
  end

  it "should ignore dollar signs" do
    Dataset::Number::Dollars.new("$43.50").value.should == 43.50
    Dataset::Number::Dollars.new("$ 100,000").value.should == 100_000
  end

  it "should display with two decimals and dollar sign" do
    Dataset::Number::Dollars.new("4.3").to_s.should == "$4.30"
    Dataset::Number::Dollars.new("+1234.3").to_s.should == "$1,234.30"
    Dataset::Number::Dollars.new("-91.6").to_s.should == "-$91.60"
    Dataset::Number::Dollars.new('123,000').to_s.should == '$123,000.00'
  end

  it "should support format control" do
    Dataset::Number::Dollars.new('123,000').to_s.should == '$123,000.00'
    Dataset::Number::Dollars.new('123,000', :decimals => 0).to_s.should == '$123,000'
    Dataset::Number::Dollars.new('123,000', :decimals => 0).class.label.should == 'Dollars'
  end

  it "should drop the dollar sign and show zero decimals when there's a multiplier" do
    Dataset::Number::Dollars.new(123, :multiplier => 1000).to_s.should == '123'
    Dataset::Number::Dollars.new(123, :multiplier => 1000, :decimals => 2).to_s.should == '123.00'
  end

  it "should reject bad input" do
    lambda {Dataset::Number::Dollars.new("n/a")}.should raise_error(RuntimeError, "Invalid number value 'n/a'")
    lambda {Dataset::Number::Dollars.new("ND")}.should raise_error(RuntimeError, "Invalid number value 'ND'")
    lambda {Dataset::Number::Dollars.new("")}.should raise_error(RuntimeError, "Invalid number value ''")
  end

  it "should carry the formatting info in the class" do
    klass = Dataset::Number.find('Dollars', :decimals => 0)
    klass.new('123').to_s.should == '$123'
  end
end

describe "index values" do
  it "should know its name" do
    Dataset::Number.find('Index').should == Dataset::Number::Index
    Dataset::Number::Index.label.should == 'Index'
    Dataset::Number::Index.should be_generic
  end

  it "should convert strings" do
    Dataset::Number::Index.new("4.3").value.should == 4.3
    Dataset::Number::Index.new("+14.3").value.should == 14.3
    Dataset::Number::Index.new("-91").value.should == -91
  end
  
  it "should display with consistent number of decimals" do
    Dataset::Number::Index.new("4").to_s.should == "4.0"
    Dataset::Number::Index.new("+14.3").to_s.should == "14.3"
    Dataset::Number::Index.new("-91").to_s.should == "-91.0"
  end

  it "should put commas in output" do
    Dataset::Number::Index.new("12345.6789").to_s.should == "12,345.7"
  end

  it "should support format override, not put commas after the decimal" do
    Dataset::Number::Index.new("12345.6789", :format => '%.4f').to_s.should == "12,345.6789"
  end

  it "should support decimals" do
    Dataset::Number::Index.new("12345.6789", :decimals => 1).to_s.should == "12,345.7"
    Dataset::Number.find('Index', :decimals => 1).new("12345.6789").to_s.should == "12,345.7"
  end
end

describe "population figures" do
  it "should know its name" do
    Dataset::Number.find('People').should == Dataset::Number::People
    Dataset::Number::People.label.should == 'People'
    Dataset::Number::People.should be_generic
  end

  it "should convert strings" do
    Dataset::Number::People.new("27").value.should == 27
  end

  it "should strip trailing alphas" do
    Dataset::Number::People.new("27b").value.should == 27
  end

  it "should handle sign" do
    Dataset::Number::People.new("-142").value.should == -142
    Dataset::Number::People.new("+93").value.should == 93
    Dataset::Number::People.new("+07").value.should == 7
  end

  it "should strip commas" do
    Dataset::Number::People.new("12,123").value.should == 12123
    Dataset::Number::People.new("-1,234,123").value.should == -1234123
  end

  it "should display with commas" do
    Dataset::Number::People.new("12345").to_s.should == "12,345"
    Dataset::Number::People.new("-1234567").to_s.should == "-1,234,567"
  end

  it "should round decimals if no multiplier" do
    Dataset::Number::People.new("47.9").to_s.should == "48"
    Dataset::Number::People.new("47.1").to_s.should == "47"
  end

  it "should display with decimals if multiplier > 1" do
    Dataset::Number::People.new("47.9", :multiplier => 1000).to_s.should == "47.9"
  end

  it "should raise error on unacceptable input" do
    lambda {Dataset::Number::People.new("n/a")}.should raise_error(RuntimeError, "Invalid number value 'n/a'")
    lambda {Dataset::Number::People.new("---")}.should raise_error(RuntimeError, "Invalid number value '---'")
    lambda {Dataset::Number::People.new("NA")}.should raise_error(RuntimeError, "Invalid number value 'NA'")
    lambda {Dataset::Number::People.new("()")}.should raise_error(RuntimeError, "Invalid number value '()'")
    lambda {Dataset::Number::People.new("")}.should raise_error(RuntimeError, "Invalid number value ''")
  end
end
