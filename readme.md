Plans
=====
* CSV files are tables
* no meta information?
* one file per table
* first line is header

CSV format
==========
* row numbers are implicit
  * index is 0
  * recalculated on the fly
* format example
  col1-numeric,col2-string,col3-calc-relative,col4-calc-absolute
  1.56e5,"hello",=col1-numeric[-1],=col1-numeric[1]
  2.56e5,"world",=col1-numeric[+0]+col1-numeric[-1],=col1-numeric[2]
  0,"multiple rows\nwith \"quotes\"",=col1-numeric[+0]+col1-numeric[-1],=col1-numeric[2]
