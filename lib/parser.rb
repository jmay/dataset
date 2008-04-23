module Dataset
  class Parser
    attr_reader :source_text, :raw, :columns, :ncolumns, :measure
#     attr_accessor :chron_column #, :chron_list
    attr_reader :headers
#     attr_accessor :headers
    attr_reader :nrows #, :virtual_columns, :vcols
    attr_accessor :extractor, :dimension
    attr_reader :format

    def to_yaml_properties
      [ '@columns', '@measure', '@dimension', '@extractor' ]
    end

    def initialize(args)
      @extractor = args[:extractor]
      @measure = args[:measure]
      @dimension = args[:dimension]
      if args[:input] then
        @source_text = args[:input]
      else
        @source_text = nil
      end
      analyze(args[:source])
    end

    # process the source text and do our best to figure out what is it:
    # * pick an appropriate extractor
    # * identify columns & headers
    # * analyze the cell values
    # * set roles for the columns
    def analyze(source = nil)
      if source
        @format = source.content_type
        @source_text = source.text || source.raw
      # else
      #   @format = "text/plain"
      end
      # unless @format
      #   @format = @source_text.looks_like_csv? ? "csv" : "txt"
      # end

      return self if @source_text.nil?

      analyze_format if @extractor.nil?
      first_pass
      # raise "Unable to extract any numeric data from the source" if extractor.data.nil? || extractor.data.empty?
      if extractor.data && extractor.data.any?
        analyze_columns
      end
      self
    end

    def analyzed?
      ! @columns.nil? && ! @columns.empty? && ! @columns.find {|col| col.role.nil?}
    end

    def parse(source)
      @source_text = source.text || source.raw if source
      explode
      commit
    end

    def commit
      sd = SourceData.new(self, extractor)
#       sd = SourceData.new(@columns.find_all {|col| !col.ignore?}, @vcols)
#       sd = SourceData.new(@columns, :multiplier => extractor.multiplier, :units => extractor.units, :measure => measure)
      # the gsub below is a workaround for a YAML bug where round-tripping breaks for strings
      # with whitespace
      pr = ParseResults.new(:data => sd, :extractor => extractor)
      # pr = ParseResults.new(:nrows => @nrows, :nheaders => extractor.headers.size, :ncolumns => @columns.size,
      #   :nrecords => sd.records.size, :notes => extractor.notes.join($/).gsub(/^\s+/m,''))
      [sd, pr]
    end

    def chron
      # @chron_column.detail
      # @chron_columns.first[0].chron.first
      unless chron_columns.empty?
        chron_columns.first.role
      # elsif @chron_list then
      #   @chron_list.first.class
      end
    end

    # in the first pass, we:
    # * figure out the file format: CSV, TSV, monospace, etc.
    # * break up the rows & columns into individual cells
    # * line things up; deal with varying column counts
    def first_pass
#       analyze_format if @extractor.nil?
      explode
      if extractor.data
        @ncolumns = count_columns
        # @columns = extractor.columns.map { |col| ParserColumn.new(:source_column => col)}
        @columns = (0..@ncolumns-1).map { |i| ParserColumn.new(:source_column => extractor.columns[i]) }
