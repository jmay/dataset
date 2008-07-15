require File.dirname(__FILE__) + '/test_helper'

class TestChron < Test::Unit::TestCase
  def test_recognize_yyyy
    @chron = Dataset::Chron::YYYY.new("1999")
    assert_equal(1999, @chron.value)
    assert_equal("1999", @chron.to_s)
    assert_equal(1999, Dataset::Chron::YYYY.new("99").value)
    assert_equal(2004, Dataset::Chron::YYYY.new("04").value)

    y2 = Dataset::Chron::YYYY.new("2006 End-of-year data")
    assert_not_nil(y2)
    assert_equal("2006", y2.to_s)
  end

  def test_yyyymm
    @chron = Dataset::Chron::YYYYMM.new("200004")
    assert_equal(2000+(4.0-1)/12, @chron.value)
    assert_equal("04/2000", @chron.to_s)
    
    assert_raise(RuntimeError, NoMethodError) { Dataset::Chron::YYYYMM.new("bogus") }
    assert_equal("Apr", @chron.mon)
    assert_equal("A", @chron.m)

    assert_equal("04/2000", Dataset::Chron::YYYYMM.new(2000.25).to_s)

    assert_equal("10/2006", Dataset::Chron::YYYYMM.new("2006.10").to_s)

    assert_equal("01/2001", Dataset::Chron::YYYYMM.new(2000.9999999999999).to_s)
    assert_raise(RuntimeError) { Dataset::Chron::YYYYMM.new(2000.9) }

    assert_same(Dataset::Chron::YYYYMM.new("2005-06"), Dataset::Chron::YYYYMM.new("2005-06-01"))

    # built-in Date parsing now recognizes "Jun 05" as "5th of June of current year"
    # assert_equal("06/2005", Dataset::Chron.new("Jun 05").to_s)
    # assert_equal(Dataset::Chron.new("Jun 05"), Dataset::Chron::YYYYMM.new(2005, "Jun"))
    # assert_equal(Dataset::Chron.new("Dec 05"), Dataset::Chron.new("December 2005"))

    dec05 = Dataset::Chron::YYYYMM.new("Dec 05")
    assert_equal(dec05, Dataset::Chron::YYYYMM.new("Dec. '05"))
    assert_equal(dec05, Dataset::Chron::YYYYMM.new("Dec '05"))
    assert_equal(dec05, Dataset::Chron::YYYYMM.new("Dec-05"))

    assert_equal("07/2007", Dataset::Chron::YYYYMM.new("July 2007").to_s)
    assert_equal("07/2007", Dataset::Chron::YYYYMM.new("July 2007 estimate").to_s)

    assert_equal("07/2007", Dataset::Chron::YYYYMM.new("2007-Jul").to_s)
  end

  def test_other_months
    @chron = Dataset::Chron::YYYYMM.new("4-2006")
    assert_equal("04/2006", @chron.to_s)
  end

  def test_school_year
    sy04 = Dataset::Chron::SchoolYear.new("2003-04")
    assert_equal(2004, sy04.value)
    assert_equal("03-04", sy04.to_s)
    # crossing the 1999/2000 boundary
    sy00 = Dataset::Chron::SchoolYear.new("1999-00")
    assert_equal(2000, sy00.value)
    assert_equal("99-00", sy00.to_s)

    assert_equal("05-06", Dataset::Chron::SchoolYear.new("2005/06").to_s)
