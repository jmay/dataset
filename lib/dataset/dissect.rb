module Dataset
  class Dissect
    attr_accessor :rows, :columns, :recipe

    def initialize(args)
      @rows = []
      args[:input].each_line do |line|
        @rows << line.chomp.split(/\t/)
      end
      analyze
    end

    def analyze
      @ncolumns = rows.map(&:size).max
      @columns = (0..@ncolumns).map { |i| Column.new(:colnum => i, :values => rows.map {|row| row[i]}) }

      analyze_columns
    end

    def recipe
      recipe = []

      if chron_columns.any?
        col = chron_columns.first
        recipe << { 'command' => 'chronify.rb', 'args' => {:column => "#{col.colnum}:#{col.role.name.split(/::/).last}"}}
      end

      measure_columns.each do |col|
        recipe << { 'command' => 'measures.rb', 'args' => {:column => "#{col.colnum}"}}
      end

      dimension_columns.each do |col|
        recipe << { 'command' => 'dimension.rb', 'args' => {:columns => "#{col.colnum}"}}
      end

      recipe
    end


    # should this input line be completely ignored for columnizing purposes?
    # TODO: deal with input that looks like multiple pages, with header lines repeated
    def is_header?(fields)
      # parsing should ignore...
      # lines that are completely blank
      # lines that appear to be entirely delimiters

      return true if fields.empty?

      line = fields.join

      # these are probably horizontal markers between any header text and the actual data
      return true if line =~ /^[-=*_\s]*$/

      return true unless line =~ /\d/

      return true if line =~ /^\s*[A-Za-z ]+$/

      # this line looks significant, keep it in.
      false
    end

    # build up a data structure for each column
    # does the column contain numeric data?
    def analyze_columns
      # digest the values for each Column
      columns.each {|c| c.crunch}

      assign_column_roles

      if columns.find_all {|col| col.measure? || col.role == :measure}.empty?
        # no measure columns, create a placeholder
        @measure = Measure.new(:name => "Unknown")
      end
    end

    # inspect the values in the header, looking for chrons.  If there are any,
    # then set up @chron_list as a substitute for the missing @chron_column
    def analyze_headers
#       @chron_list = nil
      chrons = []
      extractor.headers.each_with_index do |v, colnum|
        pv = ParsedValue.new(v)
        if !pv.chron.empty? then
          chrons << pv.chron.first
          if colnum < @ncolumns
#             puts "Setting the column role to #{pv.chron.first}"
            @columns[colnum].role = pv.chron.first
          end
        end
      end
      # p chrons
#       @chron_list = chrons unless chrons.empty?
    end

    def assign_column_roles
      @columns.each_with_index do |col, i|