#         @columns = Array.new(@ncolumns) { ParserColumn.new }
      end
    end

    # Only called if an extractor has not been explicitly specified to that Parser constructor
    # Tries to guess at the right extractor.
    def analyze_format
      test_extractor = Extractor.choose(format, @source_text)
      # klass = case format
      # when /html/
      #   Extractor::HTMLExtractor
      # when /csv/
      #   Extractor::CSVExtractor
      # else
      #   Extractor::WhitespaceExtractor
      # end
      # 
      # test_extractor = klass.new
      test_extractor.run(@source_text)
      nheaders = 0
      if test_extractor.data
        test_extractor.data.each do |row|
          break unless is_header?(row)
          nheaders += 1
        end
        test_extractor.headerlines = nheaders
      end
      @extractor = test_extractor
    end

    # build up list of records, with fields delimited by whitespace
    # ignore blank lines
    def explode
      extractor.run(@source_text)
      if extractor.data
        @raw = extractor.data
        @headers = extractor.headers
        @nrows = @raw.size
      end
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

    # figure out how many columns in the input
    # there could be variation, esp. when the headers use a different delimiter
    # there ought to be one column-count guess that is dominant; use that one
    # if there isn't a clear "winner", give up.
    def count_columns
      return 0 if @raw.empty?

      column_counts = Hash.new(0)
      @raw.each { |cols| column_counts[cols.size] += 1 }
      if column_counts.values.max < @raw.size/2
        raise "Discrepancy in the column counts (#{column_counts.keys.sort.join(' vs ')}), giving up"
      end

      column_counts.sort {|a,b| b[1]<=>a[1]}.first[0]
    end

    # build up a data structure for each column
    # does the column contain numeric data?
    def analyze_columns
      @columns.each {|col| col.clear}
      ncols = @columns.size
      # @columns = Array.new(@ncolumns) { ParserColumn.new }

      # feed any header text into the ParserColumns, in case it's useful
      @columns.each_with_index do |col,i|
        col.add_header(extractor.columns[i][:label] || extractor.headers[i])
        col.notes = extractor.columns[i][:notes]
        col.constraints = extractor.columns[i][:constraints] || extractor.constraints || {}
      end

      unless extractor.data.empty?
        # extractor has the data as an array of rows
        # ...turn it into an array of columns
        transposition = extractor.data[0].zip(*extractor.data[1..-1])
        # extractor.data.transpose.each_with_index do |values, colnum|
        transposition.each_with_index do |values, colnum|
#           @columns[colnum].concat(values.map {|v| v.to_s}) if colnum < ncols
          @columns[colnum].concat(values) if colnum < ncols
        end
      end

      # digest the values for each ParserColumn
      @columns.each {|c| c.crunch}

      assign_column_roles

      if ! @columns.any? {|col| col.measure? || col.role == :measure}
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

      if col.distinct_text_values.size <= 2 && @nrows > 20
        return :ignore
      end

      chronRoles = roles.find_all {|role| role.respond_to?(:label)}
      if !chronRoles.empty?
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
      @columns.find_all {|col| col.measure?}
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
  class ParserColumn
    # attr_accessor :active
    attr_reader :distinct_text_values, :role, :possible_roles
    attr_reader :headers, :user_label
    attr_accessor :notes, :constraints

    def to_yaml_properties
#       [ '@multiplier', '@role', '@label' ]
      [ '@role', '@label', '@user_label', '@possible_roles', '@source_column', '@constraints' ]
    end

    def initialize(args)
      @source_column = args[:source_column]
      @original_values = []
      @possible_roles = nil
      @user_label = @label = nil
#       @active = false
#       @multiplier = :ones
    end

    # def constraints
    #   @constraints ||= {}
    # end

    def source_column
      @source_column || {}
    end

    # def multiplier
    #   unless @multiplier
    #     @multiplier = :ones if measure?
    #   end
    #   @multiplier
    # end
    # 
    # def multiplier=(mult)
    #   raise "Multipliers are meaningful only for measures" unless measure?
    #   @multiplier = mult
    # end

    def add_header(header)
      return unless header
      if @label
        @label += " " + header.to_s
      else
        @label = header.to_s
      end
    end

    def <<(value)
      # kill leading and trailing whitespace
      @original_values ||= []
      value = "" if value.nil?
      @original_values << value.gsub(/^\s+/, '').gsub(/\s+$/, '')
      # eventually, do some of the data analysis as each value comes in?
    end

    def concat(values)
      @original_values ||= []
      @original_values.concat(values)
    end

    def clear
      @original_values = []
      @label = nil
    end

    def analyze_value(v)
      case v
      when String
        ParsedValue.new(v)
      when nil
        ParsedValue.new(nil)
      else
        v
      end
    end

    # figure out all the possible roles of this column
    def crunch
      # 1. clean up all the values
      @parsed_values = @original_values.sample.map {|v| analyze_value(v)}
      # 2. distinct values
