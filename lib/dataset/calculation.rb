require "cgi" # for unescape
# require "facets/enumerable/sum" # for summing across arrays

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
      if descriptor.blank?
        # this is me
        new
      else
        first, rest = descriptor.match(/^([^-]+)-?(.*)/).captures
        klass = lookup(first)
        return nil if klass.nil? # no match, unrecognized calculation
        klass.find(rest)

        # parts = descriptor.split('-')
        # klass = lookup(parts.shift)
        # return nil if klass.nil? # no match, unrecognized calculation
        # klass.find(parts.join('-'))
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
          :label => "Annual change in #{@target.measure_column.name}" }
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
          :label => "Quarterly change in #{@target.measure_column.name}" }
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
          :label => "Monthly change in #{@target.measure_column.name}" }
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

  class BaselineCalc < Calculation
    label 'baseline'
    terminal

    def self.find(descriptor)
      if descriptor.blank?
        self
      else
        self.new(descriptor)
      end
    end

    def initialize(chron_str)
      @baseline_chron_str = chron_str
    end

    def ready?
      # does it have a chron, no dimensions, and at least one measure?
      return false unless @target && @target.chron && @target.measure_columns.any? && @target.other_columns.empty?

      # does the provided baseline chron match the chron type of the target?
      baseline_chron = @target.chron.new(@baseline_chron_str) rescue nil
      return false if baseline_chron.nil?

      # does it have min & max fields for checking if the baseline chron is in-range?
      return false unless @target.chron_column.min && @target.chron_column.max

      # is the baseline in-range?
      (baseline_chron >= @target.chron_column.min) && (baseline_chron <= @target.chron_column.max)
    end

    def recipe
      if ready?
        [{
          :command => 'baseline.rb',
          :args => {
            :chroncol => @target.chron_column.colnum,
            :baseline => @target.chron.new(@baseline_chron_str).index,
            :datacols => @target.measure_columns.map {|col| col.colnum}.join(',')
          }
        }]
      end
    end

    def resultspec
      if ready?
        columns = @target.columns.map do |col|
          if col.measure?
            TableColumn.new({ :metadata => { :number => 'Index', :label => "Baselined #{col.name || col.units.label}"}})
          else
            col
          end
        end

        Table.new(:columns => columns.map(&:metadata))
      end
    end
    # TODO: def tablespec
  end

  class Extract < Calculation
    label 'extract'
    terminal

    attr_reader :dimension_name, :dimension_value, :invert

    def self.find(descriptor)
      if descriptor.blank?
        self
      else
        self.new(*descriptor.match(/^([^-]+)-?(.*)/).captures)
      end
    end

    def initialize(name = nil, value = nil, invert = nil)
      @dimension_name = CGI.unescape(name) if name
      @dimension_value = CGI.unescape(value) if !value.blank?
      @invert = invert ? true : false
    end

    def ready?
      @target && dimension_name && dimension_value && dimension_colnum && @target.columns[dimension_colnum].dimension?
    end

    def dimension_colnum
      if dimension_name =~ /^\d+$/
        dimension_name.to_i 
      else
        (column = @target.dimension_column(dimension_name)) && column.colnum
      end
    end

    def recipe
      if ready?
        [{
          :command => 'select_where.pl',
          :args => {
            :column => dimension_colnum,
            :value => @dimension_value,
            :invert => @invert ? 1 : 0
          },
        }]
      end
    end

    def resultspec
      if ready?
        columns = @target.columns.dup # separate copy of columns metadata for the new spec, which will be altered
        columns.delete_at(dimension_colnum)
        Table.new(
          :columns => columns.map(&:metadata),
          :constraints => @target.constraints.merge({@target.columns[dimension_colnum].name => dimension_value})
        )
      end
    end
  end

  class ExtractColumn < Calculation
    label 'column'
    terminal

    attr_reader :colnum

    def self.find(descriptor)
      if descriptor.blank?
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
        },
        {
          :command => 'filter_out.rb',
          :args => {
            :column => columns.size - 1,  # the last column in the output must have a value
            :match => ''
          }
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
            :chron => 'YYMMDD',
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

  class CoalesceCalculation < Calculation
    label 'coalesce'
    terminal
    attr_accessor :constituents

    def ready?
      !@target.nil? && !@constituents.nil? && @constituents.any?
    end

    def recipe
      if ready?
        [
          :command => 'coalesce',
          :args => {
            :files => @constituents
          }
        ]
      end
    end

    def resultspec
      nrows = constituents.map(&:nrows).compact.sum
      columndata = constituents.map(&:columns).transpose.map do |cols|
        newmin = cols.map{|c| c.metadata[:min]}.compact.min
        newmax = cols.map{|c| c.metadata[:max]}.compact.max
        col = cols.first.metadata
        col[:min] = newmin unless newmin.nil?
        col[:max] = newmax unless newmax.nil?
        col
      end
      Table.new(:nrows => nrows, :columns => columndata)
    end
  end

  class Subtraction < Calculation
    label 'aminusb'
    terminal

    def target2(table)
      @target2 = table
    end

    def ready?
      @target && @target2 && (@target.chron == @target2.chron) && (@target.measure_column.units.label == @target2.measure_column.units.label)
    end

    def recipe
      if ready?
        [{
          :command => 'subtract.rb',
          :args => {
            :input => '1',
            :group1 => @target.columns.find_all {|col| !col.measure?}.map(&:colnum).join(','),
            :group2 => @target2.columns.find_all {|col| !col.measure?}.map(&:colnum).join(','),
            :pick1 => @target2.measure_column.colnum,
            :pick2 => @target2.measure_column.colnum
          }
        }]
      end
    end

    def resultspec
      table = @target.dup
      table.measure_column.name = "#{@target.measure_column.name} minus #{@target2.measure_column.name}"
      table
    end
  end
end
