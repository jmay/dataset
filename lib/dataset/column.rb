module Dataset

  # this is the internal representation of a data column
  class Column
    attr_accessor :role

    def initialize(args = {})
      @role = args[:role]
    end

    def label
      return nil if role.nil?
      return role.label if chron?
      return role.name if dimension?
      return role.name if measure?
      "ignored"
    end

    def measure?
      role.is_a?(Measure)
    end

    def chron?
      role.class == Class && role.to_s =~ /Chron::/
    end

    def dimension?
      role.is_a?(Dimension)
    end

    def ignore?
      role == :ignore
    end
  end # class Column

end # module Dataset
