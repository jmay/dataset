# require "generator" # used for iterating across multiple series in parallel for set arithmetic
require "csv"

module Dataset
  class Series
    attr_accessor :chron, :dimensions, :measure
    attr_writer :constraints
    attr_reader :data, :errors

    def to_yaml_properties
      [ '@chron', '@dimensions', '@measure', '@constraints',
        '@data', '@errors' ]
    end

    # for backwards compatibility: no constraints means empty constraints, so that ops like empty?
    # will work even for an old series that doesn't have the attribute in the YAML source
    def constraints
      @constraints ||= {}
    end

    def initialize(args = {}) #chron, measure, dimensions = [])
      @chron = args.include?(:chron) ? args[:chron] : Chron::YYYY
      # @measure = args[:measure] || Measure::Units
      @measure = args[:measure] || Measure.new(:multiplier => args[:multiplier])
      # empty list of dimensions if none are specified (dimensions.size == 0)
      # dimensions should all be symbols
      @dimensions = args[:dimensions] ? args[:dimensions].map {|dname| Dimension.new(:name => dname)} : []
      @constraints = args[:constraints] || {}
#       @multiplier = args[:multiplier] || :ones
      @data = Array.new
      @keys = {}
      @errors = []
    end

    # pass in list of one or more records
    # each record is an array [ :chron, optional dimensions, :measure ]
    # series.add([1990, 27])
    # series.add([1990, 27], [1991, 104])
    # series.add([1990, 27])
    def add(*rows)
      rows.each do |row|
        entry = {}
        keys = []
        if @chron then
          entry[:chron] = case row.first
          when Chron::Base
            raise "Chron mismatch: #{row.first.class} vs #{@chron}" if row.first.class != @chron
            row.first
          else
            # if this presumed chron value doesn't match the chron type, then assume that this
            # record is invalid, and SILENTLY ignore it.  Probably some sort of junk (like a subtotal,
            # or whitespace, or extraneous commentary) without data.
            @chron.new(row.first) rescue next
          end
          keys << entry[:chron]
          @dimensions.each_with_index { |dim, i| keys << row[i+1]; entry[dim] = row[i+1] }
        else
          @dimensions.each_with_index { |dim, i| keys << row[i]; entry[dim] = row[i] }
        end
        k = keys.join(";")
        # raise "Duplicate entry in input for key '#{k.split(';')}'" if @keys.key?(k)
        if @keys.key?(k)
          @errors << "Duplicate entry in input for key '#{k.split(';')}'"
          next
        end
        @keys[k] = 1
        if row.last.is_a?(Measure)
#           entry[:measure] = row.last
          entry[:measure] = row.last.value
        else
#           entry[:measure] = @measure.instance(row.last)
          entry[:measure] = row.last.to_f
        end
        @data << entry
      end
      self
    end

    def commit
      if chron
        # by default, sort with most-recent data first
        @data.sort! {|a, b| b[:chron].value <=> a[:chron].value}
      else
        # larger measure value first
        @data.sort! {|a, b| b[:measure] <=> a[:measure] }
      end
      analyze_dimensions
#       hashme
      self
    end

    def analyze_dimensions
      dimensions.each do |dim|
        dimvals = {}
        data.map {|e| dimvals[e[dim]] = 1}
        dim.values = dimvals.keys.compact.sort
      end
    end

    def hashdata
      @hashdata ||= hashme
    end

    def hashme
      raise "can't hash a data series without a chron" if chron.nil?
      h = {}#SeriesHash.new
      data.map {|e| h[e[:chron]] = e[:measure]}
      h
    end

    def chrons
      @chrons ||= @data.map { |e| e[:chron] }
    end

    def max_measure
      data.max { |a, b| a[:measure] <=> b[:measure] }[:measure]
    end

    def [](chron)
      raise TypeError, "Expected #{self.chron}, not #{chron.class}" unless chron.class == self.chron
      if dimensions.any?
        # return all the entries with the matching chron
        data.find_all { |e| e[:chron] == chron }
      else
        # no category dimensions, so return just one entry if it exists
        data.find { |e| e[:chron] == chron }
      end
    end

    # determine whether #diffs (absolute changes operation) is permitted for this series
    # looks at the chron
    def can_diffs?(diffs_chron)
      return false if chron.nil? # no diffs if there's no chron dimension
      return false if !dimensions.empty? # TODO (compute changes for each distinct dimension value)
      return false if chron == Chron::YYMMDD # TODO
      return false unless self.chron == diffs_chron || self.chron.descendant_of?(diffs_chron)
      true
    end

    # determine whether #deltas is permitted for this series
    # identical logic to #can_diff?, at least for now
    # TODO LATER: possibly look at the measure as well (e.g. might not make sense to compute
    # % change for series already in percent units, but the logic probably needs to be more
    # sophisticated than that)
    def can_deltas?(deltas_chron)
      can_diffs?(deltas_chron)
    end

    # assumes that #can_diff? is true for this series; behavior for can_diff? == false
    # is undefined (probably will raise an exception somewhere)
    def diffs(diffs_chron = chron)
      diffs = []
      data.each do |e|
        prev_chron = e[:chron].prev(diffs_chron)
        # silently ignore any data elements that don't have a "previous" value,
        # e.g. for a series with gaps in the chron sequence
        if previous = self[prev_chron] then
