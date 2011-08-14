#!/bin/bash

# The SoX Miner
# Copyright (C) 2011  Andreas Jansson <andreas@jansson.me.uk>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 


# This script reads a number of files from stdin, preferably mp3 files,
# and extracts various bits of information from these files, using SoX.
# The output format is delimited by pipe symbols | so file names or comments
# shouldn't have pipe symbols in them.

# As of SoX version 14.3.1, the fields that are extracted are:
#   title (full, relative path)
#   channels
#   sample_rate
#   bit_depth
#   duration (multiple units)
#   file_size
#   bit_rate
#   encoding
#   comments (array)
#   dc_offset
#   min_level
#   max_level
#   peak (dBFS)
#   rms (dBFS)
#   windowed_rms_peak
#   windowed_rms_trough
#   crest_factor
#   flat_factor
#   peak_count
#   std_bit_depth (see "man sox")
#   num_samples
#   length (seconds)

# See the SoX manpages for more information about these attributes (search
# for 'stats'). The comments column is different to the other columns in
# that it contains an array of name=value pairs of comments (usually ID3 tags).

# SoX itself is not massively UNIXy when it comes to the data it digs out.
# For example, large numbers are often suffixed with the scientific unit
# instead of writing out the whole number, e.g. 3.4k instead of 3400.
# It is likely that additional processing will have to be applied in order
# to get anything useful out of this.

# The script is inherently quite fragile, but shouldn't be too difficult
# to amend if the SoX output format changes.

while read file
do
    soxi "$file" |                         # get all info about file
        grep ":" |                         # filter out lines without colon
        grep -v "Comments" |               # filter out comments (just a title on a line)
        cut -d":" -f2- |                   # filter out the first (title) column
        tr "\n" "|"                        # replace newlines with pipe symbols

    soxi -a "$file" |                      # get ID3 tags (or other comments)
        tr "\n" "," |                      # replace newlines with commas
        sed "s/,$/|/"                      # make the last comma a pipe symbol

    sox --multi-threaded "$file" \
        -n stats 2>&1 |                    # get audio stats from file
        tail -n+2 |                        # get rid of the first line of column headers
        egrep -v "^(Scale max|Window)" |   # scale max and window size are constants so we filter them out
        sed -r "s/  +/:/g" |               # we need a way to get rid of column one, this was the least horrible way
        cut -d":" -f2- |                   # filter out column one
        tr " " ":" |                       # make all fields colon separated (where they aren't already)
        sed "s/^-://g" |                   # hack, crest factor for stereo tracks is undefined, instead we use the left channel crest factor
        cut -d":" -f1 |                    # get what is now the first column (originally the second column)
        tr "\n" "|" |                      # replace newlines with pipes
        sed -r "s/\|$/\n/"                 # replace the last pipe with a newline
done

exit