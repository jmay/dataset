require "yaml"

module Dataset
  module Units
    def self.all
      self.constants.map {|c| self.const_get(c).label}.compact.sort
#       [ Discrete, Continuous, Percentage, Dollars ]
    end

    def self.find(label)
      classname = self.constants.find {|c| self.const_get(c).label == label}
      classname ? self.const_get(classname) : nil
    end

    # see chron.rb for this stuff
    yaml_as "tag:jmay.pobox.com,2007:unit"

    def self.yaml_new( klass, tag, val )
      val.split(/::/).inject(Object) {|m, n| m.const_get(n)}
    end

    def self.extract_unit(string)
      case string
      when /billion/im
        :billion
      when /million/im
        :million
      when /thousand/im
        :thousand
      else
        :ones
      end
    end

    class Base
      include Comparable
      attr_reader :value

      # def self.name
      #   @name
      # end

      def self.to_yaml( opts = {} )
        YAML::quick_emit( nil, opts ) { |out|
          out.scalar( "tag:jmay.pobox.com,2007:unit", self.to_s, :plain )
        }
      end

      def -(other)
        raise TypeError if other.class != self.class
        self.class.new(self.value - other.value)
      end

      def /(other)
        raise TypeError if other.class != self.class
#         Percentage.new(self.value.to_f / other.value * 100)
        Percentage.new(self.value.to_f / other.value)
      end

      def <=>(other)
        raise TypeError if other.class != self.class
        self.value <=> other.value
      end

      class << self
        attr_accessor :label

        def generic?; true; end
      end
    end

    class Discrete < Base
      @label = "Units"

      def initialize(v, multiplier = :ones)
        @value = v.to_i.method(multiplier).call
      end

      def format(hints = {})
        v = @value
        if hints[:divide_by]
          v /= 1.method(hints[:divide_by]).call
        end
        sign = (hints[:sign] and @value > 0.0) ? "+" : ""
        sign + v.to_s.gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,')
      end
    end

    class Continuous < Base
      @label = "Unspecified Measure"

      def initialize(v, multiplier = :ones)
        @value = v.to_f.method(multiplier).call
      end

      def format(hints = {})
        v = @value
        if hints[:divide_by]
          v /= 1.method(hints[:divide_by]).call
        end
        fmt = "#{hints[:sign] ? '+' : ''}%.#{hints[:decimals] || 1}f"
        sprintf(fmt, v).gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,')
      end

      def self.continuous?
        true
      end
    end

    class Artificial < Continuous
      @label = "Artificial Index"
    end

    class Percentage < Base
      @label = "Percent"

      def self.generic?; false; end

      def initialize(v, multiplier = :ones)
        # percentage always ignores the multiplier
        @value = v.to_f
      end

      def format(hints = {})
        sign = (hints[:sign] and @value > 0.0) ? "+" : ""
        # sign = "+" if hints[:sign] and @value > 0.0
        fmt = "#{sign}#{hints[:currency_prefix]}%.#{hints[:decimals] || 1}f"
        sprintf(fmt, @value).gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,') + "%"
      end

      # def value
      #   @value/100
      # end

      def self.continuous?
        true
      end
    end

    class Money < Continuous
    end

    class People < Discrete
      @label = "People"
      def self.generic?; false; end
    end

    class Dollars < Money
      @label = "Dollars"
      def self.generic?; false; end

      def format(hints = {})
        v = hints[:divide_by] ? @value /= 1.method(hints[:divide_by]).call : @value
        sign = (hints[:sign] and v > 0.0) ? "+" : @value < 0.0 ? "-" : ""
        # decimals = hints[:decimals] == 0 ? 0 : 2
        # sigil = hints[:sigil] || "$"
        fmt = "#{sign}#{hints[:sigil] || "$"}%.#{hints[:decimals] || 2}f"
        # fmt = "#{sign}$%.#{decimals}f"
        sprintf(fmt, v.abs).gsub(/(\d)(?=\d{3}+(\.\d*)?$)/, '\1,')
      end
    end
  end
end

class Numeric
  def ones
    self
  end
  def thousand
    self * 1_000
  end
  def million
    self * 1_000_000
  end
  def billion
    self * 1_000_000_000
  end
  def percent
    self * 0.01
  end
end
