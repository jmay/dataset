@headers = [ nil, nil, "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
split_by_newline
split_by_tabs
transform((2..13), [0,1])
explode_on_first
merge_chunks
@headers = [ nil, nil ] + @keys
