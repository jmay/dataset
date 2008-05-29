require "rubygems"
require "date"  # for month abbreviations and YYMMDD recognition
require "date/format" # MONTHS and ABBR_MONTHS constants moved to this module in ruby 1.8.6
require "yaml"

# require "facets/more/multiton"

# NOTES
#
# Don't want to enable direct arithmetic on Chrons, e.g. year "2001" minus year "2000"
# does not give another year, it gives a duration or something, which is not a Chron.
# So still with the requirement to do `a.value - b.value` which gives back a number
# and let the application figure out what it means.
#

module Dataset

  module Multiton
    # Pools of objects cached on class type.
    POOLS = {}

    # Method which can be defined by a class to determine object uniqueness.
    MULTITON_ID_HOOK = :multiton_id

    # Method which can be defined by a class to create multiton objects.
    MULTITON_NEW_HOOK = :multiton_new

    def self.append_features( klass )
      class << klass
        unless method_defined?(MULTITON_NEW_HOOK)
          alias_method MULTITON_NEW_HOOK, :new
        end

        def instance(*args, &block)
          new_thing = send(MULTITON_NEW_HOOK, *args, &block)
          k = Marshal.dump(new_thing.internal)

          unless obj = (POOLS[self] ||= {})[k]
            obj = POOLS[self][k] = new_thing
          end

          return obj
        end

        alias_method :create, :new
        alias_method :new, :instance
      end
    end
  end # module Multiton

  module Chron

    # Not sure if I'm doing this right.  I want to be able to output Chron classes in YAML streams.
    # By default, to_yaml doesn't work for Class objects, so I need to explicitly allow this behavior.
    # yaml_as appears to route yaml_new to the Class where the tag is defined, overriding
    # the default which would be to go to Class#yaml_new (which will raise an expection).
    yaml_as "tag:jmay.pobox.com,2007:chron-class"

    # walk the namespace structure and assemble the class object
    def self.yaml_new( klass, tag, val )
      val.split(/::/).inject(Object) {|m, n| m.const_get(n)}
    end

    def Chron.classes
      (self.constants - ["Base"]).map {|c| self.const_get(c)}
    end

    def Chron.new(*args)
      chrons = classes.map do |klass|
        begin
#           puts "Trying #{klass} with..."
#           p *args
          klass.new(*args)
        rescue Exception => detail
#           p detail
#           puts "#{klass} can't handle #{args} - #{detail}"
#           puts Kernel.caller
          nil
        end
      end.compact

      case chrons.size
      when 0
        nil
      when 1
        chrons.first
      else
        chrons
      end
#       chrons
    end

    # def Chron.evaluate(str)
    #   str = str.to_s if str.is_a?(Numeric)
    #   klasses = []
    #   klasses << YYYY if str =~ /^\d\d\d\d$/
    #   klasses << YYYYMM if str =~ /^\d\d\d\d\d\d$/
    #   klasses << YYYYMM if str =~ /^\d\d\d\d\.\d\d$/
    #   klasses << SchoolYear if str =~ /^\d\d\d\d[-\/]\d\d$/
    #   klasses << YYYYMM if str =~ /^\d\d?[-\/]\d\d\d\d$/
    #   klasses << YYYYQ if str =~ /^\d\d\d\d[Qq.][1234]$/
    #   klasses << Quarter if str =~ /^\d\d?$/ && str.to_i <= 4
    #   klasses << Month if str =~ /^\d\d?$/ && str.to_i <= 12
    #   klasses
    # end
    # 
    # # identify the chron type of the value, and create a matching Chron instance
    # # throw exception if unrecognized, or ambiguous
    # def Chron.to_chron(str)
    #   klasses = Chron.evaluate(str)
    #   raise "Unrecognized chron value #{str}" if klasses.empty?
    #   raise "Ambiguous chron value #{str}" if klasses.size > 1
    #   klasses[0].new(str)
    # end

    def Chron.combine(*args)
      klasses = {}
      args.flatten.each { |klass| klasses[klass] = 1 }
      if klasses[YYYY] && klasses[Month] && klasses.size == 2
        YYYYMM
      elsif klasses[YYYY] && klasses[Quarter] && klasses.size == 2
        YYYYQ
      else
        nil
      end
    end

    def Chron.+(*args)
      Chron.combine(args)
    end


    class Base
      include Comparable
      include Multiton

      def initialize(*args)
