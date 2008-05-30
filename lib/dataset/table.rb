module Dataset
  class Table
    attr_reader :columns

    def initialize(columns)
      @columns = columns.map_with_index {|coldata, colnum| TableColumn.new(:metadata => coldata, :colnum => colnum)}
      @columns.each {|col| colclean(col)}
      # @columns.each_with_index {|col, i| col[:colnum] = i}
    end

    def self.from_runlog(runlog)
      columndata = runlog['stagelogs'].map{|v| v[:columns] || []}
      ncols = columndata.map{|cols| cols.size}.max
      columndata.each {|col| col[ncols-1] ||= {}}
      merged_coldata = columndata.transpose.map {|attrs| attrs.inject({}) {|memo, d| memo.merge(d || {})}}
      Table.new(merged_coldata)
    end

    def colclean(col)
      if col[:chron] && col[:chron].is_a?(String)
        col[:chron] = Chron.const_get(col[:chron])
      elsif col[:number] && col[:number].is_a?(String)
        col[:number] = Number.const_get(col[:number])
      end
    end

    def datafile=(filename)
      @datafile = filename
    end

    def load
      File.open(@datafile).each_line do |line|
        fields = line.chomp.split("\t")
        # @columns.map_with_index {|col, i| col.data << col.interpret(fields[i])}
        @columns.zip(fields).map {|col, v| col.data << col.interpret(v)}
      end
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

    def [](key)
      @metadata[key]
    end

    def []=(key, value)
      @metadata[key] = value
    end

    def interpret(value)
      if @metadata[:chron]
        @metadata[:chron].new(:index => value)
      elsif @metadata[:number]
        @metadata[:number].new(value)
      else
        value
      end
    end
  end
end
