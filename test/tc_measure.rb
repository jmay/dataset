require File.dirname(__FILE__) + '/test_helper'

class TestMeasure < Test::Unit::TestCase
  def test_computations
    revenue = Dataset::Measure.new(:name => "Revenue", :units => Dataset::Units::Dollars)
    spending = Dataset::Measure.new(:name => "Spending", :units => Dataset::Units::Dollars)
    r1 = revenue.instance(50.million)
    s1 = spending.instance(47.million)
    surplus = r1 - s1
    assert_kind_of(Dataset::Units::Dollars, surplus)
    assert_equal(3.million, surplus.value)

    gdp = Dataset::Measure.new(:name => "GDP", :units => Dataset::Units::Dollars)
    g1 = gdp.instance(322.billion)
    frac = s1 / g1
    assert_kind_of(Dataset::Units::Percentage, frac)
    assert_equal(47.0/322/1000, frac.value)
    assert_equal("GDP", gdp.name)
    gdp.name = "Gross Domestic Product"
    assert_equal("Gross Domestic Product", gdp.name)
  end

  def test_meas_delta
    base = Dataset::Measure.new
    delta_measure = base.delta
#     assert(delta_measure.delta?)
    assert_equal("Percent Change in Unspecified", delta_measure.name)
    assert_equal(Dataset::Units::Percentage, delta_measure.units)
    assert_equal("percent", delta_measure.describe)
    assert_equal("12.2%", delta_measure.format(12.2))
  end

  def test_change_units
    measure = Dataset::Measure.new
    assert_equal(Dataset::Units::Discrete, measure.units)
    assert_equal("", measure.describe)
    measure.units = Dataset::Units::Dollars
    assert_equal(Dataset::Units::Dollars, measure.units)
    assert_equal("dollars", measure.describe)
    # (:name => "Revenue", :units => Dataset::Units::Dollars, :multiplier => Dataset::Units::MILLION)
  end

  # distinguish between "event" and "state" measures
  # def test_nature
  #   measure = Dataset::Measure.new
  #   assert(measure.state?)
  #   measure.nature = :event
  #   assert(measure.event?)
  #   assert(!measure.state?)
  # end

  def test_multipliers
    revenue = Dataset::Measure.new(:name => "Revenue", :units => Dataset::Units::Dollars)
    assert_equal("dollars", revenue.describe)
    r1 = revenue.instance(50, :million)
    assert_equal(50_000_000, r1.value)
  end

  def test_yaml
    revenue = Dataset::Measure.new(:name => "Revenue", :units => Dataset::Units::Dollars)
    # puts "units are #{revenue.units.to_yaml}"
    y = revenue.to_yaml
    r2 = YAML::load(y)
    assert_equal(r2.units, revenue.units)
  end

  def test_missing_name
    m = Dataset::Measure.new
    assert(m.unspecified?, "Haven't specified name yet")
    m.name = "Widgets"
    assert(!m.unspecified?, "Specified it now.")
    assert_equal("Widgets", m.name)
  end

  def test_measure_notes
    m1 = Dataset::Measure.new(:name => "Consumer Price Index", :units => Dataset::Units::Continuous)
    m1.notes = "Not Seasonally Adjusted"
    m2 = Dataset::Measure.new(:name => "Consumer Price Index", :units => Dataset::Units::Continuous)
    m2.notes = "Not Seasonally Adjusted"
    m3 = Dataset::Measure.new(:name => "Consumer Price Index", :units => Dataset::Units::Continuous)
    m3.notes = "Seasonally Adjusted"

    assert_equal(m1.digest, m2.digest)
    assert_not_equal(m1.digest, m3.digest)
  end

  def test_multipliers2
    m = Dataset::Measure.new(:name => "GDP", :multiplier => :billion, :units => Dataset::Units::Dollars)
    assert_equal(:billion, m.multiplier)
    assert_equal("billions of dollars", m.describe)
    m.multiplier = :million
    assert_equal(:million, m.multiplier)
    assert_equal("millions of dollars", m.describe)
  end

  def test_comparison
    m1 = Dataset::Measure.new(:name => "Measure Test")
    m2 = Dataset::Measure.new(:name => "Measure Test")
    assert_equal(m1, m2)
    m3 = :foo
    assert m1 != m3
  end

  def test_percent
    m1 = Dataset::Measure.new(:units => Dataset::Units::Percentage)
    assert_nil(m1.multiplier)
  end

  def test_format
    m1 = Dataset::Measure.new(:units => Dataset::Units::Dollars)
    assert_equal("$4,212.00", m1.format(4212))
    assert_equal("dollars", m1.describe.downcase)
    m2 = Dataset::Measure.new(:units => Dataset::Units::Dollars, :multiplier => :thousand)
    assert_equal("4,212", m2.format(4212))
    assert_equal("$4,212.00", m2.format(4212, :decimals => 2, :sigil => "$"))
    assert_equal("thousands of dollars", m2.describe.downcase)
    # m2.name = "Change in foobar"
    # assert_equal("4,212", m2.format(4212))
  end

  def test_measure_descriptions
    assert_equal("thousands", Dataset::Measure.new(:multiplier => :thousand).describe)
    assert_equal("thousands", Dataset::Measure.new(:multiplier => :thousand, :units => Dataset::Units::Discrete).describe)
    assert_equal("thousands", Dataset::Measure.new(:multiplier => :thousand, :units => Dataset::Units::Continuous).describe)
    assert_equal("", Dataset::Measure.new(:units => Dataset::Units::Continuous).describe)
    assert_equal("", Dataset::Measure.new(:units => Dataset::Units::Discrete).describe)
    assert_equal("dollars", Dataset::Measure.new(:multiplier => :ones, :units => Dataset::Units::Dollars).describe)
    assert_equal("millions of dollars", Dataset::Measure.new(:multiplier => :million, :units => Dataset::Units::Dollars).describe)
    assert_equal("percent", Dataset::Measure.new(:units => Dataset::Units::Percentage).describe)
  end

  def test_float_precision_handling
    # default precision is zero
    m1 = Dataset::Measure.new(:units => Dataset::Units::Dollars, :multiplier => :million)
    assert_equal("42", m1.format(42.3))
    m1.precision = 1
    assert_equal("42.3", m1.format(42.3))
    m1.precision = 2
    assert_equal("42.30", m1.format(42.3))

    # default behavior for dollars in ones is: precision = 2 and sigil = $
    m2 = Dataset::Measure.new(:units => Dataset::Units::Dollars, :multiplier => :ones)
    assert_equal("$42.30", m2.format(42.3))
    m2.precision = 1
    assert_equal("$42.3", m2.format(42.3))
    m2.precision = 2
    assert_equal("$42.30", m2.format(42.3))
  end
end
