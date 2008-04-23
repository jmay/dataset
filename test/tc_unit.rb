require File.dirname(__FILE__) + '/test_helper'

class TestUnits < Test::Unit::TestCase
  def test_strings
    assert_equal(32, Dataset::Units::Discrete.new("32").value)
  end

  def test_magnitudes
    fourk = Dataset::Units::Discrete.new(4.thousand)
    assert_equal(4000, fourk.value)
    assert_kind_of(Fixnum, fourk.value)
    fourm = Dataset::Units::Discrete.new(4.million)
    assert_equal(4_000_000, fourm.value)
    assert_raise(NoMethodError) { fourm.value = 32 }
    assert_raise(NoMethodError) { fourm.multiplier = 1000 }

    twok = Dataset::Units::Discrete.new(2, :thousand)
    assert_equal(2_000, twok.value)

    floatk = Dataset::Units::Continuous.new(4.7, :thousand)
    assert_equal(4_700, floatk.value)
  end

  def test_people
    peeps = Dataset::Units::People.new(23.million)
    assert_kind_of(Fixnum, peeps.value)
    assert_equal("23,000,000", peeps.format)
  end

  def test_no_mult
    somenumber = Dataset::Units::Continuous.new(123.45)
    assert_kind_of(Float, somenumber.value)
    assert_equal("123", somenumber.format(:decimals => 0))
    assert_equal("123.5", somenumber.format)
    assert_equal("123.45", somenumber.format(:decimals => 2))
  end

  def test_percentage
    pct = Dataset::Units::Percentage.new(12.4)
    assert_kind_of(Float, pct.value)
    assert_raise(NoMethodError) { pct.multiplier }
#     assert_equal(0.124, pct.value)
    assert_equal(12.4, pct.value)
    assert_equal("12.4%", pct.format)
    assert_equal("12.400%", pct.format(:decimals => 3))
    assert_equal("+12.4%", pct.format(:sign => true))
    assert_equal("-0.05%", Dataset::Units::Percentage.new(-0.05).format(:sign => true, :decimals => 2))
    assert_equal("Percent", pct.class.label)
  end

  def test_formatting
    assert_equal("12,345", Dataset::Units::Discrete.new(12345).format)
    assert_equal("+12,345", Dataset::Units::Discrete.new(12345).format(:sign => true))
    assert_equal("1,234.5", Dataset::Units::Continuous.new("1234.5").format(:decimals => 1))
    assert_equal("15%", Dataset::Units::Percentage.new(15).format(:decimals => 0))
    assert_equal("15.0%", Dataset::Units::Percentage.new(15).format(:decimals => 1))
    assert_equal("1,500%", Dataset::Units::Percentage.new(1500).format(:decimals => 0))
  end
  
  def test_unit_math
    d1 = Dataset::Units::Discrete.new(1234)
    d2 = Dataset::Units::Discrete.new(987)
    d3 = d1 - d2
    assert_kind_of(Dataset::Units::Discrete, d3)
    assert_equal(1234-987, d3.value)
    assert_equal("+#{1234-987}", d3.format(:sign => true))
    pct = d2 / d1
    assert_kind_of(Dataset::Units::Percentage, pct)
    assert((pct.value - 987.0/1234*100) < 0.00001)
    assert_equal("Units", d1.class.label)
  end

  def test_comparison
    d1 = Dataset::Units::Dollars.new(1234)
    d2 = Dataset::Units::Dollars.new(987)
    assert(d1 > d2)
    assert_raise(TypeError) { d1 > 987 }
    assert_raise(TypeError) { d1 > Dataset::Units::Continuous.new(987) }
    assert_equal("Dollars", d1.class.label)
  end

  def test_dollars
    assert_equal("$1.23", Dataset::Units::Dollars.new(1.23).format)
    assert_equal("$123", Dataset::Units::Dollars.new(123).format({:decimals => 0}))
    assert_equal("+$123", Dataset::Units::Dollars.new(123).format({:decimals => 0, :sign => true}))
    assert_equal("-$123", Dataset::Units::Dollars.new(-123).format({:decimals => 0}))
  end

  def test_lists
    assert_instance_of(Array, Dataset::Units::all)
    assert Dataset::Units.all.include?("Units")
    assert Dataset::Units.all.include?("Artificial Index")
  end

  def test_yaml
    u = Dataset::Units::Dollars.new(47)
    assert_match(/Dataset::Units::Dollars/, u.to_yaml)
    assert_kind_of(u.class, YAML.load(u.to_yaml))
    uc = Dataset::Units::Dollars
    uc2 = YAML.load(uc.to_yaml)
    assert_equal(Dataset::Units::Dollars, uc2)
    assert_equal("Dollars", uc2.label)
  end

  def test_extract_units
    assert_equal(:ones, Dataset::Units.extract_unit("no units mentioned here"))
    assert_equal(:thousand, Dataset::Units.extract_unit("this should report thousands"))
    assert_equal(:million, Dataset::Units.extract_unit("this should\nreport\tMILLIONS OF THINGS\nfoo"))
    assert_equal(:billion, Dataset::Units.extract_unit("stuff in billions of thingies\n\n"))
  end

  def test_find
    assert_equal(Dataset::Units::Discrete, Dataset::Units.find("Units"))
    assert_equal(Dataset::Units::Dollars, Dataset::Units.find("Dollars"))
    assert_nil(Dataset::Units.find("nosuchunit"))
  end

  def test_generics # core units are generic (i.e. "nameless"), others are more specific
    assert Dataset::Units::Discrete.generic?
    assert Dataset::Units::Continuous.generic?
    assert !Dataset::Units::Percentage.generic?
    assert Dataset::Units::Artificial.generic?
    assert Dataset::Units::Money.generic?
    assert !Dataset::Units::Dollars.generic?
  end
end