#         p args
        case args.size
        when 0
          raise "Cannot initialize a Chron without parameters"
        when 1
          case a = args.first
          when Numeric
            init_numeric(a)
          when String
            init_string(a)
          when Hash
            init_hash(a)
          when Date
            init_date(a)
          when Array
            initialize(*a)
#             init_multiple(*args)
          else
            raise "Cannot initialize a Chron with #{args.inspect}"
          end
        else
          init_multiple(*args)
        end
      end

      def value
        @internal.to_f
      end

      def self.pliable?
        false
      end

      yaml_as "tag:jmay.pobox.com,2007:chron"

      # can't find a variable that holds the taguri that I want, so I have to repeat it here
      def self.to_yaml( opts = {} )
        YAML::quick_emit( nil, opts ) { |out|
          out.scalar( "tag:jmay.pobox.com,2007:chron-class", self.to_s, :plain )
        }
      end

      def self.yaml_new( klass, tag, val )
        if klass == SchoolYear
          v = val["internal"]
          yyyy = sprintf("%04d", v - 1)
          yy1 = sprintf("%02d", v % 100)
          klass.instance("#{yyyy}-#{yy1}")
        else
          klass.instance(val["internal"])
        end
      end

      def to_yaml_properties
        ['@internal']
      end

      def internal
        @internal
      end
      # tip for this: http://railstips.org/2006/11/18/class-and-instance-variables-in-ruby
      # @interval = nil
      # @intervals = []
      # @offset = nil
      class << self
        def interval
          @interval || superclass.interval
        end
        def intervals
          @intervals || superclass.intervals
        end
        def next_interval_after(interval)
#           this = intervals.index(interval)
          this = intervals.find {|v| v > interval.to_f * 1.1}
#           intervals[this+1]
        end

        def offset
          @offset || superclass.offset
        end

        attr_accessor :label
#         attr_reader :operations

        def operations
          @operations || []
        end
      end
    end

    class YYYY < Base
      @interval = 1
      @intervals = [1, 5, 10, 20, 100]
      @offset = 1
      @label = "Year"
      @operations = [
        {:method => :diff_annual, :label => "Absolute Changes, year-over-year"},
        {:method => :delta_annual, :label => "Percentage Changes, year-over-year"},
      ]

      def self.descendant_of?(chron)
        false # years aren't a descendant of anything (until we have decades or centuries)
      end

      def self.pliable?; true; end

      def init_numeric(value)
        raise "Invalid year #{value}" if value.is_a?(Float) && (value % 1 != 0)
        if value < 100
          value += (value <= 30) ? 2000 : 1900
        end
        raise "Invalid year #{value}" if value < 1000 or value > 2999
        @internal = value.to_i
      end
      def init_string(value)
        raise "Invalid year #{value}" if value !~ /^\d\d(\d\d)?\b[^0-9]*$/
        init_numeric(value.to_i)
      end
      def init_hash(hash)
        if index = hash[:index]
          @internal = index
          return
        end

        @internal = hash[:year]
      end

      def value; @internal; end
      def index; @internal; end
      def to_s; @internal.to_s if defined? @internal; end

      def next(step_chron = self.class)
        raise "Invalid step #{step_chron.label}" if step_chron != self.class
        self.class.new(value + 1)
      end
      def prev(step_chron = self.class)
        raise "Invalid step #{step_chron.label}" if step_chron != self.class
        self.class.new(value - 1)
      end

      def <=>(other)
        raise TypeError unless other.kind_of?(self.class)
        @internal <=> other.value
      end
      def step(n)
        self.class.new(value + n)
      end
    end

    # sames of Year&Month formats accepted are:
    #   200506
    #   2005-06
    #   2005/06
    #   2005-06-01, 2005/06/01, 20050601 (must have 01 for day number)
    #   06/2005, 06-2005
    #   6/2005, 6-2005
    #   Jun-2006, JUN-2005
    #   Jun 2005, JUN 2005
    #   Jun-05, JUN 05
    class YYYYMM < Base
      @interval = 1.0/12
      @intervals = [1.0/12, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0]
      @offset = 12
      @label = "Year & Month"
      @operations = [
        {:method => :diff_annual, :label => "Absolute Changes, 12-month change"},
        {:method => :diff_monthly, :label => "Absolute Changes, month-over-month"},
        {:method => :delta_annual, :label => "Percentage Changes, 12-month change"},
        {:method => :delta_monthly, :label => "Percentage Changes, month-over-month"},
      ]

      def self.descendant_of?(chron)
        [YYYYQ, YYYY].include?(chron)
      end

      def self.pliable?; true; end

      # valid numeric input is YYYY.00 (Jan), YYYY+1/12 (Feb) thru YYYY+11/12 (Dec)
      def init_numeric(input)
        raise "invalid value #{input}" if input.is_a?(Fixnum)
        yyyy, fracpart = input.divmod(1)
        raise "Invalid input #{input}" if yyyy < 1000 or yyyy > 2999
        mm = fracpart*12 + 1
