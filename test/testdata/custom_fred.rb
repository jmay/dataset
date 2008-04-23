split_by_newline
hdrs = []
hdrs << lines.shift until lines.first =~ /^DATE/
fields = {}
hdrs.each {|line| line =~ /^\s*(.*?):\s*(.*)/ and fields[$1] = $2}
self.notes = hdrs.join("\n")
self.title = fields['Title']
units_from(notes)
multiplier_from(notes)
split_on_whitespace
headerlines(1)
columns[1] = { :role => Dataset::Measure.new(:name => title)}
