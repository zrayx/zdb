priority n-1
============
* delete row
* replaceAt(x,y)
* convert all snake _ case table to camelCase
  * rg 'pub fn. * _ '

priority n-1
============
* cache column.maxWidth
* write TUI spreadsheet program

priority n-1
============
* add datatype database (collection of tables)
* add convenience functions
  * len()
  * getAt()/valueAt()/at()
  * get()/getNamed()/getByName()/value()
    * row()/column()/value()
    * rowAt()/columnAt()/valueAt()
* rename column
* math operations
  * avg, sum, etc.
* result set
  * is a temp table?
  * 2D, 1D, Value
* filter
* foreign keys
  * new data type "RowId"
* deleted rows
  * preserves RowId
  * implementation: every column in a row is Type.empty?
    * would need to detect empty rows in output
    * new table object "bitmap of empty rows"?
  * reset RowId after deleting many rows
    * function compact()
    * rewrite all references
* understand length of unicode text
* auto generated columns
  * e.g. date: 15.3.2022/16.3.2022/17.3.2022 etc.
  * function "incAbove"?
* delete row(s)
  * ArrayList.orderedRemove()
* insert row(s)
* delete/insert columns

priority n-1
============
* multi-line column contents
* recursive select
  * native support for good representation in print()
    * should be a very good representation for e.g. todo lists