#       @distinct_numeric_values = @parsed_values.map {|v| v.number}.compact.uniq
#       @distinct_non_numeric_values = @parsed_values.map {|v| v.text if v.number.nil?}.compact.uniq
      @distinct_text_values = @parsed_values.map {|v| v.respond_to?(:text) ? v.text : ""}.compact.uniq
      # 3. chron analysis
#       @distinct_chrons = @parsed_values.map {|v| v.chron}.flatten.uniq.compact
      # 4. char-count analysis (to look for ZIP codes, state abbreviations, other code-like things)
#       @distinct_char_counts = @parsed_values.map {|v| v.text}.compact.map {|v| v.length}.uniq

#       @label = headers.join(' ') if headers
      @possible_roles = find_possible_roles
      self
    end

    # def possible_roles
    #   return nil if @possible_roles.nil? && values.nil?
    #   @possible_roles ||= find_possible_roles
    # end

    def find_possible_roles
      if source_column[:role]
        return [source_column[:role]]
      end

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

    def values
      @parsed_values
    end

    def [](i)
      @parsed_values[i]
    end

    # scrub input values
    # ASSUMPTION: all leading & trailing whitespace has already been removed
    # if the value looks numeric, then turn it into a Numeric
    # spot things like "n/a", "-" etc. that look like blank values, and turn them into nils
    def cleanup(v)
      if v =~ /^\-?\d+/ then
        # ISSUE: this will recognize the number 123 for the value "1,2,3"
        # That might be OK.  A value like that is probably a footnote reference or something,
        # and is likely to be an ignored column.
        # But what if there is a column that includes multiple comma-separated ZIP code values?
        # "94012,94123" will be treated as the number 9401294023.
        # Deal with this only if it ever arises as a problem.
        v.gsub(/,/,'').to_f
      else
        v
      end
    end

    # Every non-null value is numeric
    # def all_values_numeric?
    #   @distinct_non_numeric_values.size == 0
    # end

    def could_be_measure?
      num_numeric = @parsed_values.find_all {|v| !v.number.nil?}.size
      return false if num_numeric == 0 or num_numeric < @distinct_text_values.size/2

      measure = Measure.new(:name => label, :notes => source_column[:notes], :units => source_column[:units], :multiplier => source_column[:multiplier])
      if source_column[:units].nil? && (@original_values.grep(/\.\d+/).size > 0) then
        # found a decimal point in the data (with some digits after it),
        # so this is probably a measure of something continuous, not discrete things
        # Economagic sources have integer values ending with a period.
        measure.units = Units::Continuous
      end
      measure
    end

    # def any_numeric_values?
    #   @distinct_numeric_values.size > 0
    # end
    # 
    # # are all of the values non-numeric?
    # def text_only?
    #   @distinct_numeric_values.size == 0
    # end

    # A column could be a chron if all of the values are non-nil and all are
    # resolvable to a single unambiguous chron type.
    #
    # 070125: needs to be smarter than this.  e.g. for the budget source where there's a "TQ"
    # row hidden in there.  We want to recognize that the column is Years, with a funky record in there.
    # How about: Find the Chron that represents the majority of the rows, and use that; then when pulling
    # out the data we ignore every row that doesn't match that Chron.
    # Need to put the ignored values somewhere, so we can tell the user what's going on.
    def possible_chron_roles
      counts_by_chron_type = Hash.new
      # p @parsed_values[0..9]
      @parsed_values.each { |v| v.chron.each {|chr| counts_by_chron_type[chr.class] ||= 0; counts_by_chron_type[chr.class] += 1} }

      # give up if there are no chron-like values
      return [] if counts_by_chron_type.empty?

      # p counts_by_chron_type

      counts_by_chron_type = counts_by_chron_type.sort {|a,b| b[1]<=>a[1]}

      # give up if at least 75% of the values aren't chron-like
      # puts "Total values: #{@parsed_values.size}; chron matches: #{counts_by_chron_type.first.inspect}"
      counts_by_chron_type.find_all {|ct| ct[1] >= @parsed_values.size * 0.75}.map {|ct| ct[0]}
      # return [] if (counts_by_chron_type.first[1] < @parsed_values.size * 0.75)
      # 
      # # respond with the chosen chron type
      # p counts_by_chron_type
      # return counts_by_chron_type.map {|x| x[0]}

      # return false if counts_by_chron_type.values.max != @parsed_values.size
      # rows_with_unique_chron = non_chron_rows = 0
      # @parsed_values.each do |v|
      #   non_chron_rows += 1 if v.chron.size == 0
      #   rows_with_unique_chron += 1 if v.chron.size == 1
      # end
      # return false if non_chron_rows > 5 # some low number, or low percentage of the total
      # # rows_with_unique_chron > @parsed_values.size/2
      # true
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

    # def active?
    #   @active
    # end

    def summary
      @distinct_text_values.sort.join(',')
    end
    
    def inspect
      "\nRole: #{@role.inspect}\n" +
      (label ? "Label: #{label}" : "(unlabelled)") +
