# Measures can be "base" measures, that contain an actual quantity
# in some unit, or "change" measures that indicate a change in a
# base measure between two time periods.
#
# For "change" measures, the time period is not included, so you
# can't tell the difference between "change in revenue between
# months" and "change in revenue between years", for example.
# Have to look at the Chron to figure that out.
#
# Two types of Change measures: absolute, and percentage.
#
# Base measures have units, and multipliers

require "digest/sha1"

module Dataset
  class Measure
    attr_reader :units
#     attr_accessor :name
    attr_accessor :multiplier, :precision
#     attr_accessor :nature
    attr_accessor :change
    attr_accessor :notes
    
    def initialize(options = {})
      @name = options[:name] || nil
      @notes = options[:notes]
      @units = options[:units] || Units::Discrete
      # @units = @units.to_s
      # if @units.has_multiplier?
      @multiplier = options[:multiplier] || :ones unless @units == Units::Percentage
      @precision = options[:precision]
      # end
      # @diff = options[:diff] || false
      # @delta = options[:delta] || false
      # by default, assume this measure is the state of something, so values cannot be aggregated
      # over time, and if rendered as bars, the bars should be separate 
#       @nature = options[:nature] || :state
    end

    # Use this as a test whether the measure has been given a proper name.
    # Specifically for creating a Series - we won't build a Series without naming the Measure first.
    def unspecified?
      @name.nil? or @name == 'Unspecified'
    end

    # until a measure has been explicitly named, return "Unspecified" as the name for UI purposes
    def name
      @name || "Unspecified"
    end

    def name=(newname)
      @name = newname unless newname.nil?
    end

    def digest
      Digest::SHA1.hexdigest([name,notes].join.downcase)
    end

    def change?
      name =~ /\bChange\b/i;
    end
    # def diff?
    #   @diff
    # end
    # def delta?
    #   @delta
    # end
    # def base?
    #   not (@diff or @delta)
    # end

    # def event?
    #   @nature == :event
    # end
    # def state?
    #   @nature == :state
    # end
    # def rate?
    #   @nature == :rate
    # end

    def instance(value, multiplier = :ones)
      @units.new(value, multiplier)
    end

    def format(value, hints = {})
#       if hints.nil?
# #         if diff? or delta? then
#         if change?
#           hints = { :sign => true }
#         else
#           hints = {}
#         end
#       end
      case multiplier
      when nil
        # no multiplier provided, should only be for a unit where multiplier is irrelevant, e.g. Percentage
        v = v.is_a?(Units::Base) ? v : @units.new(value)
        v.format(hints)
      when :ones
        hints[:decimals] ||= precision
        v = v.is_a?(Units::Base) ? v : @units.new(value)
        v.format(hints)
      else
        hints[:decimals] ||= precision || 0
        hints[:sigil] = "" unless hints[:sigil]
        @units.new(value).format(hints)
      end
    end

    def diff
      self.class.new(:name => "Change in #{self.name}", :units => self.units) #, :diff => true)
    end
    def delta
      self.class.new(:name => "Percent Change in #{self.name}", :units => Units::Percentage) #, :delta => true)
    end

    def units=(newUnits)
      @units = newUnits
    end

    def describe
      case multiplier
      when nil
        if units.nil?
          ""
        else
          units.label.downcase
        end
      when :ones
        if units.nil?
          ""
        else
          if units.generic?
            ""
          else
            units.label.downcase
          end
        end
      else
        if units.generic?
          "#{multiplier.to_s}s"
        else
          "#{multiplier.to_s}s of #{units.label.downcase}"
        end
      end
    end

    def ==(target)
      return false unless target.class == self.class
      (name == target.name) && (units == target.units) && (multiplier == target.multiplier)
    end
  end # class Measure
end # module Dataset

# workaround for a ruby 1.8.4 bug that bites YAML handling of Bignums
# http://groups.google.com/group/comp.lang.ruby/browse_frm/thread/4d62fa19fc7f4ffe/2331cd65b83bffe2
if RUBY_VERSION == "1.8.4"
  class Bignum
    def to_yaml( opts = {} )
      YAML::quick_emit( nil, opts ) { |out|
        out.scalar( nil, to_s, :plain )
      }
    end
  end
end


# examples of Measures
#
# "Fatalities, in thousands"
#  - fatalities are People; People are DiscreteUnits
# "GDP, in billions"
#  - GDP is in Dollars, which is a Currency; Currency is a ContinuousMeasure
# "Consumer Price Index"
#  - CPI is in ArbitraryUnits, a Continuous Measure
# "Federal Expenditures, in billions"
#  - in Dollars
# "Inflation"
#  - is Change in CPI
#
# is "GDP" or "Spending" the measure, or is "Dollars" the measure?
#
# "CBO Spending Forecast"
#  - in Dollars
#  - but it is the same core measure as Historical Spending
