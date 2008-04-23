=begin

Utility functions used in dataset modules and classes.

=end

class ArrayOfHashes < Array
  def [](i)
    super(i) || {}
  end
end


class Array
  # returns true iff every element of the array satisfies the condition provided
  # in the block, e.g. [1,2,3,4,5].all_satisfy? {|v| v<6}
  def all_satisfy?
    ! self.map {|v| yield v}.include?(false)
  end

  # found this at http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/6996
	def each2
		collect {|a|
			a.length
		}.max.times {|i|
			yield collect {|a|a[i]}
		}
	end

  def parallel
    x = []
    each2 {|e| x << e}
    x
  end

  # def find_with_index
  #     each_with_index { |x,i| return x if yield(x,i) }
  # end

  def map_with_index
    a = []
    each_with_index do |x, i|
      a << yield(x, i)
    end
    a
  end

  # sampling lets us limit the number of values picked from really large sources
  # use the first 100 values, the last 100, then up to a hundred randomly-selected in between
  # Why sample this way?
  # Because the most recent data figures are most likely to have good data (sometimes values
  # are missing for old time periods); and we don't know whether the most-recent data are at
  # the beginning or the end, so pull off some rows from top and bottom.  And to make sure
  # we don't missing anything in the middle, grab a few rows at random from in there.
  def sample
    return self if size < 300
    self[0..99] + values_at(*(Array.new(100) {|i| Kernel.rand(size-200)+100}.sort.uniq)) + self[-100..-1]
  end
end

# This is a real hack.  Need a better approach to this.
class String
  def looks_like_csv?
    if self =~ /\t/
      # tabs are a giveaway, not CSV
      return false
    end

    self =~ /,/
    # if self =~ /,/
    #   # has a comma, so could be CSV
    #   if self =~ /\s/
    #     # but there's some whitespace too!
    #     if self =~ /"/
    #       # whitespace should be surrounded by quotes
    #       true
    #     else
    #       false
    #     end
    #   else
    #     true
    #   end
    # else
    #   false
    # end
    # this one didn't work
#     self =~ /",/ || (self =~ /,/ && self !~ /[ \t]/)
  end

  def to_number
    if self =~ /^\s*\$?\s*\-?\s*\$?\s*\d*\.?\d+/ then
      # ISSUE: this will recognize the number 123 for the value "1,2,3"
      # That might be OK.  A value like that is probably a footnote reference or something,
      # and is likely to be an ignored column.
      # But what if there is a column that includes multiple comma-separated ZIP code values?
      # "94012,94123" will be treated as the number 9401294023.
      # Deal with this only if it ever arises as a problem.

      # strip commas, whitespace, dollar signs
      gsub!(/,/, '')
      gsub!(/\s/, '')
      gsub!(/\$/, '')

      case self
      when /\.\d+/
        # found a decimal, convert to float
        to_f
      else
        # no decimal, convert to FixNum or BigNum
        to_i
      end
    else
      nil
    end
  end
end
