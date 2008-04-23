require "delegate"

module Dataset
  module Number
    class Base
      def initialize(num, options = {})
        @value = num
        @options = options
      end

      def method_missing(meth, *args, &block)
        (@value * (options[:multiplier] || 1)).send meth, *args, &block
      end

      def to_s
        sprintf(@options[:format], @value).gsub(/(\d)(?=\d{3}+(\.\d*)?[^0-9]*$)/, '\1,')
      end
    end

    # a non-negative integer value
    class Count < Base
      def initialize(num, options = {})
        # raise "Must be non-negative" if num < 0
        options[:format] = "%d"
        super(num, options)
      end
    end

    # a non-negative float value
    class Quantity < Base
      def initialize(num, options = {})
        options[:format] ||= "%.2f" # default is two decimals
        super(num, options)
      end
    end

    # a non-negative percentage
    class Percentage < Base
      def initialize(num, options = {})
        options[:format] ||= "%.0f%%" # default is zero decimals
        options[:multiplier] = 0.01
        super(num, options)
      end
    end

    # a positive integer, but these can only be used for ordering, not math
    class Rank
      
    end

    # a positive float; might restrict some math operations
    class Index
      
    end

    # an integer; always show the sign when displaying
    class Difference
      def initialize(num, options = {})
        options[:format] = "%+d"
        super(num, options)
      end
    end

    # a percentage; always show sign when displaying
    class Delta
      def initialize(num, options = {})
        options[:format] ||= "%+.1f%%" # default is one decimal place
        options[:multiplier] = 0.01
        super(num, options)
      end
    end

    class Money
      
    end

    # a positive float, measuring time in seconds?
    class Duration
      
    end


    COUNT_FORMAT = "%d"
    FLOAT_FORMAT = "%.2f"
    PERCENT_FORMAT
    DIFF_FORMAT

    class Formatter
      def initialize(format)
        @fmt = format
      end
      def format(num)
        sprintf(@fmt, @value).gsub(/(\d)(?=\d{3}+(\.\d*)?[^0-9]*$)/, '\1,')
      end
    end
  end
end
