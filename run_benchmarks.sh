#!/bin/bash

if [ -x $JULIA_HOME/julia ]
then
    JULIA_EXE=$JULIA_HOME/julia
    echo "Using julia found in $JULIA_EXE "
else
    JULIA_EXE=julia
    echo "Using default julia"
fi

echo "pidigits.jl 68470"
$JULIA_EXE pidigits.jl 68470
echo "iterations.jl 5"
$JULIA_EXE iterations.jl 5
echo "list.jl"
$JULIA_EXE list.jl
echo "pollard.jl"
$JULIA_EXE pollard.jl
echo "burn.jl"
$JULIA_EXE burn.jl
echo "tree.jl 5 4"
$JULIA_EXE tree.jl 5 4
echo "fileio.jl"
$JULIA_EXE fileio.jl
