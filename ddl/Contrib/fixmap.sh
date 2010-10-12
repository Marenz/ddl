#!/bin/bash
#
# converts ld generated map into
# insitu-compatible format

if [ -z $# ]; then
    echo "Syntax: $0 <mapfile>"
    echo "the map file is overwritten"
    exit 1
fi

cat $1 | grep -v '\.o$' |grep '^ *0x' | awk '{if(NF == 2) { print $2, $1; }}' | grep -v '^[0-9]' | sed 's/\(.*\) 0x[0-9]*\(........\)$/12345678901234567890 \1 \2/' | sed 's/@@GLIBC[^ ]*//' > out.map
xxd -r << EOF > $1
00000000: 0d0a
EOF
echo ' Start' >> $1
echo >> $1
echo 'alamakota' >> $1
cat out.map >> $1
rm out.map