#     assert_equal("05-06", Dataset::Chron::SchoolYear.new(2006).to_s)

    assert_equal("00-01", sy00.next.to_s)
    assert_equal("98-99", sy00.prev.to_s)
    assert_equal("02-03", sy00.step(3).to_s)

    assert_raise(NoMethodError) { Dataset::Chron::SchoolYear.new(2006) }
    assert_equal("05-06", Dataset::Chron::SchoolYear.new(:yyyy => 2006).to_s)

    sy_yaml = YAML.load(sy04.to_yaml)
    assert_same(sy04, sy_yaml)

    sy05 = Dataset::Chron::SchoolYear.new("2005-2006")
    assert_equal(2006, sy05.value)
    assert_equal("05-06", sy05.to_s)
  end

  def test_next
    assert_equal("2000", Dataset::Chron::YYYY.new("1999").next.to_s)
    assert_equal("1998", Dataset::Chron::YYYY.new("1999").prev.to_s)
    assert_equal("06/2001", Dataset::Chron::YYYYMM.new("200105").next.to_s)
    assert_equal("04/2001", Dataset::Chron::YYYYMM.new("200105").prev.to_s)
    assert_equal("01/2006", Dataset::Chron::YYYYMM.new("200512").next.to_s)
    assert_equal("12/2005", Dataset::Chron::YYYYMM.new("200601").prev.to_s)
    assert_equal("05-06", Dataset::Chron::SchoolYear.new("2004-05").next.to_s)
    assert_equal("03-04", Dataset::Chron::SchoolYear.new("2004-05").prev.to_s)
  end

  # def test_names
  #   assert_equal("Year", Dataset::Chron::YYYY.name)
  #   assert_equal("Month", Dataset::Chron::YYYYMM.name)
  #   assert_equal("School Year", Dataset::Chron::SchoolYear.name)
  # end

  def test_comparisons
    assert_same(Dataset::Chron::YYYY.new(2005), Dataset::Chron::YYYY.new(2005))
    assert_same(Dataset::Chron::YYYY.new(2005), YAML.load(Dataset::Chron::YYYY.new(2005).to_yaml))
    assert_equal(Dataset::Chron::YYYY.new(2005), Dataset::Chron::YYYY.new(2005))
    assert(Dataset::Chron::YYYY.new(1990) > Dataset::Chron::YYYY.new(1989))
    assert_equal(Dataset::Chron::YYYY.new(2005), Dataset::Chron::YYYY.new(2001).step(4))
  end

  def test_intervals
    y = Dataset::Chron::YYYY
    assert_equal(1, y.intervals.first)
    assert_equal(5, y.next_interval_after(1))
    assert_equal(10, y.next_interval_after(5))
    assert_equal(20, y.next_interval_after(10))
    assert_equal(100, y.next_interval_after(20))
    assert_equal(nil, y.next_interval_after(100))
    assert_equal(5, Dataset::Chron::SchoolYear.next_interval_after(1))
    yq = Dataset::Chron::YYYYQ
    assert_equal(1.0/4, i1 = yq.intervals.first)
    assert_equal(1.0, i2 = yq.next_interval_after(i1))
    assert_equal(2.0, i3 = yq.next_interval_after(i2))
    assert_equal(5.0, i4 = yq.next_interval_after(i3))
    assert_equal(10.0, i5 = yq.next_interval_after(i4))
    assert_equal(20.0, i6 = yq.next_interval_after(i5))
    assert_nil(i7 = yq.next_interval_after(i6))
  end

  def test_offsets
    assert_equal(1, Dataset::Chron::YYYY.offset)
    assert_equal(12, Dataset::Chron::YYYYMM.offset)
    assert_equal(1, Dataset::Chron::SchoolYear.offset)
  end

  def test_quarters
    chrons = Dataset::Chron.new("2000.3")
    assert chrons.has?(Dataset::Chron::YYMMDD)
    assert q3_2k = chrons.has?(Dataset::Chron::YYYYQ)
#     assert_kind_of(Dataset::Chron::YYYYQ, q3_2k)
    assert_equal("2000Q3", q3_2k.to_s)
    assert_equal(2000, q3_2k.year)
    assert_equal(3, q3_2k.quarter)
    assert_equal("2001Q3", q3_2k.step(4).to_s)
    assert_nil(Dataset::Chron.new(11506.5)) # doesn't recognize Fixnums
    # the new Date parsing in ruby 1.8.6 recognizes these things as nth-month-of-year
#     assert_nil(Dataset::Chron.new("9871.9"))
#     assert_nil(Dataset::Chron.new("9502.2"))
    assert_raise(RuntimeError) { Dataset::Chron::YYYYQ.new([nil,nil]) }
    assert_raise(RuntimeError) { Dataset::Chron::YYYYQ.new({:year => 2002, :quarter => nil}) }
  end

  def test_chron_names
    y = Dataset::Chron::YYYY.new("2005")
    assert_equal("Year", y.class.label)
    assert_equal("School Year", Dataset::Chron::SchoolYear.label)
  end
  
  def test_combinations
    y = Dataset::Chron.new(2005)
    m = Dataset::Chron::Month.new(6)
    assert_instance_of(Dataset::Chron::YYYY, y)
    assert_instance_of(Dataset::Chron::Month, m)
    ym1 = Dataset::Chron::YYYYMM.new(y, m)
    assert_instance_of(Dataset::Chron::YYYYMM, ym1)
    ym = Dataset::Chron.new(y, m)
    assert_instance_of(Dataset::Chron::YYYYMM, ym)
    assert_equal(2005, ym.year)
    assert_equal("Jun", ym.mon)

    # test the reverse combination (month-year)
    my = Dataset::Chron.new(m, y)
    assert_instance_of(Dataset::Chron::YYYYMM, my)
    assert_equal(2005, my.year)
    assert_equal("Jun", my.mon)
  end

  def test_combo2
    yClass = Dataset::Chron::YYYY
    mClass = Dataset::Chron::Month
    chronClasses = [yClass, mClass]
    assert_equal(Dataset::Chron::YYYYMM, Dataset::Chron.combine(yClass, mClass))
    assert_equal(Dataset::Chron::YYYYMM, Dataset::Chron.combine(mClass, yClass))
    assert_equal(Dataset::Chron::YYYYMM, Dataset::Chron.combine(chronClasses))
