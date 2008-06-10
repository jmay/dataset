# TODO: consider renaming Table to TableSpec or Tablespec
# TODO: user-provided vs system-automated metadata, esp. user-provided column labels
# TODO: constraints (look at TableDescriptor)
module Dataset
  class Table
    attr_reader :nrows, :constraints  # table-global metadata
    attr_reader :columns  # array containing per-column metadata

    def initialize(args = {})
      @nrows = args[:nrows]
      @columns = (args[:columns] || []).map_with_index {|coldata, colnum| TableColumn.new(:metadata => coldata, :colnum => colnum)}
      @constraints = args[:constraints] || {}
    end

    def self.from_runlog(runlog)
      stagedata = runlog['stagelogs']
      nrows = stagedata.map{|stage| stage[:nrows]}.compact.last

      columndata = stagedata.map{|v| v[:columns] || []}
      ncols = columndata.map{|cols| cols.size}.max
      merged_coldata = []
      if ncols > 0
        columndata.each {|col| col[ncols-1] ||= {}}
        merged_coldata = columndata.transpose.map {|attrs| attrs.inject({}) {|memo, d| memo.merge(d || {})}}
      end
      Table.new(:columns => merged_coldata, :nrows => nrows)
    end

    def merge(table2)
      @nrows = table2.nrows if table2.nrows

      table2.columns.each_with_index do |col, i|
        self.columns[i].merge(col)
      end
    end

    # process file as stream
    def read(datafile, &block)
      File.open(datafile).each_line do |line|
        fields = line.chomp.split("\t")
        yield(@columns.zip(fields).map {|col, v| col.interpret(v)})
      end
    end

    # process file as a batch
    def load(datafile)
      File.open(datafile).each_line do |line|
        fields = line.chomp.split("\t")
        @columns.zip(fields).map {|col, v| col.data << col.interpret(v)}
      end
    end

    # a table is NSF if:
    # * at most one (explicitly-specified-as-)chron column
    # * at least one (explicitly-specified-as-)number column
    def nsf?
      (chron_columns.size <= 1) && (measure_columns.size >= 1)
    end

    def chron_columns
      columns.find_all {|col| !col[:chron].nil?}
    end

    def chron_column
      chron_columns.any? ? chron_columns.first : nil
    end

    def chron?
      chron_columns.any?
    end

    def chron
      chron_column.chron rescue nil
    end

    def chron_str
      chron_columns.first[:chron]
    end

    def dimension_columns
      columns.find_all {|col| !col[:chron] && !col[:number]}
    end

    def dimensions
      dimension_columns.map {|col| col[:name]}
    end

    def dimension_column(name)
      dimension_columns.find {|col| col[:name] == name}
    end

    def measure_columns
      columns.find_all {|col| !col[:number].nil?}
    end

    def measure_column
      measure_columns.any? ? measure_columns.first : nil
    end

    def measures
      measure_columns.map {|col| col[:number]}
    end

    def measure?
      measures.any?
    end

    def measure
      measure_column.measure rescue nil
    end

    def measure_str
      measures.first
    end
  end

  class TableColumn
    attr_reader :metadata, :data
    attr_reader :colnum

    def initialize(args)
      @metadata = args[:metadata]
      @colnum = args[:colnum]
      @data = []
    end

    def merge(col2)
      metadata.merge!(col2.metadata)
    end

    def [](key)
      @metadata[key]
    end

    def []=(key, value)
      @metadata[key] = value
    end

    def label
      @metadata[:label]
    end

    def chron
      Chron.const_get(@metadata[:chron])
    end

    def number
      Number.const_get(@metadata[:number])
    end

    def measure
      Measure.new(
        :name => label,
        :units => number,
        :multiplier => @metadata[:multiplier]
        )
    end

    def interpret(value)
      if @metadata[:chron]
        # @metadata[:chron].new(:index => value)
        chron.new(:index => value)
      elsif @metadata[:number]
        number.new(value)
      else
        value
      end
    end

    def min
      @metadata[:min] && interpret(@metadata[:min])
    end

    def max
      @metadata[:max] && interpret(@metadata[:max])
    end
  end
end

if $0 == __FILE__
  require "dataset"
  y = YAML.load($stdin)
  table = Dataset::Table.from_runlog(y)
  puts table.to_yaml
end
