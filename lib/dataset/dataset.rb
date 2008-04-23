require "rubygems"
require 'digest/sha1'
require "uuidtools"
require "yaml"

module Dataset
  class Dataset
#     include Caching

    attr_accessor :name
    attr_accessor :source, :dimensions, :series
    # attr_reader :source_uuid

    def initialize(args = {})
      # super
      @title = args[:title]
      # @measures = Array.new
      @series = args[:series] || Array.new
      @source = args[:source] || Source.new
      # if @source.is_a?(Source) and @source.parser then
      if @source.is_a?(Source) && @source.text then
        parser = @source.analyze
        data, results = parser.commit
        add(data.make_series)
        # series = Series.new(
        #   :chron => @source.parser.chron,
        #   :measure => @source.parser.measures[0])
        # 
        # # build series from the first (=chron) and last (=measure) elements in each row
        # # records.each {|e| series.add(e.split.values_at(0,-1))}
        # @source.parser.records.each {|r| series.add(r)}
        # @series = [ series ]
      end
      @name = args[:name] || gen_name
      @saved = false
      @source_proxy = nil
    end

    def title
      @title = nil if @title == "Untitled"  # for old datasets labeled Untitled
      @title || series[0].measure.name
    end

    def add(series)
      @series << series
      self
    end

    def url
      "#{name}"
    end

    def derived?
      source.is_a?(Derivation)
    end

    def diffs
      diff_series = series.map { |s| s.diffs }
      d2 = Dataset.new(
        :title => "Changes in #{title}",
        :series => diff_series,
        :source => Derivation.new(:diffs, [self]),
        :name => self.name + ":diffs"
        )
    end

    def deltas
      delta_series = series.map { |s| s.deltas }
      d2 = Dataset.new(
        :title => "Changes in #{title}",
        :series => delta_series,
        :source => Derivation.new(:deltas, [self]),
        :name => self.name + ":deltas"
        )
    end

    def chron
      series.first.chron
    end

    def baseline(chron)
      raise "Could not find any data for #{self.chron.name} = #{chron.value} in dataset" if series.map {|s| s[chron]}.compact.empty?
      d2 = Dataset.new(
        :title => "#{title} (#{chron.to_s} = 100%)",
        :series => series.map {|s| s.baseline(chron)},
        :source => Derivation.new(:baseline, [self]),
        :name => self.name + ":b:" + chron.to_s
        )
    end

    def baseline?
      source.is_a?(Derivation) and source.operation == :baseline
    end

    def can_baseline?
      !derived? or source.operation != :baseline
    end

    def ratio(d2)
      ratio_series = series[0].ratio(d2.series[0])
      d3 = Dataset.new(
        :title => "#{self.title} per #{d2.title}",
        :series => [ ratio_series ])
    end

    def to_yaml_properties
      if @source.is_a?(Source) then
        instance_variables - ["@source"]
      else
        super
      end
    end

    def proxify
      if @source.is_a?(Source) then
        @source_proxy = @source.name
        @source.save
        # @source = nil
        # @source_uuid = s.name
      end
    end

    def unproxify
      if @source_proxy then
        @source = Source.load(@source_proxy)
      else
        @source.unproxify
      end
      @saved = true
    end

    def saved?
      @saved || false
    end

    def ready_to_save?
      case @source
      when Source
        # automatically caches Source if there is one
        true
      else
        # check that all parent datasets have been saved
        ! @source.parents.map {|ds| ds.saved?}.include?(false)
      end
    end

    def save
      raise "Must save all parent objects first" unless ready_to_save?
      proxify
      super
      @saved = true
      # @source = s
    end

    def self.load(dataset_id)
      # d = YAML.load_file("#{@@cachedir}/#{dataset_id}")
      d = super
      d.unproxify
      # if d.source_uuid then
      #   d.source = Source.load(d.source_uuid)
      # end
      d
    end

    def delete
      if @source.is_a?(Source) then
        @source.delete
      end
      super
    end

    private

    def gen_name
      UUID.timestamp_create.to_s
      # @name = title.downcase.split[0..2].collect {|w| w[0..2]}.join + Digest::SHA1.hexdigest("#{title} #{Time.now}")[0..5]
    end
  end

  class Derivation
    attr_accessor :operation, :parents

    def initialize(operation, parents)
      @operation = operation
      @parents = parents
    end

    def to_yaml_properties
      [ "@operation", "@proxy" ]
    end

    def proxify
      @proxy = parents.map {|p| p.name}
    end

    def unproxify
      @parents = @proxy.map {|dsname| Dataset.load(dsname)}
    end

    def to_yaml( opts = {} )
      proxify
      super
    end

  end

end