#           diffs << [ e[:chron], e[:measure].value - self[prev_chron].value ]
          diffs << [ e[:chron], e[:measure] - previous[:measure] ]
        end
      end
      diff_series = Series.new(:chron => self.chron, :measure => self.measure.diff)
      diff_series.add(*diffs)
      diff_series.commit
    end

    # compute series of percentage deltas
    # if there's a zero value (probably indicates an error in the source),
    # just omit the corresponding value from the output series.
    # So we'll probably get a -100% value following by a hole in the sequence.
    # This follows the principle of trying to make most things work most of the time.
    # assumes that #can_delta? is true for this series
    def deltas(delta_chron = chron)
      diffs = []
      data.each do |e|
        prev_chron = e[:chron].prev(delta_chron)
        if previous = self[prev_chron] then
#           prev_value = self[prev_chron].value
          prev_value = previous[:measure]
#           raise "Can't compute percentage change from zero value" if prev_value == 0.0
          unless prev_value == 0.0
#             diffs << [ e[:chron].value, (e[:measure].value.to_f - prev_value) / prev_value * 100 ]
            diffs << [ e[:chron].value, (e[:measure].to_f - prev_value) / prev_value * 100 ]
          end
        end
      end
      diff_series = Series.new(:chron => self.chron, :measure => self.measure.delta)
      diff_series.add(*diffs)
      diff_series.commit
    end

    def baseline(chron)
      raise "Type mismatch for baseline: got #{chron.class}, expected #{self.chron}" unless chron.class == self.chron
#       base_value = data.find {|e| e[:chron] == chron}[:measure].value
      base_value = data.find {|e| e[:chron] == chron}[:measure]
      raise "Unable to baseline: no series value for #{chron.value}" if base_value.nil?

      new_data = data.map do |e|
#         [ e[:chron].value, (e[:measure].value.to_f / base_value) * 100 ]
        [ e[:chron].value, (e[:measure].to_f / base_value) * 100 ]
      end

      new_measure = Measure.new(:name => "#{measure.name} (baseline at #{chron.to_s}=100)", :units => Units::Percentage)
      s2 = Series.new(:chron => self.chron, :measure => new_measure)
      s2.add(*new_data)
      s2.commit
    end

    def ratio(s2)
      raise "Chron mismatch for ratio: #{self.chron} vs #{s2.chron}" unless self.chron == s2.chron
      overlapping_chrons = self.chrons & s2.chrons
      new_data = overlapping_chrons.map do |c|
#         [ c, self.hashdata[c].value.to_f / s2.hashdata[c].value ]
        [ c, self.hashdata[c].to_f / s2.hashdata[c] ]
      end

      # what's the measure of the new series?
      if self.measure.units == s2.measure.units then
        # dollars/dollars = percentage
        new_measure = Measure.new(:units => Units::Percentage)
      else
        # dollars/people = dollars; use the same measure as the original (numerator) series
        new_measure = Measure.new(:name => "#{self.measure.name} / #{s2.measure.name}", :units => self.measure.units)
      end
      s3 = Series.new(:chron => self.chron, :measure => new_measure)
      s3.add(*new_data)
      s3.commit
    end

    def range(t0 = nil, t1 = nil)
      raise "Range not available for series without chron" if self.chron.nil?
      raise "Range not specified" if t0.nil? && t1.nil?
      if (t0 && t0.class != chron) || (t1 && t1.class != chron)
        raise TypeError, "Invalid chron for range"
      end
      s2 = Series.new(:chron => self.chron, :measure => self.measure)
      t0 = chrons.min if t0.nil?
      t1 = chrons.max if t1.nil?
      range_data = self.data.find_all {|e| e[:chron] >= t0 && e[:chron] <= t1}
      s2.data = range_data
      s2.commit
    end

    def units=(newUnits)
      self.measure.units = newUnits
