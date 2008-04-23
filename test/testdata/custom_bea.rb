csv
self.title = data.shift.join
self.notes = data.find_all {|row| row.size <= 1}.join("\n")
self.data = data.find_all {|row| row.size > 1}
multiplier_from(notes)
units_from(notes)
headerlines(1)
roman_map = { "I" => "Q1", "II" => "Q2", "III" => "Q3", "IV" => "Q4"}
columns[0] = { :role => :ignore }
measure_column(1)
self.headers = headers.map {|hdr| hdr.gsub(/-(.*)$/) { roman_map[$1] } }