#         yyyy, mm = (input*12).round.divmod(12.0)
#         mm += 1
        raise "Invalid input #{input}" unless mm.about_equal(mm.round)
        # raise "invalid month format" if yyyy.nil? or mm.nil?
        @internal = { :year => yyyy.to_i, :month => mm.round }
      end

      def init_string(input)
        case input
        when /^(\d\d\d\d)[-\/\.]?(\d\d)([-\/\.]?(01))?$/
          # 2006-05[-01]
          yyyy, mm = $1, $2
        when /^(\d\d?)[-\/](\d\d\d\d)$/
          # 05-2006, 5-2006
          mm, yyyy = $1, $2
        when /^(\w+)\.?[- ]'?(\d{2,4})\b[^0-9]*$/
          # Dec-2006, December-2006, Dec. '06, "July 2007 estimate"
          mon, yyyy = $1, $2
          mm = Date::Format::ABBR_MONTHS[mon.downcase] || Date::Format::MONTHS[mon.downcase] unless mon.nil?
          if yyyy && yyyy.length == 2
            century = yyyy.to_i > 30 ? "19" : "20"
            yyyy = "#{century}#{yyyy}"
          end
        end
        # yyyy, mm = input.scan(/^(\d\d\d\d)[-\/\.]?(\d\d)([-\/\.]?(01))?$/)[0]
        # if yyyy.nil? or mm.nil? then
        #   mm, yyyy = input.scan(/^(\d\d?)[-\/](\d\d\d\d)$/)[0]
        # end
        # if yyyy.nil? or mm.nil? then
        #   mon, yyyy = input.scan(/^(\w+)[- ](\d{2,4})$/)[0]
        #   mm = Date::ABBR_MONTHS[mon.downcase] || Date::MONTHS[mon.downcase] unless mon.nil?
        #   if yyyy && yyyy.length == 2
        #     century = yyyy.to_i > 30 ? "19" : "20"
        #     yyyy = "#{century}#{yyyy}"
        #   end
        # end
        raise "Invalid input #{input}" if yyyy.to_i < 1000 or yyyy.to_i > 2999
        raise "invalid month format #{input}" if yyyy.nil? or mm.nil?
        raise "invalid month format #{input}" if mm.to_i > 12
        @internal = { :year => yyyy.to_i, :month => mm.to_i }
      end

      def init_hash(hash)
        if index = hash[:index].to_i
          @internal = { :year => (index / 12), :month => (index % 12 + 1) }
          return
        end

        year = case y = hash[:year]
        when Chron::YYYY
          y.value
        when Fixnum
          y
        else
          raise "invalid year #{y}"
        end
        month = case m = hash[:month]
        when Chron::Month
          m.value
        when Fixnum
          m
        else
          m = Chron::Month.new(m).value
        end
        @internal = { :year => year, :month => month }
      end

      def init_multiple(year, month)
        if year.is_a?(Chron::Base)
          # if Chron objects are passed in, then swap them around if they aren't in
          # the expected year/month order
          unless year.is_a?(Chron::YYYY)
            year, month = month, year
          end
        end
        init_hash(:year => year, :month => month)
      end
      # def initialize(*args)
      #   # TODO: validate input
      # 
      #   if args.size == 1 then
      #     input = args.first
      #     case input
      #       when String:
      #         yyyy, mm = input.scan(/^(\d\d\d\d)\.?(\d\d)$/)[0]
      #         if yyyy.nil? or mm.nil? then
      #           mm, yyyy = input.scan(/^(\d\d?)[-\/](\d\d\d\d)$/)[0]
      #         end
      #       when Float:
      #         # 2000.0 = January 2000
      #         # 2000.25 = April 2000 (1/4 of 12 months = 3 months after January)
      #         # the round.divmod business below is to make sure that 2000.99999 == January 2001
      #         yyyy, mm = (input*12).round.divmod(12.0)
      #         mm += 1
      #       when Fixnum:
      #         yyyy, mm = input, 0
      #     end
      # 
      #     raise "invalid month format" if yyyy.nil? or mm.nil?
      #     @internal = { :year => yyyy.to_i, :month => mm.to_i }
      #     @interval = 1.0/12
      #   else
      #     # multiple arguments
      #     y, m = args
      #     initialize(sprintf("%04d%02d", y.value, m.value))
      #   end
      # end

      def value
        @internal[:year].to_f + (@internal[:month].to_f-1)/12
      end

      def index
        @internal[:year] * 12 + @internal[:month] - 1
      end

      def to_s
        mm = sprintf("%02d", @internal[:month])
        yyyy = sprintf("%04d", @internal[:year])
        "#{mm}/#{yyyy}"
      end

      def m
        Date::MONTHNAMES[@internal[:month]][0..0]
      end

      def mon
        Date::ABBR_MONTHNAMES[@internal[:month]]
      end

      def year
        @internal[:year]
      end

      def next(step_chron = self.class)
        if (step_chron == self.class)
          mo = (@internal[:month] + 1) % 12
          yr = @internal[:year]
          yr += 1 if mo == 1
          self.class.new("#{mo}/#{yr}")
        elsif (step_chron == YYYY)
          mo = @internal[:month]
          yr = @internal[:year] + 1
          self.class.new("#{mo}/#{yr}")
        elsif (step_chron == YYYYQ)
          mo = (@internal[:month] + 3) % 12
          yr = @internal[:year]
          yr += 1 if mo <= 3
          self.class.new("#{mo}/#{yr}")
        else
          raise "Invalid step #{step_chron.label}"
        end
      end

      def prev(step_chron = self.class)
        if (step_chron == self.class)
          mo = @internal[:month] - 1
          yr = @internal[:year]
          if mo == 0
            yr -= 1
            mo = 12
          end
          self.class.new("#{mo}/#{yr}")
        elsif (step_chron == YYYY)
          mo = @internal[:month]
          yr = @internal[:year] - 1
          self.class.new("#{mo}/#{yr}")
        elsif (step_chron == YYYYQ)
          mo = (@internal[:month] - 3) % 12
          mo = 12 if mo == 0
          yr = @internal[:year]
          yr -= 1 if mo >= 10
          self.class.new("#{mo}/#{yr}")
        else
          raise "Invalid step #{step_chron.label}"
        end
      end

      def step(months)
        raise "Only supporting step=12 for now" unless months.abs == 12
        yr = months > 0 ? @internal[:year]+1 : @internal[:year]-1
        self.class.new("#{@internal[:month]}/#{yr}")
      end

      def <=>(other)
        raise TypeError unless other.kind_of?(self.class)
        self.value <=> other.value
      end
    end

    class SchoolYear < YYYY
      @interval = 1
      @offset = 1
      @intervals = [1, 5, 10, 20, 100]

      @label = "School Year"

      undef init_numeric