#       (measure? ? " in #{multiplier}" : "") +
      "\n"
      # "=== COLUMN DATA ===\n" +
      # (@parsed_values ? @parsed_values[0..9].inspect : "(none)")
      # @parsed_values.each { |v| sprintf("%-20s %-20s %-20s\n", v.text, v.number.nil? ? "(nil)" : v.number.to_s, v.chron) }.join("\n")
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

  class ParsedValue
    attr_reader :text, :number, :chron

    def initialize(v)
      @text = v
      @number = v.to_number unless v.nil?
      @chron = Array(Chron.new(v))  # list of one or more Chron instances; wrap it in an array if it isn't already an array
      # case @chron
      # when nil
      #   @chron = []
      # when Chron::Base
      #   @chron = [@chron]
      # end
#       @chron = [@chron] unless @chron.is_a?(Array)
    end

    # # scrub input values
    # # ASSUMPTION: all leading & trailing whitespace has already been removed
    # # if the value looks numeric, then turn it into a Numeric
    # # spot things like "n/a", "-" etc. that look like blank values, and turn them into nils
    # def to_number(v)
    #   if v =~ /^\-?\d+/ then
    #     # ISSUE: this will recognize the number 123 for the value "1,2,3"
    #     # That might be OK.  A value like that is probably a footnote reference or something,
    #     # and is likely to be an ignored column.
    #     # But what if there is a column that includes multiple comma-separated ZIP code values?
    #     # "94012,94123" will be treated as the number 9401294023.
    #     # Deal with this only if it ever arises as a problem.
    #     v.gsub(/,/,'').to_f
    #   else
    #     nil
    #   end
    # end

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

    def inspect
          <<_EOT_
Total source rows: #{@nrows}
Header records: #{@nheaders}
Data records: #{@nrecords}
Data columns: #{@ncolumns}
_EOT_
    end
  end

  # SourceData is the "clean" output from applying a Parser to a Source.
  # It consists of typed columns, where all the data values match the column type.
  class SourceData
    attr_accessor :columns, :measure, :dimension, :constraints
