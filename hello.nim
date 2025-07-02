import os

if paramCount() > 0:
  let name = paramStr(1)
  echo "hello world, " & name
else:
  echo "hello world"