module Dataset
  class Calculation

    class << self
      # register with the superclass
      def label(label)
        superclass.register(label, self)
      end

      # allow other classes to register with this one
      def register(label, klass)
        @registry ||= {}
        @registry[label] = klass
      end

      # find another class in the registry
      def lookup(label)
        @registry[label]
      end

      # only actual instances of calculations are terminal
      def terminal?
        false
      end

      def ready?
        false
      end
    end

    def self.terminal
      define_method(:target) { |obj| @target = obj }
      define_method(:execute) {
        p recipe
      }
    end

    def terminal?
      self.respond_to?(:recipe)
    end

    def self.find(descriptor)
      if descriptor == ""
        # this is me
        new
      else
        parts = descriptor.split('-')
        klass = lookup(parts.shift)
        return nil if klass.nil? # no match, unrecognized calculation
        klass.find(parts.join('-'))
      end
    end
  end

  class Changes < Calculation
    label "chg"

    def self.choices
      [ 'chg-pct', 'chg-abs' ]
    end
  end

  class Deltas < Changes
    label "pct"

    class << self
      attr_accessor :intervals
    end

    def recipe
      if ready?
        [{
          :command => 'deltas',
          :args => {
            :ordercol => @target.chron_columns.first.colnum,
            :datacol => @target.measure_columns.first.colnum,
            :interval => self.class.intervals[@target.chron],
            :percent => true
          }
        }]
      end
    end

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => 'Percentage',
          :label => "Monthly change in #{@target.measure_column.label}" }
        ])
    end

    def ready?
      @target && !self.class.intervals[@target.chron].nil?
    end
  end

  class Diffs < Changes
    label "abs"
  end

  class AnnualDeltas < Deltas
    label "ann"
    terminal
    self.intervals = { Chron::YYYY => 1, Chron::YYYYQ => 4, Chron::YYYYMM => 12 }
  end

  class QuarterlyDeltas < Deltas
    label "ann"
    terminal
    self.intervals = { Chron::YYYYQ => 1, Chron::YYYYMM => 3 }
  end

  class MonthlyDeltas < Deltas
    label "mon"
    terminal
    self.intervals = { Chron::YYYYMM => 1 }
  end

  class AnnualDiffs < Diffs
    label "ann"
  end

  class Baseline < Calculation
    label 'baseline'
    terminal

    attr_reader :baseline_chron

    def self.find(descriptor)
      if descriptor == ""
        self
      else
        self.new(descriptor)
      end
    end

    def initialize(baseline_chron)
      @baseline_chron = baseline_chron
    end

    def ready?
      @target && !@target.chron.new(baseline_chron).nil? rescue false
    end

    def recipe
      if ready?
        [{
          :command => 'baseline',
          :args => {
            :chroncol => 0,
            :basechron => @target.chron.new(baseline_chron).index,
          }
        }]
      end
    end
  end

  class Extract < Calculation
    label 'extract'
    terminal

    attr_reader :dimension_name, :dimension_value

    def self.find(descriptor)
      if descriptor == ""
        self
      else
        self.new(*descriptor.split('-'))
      end
    end

    def initialize(name = nil, value = nil)
      @dimension_name = name
      @dimension_value = value
    end

    def ready?
      @target && dimension_name && dimension_value && !@target.dimension_column(dimension_name).nil?
    end

    def recipe
      if ready?
        [{
          :command => 'filter',
          :args => {
            :column => @target.dimension_column(dimension_name).colnum,
            :value => @dimension_value,
          },
        }]
      end
    end
  end

  class Column < Calculation
    label 'column'
    terminal

    attr_reader :column

    def self.find(descriptor)
      if descriptor == ""
        self
      else
        self.new(*descriptor.split('-'))
      end
    end

    def initialize(colnum = nil)
      @column = colnum.to_i
    end

    def ready?
      @target && @target.measure? && @target.columns[@column] && @target.columns[column].number?
    end

    def recipe
      if ready?
        columns = [@target.chron_columns, @target.dimension_columns].flatten.map(&:colnum) + [column]
        [{
          :command => 'columns.rb',
          :args => {
            :columns => columns.join(",")
          },
        }]
      end
    end
  end

  # 
  #   module Changes
  #     module Percent
  #     end
  #   end
  # 
  #   MonthlyDeltas = Deltas.new
  # 
  #   class Baseline < Base
  #     takes_param
  # 
  #     def options(target)
  #       target.chrons
  #     end
  # 
  #     def recipe
  #       { :command => 'baseline', :basecol => target.chroncol }
  #     end
  #   end
  # end
end

# p Dataset::Calculation.find('')
# p Dataset::Calculation.find('chg')
# p Dataset::Calculation.find('foo')
# p Dataset::Calculation.find('chg-pct')
# p Dataset::Calculation.find('chg-pct-mon')
# p Dataset::Calculation.find('chg-abs')
# p Dataset::Calculation.find('bogus')
# p Dataset::Calculation.find('baseline')
# p Dataset::Calculation.find('baseline-1995')