#     attr_reader :measure_columns

    def to_yaml_properties
      [ '@columns', '@measure', '@dimension', '@constraints' ]
    end

    def initialize(parser, extractor)
      @columns = []
      parser.columns.each_with_index do |col, i|
        @columns << DataColumn.new(parser, extractor, i)
      end
      @measure = parser.measure
      @dimension = parser.dimension
      @constraints = extractor.constraints
    end

    def old_initialize(columns, args = {})
      @columns = columns.map {|col| DataColumn.new(col, :units => args[:units], :multiplier => args[:multiplier])}

      @records = nil
      # @chron_columns = @columns.find_all {|col| col.chron?}
      # @measure_columns = @columns.find_all {|col| col.measure?}
      # @dimension_columns = @columns.find_all {|col| col.dimension?}
      @measure = args[:measure]
    end

    def chron_columns
      @columns.find_all {|col| col.chron?}
    end

    def measure_columns
      @columns.find_all {|col| col.measure?}
    end

    def dimensionality
      dims = @columns.find_all {|col| col.dimension?}.map {|c| c.role}
      dims << dimension if dimension
      dims
    end

    def dimension_columns
      @columns.find_all {|col| col.dimension?}
    end

    def dimension_value_columns
      @columns.find_all {|col| col.role == :value}
    end

    def measure_dimension_column
      @columns.find {|col| col.role == :measure}
    end

    def chron_data_columns
      @columns.find_all {|col| col.role.is_a?(Chron::Base)}
    end

    def row_has_data?(rownum)
      chron_data_columns.find_all {|col| !col.values[rownum].nil?}.size > 0
    end

    def measures
      if measure_dimension_column
        measure_dimension_column.values.map_with_index {|measure, i| row_has_data?(i) ? measure : nil}.compact
      elsif measure_columns.any?
        measure_columns.map {|col| col.role}
      else
        @measure ? [@measure] : nil
      end
    end

    def measure_row(measure)
      return nil unless mdcol = measure_dimension_column
      mdcol.values.each_with_index do |meas, i|
        return i if meas.name == measure
      end
      # didn't find it
      nil
    end

    def inspect
      "Data Columns: #{@columns.size}\n" +
      @columns.inspect + "\n"
#       <<_EOT_
# Data Columns: #{@columns.size + @vcols.size}
# #{@columns.inspect}
# #{@vcols.inspect}
# _EOT_
    end

    def records
      unless @columns.empty?
        @records ||= @columns.map {|col| col.values}.parallel
      else
        @records = []
      end
    end

    def clean_for_series?
      # TODO: error handling for ambiguity:
      #  raise if no :chron parameter provided and there are multiple chron columns
      #  raise if no :measure param provided and there are multiple measure columns

      # return false if duplicate_keys?
      true
    end

    def spanning_role
      roles = columns.find_all {|col| col.role != :ignore && !col.chron?}.map {|col| col.role}
      # roles.delete(:ignore)
      # roles.delete_if { |role| role.chron? }
      role_classes = roles.map { |role| role.class }.uniq
      nil if role_classes.size != 1
      role_classes.first
    end

    def chron
      if spanning_role &&
        (spanning_role.superclass == Chron::Base) &&
        (chron_columns.size == 1)
        return Chron.combine(spanning_role, chron_columns.first.role)
      end

      case chron_columns.size
      when 1
        chron_columns.first.role
      when 0
        chrons = chron_data_columns.map {|col| col.role.class}.uniq
        case chrons.size
        when 0
          nil
        when 1
          chrons.first
        else
          chrons
        end
      else
        Chron.combine(chron_columns.map {|col| col.role})
      end
    end

    def chrons
      if col = chron_column
        col.values
      else
        chron_data_columns.map {|col| col.role}
      end
    end

    def chron_column
      @chron_column ||= case chron_columns.size
      when 1
        chron_columns.first
      when 0
        nil
      else
#         ccol = ChronColumn.new
        chrons = chron_columns.map{|col| col.values}.parallel.map { |ar| Chron.new(ar) }
