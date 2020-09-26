function get_array_for_hdf(ts::SingleTimeSeries)
    return TimeSeries.values(ts.data)
end
