fsdata_export
=============

Sample code for extracting CopperEgg filesystem data, exporting it to a spreadsheet (xlsx), and doing some simple analysis and charting. 

* [Website](https://github.com/sjohnsoncopperegg/fsdata_export)

## Installation

Clone this repository.

###git clone http://git@github.com:sjohnsoncopperegg/fsdata_export.git

Run the Bundler

###bundle install


## Usage

```ruby
###fsdata_extract.rb APIKEY [options]
```
Substitute APIKEY with your CopperEgg User API key. Find it as follows:
  Settings tab -> Personal Settings -> User API Access

Your command line will appear as follows:

```ruby
###fsdata_extract.rb '1234567890123456'
```
    
## Defaults and Options

##  LICENSE

(The MIT License)

Copyright © 2012 [CopperEgg Corpotration](http://copperegg.com)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
