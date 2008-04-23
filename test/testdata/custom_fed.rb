csv
headings = data.slice!(0,6).transpose
headings.each_with_index do |h, colnum|
  columns[colnum] = {
    :label => h[0],
    :notes => h[4],
    :units => unit_from(h[1]),
    :multiplier => case h[2].to_i
      when 1_000_000 then :million
      when 1_000 then :thousand
      else :ones
    end
  }
end
