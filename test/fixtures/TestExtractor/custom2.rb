def translate(code)
  sectorcodes = {
    "MTM" => "Total Manufacturing",
    "MDM" => "Durable Goods",
    "31S" => "Primary Metals",
    "31C" => "Ferrous Metal Foundries"
  }
  dataitems = {
    "NO" => "New Orders",
    "TI" => "Total Inventories"
  }
  code =~ /^(.)(...)(..)$/
  a = case $1
  when 'A'
    "Adjusted"
  when 'U'
    "Unadjusted"
  else
    "Unknown"
  end
  b = sectorcodes[$2]
  c = dataitems[$3]
  "#{code} - #{a} #{c} - #{b}"
end

@headers = [ nil, nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
split_by_newline
split_by_tabs
data.each {|row| row[0] = translate(row[0])}
