#       config.rb
#       
#       Copyright (C) 2015 Jan Brouwer <jan@brewsky.nl>
#       
#       This program is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 3 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Read and parse config file
    
module Brewsky::BIMserver
  class Config
    def initialize(config_file)
      @h_defaults = Hash.new
      parse_config(config_file)
    end
    def parse_config(config_file)
  
      pathname = File.expand_path( File.dirname(__FILE__) )
      mainpath = pathname.split('lib')[0]
      filepath = File.join(mainpath, config_file)
  
      # open the file
      f = File.open(filepath, 'r')
  
      # loop through each record in the file, adding each record to our array.
      f.each_line { |line|
        
        # parse line unless the first character == # or the line is empty
        unless line[0] == "#" || line.length == 1
          a_Value = line.split('=')
          key = a_Value[0].strip
          value = a_Value[1].strip
          @h_defaults[key] = value
        end
      }
    end
    
    # call this function to get a default value for "key", if does not exist it returns nil
    def get(key)
      if @h_defaults[key]
        return @h_defaults[key]
      else
        return nil
      end
    end
  end # Class Config
end # module Brewsky::BIMserver
