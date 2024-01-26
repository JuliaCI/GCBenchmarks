JULIA_BIN=$1
HEAP_SIZE=$2
BENCHMARK=$3

$JULIA_BIN --heap-size-hint=$HEAP_SIZE $BENCHMARK

if [ $? -ne 0 ]; then
    echo "Failed to run $BENCHMARK with heap size $HEAP_SIZE"
    exit 1
fi

echo "Successfully ran $BENCHMARK with heap size $HEAP_SIZE"
