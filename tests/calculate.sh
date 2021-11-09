#!/bin/bash
cd $1

find .  -name "*\.zip" -exec unzip -q {} \; >/dev/null # unzip the results files

# - .tsv files have no stochastic content, may be md5sum-checked
# - .seg files are generically named, there may be differences at pos 10 after the decimal point, so we round to 3 digits
# - *.png files should be generating the same md5sum, apparantly no stochastic content except for bias plot which we are not checkong

# Therefore:
# - Check md5sums for all types of files (where possible), sort

echo ".seg files:"
for f in *.seg;do awk '{printf "%s %s %i %i %.3f\n", $1, $2, $3, $4, $5}' $f | md5sum;done | sort -V

echo ".tsv files:"
for f in *.tsv;do awk '{printf "%s %s %i %i %i %.3f\n", $1, $2, $3, $4, $5, $6}' $f | md5sum;done | sort -V

echo ".png files:"
find . -name "*.png" | grep -v bias | xargs md5sum | sort -V