#         next if col.role
        col.role = choose_role_for(i)
      end
    end

    def choose_role_for(colnum)
      col = @columns[colnum]
      roles = col.possible_roles

      return roles.first if roles.size == 1

      chronDimRoles = roles.find_all {|role| role.is_a?(Chron::Base)}
      if !chronDimRoles.empty?
        return chronDimRoles.first
      end

      if col.distinct_text_values.size <= 2 && rows.size > 20
        return :ignore
      end

      chronRoles = roles.find_all {|role| role.respond_to?(:label)}
      if !chronRoles.empty?
        chronRoles.delete(Chron::SchoolYear)
        if colnum == 0
          return chronRoles.first
        end
        chronRoles -= (@columns[0..colnum-1].find_all {|col| col.chron?}.map {|col| col.role})
        if !chronRoles.empty?
          return chronRoles.first
        end
        # duplicate chrons, so this is probably a measure
      end

      if measureRole = roles.find {|role| role.is_a?(Measure)}
        return measureRole
      end

      if col.distinct_text_values.size < 3
        return :ignore
      end

      if dimensionRole = roles.find {|role| role.is_a?(Dimension)}
        return dimensionRole
      end

      raise "Unable to guess role for column #{colnum}: #{col.label}"
    end

    def chron_columns
      @columns.find_all {|col| col.chron?}
    end

    def measure_columns
      @columns.find_all {|col| col.could_be_measure? && !col.chron?}
    end

    def dimension_columns
      @columns.find_all {|col| col.could_be_dimension?}
    end

    # does this source have a chron column?
    def has_chron?
      ! chron_columns.empty?
    end

    def inspect
      formatting_info +
      "Columns: #{@columns.inspect}\n"
    end

    def formatting_info
      "Extractor: #{extractor.inspect}\n"
    end

    def measures
      columns.find_all {|col| col.measure? || col.role == :measure}
    end

    def measure=(measure)
      raise "Cannot set a global measure where there are measure columns" if measure && measures.any?
      @measure = measure
    end
  end # class Parser

  # this is the internal representation of a column in the source
  # @label is the column label as parsed out from the source
  # @user_label is an optional user-provided text label which will override the source label
  class Column
    # attr_accessor :active
    attr_reader :distinct_text_values, :role, :possible_roles, :cell_values
    attr_reader :headers, :user_label
    attr_accessor :notes, :constraints
    attr_reader :colnum

    def initialize(args)
      @original_values = args[:values]
      @colnum = args[:colnum]
      @possible_roles = nil
    end

    # figure out all the possible roles of this column
    def crunch
      @cell_values = @original_values.map {|v| CellValue.new(v)}

      @distinct_text_values = cell_values.find_all {|v| !v.number && v.text}.compact.uniq

      @possible_roles = find_possible_roles
      self
    end

    def find_possible_roles
      roles = []
      roles << :ignore

      chrons = possible_chron_roles
      if chrons.any?
        roles.concat(possible_chron_roles)
      end

      # could be a set of values for a particular Chron dimension, with a global or per-row measure
      # (but not if the values themselves look like chrons)
      roles.concat(Array(Chron.new(label))) if chrons.empty?

      # could be a global constraint with this label as the value
      roles << :value

      if measure = could_be_measure?
        roles << measure
      else
        roles << :measure
      end

      # any column could be a dimension
      roles << Dimension.new(:name => label || "Untitled")

      roles
    end

    def label
      @user_label || @label
    end

    def source_label
      @label
    end

    def label=(label)
      possible_roles.each { |role| role.name = label if role.respond_to?(:name=) }
      @user_label = label
    end

    def could_be_measure?
      num_numeric = cell_values.find_all {|v| !v.number.nil?}.size
      return false if num_numeric == 0 or num_numeric < @distinct_text_values.size/2

      true
      # measure = Measure.new(:name => label, :notes => source_column[:notes], :units => source_column[:units], :multiplier => source_column[:multiplier])
      # if source_column[:units].nil? && (@original_values.grep(/\.\d+/).size > 0) then
      #   # found a decimal point in the data (with some digits after it),
      #   # so this is probably a measure of something continuous, not discrete things
      #   # Economagic sources have integer values ending with a period.
      #   measure.units = Units::Continuous
      # end
      # measure
    end

    def could_be_dimension?
      distinct_text_values.size > 3
    end

    def possible_chron_roles
      counts_by_chron_type = Hash.new
      @cell_values.each { |v| v.chron.each {|chr| counts_by_chron_type[chr.class] ||= 0; counts_by_chron_type[chr.class] += 1} }

      # give up if there are no chron-like values
      return [] if counts_by_chron_type.empty?

      counts_by_chron_type = counts_by_chron_type.sort {|a,b| b[1]<=>a[1]}

      # give up if at least 75% of the values aren't chron-like
      # puts "Total values: #{@parsed_values.size}; chron matches: #{counts_by_chron_type.first.inspect}"
      counts_by_chron_type.find_all {|ct| ct[1] >= @cell_values.size * 0.75}.map {|ct| ct[0]}
    end

    def measure?
      @role.is_a?(Measure)
    end

    def chron?
      @role.class == Class && @role.to_s =~ /Chron::/
    end

    def ignore?
      @role == :ignore
    end

    def dimension?
      @role.is_a?(Dimension)
    end

    def summary
      @distinct_text_values.sort.join(',')
    end
    
    def role=(r)
      # puts "ROLE ASSIGNMENT: #{r.inspect}"
      @role = r
      if (r.is_a?(Measure)) then
        # if @original_values.grep(/\.\d+/).size > 0 then
        #   # found a decimal point in the data (with some digits after it),
        #   # so this is probably a measure of something continuous, not discrete things
        #   # Economagic sources have integer values ending with a period.
        #   r.units = Units::Continuous
        # end

        r.name = label if r.name.nil? && !label.nil?
      end
    end
  end

  class CellValue
    attr_reader :text, :number, :chron

    def initialize(v)
      @text = v
      @number = v.to_number unless v.nil?
      @chron = Array(Chron.new(v))  # list of one or more Chron instances; wrap it in an array if it isn't already an array
    end

    def chron?
      @chron.size > 0
    end
  end # class ParsedValue

  # ParseResults is a collection of statistics describing how the parsing process went.
  # number of rows in the raw source
  # number of data records in the output
  # number of header records
  # number of rows ignored (with reasons, and the rejected data for reference)
  # number of data columns in the raw source
  class ParseResults
    attr_accessor :nrows, :nrecords, :nheaders, :nignored
    attr_accessor :notes, :errors
    attr_reader :ncolumns

    def initialize(args)
      if args[:nrows]
        old_initialize(args)
      else
        @errors = []
        analyze(args[:data], args[:extractor])
      end
    end

    def old_initialize(args)
      @nrows = args[:nrows]
      @nrecords = args[:nrecords]
      @nheaders = args[:nheaders]
      @nignored = args[:nignored]
      @ncolumns = args[:ncolumns]
      @notes = args[:notes]
    end

    def analyze(data, extractor)
      find_errors(data)
      @nrows = extractor.data.size
      @ncolumns = data.columns.size
    end

    # scan the parsed data to find any problems that would prevent series generation
    # * duplicate keys (chron + dimensions)
    def find_errors(data)
      keys = Hash.new(0)
      columns = [data.chron_column, data.dimension_columns].flatten.compact
      allkeys = columns.map{|col| col.values}.transpose
      allkeys.each {|keylist| keys[keylist] += 1}
      duplicates = []
      keys.each_pair do |key, count|
        duplicates << key if count > 1
      end
      duplicates.each do |dup|
        @errors << "Duplicate entry in source for (#{dup.map {|key| key.to_s}.join(', ')})"
      end
    end

  end
end # module Dataset

if $0 == __FILE__
  require 'dataset'
  require "yaml"

  dissector = Dataset::Dissect.new(:input => $stdin)
  puts dissector.recipe.to_yaml
end
