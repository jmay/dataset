module Dataset
  class Table
    attr_reader :columns

    def initialize(columns)
      @columns = columns
      @columns.each_with_index {|col, i| col[:colnum] = i}
    end

    def chron_columns
      columns.find_all {|col| !col[:chron].nil?}
    end

    def chron?
      chron_columns.any?
    end

    def chron
      chron_columns.first[:chron]
    end

    def dimension_columns
      columns.find_all {|col| !col[:chron] && !col[:units]}
    end

    def dimensions
      dimension_columns.map {|col| col[:name]}
    end

    def measure_columns
      columns.find_all {|col| !col[:units].nil?}
    end

    def measures
      measure_columns.map {|col| col[:units]}
    end

    def measure?
      measures.any?
    end

    def measure
      measures.first
    end
  end
end
