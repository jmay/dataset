html
pre_section
if text =~ /^Series Id,/
  self.notes = $PREMATCH
  self.text = $MATCH + $POSTMATCH
end
fields = {}
self.notes.each_line {|line| line =~ /^\s*(.*?):\s*(.*)/ and fields[$1] = $2}
self.title = fields["Series Id"] + self.notes.split($/)[1]
csv
autoheaders
headers.pop
if fields["Column"]
  constraints[fields["Table"]] = fields["Column"]
  self.title = "#{fields["Series Id"]} - #{fields["Item"]} - #{fields["Column"]}"
end
columns[3] = { :label => fields["Item"], :role => Dataset::Measure.new(:name => fields["Item"]) }
data.pop while data.last.size != headers.size
