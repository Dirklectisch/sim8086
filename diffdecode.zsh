#!/bin/zsh

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path>"
    exit 1
fi

# Assign the input parameter to a variable
input_path="$1"

# Check if the path exists
if [ -e "$input_path" ]; then
  
    # Check if it's a directory
    if [ -d "$input_path" ]; then
        echo "$input_path is a directory."
    # Check if it's a file
    elif [ -f "$input_path" ]; then
        # Create output directory
        if ! [ -d "output" ]; then
            mkdir -p "output"
        fi
        
        # Run sim8086 tool to decode machine code
        filename=$(basename $input_path)        
        zig run src/cli.zig -- $input_path > ./output/$filename.asm
        
        # Diff output file against provided file 
        diff --ignore-matching-lines='^;' --ignore-blank-lines ./output/$filename.asm ./vendor/computer_enhance/perfaware/part1/$filename.asm
    else
        echo "$input_path is neither a file nor a directory."
    fi
else
    echo "$input_path does not exist."
fi
