=begin

The Extractor module is intended for transforming any source data (presented as a string)
into rows & columns.

In addition to constructing a rows & columns array, extraction may also do the following:

* rearrange the source data if the input structure is too complicated
* find a title in the input, if possible
* identify column headers, if possible
* extract column notes, if any
* extract column metadata, e.g. measure units & multiplier

Source formats supported by Extractor include:

* comma-separated
* tab-separated
* whitespace-separated (spaces and/or tabs)
* HTML containing a <pre> block with (comma-, tab-, whitespace-)separated text
* HTML containing a data table
* Excel workbook (XLS)

Custom extraction rules can augment these basic format-based extractions with source-specific handling,
covering any of the features listed above.

=end

require "hpricot"
require "csv"
require "fastercsv"
require "enumerator"

module Extractor
  Hpricot.buffer_size = 250000

  def self.all
    self.constants.map {|c| self.const_get(c).desc}.compact.sort
  end

  def self.find_by_desc(desc)
    classname = self.constants.find {|c| self.const_get(c).desc == desc}
    classname ? self.const_get(classname) : nil
  end

  # try to pick an appropriate Extractor for the provided data.
  def self.choose(format, data)
    case format
    when /html/
      doc = Hpricot(data)
      if (doc/:pre).any?
        # found a <pre> section
        Extractor::HTMLExtractor.new
      elsif (doc/:table).any?
        # found some tables
        Extractor::HTMLTableExtractor.new
      else
        nil
      end
    when /excel/
      Extractor::CustomExtractor.new("xls")
    when /csv/
      Extractor::CSVExtractor.new
    else # raw text
      if data =~ /\t/
        Extractor::TSVExtractor.new
      elsif data =~ /,/
        Extractor::CSVExtractor.new
      else
        # whitespace
        Extractor::WhitespaceExtractor.new
      end
    end
  end

  class Base
    attr_accessor :headerlines, :notelines
    attr_reader :data, :headers, :notes, :title, :columns, :multiplier, :units, :constraints

    def to_yaml_properties
      ['@headerlines', '@notelines']
    end

    def properties
      {
        :headerlines => "Number of header rows",
        :notelines => "Number of lines of notes"
      }
    end

    def initialize(args = {})
      @headerlines = args[:headerlines] || 0
      @notelines = args[:notelines] || 0
    end

    def run(source)
      @notes = []
      @headers = []
      @columns = ArrayOfHashes.new
      @data = extract(source)
      notelines.times { @notes << @data.shift } if notelines
      if headerlines > 0 && @headers.empty?
        (headerlines-1).times { @data.shift }
        @headers = @data.shift
      end
      @data
    end

    def desc
      self.class.desc
    end
    
    class << self
      attr_accessor :desc
    end
  end

  # lines are separated by DOS or UNIX newlines
  # fields are separated by any amount of whitespace
  # ignore blank lines
  class WhitespaceExtractor < Base
    @desc = "Raw ASCII text, fields delimited by whitespace"

    def extract(source)
      source.split(/\s*[\n\r]+/).grep(/./).map {|l| l.split}
    end
  end

  # lines are separated by DOS or UNIX newlines
  # fields are separated by tabs only (vs. WhitespaceExtractor)
  # ignore blank lines
  class TSVExtractor < Base
    @desc = "Raw ASCII text, fields delimited by single tabs"

    def extract(source)
      source.split(/\s*[\n\r]+/).grep(/./).map {|l| l.split("\t")}
    end
  end

  # use parsing from CSV.rb for distinguishing lines & fields
  # ignore blank lines
  # remove leading & trailing whitespace from all values
  class CSVExtractor < Base
    @desc = "Comma-separated values"

    def extract(source)
      # source.split(/\r|\n|\r\n/).find_all{|row| row.length > 0}.map do |row|
      #   row.split(/,/, -1).map do |v|
      #     v.gsub(/^\s*"?\s*/, '').gsub(/\s*"?\s*$/, '')
      #   end
      # end
      CSV.parse(source).find_all{|row| row.find_all{|v| !v.nil?}.size > 0}.map { |row| row.each {|v| v.strip! unless v.nil?} }
    end
  end

  class HTMLExtractor < Base
    @desc = "HTML - pre-formatted text inside a web page"

    def extract(source)
      doc = Hpricot(source)
      @title = (doc/:title).inner_text.strip.gsub(/\s+/, ' ')
      pre = (doc/"pre").map {|pre| pre.inner_text}.join
      if pre.size > 0
        pre.split(/\s*[\n\r]+/).grep(/./).map {|line| line.split}
      else
        nil
      end
    end
  end

  # extract all HTML <pre> sections from the source, join them together,
  # and then process as either CSV or whitespace
  class EconstatsExtractor < Base
    @desc = "Econstats source: <pre> containing either whitespace-delimited or tab-delimited data"

    def extract(source)
      doc = Hpricot(source)
      @title = (doc/"title").text.gsub(/^EconStats[^a-zA-Z0-9]*/, '')
      pre = (doc/"pre").map {|pre| pre.inner_text}.join
      lines = pre.split(/\r\n|\n|\r/)
      @notes << lines.shift until lines[0].match(/^\d/)
      if lines[0] =~ /,/
        # CSV
        @notes[1].split(/\s*,\s*/).each_with_index {|text,i| @columns[i] = {:label => text}}
        lines.map {|line| line.gsub(/\s*$/, '').split(/\s*,\s*/)}
      else
        # whitespace
        lines.map {|line| line.split}
      end
    end
  end

  # extract all HTML <pre> sections from the source, remove some embedded junk HTML, join the pieces together,
  # and then process as a whitespace source
  class EconomagicExtractor < WhitespaceExtractor
    attr_reader :measure, :multiplier

    @desc = "Economagic source: HTML page with whitespace-delimited data inside multiple <pre> sections"

    def extract(source)
      doc = Hpricot(source)

      # attempt to extract some metadata from the page title
      @title = (doc/"title").text || "Unspecified Stuff"
      @measure = @title.match(/(.*?)[:;]/)[1] if @title.match(/[:;]/)
      mults = title.scan(/\b(thousands|millions|billions)\b/i)[0]
      if mults
        @multiplier = mults[0].downcase.gsub(/s$/,'').to_sym
      else
        @multiplier = :ones
      end

      raw = (doc/"pre").map {|pre| pre.inner_html.gsub(/ *<font .*?\/font> */, ' ').gsub(/\s*<a .*?\/a>/, '').gsub(/\s*$/, '')}.join
      raw.split(/\s*[\n\r]+/).grep(/./).map {|l| l.split}
    end
  end

  # This Extractor is custom for Bureau of Labor Statistics sources acquired through
  # their SurveyOutputServlet query tool.  This one pulls out only Monthly data from
  # source, ignoring any Annual or Bi-annual (HALF1, HALF2) entries.
  #
  # extract the single HTML <pre> section from the source, pick off the headers,
  # and then process as a CSV source
  #
  # BLS sources sometimes (haven't investigated how often) have &nbsp; text in some (but not all)
  # of the whitespace in the headers.  AFAICT this is the only case of HTML entities in the source.
  class BLSExtractor < CSVExtractor
    @desc = "BLS source: HTML page with CSV inside a <pre> section"

    def extract(source)
      doc = Hpricot(source.gsub(/&nbsp;/,' '))

      # title & measure are in the header lines

      lines = (doc/"pre").inner_text.split(/\r\n|\n|\r/)
      @notes << lines.shift until lines[0].match(/^Series Id,/i)
      @notes.each { |line| line.gsub!(/^\s+/,'') }

      @headers = CSV.parse_line(lines.shift)
      datacol = @headers.index("Value")

      colnotes = @notes.join($/).match(/Series.*?\n+(.*?)\n+\Z/m)[1]
      colnotes.match(/title:\s*(.*)/)
      label = $1 || @notes[1].gsub(/\s*\-.*/, '')
      @columns[datacol] = {
        :label => label,
        :notes => colnotes,
        :multiplier => Dataset::Units.extract_unit(colnotes)
      }

      series = @notes.grep(/Series Id/i).first.match(/:\s+(\w+)/)[1]

      footers = []
      footers << lines.pop until lines.last.match(/^#{series}/)
      @notes << footers.reverse

      @title = "BLS series #{series}: #{@notes[1]}"

      rows = lines.map {|line| CSV.parse_line(line)}
      if rows.find {|row| row[2] !~ /Annual/}
        # if there is *non-annual* (ie monthly) data in the source, then remove all the
        # Annual data, so we don't get records for different time periods
        rows.delete_if {|row| row[2] =~ /Annual|HALF/}
      end
      rows
    end
  end # class BLSExtractor

  # BEA sources are CSV, with some useful header lines at the top
  # ...except that the CSV module can't handle them.  The line separator here is 
  class BEAExtractor < Base
    @desc = "BEA source: CSV"

    def extract(source)
#       lines = super
      lines = source.split(/\r\n|\n|\r/)
      @title = CSV.parse_line(lines.shift)[0]
      3.times { @notes << lines.shift }

      if lines.find {|line| line.empty?}
        # there's a blank line in there
        footers = []
        footers << lines.pop until lines.last.nil? or lines.last.empty?
        lines.pop
        @notes.concat(footers.reverse)
      end
      @notes = @notes.map {|line| CSV.parse_line(line)[0]}

      @headers = CSV.parse_line(lines.shift).map {|v| v.strip unless v.nil?}
      notestext = @notes.join($/)
      @multiplier = Dataset::Units.extract_unit(notestext)
      case notestext
      when /\bdollars\b/i
        @units = Dataset::Units::Dollars
      when /\bpercent\b/i
        @units = Dataset::Units::Percentage
      end
      lines.map{|line| CSV.parse_line(line).map {|v| v.strip unless v.nil?}}
    end
  end # class BEAExtractor

  class FedExtractor < Base
    @desc = "Federal Reserve - Economic Research - FRED"
    def extract(source)
      lines = source.split(/\r\n|\n|\r/)
      @notes << lines.shift until lines[0].empty?
      lines.shift # skip the blank line
      @title = @notes.first.match(/Title:\s*(.*)/)[1]
      @headers = lines.shift.split
      lines.map {|line| line.split}
    end
  end # class FedExtractor

  class HTMLTableExtractor < Base
    @desc = "HTML table inside a web page"

    def extract(source)
      doc = Hpricot(source.gsub(/&nbsp;/,' '))
      @title = (doc/:title).inner_text.strip.gsub(/\s+/, ' ')

      (doc/:table).each_with_index do |table, i|
        next unless (table/:table).empty?
        rows = (table/:tr)
        if rows.size > 3
          if cells(rows.first).size > 1
            # use this one
            lines = []
            rows.each do |row|
              rowcells = (cells(row)).map {|cell| cell.inner_text.strip.gsub(/[$,]/, '')}
              if rowcells.find {|cell| cell =~ /\S/}
                # there's at least one cell that has a non-blank in it
                lines << rowcells
              end
            end
            return lines
          end
        end
      end
      return []
    end

    def cells(row)
      (row).children.find_all {|node| node.is_a?(Hpricot::Elem)}
    end
  end # class HTMLTableExtractor

  class CustomExtractor
    def self.desc
      "Custom"
    end

    def desc
      self.class.desc
    end

    def to_yaml_properties
      ['@code']
    end

    def properties
      {
        :code => "Processing rules"
      }
    end

    # attr_reader :title, :multiplier, :units
    attr_accessor :code, :text
    attr_accessor :lines, :data, :headers, :columns, :constraints, :errors
    attr_accessor :title, :notes
    attr_accessor :multiplier, :units

    def initialize(code = nil)
      @code = code
    end

    def reset
      @data = []
      @headers = []
      @columns = ArrayOfHashes.new
      @constraints = {}
      @errors = []
      @units = @multiplier = nil
    end

    def run(source_text)
      @text = source_text
      reset
      instance_eval(@code)
    end

    def split_by_newline
      @lines = @text.split(/\s*[\n\r]+/)
    end

    def split_by_tabs
      @data = @lines.map {|line| line.split("\t").map {|cell| cell.strip}}
    end

    def split_on_whitespace
      @data = @lines.map {|line| line.split(/\s+/)}
    end

    def explode_on_first
      @chunks = Hash.new { |hash, key| hash[key] = [] }
      @data.each do |line|
        key = line[0]
        rest = line[1..-1]
        @chunks[key] << rest
      end
      @keys = @data.map {|line| line[0]}.uniq
    end

    def merge_chunks
      k = @keys.first
      result = @chunks[k]
      @keys[1..-1].each do |key|
        new_result = []
        result.each_with_index do |old_line, i|
          new_result << old_line + [ @chunks[key][i].last ]
        end
        result = new_result
      end
      @data = result
    end

    def headerlines(n)
      @headers = @data.slice!(0, n)[0]
    end

    def transform(colnums, retainlist = [0])
      transformed = []
      @data.each do |line|
        colnums.each do |colnum|
          retained = retainlist.map {|n| line[n]}
          transformed << retained + [ @headers[colnum], line[colnum] ]
        end
      end
      @data = transformed
    end

    def measure_column(colnum)
      columns[colnum] = {:role => :measure}
      @data.each do |row|
        row[colnum] = Dataset::Measure.new(:name => row[colnum], :units => @units, :multiplier => @multiplier)
      end
    end

    def html
      @htmldoc = Hpricot(@text.gsub(/&nbsp;/,' '))
      @title = (@htmldoc/:title).inner_text.strip.gsub(/\s+/, ' ')
    end

    def choose_table(tablenum = nil)
      if tablenum
        table = (@htmldoc/:table)[tablenum]
        crunch_html_table(table)
      else
        # look for the first table with more than 3 rows and more than one column
        (@htmldoc/:table).each_with_index do |table, i|
          rows = (table/"/tr")
          if rows.size > 3
            rowcells = html_table_row_cells(rows.first)
            # puts "looking at a table with #{rows.size} rows and #{rowcells.size} columns"
            if rowcells.size > 1
              # use this one
              return crunch_html_table(table)
            end
          end
        end
        nil
      end
    end

    def crunch_html_table(table)
      lines = []
      (table/"/tr").each do |row|
        rowcells = (html_table_row_cells(row)).map {|cell| cell.inner_text.strip.gsub(/[$,]/, '').gsub(/\s+/, ' ')}
        if rowcells.find {|cell| cell =~ /\S/}
          # there's at least one cell that has a non-blank in it
          lines << rowcells
        end
      end
      @data = lines
    end

    def html_table_row_cells(row)
      (row/"td,th")
      # (row).children.find_all {|node| node.is_a?(Hpricot::Elem)}
    end

    def csv
      @data = []
      # @text.each splits lines on $/ which is a string, not a regexp
      # collapses blank lines
      @text.split(/\r\n?|\n/).each do |line|
        begin
          @data << FasterCSV.parse_line(line).map {|cell| cell.nil? ? nil : cell.strip}
        rescue
          @errors << line
        end
      end
    end

    def tsv
      split_by_newline
      split_by_tabs
    end

    def xls
      
      xls_extractor = IO.popen(File.dirname(__FILE__) + "/../bin/extract-excel.pl", "r+") do |io|
        io.write @text
        io.close_write
        @csv = io.read
      end
      @data = CSV.parse(@csv)
    end

    def autoheaders
      header_rows = []
      while Extractor.looks_like_headers(@data.first) do
        header_rows << @data.shift
      end

      @headers = []
      @headers = header_rows.last.map_with_index {|c, i| header_rows.map {|r| r[i]}.compact.join(" ")} if header_rows.any?
    end

    def pre_section
      @text = (@htmldoc/"pre").inner_text
    end

    def multiplier_from(text)
      @multiplier = Dataset::Units.extract_unit(text)
    end

    def unit_from(text)
      case text
      when /\bdollars\b/i
        Dataset::Units::Dollars
      when /\bpercent(age)?\b/i
        Dataset::Units::Percentage
      when /\bindex\b/i
        Dataset::Units::Artificial
      when /\bunits\b/i
        Dataset::Units::Discrete
      else
        Dataset::Units::Continuous
      end
    end

    def units_from(text)
      @units = unit_from(text)
    end
  end # class CustomExtractor

  def self.looks_like_headers(ary)
    return false if ary.nil?
    ary.all? {|v| v.nil? || v.empty? || v =~ /[A-Za-z]/}
  end

end # module Extractor

class ArrayOfHashes < Array
  def [](i)
    super(i) || {}
  end
end
