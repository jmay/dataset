require "cgi" # for unescape

# TODO: baseline
# TODO: ratio
# TODO: adjust-multiplier

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
            :percent => '1'
          }
        }]
      end
    end

    def ready?
      @target && !self.class.intervals[@target.chron].nil?
    end
  end

  class Diffs < Changes
    label "abs"

    class << self
      attr_accessor :intervals
    end

    def ready?
      @target && !self.class.intervals[@target.chron].nil?
    end

    def recipe
      if ready?
        [{
          :command => 'deltas',
          :args => {
            :ordercol => @target.chron_columns.first.colnum,
            :datacol => @target.measure_columns.first.colnum,
            :interval => self.class.intervals[@target.chron],
            :percent => '0'
          }
        }]
      end
    end
  end

  class AnnualDeltas < Deltas
    label "ann"
    terminal
    self.intervals = { Chron::YYYY => 1, Chron::YYYYQ => 4, Chron::YYYYMM => 12 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => 'Percent',
          :label => "Annual change in #{@target.measure_column.label}" }
        ])
    end
  end

  class QuarterlyDeltas < Deltas
    label "qtr"
    terminal
    self.intervals = { Chron::YYYYQ => 1, Chron::YYYYMM => 3 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => 'Percent',
          :label => "Quarterly change in #{@target.measure_column.label}" }
        ])
    end
  end

  class MonthlyDeltas < Deltas
    label "mon"
    terminal
    self.intervals = { Chron::YYYYMM => 1 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => 'Percent',
          :label => "Monthly change in #{@target.measure_column.label}" }
        ])
    end
  end

  class AnnualDiffs < Diffs
    label "ann"
    terminal
    self.intervals = { Chron::YYYY => 1, Chron::YYYYQ => 4, Chron::YYYYMM => 12 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => @target.measure.units.label,
          :multiplier => @target.measure.multiplier,
          :label => "Annual change in #{@target.measure_column.name}" }
        ])
    end
  end

  class QuarterlyDiffs < Diffs
    label "qtr"
    terminal
    self.intervals = { Chron::YYYYQ => 1, Chron::YYYYMM => 3 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => @target.measure.units.label,
          :multiplier => @target.measure.multiplier,
          :label => "Quarterly change in #{@target.measure_column.name}" }
        ])
    end
  end

  class MonthlyDiffs < Diffs
    label "mon"
    terminal
    self.intervals = { Chron::YYYYMM => 1 }

    def resultspec
      Table.new(:columns => [
        { :chron => @target.chron_str },
        { :number => @target.measure.units.label,
          :multiplier => @target.measure.multiplier,
          :label => "Monthly change in #{@target.measure_column.name}" }
        ])
    end
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

    # TODO: def tablespec
  end

  class Extract < Calculation
    label 'extract'
    terminal

    attr_reader :dimension_name, :dimension_value, :invert

    def self.find(descriptor)
      if descriptor == ""
        self
      else
        self.new(*descriptor.split('-'))
      end
    end

    def initialize(name = nil, value = nil, invert = nil)
      @dimension_name = CGI.unescape(name) if name
      @dimension_value = CGI.unescape(value) if value
      @invert = invert ? true : false
    end

    def ready?
      @target && dimension_name && dimension_value && !@target.dimension_column(dimension_name).nil?
    end

    def recipe
      if ready?
        [{
          :command => 'select_where.pl',
          :args => {
            :column => @target.dimension_column(dimension_name).colnum,
            :value => @dimension_value,
            :invert => @invert ? 1 : 0
          },
        }]
      end
    end

    def resultspec
      if ready?
        columns = @target.columns.dup # separate copy of columns metadata for the new spec, which will be altered
        columns.delete_at(@target.dimension_column(dimension_name).colnum)
        Table.new(:columns => columns.map(&:metadata))
      end
    end
  end

  class ExtractColumn < Calculation
    label 'column'
    terminal

    attr_reader :colnum

    def self.find(descriptor)
      if descriptor == ""
        self
      else
        self.new(*descriptor.split('-'))
      end
    end

    def initialize(colnum = nil)
      @colnum = colnum.to_i
    end

    def ready?
      @target && @target.measure? && @target.columns[@colnum] && @target.columns[@colnum].number?
    end

    def columns
      [@target.chron_columns, @target.dimension_columns, @target.columns[@colnum]].flatten
    end

    def recipe
      if ready?
        [{
          :command => 'columns.pl',
          :args => {
            :columns => columns.map(&:colnum).join(",")
          },
        }]
      end
    end

    def resultspec
      if ready?
        Table.new(:columns => columns.map(&:metadata))
      end
    end
  end

  class MergeCalculation < Calculation
    label "merge"
    terminal

    def target2(table)
      @target2 = table
    end

    def ready?
      @target && @target2 && (@target.chron == @target2.chron) && @target.dimension_columns.empty? && @target2.dimension_columns.empty?
    end

    def recipe
      if ready?
        [{
          :command => 'merge.rb',
          :args => {
            :input => '1',
            :group1 => @target.columns.find_all {|col| !col.measure?}.map(&:colnum).join(','),
            :group2 => @target2.columns.find_all {|col| !col.measure?}.map(&:colnum).join(','),
            :pick2 => @target2.measure_columns.map(&:colnum).join(',')
          }
        }]
      end
    end

    def resultspec
      columns = @target.columns.dup
      columns.concat(@target2.measure_columns)
      Table.new(:columns => columns.map(&:metadata))
      # Table.new(:columns => columns)
    end
  end

  class RollupCalculation < Calculation
    label "rollup"
  end

  class MonthlyRollupCalculation < RollupCalculation
    label "mon"
  end

  class EOMRollupCalculation < MonthlyRollupCalculation
    label "last"
    terminal

    def ready?
      @target &&
      (@target.chron == Chron::YYMMDD) &&
      @target.dimension_columns.empty? &&
      @target.other_columns.empty? &&
      (@target.measure_columns.size == 1)
    end

    def recipe
      if ready?
        [
          :command => 'rollup.rb',
          :args => {
            :level => 'month',
            :formula => 'last',
            :chroncol => @target.chron_column.colnum,
            :datacol => @target.measure_column.colnum
          }
        ]
      end
    end

    def resultspec
      Table.new(:columns => [
        {:chron => 'YYYYMM'},
        @target.measure_column.metadata
        ])
    end
  end
end
