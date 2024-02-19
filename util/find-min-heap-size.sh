# Do binary search to find the required minimum heap size
# to run a benchmark. Minimum is 4MB and maximum is the machine
# memory size.

JULIA_BIN=$1
BENCHMARK=$2

# Set the initial heap size to 4MB
min_heap=4
max_heap=$($JULIA_BIN -e 'println(Int(Sys.total_memory() / 1024 / 1024))')
heap_size=$min_heap

# Run the benchmark with the initial heap size
while [ $min_heap -lt $max_heap ]
do
    heap_size_str="$heap_size"M
    echo "Trying heap size: $heap_size_str"
    $JULIA_BIN --heap-size-hint=$heap_size_str $BENCHMARK
    if [ $? -eq 0 ]
    then
        max_heap=$heap_size
        heap_size=$((($min_heap + $max_heap) / 2))
    else
        min_heap=$heap_size
        heap_size=$((($min_heap + $max_heap) / 2))
    fi
    # Break early if the difference is less than 16MB
    if [ $(($max_heap - $min_heap)) -lt 16 ]
    then
        heap_size=$max_heap
        break
    fi
done

# Return the minimum heap size
echo $min_heap
echo "---"
