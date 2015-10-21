fsdata_export
=============

Sample code for extracting Uptime Cloud Monitor filesystem data, exporting it to a spreadsheet (xlsx), and doing some simple analysis and charting.

###Synopsis
The intent of this script is to provide examples of using the Uptime Cloud Monitor API to export data to a spreadsheet from a user-selected time-frame, programmatically create charts in the spreadsheet, and do some simple analysis of the data.

This ruby script is based on three components:   
* The Uptime Cloud Monitor API
* Axlsx, an Office Open XML Spreadsheet generator for the Ruby programming.   
* Typhoeus, which runs HTTP requests in parallel while cleanly encapsulating libcurl handling logic. 

* [Uptime Cloud Monitor API](http://dev.copperegg.com/)
* [Axlsx](https://github.com/randym/axlsx)
* [Typhoeus](https://github.com/typhoeus/typhoeus)

## Installation

###Clone this repository.

```ruby
git clone http://git@github.com:sjohnsoncopperegg/fsdata_export.git
```

###Run the Bundler

```ruby
bundle install
```

## Usage

```ruby
ruby fsdata_extract.rb APIKEY [options]
```   
Substitute APIKEY with your Uptime Cloud Monitor User API key. Find it as follows:
Settings tab -> Personal Settings -> User API Access

Your command line will appear as follows:

```ruby
ruby fsdata_extract.rb '1234567890123456'
```
    
## Defaults and Options

The available options can be found by typing in the following on your command line
```ruby
ruby fsdata_extract.rb -h
```

Today these options are   
   
* -o, --output_path                Path to write .xlsx files   
* -s, --sample_size [SECONDS]      Override default sample size   
* -i, --interval [INTERVAL]        Select interval (ytd, pm, mtd)   
* -v, --verbose                    Run verbosely

### Output Path
The spreadsheet will be written to the current directory ("./"), with the filename 'hostname-uuid.xlsx'.

To override the destination path, use the -o option. An example follows:

```ruby
ruby fsdata_extract.rb '1234567890123456' -o 'fsdata-20121001'
```
In this example, all files will be written to the 'fsdata-20121001' subdirectory of the current directory. If the specified destination directory does not exist, it will be created.

### Sample Size
The 'sample size' refers to the interval over which each data point is averaged. The sample size in realtime operation is 5 seconds. 

The sample size of the data returned by the API is a function of the range of time requested. Using the default time interval (which is the previous calendar month), the default sample size is 21600 seconds, or 6 hours.If you select a longer time interval, (for example, year-to-date), the sample size will be as long as 1 day.   
 * Note that you cannot select a sample time less than the sample time returned from the API by default. To shorten the time sample length, you need to request data from a shorter time interval.

In the following example, the data from the previous month is exported as a series of one day samples

```ruby
ruby fsdata_extract.rb '1234567890123456' -o 'fsdata-20121001' -s 86400
``` 

### Time Interval
Specify the interval over which to export data. The default (no option specified) is to export the data from the previous calendar month. To specify exporting year-to-date filesystem data, use the '-i' option:

```ruby
ruby fsdata_extract.rb '1234567890123456' -o 'fsdata-20121001' -i 'ytd'
``` 

### Verbosity
To see what is happening as the script is running, include the -v option.


## Outputs

### Analytics:

A set of simple analytics is printed to the terminal screen when the script finishes. The following analytics will appear:   
* Total systems monitored this period   
* Total filesystems monitored this period   
* Number of filesystems > 95% full    
** if > 0, a list of the top 10 most full      
* Number of filesystems that have grown over the period exported    
** if > 0, a list of the top 10 most rapidly growing filesystems

### Spreadsheets

One spreadsheet is created for each system monitored during the time interval exported.

### Charts

Two charts are created for each filesystem, on every system monitored.


##  LICENSE

(The MIT License)

Copyright © 2012 [IDERA](http://idera.com)

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
FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