#         p chrons
        DataColumn.new(:role => chron, :values => chrons)
        # raise "foo!"
        # newchrons = chrons.map {|c| puts c; Chron.new(c)}
        # p newchrons
        # chrons = @chron_columns
        # Chron.combine(@chron_columns.map {|col| col.role})
      end
    end
    # def chronval(row)
    #   case @chron_columns.size
    #   when 1
    #     @chron_column[row]
    #   when 0
    #     nil
    #   else
    #     c = Chron.new(@chron_columns.map {|col| col[row].chron}.parallel)
    #     p c
    #   end
    # end

    # generate stub Series (constructed, but no data) for all the measures in the source
    def all_series
      measures.map do |measure|
        Series.new(:chron => chron, :measure => measure, :dimensions => dimension_columns.map { |col| col.role.name })
      end
    end

    # generate a single series from this data
    # if there is any ambiguity in which chron or measure column to use, specify with
    # make_series(:chron => chron_column, :measure => measure_column)
    def make_series(args = {})
      clean_for_series?

#       chron_column = args[:chron] || @chron_columns.first

      if !args[:measure]
        # no measure specified; if there's only one to choose, use that as the default
        # if there are several to choose between, force the user to be explicit
        if @measure
          return series_for_explicit_measure
        elsif measure_columns.size == 1
          return series_from_column(measure_columns.first)
        elsif measure_dimension_column && (measure_dimension_column.values.size == 1)
          return series_from_row(0)
        else
          raise "You must specify one of the #{measures.size} measures"
        end
      end

      if measure_column = measure_columns.find {|col| col.role.name == args[:measure]}
#         raise "Can't make a series with an unspecified measure" if measure_column.role.unspecified?
        return series_from_column(measure_column)
      end

      if rownum = measure_row(args[:measure])
        return series_from_row(rownum)
      end

      if @measure && @measure.name == args[:measure]
        return series_for_explicit_measure
      end

      raise "Can't understand what measure you want: #{args[:measure]}"
    end

    def series_from_column(measure_column)
      series = Series.new(
        :chron => chron, #chron_column.role,
        :dimensions => dimension_columns.map { |col| col.role.name },
        :measure => measure_column.role)

#       rows = [chron_column, @dimension_columns, measure_column].flatten.map{|col| col.values}.parallel
      columns = [chron_column, dimension_columns, measure_column].compact
      rows = columns.flatten.map{|col| col.values}.parallel.find_all {|row| !row.first.nil? && !row.last.nil?}
      series.add(*rows)
      series.constraints = measure_column.constraints
      series.commit
    end

    def series_from_row(measure_row)
      series = Series.new(
        :chron => chron,
        :measure => measure_dimension_column.values[measure_row])

      chron_data_columns.each do |col|
        v = col.values[measure_row]
        next if v.nil?
        if v.is_a?(String)
          v = v.to_number 
          next if v.nil?
        end
        series.add([col.role, v])
      end

      series.constraints = constraints
      series.commit
    end

    def flatten_columns
      rows = []

      if chron_data_columns.any?
        if chron_column
          # chrons are both in columns and rows, need to merge them
          chron_column.values.each_with_index do |c1, rownum|
            next if c1.nil?
            chron_data_columns.each do |c2col|
              row = [ Chron.new(c1, c2col.role), c2col.values[rownum] ]
              rows << row
            end
          end
        else
          # chrons across the columns
          chron_data_columns.each do |col|
            col.values.each_with_index do |v, i|
              row = []
              row << col.role
              dimension_columns.each do |dcol|
                row << dcol.values[i]
              end
              row << v #@measure.instance(v)
              rows << row
            end
          end
        end
      end

      # if there is a dimension across the columns...
      dimension_value_columns.each do |col|
        col.values.each_with_index do |v, i|
          row = []
          if chron_column
            next if chron_column.values[i].nil? # ignore garbage row
            row << chron_column.values[i]
          end
          dimension_columns.each do |dcol|
            row << dcol.values[i]
          end
          row << col.label
          row << v
          rows << row
        end
      end

      rows
    end

    def series_for_explicit_measure
      series = Series.new(
        :chron => chron,
        :dimensions => dimensionality.map {|dim| dim.name},
        :measure => @measure)
      series.add(*flatten_columns)
      series.constraints = constraints
      series.commit
    end

  end # class SourceData

  class ChronColumn
    attr_reader :values
    def initialize(values)
      @values = values
    end
  end

  class DataColumn
    attr_reader :role, :values, :label, :constraints
