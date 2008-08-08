# TODO: consider renaming Table to TableSpec or Tablespec
# TODO: user-provided vs system-automated metadata, esp. user-provided column labels

require "facets/hash"
require "facets/blank"
# require "facets"

module Dataset
  class Table
    attr_reader :nrows  # table-global metadata
    attr_reader :columns  # array containing per-column metadata
    attr_reader :rows # if #read has been called, this will contain an array of data rows

    def initialize(args = {})
      @nrows = args[:nrows]
      @columns = (args[:columns] || []).map_with_index {|coldata, colnum| TableColumn.new(:metadata => coldata, :colnum => colnum)}
      @constraints = args[:constraints] || {}
    end

    def self.from_runlog(runlog)
      return nil if runlog.nil?

      stagedata = runlog['stagelogs']
      return nil if stagedata.nil?

      # if any of the pipeline stages failed, abort
      return nil if stagedata.map{|stage| stage && stage[:error_code]}.compact.any?

      nrows = stagedata.map{|stage| stage && stage[:nrows]}.compact.last.to_i

      columndata = stagedata.map{|stage| stage && stage[:columns] || []}
      ncols = columndata.map{|cols| cols.size}.max
      merged_coldata = []
      if ncols && ncols > 0
        columndata.each {|col| col[ncols-1] ||= {}}
        merged_coldata = columndata.transpose.map {|attrs| attrs.inject({}) {|memo, d| memo.merge(d || {})}}
      end
      Table.new(:columns => merged_coldata, :nrows => nrows)
    end

    def merge(table2)
      @nrows = table2.nrows if table2.nrows

      if @columns.empty?
        # don't have any column info; import the target's column info wholesale
        @columns = table2.columns
      elsif table2.columns.empty?
        # no-op, there's no column metadata in the target to import
      elsif @columns.size != table2.columns.size
        raise "Column mismatch between tablespecs"
      else
        table2.columns.each_with_index do |col, i|
          @columns[i].merge(col)
        end
      end
      self
    end

    # process file as stream (if block provided) or batch
    # yield each row as an array of converted types: Chron, Number or the untouched string
    def read(datafile, args = {}, &block)
      if args[:tmin] || args[:tmax] || args[:reverse]
        read_with_chron_range(datafile, args, &block)
      else
        read_with_limit_and_offset(datafile, args, &block)
      end
    end

    def read_with_chron_range(datafile, args, &block)
      raise "No chron column in this table" unless chron?
      raise "Chron mismatch - expected #{chron}" if (args[:tmin] && args[:tmin].class != chron) || (args[:tmax] && args[:tmax].class != chron)

      if args[:reverse]
        if args[:limit]
          tmin = chron_column.metadata[:max] - (args[:offset] || 0) - args[:limit] + 1
          tmax = tmin + args[:limit] - 1
        else
          tmin = chron_column.metadata[:min]
          tmax = chron_column.metadata[:max]
        end

        args[:tmin] = chron.new(:index => tmin)
        args[:tmax] = chron.new(:index => tmax)
      end

      @rows = []
      File.open(datafile).each do |line|
        fields = line.chomp.split("\t")
        row = fields.zip(@columns).map {|v, col| col ? col.interpret(v, args) : v}

        next if args[:tmin] && row[chron_column.colnum] < args[:tmin]
        next if args[:tmax] && row[chron_column.colnum] > args[:tmax]

        if block && !args[:reverse]
          yield row
        else
          @rows << row
        end
      end

      if args[:reverse]
        @rows.reverse!
        if block
          @rows.each {|row| yield row}
        else
          @rows
        end
      else
        @rows
      end
    end

    def read_with_limit_and_offset(datafile, args, &block)
      limit = args[:limit] || nil
      offset = args[:offset] || 0
      @rows = []

      File.open(datafile).each_with_index do |line, i|
        break if limit && i >= offset+limit
        next if i < offset
        fields = line.chomp.split("\t")
        if @columns.any?
          # row = @columns.zip(fields).map {|col, v| col.interpret(v, args)}
          row = fields.zip(@columns).map {|v, col| col ? col.interpret(v, args) : v}
        else
          row = fields
        end
        if block
          yield row
        else
          @rows << row
        end
      end
      @rows
    end

    def constraints
      @constraints ||= {}
    end

    # a table is NSF if:
    # * at most one (explicitly-specified-as-)chron column
    # * at least one (explicitly-specified-as-)number column
    # * every column is either a chron, dimension, or measure
    # def nsf?
    #   columns.each do |col|
    #     return false if !col.chron? && !col.dimension? && !col.measure? 
    #   end
    #   true
    # end
    def nsf?
      (chron_columns.size <= 1) && (measure_columns.size >= 1) && columns.none? {|col| !col.chron? && !col.dimension? && !col.measure?}
    end

    # 'other' columns are neither chrons nor measures nor dimensions
    def other_columns
      columns.find_all {|col| !col[:chron] && !col[:number] && !col[:values]}
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
      columns.find_all {|col| col[:values]}
    end

    def dimensions
      dimension_columns.map {|col| Dimension.new(:name => col.name, :values => col[:values])}
    end

    def dimension_column(name)
      dimension_columns.find {|col| col.name == name}
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

    def measure=(measure)
      if measure.respond_to?(:name)
        measure_column.metadata.merge!(:name => measure.name, :multiplier => measure.multiplier, :units => measure.units.label)
      else
        measure_column.metadata.merge!({
          :name => measure[:name] || measure['name'],
          :units => measure[:number] || measure[:units] || measure['units'],
          :multiplier => measure[:multiplier] || measure['multiplier']
        })
      end
    end

    def column_labels
      columns.map(&:name_or_default)
    end

    def chrondata
      @rows.map {|row| row[chron_column.colnum]}
    end

    def measuredata
      @rows.map {|row| row[measure_column.colnum]}
    end
  end

  class TableColumn
    attr_reader :metadata, :data
    attr_reader :colnum

    def initialize(args)
      @metadata = args[:metadata]
      @colnum = args[:colnum]
    end

    def merge(col2)
      @metadata.merge!(col2.metadata)
    end

    def [](key)
      @metadata[key]
    end

    def []=(key, value)
      @metadata[key] = value
    end

    # TODO: user vs system labeling, separate 'name' and 'label' internal metadata attributes?
    def label
      @metadata[:label]
    end

    def name
      @metadata[:name] || @metadata[:label] || @metadata[:heading]
    end

    def name=(value)
      if value.nil?
        # don't just set the value to nil, remove the key entirely from the spec so that
        # we are sure that any automatic column name will apply
        @metadata.delete(:name)
      else
        @metadata[:name] = value
      end
    end

    def name_or_default
      return name unless name.blank?
      return chron.label if chron?
      return number.label if number?
      ''
    end

    def chron?
      !metadata[:chron].nil?
    end

    def chron
      Chron.const_get(@metadata[:chron])
    end

    def number?
      !metadata[:number].nil?
    end

    def number
      Number.find(@metadata[:number])
    end

    def units
      Number.find(@metadata[:units] || @metadata[:number])
    end

    def measure
      Measure.new(
        :name => name,
        :units => units,
        :multiplier => @metadata[:multiplier]
        )
    end

    def measure?
      ! units.nil?
    end

    def dimension?
      ! metadata[:values].nil?
    end

    def interpret(value, params = {})
      if @metadata[:chron]
        chron.new(:index => value.to_i)
      elsif @metadata[:number] && !params[:skip_number_formatting]
        units.new(value)
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
