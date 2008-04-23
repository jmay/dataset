require "rubygems"
require "facets/core/module/class_extension"
require "yaml"

module Caching
  def initialize
    @saved_ts = nil
  end

  def save
    f = File.new("#{self.class.cachedir}/#{self.name}", "w")
    f << self.to_yaml
    f.close
    @saved_ts = Time.now
  end

  def cachefile
    raise "Object #{object_id} has not been cached" unless @saved_ts
    "#{self.class.cachedir}/#{self.name}"
  end

  def delete
    File.delete("#{self.class.cachedir}/#{self.name}")
  end

  class_extension do
    def cachedir
      "#{Caching::CACHEDIR}/#{self.name}"
    end

    def cachelist
      Dir.entries(cachedir).grep(/\w+/)
    end

    def load(name)
      raise "Missing name" unless name
      YAML::load(File.open("#{self.cachedir}/#{name}"))
    end

    def purge(name)
      File.delete("#{self.cachedir}/#{name}")
    end
  end
end
