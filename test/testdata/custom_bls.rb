html
pre_section
if text =~ /^Series Id,/
  notes = $PREMATCH
end
fields = {}
notes.each_line {|line| line =~ /^\s*(.*?):\s*(.*)/ and fields[$1] = $2}
title = fields["Series Id"] + notes.split($/)[1]
csv
autoheaders
if fields["Column"]
  constraints[fields["Table"]] = fields["Column"]
  title = "#{fields["Series Id"]} - #{fields["Item"]} - #{fields["Column"]}"
end
data.reject! {|row| row[2] == "Annual" || row[0] != fields["Series Id"]}
