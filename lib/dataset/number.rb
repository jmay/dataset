# require "delegate"

# how to use a Number:
#  number = Number::Subclass.new("numeric-string")
#  number.value # output the numeric value as a Fixnum or Float (whichever is appropriate)
#  number.to_s # output the value formatted appropriately (commas, %, $, etc.)
#
module Dataset
  module Number
    def self.all
      self.constants.map {|c| self.const_get(c).label}.compact.sort
    end

    def self.find(label)
      classname = self.constants.find {|c| self.const_get(c).label == label}
      classname ? self.const_get(classname) : nil
    end

    class Base
      class << self
        attr_accessor :label
        def generic?; true; end
      end

      def initialize(num, options = {})
        @value = num
        @options = options
      end

      def method_missing(meth, *args, &block)
        return super unless @value.respond_to?(meth)
        value.send meth, *args, &block
      end

      def value
        @value * (@options[:multiplier] || 1)
      end

      def to_s
        sprintf(@options[:format], @value).gsub(/(\d)(?=\d{3}+(\.\d*)?[^0-9]*$)/, '\1,')
      end
    end

    # a non-negative integer value
    class Count < Base
      @label = 'Units'

      def initialize(num, options = {})
        # raise "Must be non-negative" if num < 0
        options[:format] = "%d"
        super(num.is_a?(String) ? Count.convert(num) : num, options)
      end

      def Count.convert(str)
        str.gsub(/(\d),(\d)/, '\1\2').to_i
      end
    end

    # a non-negative float value
    class Quantity < Base
      @label = 'Unspecified Measure'

      def initialize(num, options = {})
        options[:format] ||= "%.2f" # default is two decimals
        super(num.is_a?(String) ? Quantity.convert(num) : num, options)
      end

      def Quantity.convert(str)
        str.gsub(/(\d),(\d)/, '\1\2').to_f
      end
    end

    # a non-negative percentage
    class Percentage < Base
      @label = 'Percent'
      def self.generic?; false; end

      def initialize(num, options = {})
        options[:format] ||= "%.0f%%" # default is zero decimals
        options[:multiplier] = 0.01
        super(num.is_a?(String) ? Percentage.convert(num) : num, options)
      end

      def Percentage.convert(str)
        Quantity.convert(str.gsub(/%^/, ''))
      end
    end

    # a positive integer, but these can only be used for ordering, not math
    class Rank < Base
      
    end

    # a positive float; might restrict some math operations
    class Index < Base
      
    end

    # an integer; always show the sign when displaying
    class Difference < Base
      def initialize(num, options = {})
        options[:format] = "%+d"
        super(num, options)
      end
    end

    # a percentage; always show sign when displaying
    class Delta < Base
      def initialize(num, options = {})
        options[:format] ||= "%+.1f%%" # default is one decimal place
        options[:multiplier] = 0.01
        super(num, options)
      end
    end

    # float, format output with leading '$'; for negatives, minus sign before the '$'
    class Dollars < Base
      @label = 'Dollars'

      def initialize(num, options = {})
        options[:format] = "%.2f"
        super(num, options)
      end
    end

    # a positive float, measuring time in seconds?
    class Duration < Base
      
    end


    # # COUNT_FORMAT = "%d"
    # # FLOAT_FORMAT = "%.2f"
    # # PERCENT_FORMAT = "%.2f%%"
    # # DIFF_FORMAT
    # 
    # class Formatter
    #   def initialize(format)
    #     @fmt = format
    #   end
    #   def format(num)
    #     sprintf(@fmt, @value).gsub(/(\d)(?=\d{3}+(\.\d*)?[^0-9]*$)/, '\1,')
    #   end
    # end
  end
end
