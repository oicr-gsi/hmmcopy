#!/bin/bash
cd $1

find .  -name "*\.zip" -exec unzip -q {} \; >/dev/null # unzip the results files

# - .tsv files have no stochastic content, may be md5sum-checked
# - .seg files are generically named, no stochastic content, may be md5sum-checked
# - *.png files should be generating the same md5sum, apparantly no stochastic content

# Therefore:
# - Check md5sums for all types of files, sort

echo ".tsv files:"
find . -name "*.tsv" | xargs md5sum | sort -V

echo ".seg files:"
find . -name "*.seg" | xargs md5sum | sort -V

echo ".png files:"
find . -name "*.png" | xargs md5sum | sort -V
