html
choose_table  # find the table
@data.slice!(0,2) # pull off the headers
@prices = []
@data.each do |row|
  yrmon = row.shift
  yrmon.match(/^(\d+)/)
  yr = $1
  row.each_slice(2) do |dt,price|
    next if dt.empty?
    @prices << ["#{yr}/#{dt}", price]
  end
end
@data = @prices
