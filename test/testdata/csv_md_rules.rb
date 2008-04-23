@data = CSV.parse(text)
headerlines(1)
multiplier = @headers[0].to_s.downcase.to_sym
@headers[0] = ""
measure_column(0)
@data.each do |row|
  case row[0].name
  when /\bshares\b/i # "shares outstanding"
    # number of shares
    row[0].multiplier = multiplier
    row[0].units = Dataset::Units::Discrete # "things", i.e. shares
  when /\bper\b.*\bshare\b/i # "per share", "per common share"
    row[0].units = Dataset::Units::Dollars
  else
    # dollar entries
    row[0].multiplier = multiplier
    row[0].units = Dataset::Units::Dollars
  end
end
