require "open-uri"
require "hpricot" # for extracting titles

module Dataset
  class Source
    attr_accessor :text
    attr_reader :content_type

    def initialize(args = {})
      if args[:url]
        @text = fetch(args[:url])
      else
        @text = args[:text]
      end
    end

    def fetch(uri)
      f = open(uri)
      @content_type = f.content_type
      @text = f.read
    end

    def analyze
      @parser = Parser.new(:source => self)
    end

    def parse(parser = nil)
      parser ||= @parser
      parser.parse(self)
      self
    end

    def title
      raise "No title here" unless @content_type =~ /html/
      (Hpricot(text)/"title").text
    end
  end # class Source
end
