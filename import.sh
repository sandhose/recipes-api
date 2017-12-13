#!/bin/zsh

for file in $@; do
  echo $file
  HASH=`shasum $file | awk '{print $1}'`
  DIR="media/${HASH:0:1}/${HASH:1:1}"
  mkdir -p $DIR
  ln -s ../../../$file $DIR/${HASH:2}
done