#       self.data.each { |e| e[:measure] = newUnits.new(e[:measure].value) }
    end

    def gaps?
      gaps = {}
      data.map {|e| e[:chron]}.inject do |c1, c2|
        gaps[c2.value - c1.value] = 1
        c1 = c2
      end
      gaps.size == 1 ? false : true
    end

    # extract a subset from a series based on dimension=value
    # eliminates that dimension column from the new series
    def extract(args)
      dim = dimensions[args[:dimension]]
      raise "Invalid dimension specification" unless dim && args[:dimension] >= 0

      # pull out all the records that match the criteria, and remove the extracted dimension
      # field from each data item
      matches = data.find_all {|e| e[dim] == args[:value]}.map {|h| h.reject {|k,v| k == dim}}
      raise "There is no '#{dim.name}' = '#{args[:value]}' in the source data" if matches.empty?

      new_series = Series.new(:chron => self.chron, :measure => self.measure)
      new_series.dimensions = self.dimensions - [dim]
      new_series.constraints[dim.name] = args[:value]
      # new_series.measure.notes = "#{dim.name} = #{args[:value]}"
      new_series.data = matches
      new_series.commit
    end

    # construct a new series from the original, adjusting for a new multiplier
    def adjust_multiplier(new_multiplier)
      # puts measure.multiplier
      # puts new_multiplier
      adjustment = 1.0.send(new_multiplier) / 1.send(measure.multiplier)
      # deep copy the original series so it isn't altered
      new_series = Marshal::load(Marshal.dump(self))
#       new_series.data.each {|e| e[:measure] = self.measure.instance(e[:measure].value.to_f / adjustment)}
      new_series.data.each {|e| e[:measure] = e[:measure].to_f / adjustment}
      new_series.measure.multiplier = new_multiplier
      new_series
    end

    def format(value, hints = {})
      measure.format(value, hints)
#       measure.format(value, hints || format_hints)
    end

    # # override the default formatting of measure values
    # def format_hints
    #   @format_hints || default_format_hints
    # end
    # 
    # def default_format_hints
    #   if measure.units == Units::Percentage
    #     data.map {|e| e[:measure]}.map {|n| n.to_f % 1.0}
    #   end
    # end

    def operations
      ops = []
      # diffs & deltas operations (monthly, annual) require & depend on the chron
      ops.concat(chron.operations) if chron
      # baseline
#       ops << {:method => :baseline, :label => "Baseline"}
      # range
      # if chron
      #   ops << {:method => :range, :label => "Time Range"}
      # end

      ops
    end

    def csv
      lines = []

      header = []
      header << @chron.label if @chron
      @dimensions.each { |dim| header << dim.name }
      header << @measure.name
      lines << CSV.generate_line(header)

      data.each do |datum|
        row = []
        row << datum[:chron] if @chron
        @dimensions.each { |dim| row << datum[dim] }
        row << datum[:measure]
        lines << CSV.generate_line(row)
      end
      lines.join($/)
    end
    
    def to_ext_json(dataLimit = PreviewTableLimit)
      {:data => data_to_json(dataLimit), :dataModel => data_model_to_json, :columnModel => column_model_to_json}.to_json
    end    
    
    def data_to_json(limit)
    limit = !limit ? self.data.length : (limit-1)      
      self.data[0..limit].map do |row| 
        row_to_ext_json(row)
      end     
    end
    
    def row_to_ext_json(datum)
      cells = []
      cells << "#{datum[:chron].to_s}" if datum[:chron]
      self.dimensions.each { |dim| cells << "#{datum[dim]}" }
      cells << "#{self.measure.format(datum[:measure])}"
      cells
    end
    
    def data_model_to_json
      cells = []
      cells << { :name => "chron" } if self.chron
      self.dimensions.each_with_index { |dim, i| cells << {:name => "dim#{i}"} }
      cells << { :name => "measure" }
      cells
    end

    def column_model_to_json
      cols = []
      if self.chron
        hash = {
          :header => self.chron.label,
          :sortable => true,
          :dataIndex => 'chron',
          :resizable => false }
        cols << hash
      end

      self.dimensions.each_with_index do |dim, i|
        hash = {
          :id => "dim#{i}",
          :header => dim.name,
          :sortable => true,
          :dataIndex => "dim#{i}",
          :resizable => false }
        cols << hash
      end

      hash = {
        :id => 'measure',
        :header => self.measure.name,
        :sortable => true,
        :dataIndex => 'measure',
        :resizable => false }
      cols << hash
      cols
    end
    
    protected
    def data=(rows)
      @data = rows
    end
  end

  class SeriesHash < Hash
    def initialize(*args)
      super
    end

    alias oldGet []
    def [](index)
      if index.is_a?(Chron::Base) then
        oldGet(index.value)
      else
        oldGet(index)
      end
    end
  end

end