#     attr_reader :multiplier # only valid for measure columns

    def initialize(*args)
      case args[0]
      when Hash
        initialize_explicit(args[0][:role], args[0][:values])
      else
        initialize_from_parser(*args)
      end
    end

    def initialize_explicit(role, values)
      @role = role
      @values = values
    end

    def value_to_measure(v, extractor)
      return v if v.is_a?(Measure)
      Measure.new(:name => v, :units => extractor.units || Units::Continuous, :multiplier => extractor.multiplier)
    end

    def initialize_from_parser(parser, extractor, colnum)
      @role = parser.columns[colnum].role
      @label = parser.columns[colnum].label
      # missing values could be nil, not ""
      text_values = extractor.data.map {|row| row[colnum] }
      case @role
      when Class
        case @role.to_s
        when /Chron::/
          # if you try to coerce a value to a Chron that doesn't recognize it,
          # put a nil there
          @values = text_values.map {|v| @role.new(v) rescue nil}
        else
          raise "Unrecognized column role #{@role.inspect} for column #{colnum}"
        end
      when Chron::Base
        # all the values in the column are for some specific chron value
        @values = text_values.map {|v| v && v.to_number}
      when Measure
        # any nils should remain as such, don't convert them to zeroes
        @values = text_values.map {|v| v && v.to_number}
        @constraints = parser.columns[colnum].constraints || {}
      when :measure
        # this column specifies the measure for all the numbers in the row
        @values = text_values.map {|v| value_to_measure(v, extractor)}
      when Dimension
        @values = text_values
      when :ignore
        # even for ignored columns we leave the values there for viewing in preview
        @values = text_values
      when :value
        @values = text_values.map {|v| v && v.to_number}
      else
        raise "Unrecognized column role #{@role.inspect} for column #{colnum}"
      end
    end

    def old_initialize(arg, params = {})
      case arg
      when ParserColumn
        parser_column = arg
        @role = parser_column.role
        case @role
        when Class
          case @role.to_s
          when /Chron::/
            # make sure you get the right chron values; since there could be ambiguity in the source,
            # there might be multiple alternative chrons; @role specifies which chron type we're using.
            @values = parser_column.values.map {|v| v.chron.find {|c| c.class == @role}}
          else
            raise "Unrecognized column role #{@role}"
          end
        when Measure
          # puts "Measure column like #{@role.inspect}"
          @values = parser_column.values.map {|v| v.number}
#           @multiplier = parser_column.multiplier
        when :measure
          # this column specifies the measure for all the numbers in the row
          @values = parser_column.values.map {|v| Measure.new(:name => v.text, :units => params[:units] || Units::Continuous, :multiplier => params[:multiplier])}
        when Dimension
          @values = parser_column.values.map {|v| v.text}
        else
          # this column probably has a chron at the top
          @values = parser_column.values.map {|v| v.text}
        end
      when Hash
        @role = arg[:role]
        @values = arg[:values]
#         @multipler = arg[:multiplier] if arg[:multiplier]
      else
        raise "unable to create column with #{arg}"
      end
    end

    def chron?
      # puts "Checking role #{@role}"
      # puts "It's a class" if @role.class == Class
      # puts "yep" if @role.class == Class && @role.to_s =~ /Chron::/
      @role.class == Class && @role.to_s =~ /Chron::/
#       @role.is_a?(Chron::Base)
    end

    def measure?
      @role.is_a?(Measure)
    end

    def dimension?
      @role.is_a?(Dimension)
    end

    def inspect
      "\nRole: " +
      @role.inspect + "\n" +
#       (measure? ? " (in #{multiplier})" : "") +
      (constraints ? "Constraints: #{constraints.inspect}" : "") + "\n" +
      "Values: #{@values[0..10].inspect}\n"
    end

    def distinct_text_values
      values.compact.sort.uniq
    end
  end # class DataColumn

end # module Dataset