#     assert_equal(Dataset::Chron::YYYYMM, yClass + mClass)
    y = Dataset::Chron.new(2005)
    m = Dataset::Chron::Month.new(6)
    assert_kind_of(Dataset::Chron::YYYY, y)
#     assert_kind_of(Dataset::Chron::Month, m)
    ym1 = Dataset::Chron.new(y, m)
    assert_instance_of(Dataset::Chron::YYYYMM, ym1)
    # ym2 = Dataset::Chron.new(m, y)
    # assert_instance_of(Dataset::Chron::YYYYMM, ym2)
  end

  def test_combo_yq
    assert_equal(Dataset::Chron::YYYYQ, Dataset::Chron.combine(Dataset::Chron::YYYY, Dataset::Chron::Quarter))
    yq = Dataset::Chron.new(Dataset::Chron::YYYY.new(2004), Dataset::Chron::Quarter.new(3))
    assert_instance_of(Dataset::Chron::YYYYQ, yq)
  end

  def test_yaml
    klass = Dataset::Chron::YYYYMM
    yaml = klass.to_yaml
    # puts "YAML is #{yaml}"
    yyyymm = YAML.load(yaml)
    assert_equal(klass, yyyymm)

    y = Dataset::Chron::YYYY.new(2006)
    # puts "YAML is #{y.to_yaml}"
    y2 = YAML.load(y.to_yaml)
    assert_kind_of(Dataset::Chron::YYYY, y2)
    assert_same(y2, y)

    # ym = Dataset::Chron::YYYYMM.new("04/2006")
    # puts "POOLS"
    # p Multiton::POOLS[ym.class]
    # p ym.internal
    # puts "Found it?"
    # p Multiton::POOLS[ym.class][ym.internal]
    # puts "Try now"
    # p Multiton::POOLS[ym.class][Marshal.dump(ym.internal)]
    # puts "Keys are"
    # p Multiton::POOLS[ym.class].keys
    # puts "YAML is #{ym.to_yaml}"
    # ym2 = YAML.load(ym.to_yaml)
    # assert_same(ym2, ym)
  end

  def test_quarters_only
    q4 = Dataset::Chron::Quarter.new("04")
    assert_equal("Q4", q4.to_s)
    chrons = Dataset::Chron.new("04")
    assert_equal(3, chrons.size)
    assert chrons.has?(Dataset::Chron::YYYY)  # 2004
    assert chrons.has?(Dataset::Chron::Quarter) # Q4
    assert chrons.has?(Dataset::Chron::Month) # April
  end

  def test_new_instantiation
    # only a year
    c1 = Dataset::Chron.new(2005)
    assert_kind_of(Dataset::Chron::YYYY, c1)

    # only a month
    c2 = Dataset::Chron.new(2005 + 1.0/12)
    assert_kind_of(Dataset::Chron::YYYYMM, c2)
    assert_equal("Feb", c2.mon)
    assert_equal("02/2005", c2.to_s)

    # quarter (Q2) OR month (Apr)
    c3 = Dataset::Chron.new(2005.25)
    assert_equal(2, c3.size)
    assert(c3.has?(Dataset::Chron::YYYYMM))
    assert(c3.has?(Dataset::Chron::YYYYQ))

    # month again
    c4 = Dataset::Chron.new("200501")
    yyyymm = c4.has?(Dataset::Chron::YYYYMM)
    assert(yyyymm)
    assert(c4.has?(Dataset::Chron::YYMMDD))
    assert_equal("01/2005", yyyymm.to_s)

    # quarter again
    c5 = Dataset::Chron.new("2005Q1")
    # assert_equal(1, c5.size)
    assert_kind_of(Dataset::Chron::YYYYQ, c5)

    # school year OR month or yymmdd
    c6 = Dataset::Chron.new("2005-06")
    assert_equal(3, c6.size)
    assert(c6.has?(Dataset::Chron::SchoolYear))
    assert(c6.has?(Dataset::Chron::YYYYMM))
    assert(c6.has?(Dataset::Chron::YYMMDD))

    # school year only
    c6a = Dataset::Chron.new("1995-96")
    assert_kind_of(Dataset::Chron::SchoolYear, c6a)

    # year or quarter or month
    c7 = Dataset::Chron.new(2005.00)
    assert_equal(3, c7.size)
    assert(c7.has?(Dataset::Chron::YYYYQ))
    assert(c7.has?(Dataset::Chron::YYYY))
    assert(m = c7.has?(Dataset::Chron::YYYYMM))
    assert_equal("Jan", m.mon)

    # month only
    c8 = Dataset::Chron.new("01/2005")
    assert(c8_mm = c8.has?(Dataset::Chron::YYYYMM))
    assert(c8_md = c8.has?(Dataset::Chron::YYMMDD))
    assert_equal("Jan", c8_mm.mon)
    assert_equal("Jan", c8_md.mon)

    # month or quarter *without year*
    c9 = Dataset::Chron.new(3)
    assert_equal(3, c9.size)
    assert c9.has?(Dataset::Chron::YYYY)
    assert c9.has?(Dataset::Chron::Quarter)
    m = c9.has?(Dataset::Chron::Month)
    assert(m)
    assert_equal("Mar", m.mon)

    # just-the-month
    c10 = Dataset::Chron.new("06")
    assert_equal(2, c10.size)
    assert m = c10.has?(Dataset::Chron::Month)
    assert c10.has?(Dataset::Chron::YYYY)
    assert_equal("Jun", m.mon)

    c11 = Dataset::Chron.new("Jul")
    assert_kind_of(Dataset::Chron::Month, c11)
    assert_equal("Jul", c11.mon)
  end

  def test_intersection
    a = [ Dataset::Chron::YYYY.new(2001), Dataset::Chron::YYYY.new(2002) ]
    b = [ Dataset::Chron::YYYY.new(2002) ]
    assert_equal(1, (a&b).size)
  end

  def test_multiton
    y1 = Dataset::Chron::YYYY.new("2001")
    y2 = Dataset::Chron::YYYY.new(2001)
    y3 = Dataset::Chron::YYYY.new(2001)
    assert_same(y2, y3)
    assert_same(y1, y2)
    m1 = Dataset::Chron::YYYYMM.new("04/2006")
    m2 = Dataset::Chron::YYYYMM.new("Apr-2006")
    m3 = Dataset::Chron::YYYYMM.new("2006-04")
    assert_same(m1, m2)
    assert_same(m1, m3)
  end

  def test_month_comparisons
    m1 = Dataset::Chron::Month.new("Mar")
    m2 = Dataset::Chron::Month.new("Nov")
    assert(m2 > m1)
  end

  def test_yymmdd
    d1 = Dataset::Chron.new("580329")
    assert_kind_of(Dataset::Chron::YYMMDD, d1)
    d2 = Dataset::Chron.new("060412")
    assert_kind_of(Dataset::Chron::YYMMDD, d2)
    d3 = Dataset::Chron.new("1973-06-24")
    assert_kind_of(Dataset::Chron::YYMMDD, d3)
    assert(d2 > d1)
    assert_same(d1, YAML.load(d1.to_yaml))

    d4 = Dataset::Chron.new("2005-04-01")
    assert d4.has?(Dataset::Chron::YYYYMM)
    assert d4.has?(Dataset::Chron::YYMMDD)

    d5 = Dataset::Chron::YYMMDD.new("July 13, 1904")
    assert_kind_of(Dataset::Chron::YYMMDD, d5)
    d6 = Dataset::Chron::YYMMDD.new("July 13,1904")
    assert_kind_of(Dataset::Chron::YYMMDD, d6)
    d7 = Dataset::Chron::YYMMDD.new("July 13 1904")
    assert_kind_of(Dataset::Chron::YYMMDD, d7)

    assert_nil(Dataset::Chron.new("this 1.2 is not a date"))
  end

  def test_operations
    c1 = Dataset::Chron::YYYY
    assert_not_nil(c1.operations.find {|op| op[:method] == :diff_annual})
  end

  def test_ymd_comparison
    c1 = Dataset::Chron::YYMMDD.new("09/24/2006")
    c2 = Dataset::Chron::YYMMDD.new("09/26/2004")
    chrons = [c1, c2]
    assert_equal(c1, chrons.max)
    assert_equal(c2, chrons.min)
  end

  def test_descendant_of
    assert Dataset::Chron::YYYYMM.descendant_of?(Dataset::Chron::YYYY)
    assert Dataset::Chron::YYYYMM.descendant_of?(Dataset::Chron::YYYYQ)
    assert Dataset::Chron::YYYYQ.descendant_of?(Dataset::Chron::YYYY)

    assert !Dataset::Chron::YYYYQ.descendant_of?(Dataset::Chron::YYYYMM)
    assert !Dataset::Chron::YYYY.descendant_of?(Dataset::Chron::YYYYMM)
    assert !Dataset::Chron::YYYY.descendant_of?(Dataset::Chron::YYYYQ)
  end

  def test_prev_and_next_with_steps
    y = Dataset::Chron::YYYY.new("2005")
    assert_equal(2006, y.next.value)
    assert_equal(2004, y.prev.value)
    assert_equal(2006, y.next(Dataset::Chron::YYYY).value)
    assert_equal(2004, y.prev(Dataset::Chron::YYYY).value)
    assert_raise(RuntimeError) { y.next(Dataset::Chron::YYYYMM) }

    m = Dataset::Chron::YYYYMM.new("200506")
    assert_equal("07/2005", m.next.to_s)
    assert_equal("05/2005", m.prev.to_s)
    assert_equal("07/2005", m.next(Dataset::Chron::YYYYMM).to_s)
    assert_equal("05/2005", m.prev(Dataset::Chron::YYYYMM).to_s)
    assert_equal("09/2005", m.next(Dataset::Chron::YYYYQ).to_s)
    assert_equal("03/2005", m.prev(Dataset::Chron::YYYYQ).to_s)
    assert_equal("06/2006", m.next(Dataset::Chron::YYYY).to_s)
    assert_equal("06/2004", m.prev(Dataset::Chron::YYYY).to_s)

    m = Dataset::Chron::YYYYMM.new("200501")
    assert_equal("02/2005", m.next.to_s)
    assert_equal("12/2004", m.prev.to_s)
    assert_equal("02/2005", m.next(Dataset::Chron::YYYYMM).to_s)
    assert_equal("12/2004", m.prev(Dataset::Chron::YYYYMM).to_s)
    assert_equal("04/2005", m.next(Dataset::Chron::YYYYQ).to_s)
    assert_equal("10/2004", m.prev(Dataset::Chron::YYYYQ).to_s)

    q = Dataset::Chron::YYYYQ.new("2005Q1")
    assert_equal("2005Q2", q.next.to_s)
    assert_equal("2004Q4", q.prev.to_s)
    assert_equal("2005Q2", q.next(Dataset::Chron::YYYYQ).to_s)
    assert_equal("2004Q4", q.prev(Dataset::Chron::YYYYQ).to_s)
    assert_equal("2006Q1", q.next(Dataset::Chron::YYYY).to_s)
    assert_equal("2004Q1", q.prev(Dataset::Chron::YYYY).to_s)

    y = Dataset::Chron::SchoolYear.new("2005/06")
    assert_equal(2007, y.next.value)
    assert_equal(2005, y.prev.value)
    assert_equal(2007, y.next(Dataset::Chron::SchoolYear).value)
    assert_equal(2005, y.prev(Dataset::Chron::SchoolYear).value)
    assert_equal(2007, y.next(Dataset::Chron::YYYY).value)
    assert_equal(2005, y.prev(Dataset::Chron::YYYY).value)
    assert_raise(RuntimeError) { y.next(Dataset::Chron::YYYYMM) }
  end

  def test_chron_index_conversions
    assert_equal(24067, Dataset::Chron::YYYYMM.new("August 2005").index)
    assert_equal(Dataset::Chron::YYYYMM.new("Aug 2005"), Dataset::Chron::YYYYMM.new(:index => 24067))
    assert_equal(8022, Dataset::Chron::YYYYQ.new("2005Q3").index)
    assert_equal(Dataset::Chron::YYYYQ.new("2005Q3"), Dataset::Chron::YYYYQ.new(:index => 8022))
    assert_equal(2003, Dataset::Chron::YYYY.new("2003").index)
    assert_equal(Dataset::Chron::YYYY.new("2003"), Dataset::Chron::YYYY.new(:index => 2003))
  end

end

class Array
  def has?(klass)
    self.find {|o| o.is_a?(klass)}
  end
end