#       undef init_hash

      def init_hash(hash)
        raise "not supported" unless hash[:yyyy]
        @internal = hash[:yyyy]
      end

      # def init_numeric(value)
      #   raise "Invalid year #{value}" if value.is_a?(Float) && (value % 1 != 0)
      #   raise "Invalid year #{value}" if value < 1000 or value > 2999
      #   @internal = value
      # end

      def init_string(value)
        yyyy, nextyear = value.scan(/^(\d\d\d\d)[-\/](\d\d\d?\d?)$/)[0]
        raise "invalid value #{value} for SchoolYear" unless nextyear.to_i % 100 == (yyyy.to_i + 1) % 100
        @internal = yyyy.to_i + 1
      end

      def to_s
        raise RuntimeError unless defined? @internal
        yy = sprintf("%02d", (@internal - 1) % 100)
        yy1 = sprintf("%02d", @internal % 100)
        "#{yy}-#{yy1}"
      end

      def next(step_chron = self.class)
        raise "Invalid step #{step_chron.label}" unless [self.class, YYYY].include?(step_chron)
        self.class.new("#{@internal}-#{sprintf("%02d", (@internal+1) % 100)}")
      end
      def prev(step_chron = self.class)
        raise "Invalid step #{step_chron.label}" unless [self.class, YYYY].include?(step_chron)
        self.class.new("#{@internal-2}-#{sprintf("%02d", (@internal-1) % 100)}")
      end
      def step(n)
        self.class.new("#{@internal+n-1}-#{sprintf("%02d", (@internal+n) % 100)}")
      end
    end

    class YYYYQ < Base
      @interval = 1.0/4
      @intervals = [1.0/4, 1.0, 2.0, 5.0, 10.0, 20.0]
      @offset = 4

      @label = "Quarter"

      def self.descendant_of?(chron)
        [YYYY].include?(chron)
      end

      def init_string(input)
        yyyy, q = input.scan(/^(\d\d\d\d)[Qq.](\d)$/)[0]
        raise "invalid format #{input}" if yyyy.nil? or q.nil?
        raise "Invalid input #{input}" if yyyy.to_i < 1000 or yyyy.to_i > 2999 or q.to_i > 4
        @internal = { :year => yyyy.to_i, :quarter => q.to_i }
      end

      # valid numeric inputs are YYYY.00 (Q1), YYYY.25 (Q2), YYYY.50 (Q3), YYYY.75 (Q4)
      def init_numeric(input)
        raise "Invalid input #{input}" if input.is_a?(Fixnum)
        yyyy, fracpart = input.divmod(1)
        raise "Invalid input #{input}" if yyyy < 1000 or yyyy > 2999
        # raise "Invalid input #{input}" unless q*4 % 1 == 0.0
        q = fracpart * 4 + 1
        # yyyy, q = (input*4).round.divmod(4.0)
        # q += 1
        raise "Invalid input #{input}" unless q.about_equal(q.round)
        @internal = { :year => yyyy.to_i, :quarter => q.to_i }
      end

      def init_hash(hash)
        if index = hash[:index]
          @internal = { :year => (index / 4), :quarter => (index % 4 + 1) }
          return
        end

        yyyy = case hash[:year]
        when Chron::YYYY
          hash[:year].value
        when String
          hash[:year].to_i
        when Fixnum
          hash[:year]
        else
          raise "invalid year #{hash[:year]}"
        end
        q = case hash[:quarter]
        when Chron::Quarter
          hash[:quarter].value
        when String
          hash[:quarter].to_i
        when Fixnum
          hash[:quarter]
        else
          raise "invalid quarter #{hash[:quarter]}"
        end
        # yyyy, q = hash[:year], hash[:quarter]
        @internal = { :year => yyyy, :quarter => q }
      end

      def init_multiple(year, quarter)
        init_hash(:year => year, :quarter => quarter)
      end

      # def initialize(input)
      #   case input
      #   when String:
      #     yyyy, q = input.scan(/^(\d\d\d\d)[Qq.](\d)$/)[0]
      #   when Float:
      #     yyyy, q = (input*4).round.divmod(4.0)
      #     q += 1
      #   when Fixnum:
      #     yyyy, q = input, 0
      #   end
      # 
      #   raise "invalid quarter format" if yyyy.nil? or q.nil?
      #   @internal = { :year => yyyy.to_i, :quarter => q.to_i }
      #   @interval = 1.0/4
      # end

      def value
        @internal[:year].to_f + (@internal[:quarter].to_f-1)/4
      end

      def index
        @internal[:year] * 4 + @internal[:quarter] - 1
      end

      def to_s
        return nil unless defined? @internal
        q = sprintf("%01d", @internal[:quarter])
        yyyy = sprintf("%04d", @internal[:year])
        "#{yyyy}Q#{q}"
      end

      def year
        @internal[:year]
      end

      def quarter
        @internal[:quarter]
      end

      def next(step_chron = self.class)
        if (step_chron == self.class)
          q = (@internal[:quarter] + 1) % 4
          yr = @internal[:year]
          yr += 1 if q == 1
          self.class.new("#{yr}Q#{q}")
        elsif (step_chron == YYYY)
          q = @internal[:quarter]
          yr = @internal[:year] + 1
          self.class.new("#{yr}Q#{q}")
        else
          raise "Invalid step #{step_chron.label}"
        end
      end

      def prev(step_chron = self.class)
        if (step_chron == self.class)
          q = @internal[:quarter] - 1
          yr = @internal[:year]
          if q == 0 then
            yr -= 1
            q = 4
          end
          self.class.new("#{yr}Q#{q}")
        elsif (step_chron == YYYY)
          q = @internal[:quarter]
          yr = @internal[:year] - 1
          self.class.new("#{yr}Q#{q}")
        else
          raise "Invalid step #{step_chron.label}"
        end
      end

      def step(quarters)
        raise "Only supporting step=4 for now" unless quarters.abs == 4
        yr = quarters > 0 ? @internal[:year]+1 : @internal[:year]-1
        self.class.new("#{yr}Q#{@internal[:quarter]}")
      end

      def <=>(other)
        raise TypeError unless other.kind_of?(self.class)
        self.value <=> other.value
      end

    end

    class Month < Base
      @label = "Month"
      @interval = 1

      def init_numeric(value)
        raise "invalid value #{value}" unless value.integer?  && value >= 1 && value <= 12
        @internal = value
      end

      def init_string(value)
        case value
        when /^\d\d?$/
          init_numeric(value.to_i)
        when /^\w\w\w$/
          m = Date::Format::ABBR_MONTHS[value.downcase]
          if m.nil?
            raise "invalid value #{value}"
          else
            init_numeric(m)
          end
        else
          raise "invalid value #{value}"
        end
      end
      # def initialize(input)
      #   # TODO: validate input
      #   @internal = input.to_i
      # end

      def value
        @internal
      end

      def to_s
        "#{@internal}" if defined? @internal
      end

      def mon
        Date::ABBR_MONTHNAMES[@internal]
      end

      def <=>(other)
        raise TypeError unless other.kind_of?(self.class)
        @internal <=> other.value
      end
    end # class Month

    class Quarter < Base
      @label = "Quarter"
      @interval = 1

      def init_numeric(value)
        raise "invalid value #{value}" unless value.integer?
        raise "invalid value #{value}" unless value >= 1 && value <= 4
        @internal = value
      end
      def init_string(value)
        case value
        when /^\d\d?$/
          init_numeric(value.to_i)
        when /^q\w*(\d+)$/i
          init_numeric($1.to_i)
        else
          raise "invalid value #{value}"
        end
      end
      # def initialize(input)
      #   # TODO: validate input
      #   @internal = input.to_i
      # end

      def value
        @internal
      end

      def to_s
        "Q#{@internal}" if defined? @internal
      end
    end # class Quarter

    class YYMMDD < Base
      @label = "Year-Month-Day"

      def init_string(value)
        @internal = case value
        when /^(\d\d)(\d\d)(\d\d)$/
          # would prefer to use Date.strptime, but couldn't get it to work for YYMMDD
          year = $1.to_i
          year += (year > 30 ? 1900 : 2000)
          month = $2.to_i
          day = $3.to_i
          Date.new(year, month, day)
        when /^\d+$/
          # Date.parse in ruby 1.8.6 now recognizes "02" as "2nd of the current month"
          # bypass that - such an input should match only as a Month or Quarter
          raise "invalid value #{value}"
        when /^[A-Za-z]+$/
          # Date.parse in ruby 1.8.6 now recognizes "Jul" as "1st of July, current year"
          # we want "Jul" to map only to Month
          raise "invalid value #{value}"
        when /[A-Z]\d\d[A-Z]/
          # this one is weird.  Date.parse is finding buried digits.
          raise "invalid value #{value}"
        else
          # calm down the over-aggressive Date#parse recognizer
          # a potential date should have at least three digits in it, possible with separators
          raise "invalid value #{value}" unless value =~ /\d.*\d.*\d/
          begin
            dt = Date.parse(value)
          rescue
            raise "invalid value #{value}"
          end
          # more protection, this time against recognizing "1.2345" as "1st of Jan, year 2345"
          raise "value #{value} out of range" if dt.year < 1800 or dt.year > 2050
          dt
        end
      end

      def init_date(date)
        @internal = date
      end

      def value
        @internal.mjd
      end

      def to_s
        @internal.to_s
      end

      def <=>(other)
        raise TypeError unless other.kind_of?(self.class)
        internal.mjd <=> other.value
      end

      def mon
        Date::ABBR_MONTHNAMES[@internal.month]
      end
    end # class YYMMDD
  end # module Chron
end # module Dataset

class Float
  def about_equal(f2, delta = 0.001)
    (self - f2).abs <= delta
  end
end
