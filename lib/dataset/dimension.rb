# A dimension can be defined with an explicit set of values, or the values
# can be omitted.  If no values are defined, any values can be supplied in
# data series.

module Dataset
  class Dimension
    attr_accessor :name, :values

    def initialize(opts = {})
      @name = opts[:name] || "Untitled"
      @values = opts[:values] || []
    end

    def inspect
      "Dimension: #{name} - #{values.size} values"
    end
  end
end
