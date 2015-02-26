#  ifc_handler.rb
#  
#  Copyright 2015 Jan Brouwer <jan@brewsky.nl>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  

# IFC processors

require 'sketchup'

module OpenSourceBIM
  module BIMserver
    
    # Is this right???
    extend self
    
    def IfcRead(tempfile)
      
      file = nil
      counter = 1
      ifc_data = ""
      begin
        file = File.new(tempfile, "r")
        while (line = file.gets)
          ifc_data = ifc_data + line
          counter = counter + 1
        end
        file.close
        file.unlink    # deletes the temp file
      rescue => err
        puts "Error reading temporary IFC file: #{err}"
        err
      end
      
      ifc_data
      
    end # def IfcRead
    
    # currently only writes temporary file
    def IfcWrite
      
      # check if it's possible to write IFC files
      unless Sketchup.version_number > 14000000
        raise "You need at least SketchUp 2014 to be able to create IFC-files"
      end
      unless Sketchup.is_pro?
        raise "You need at least SketchUp PRO to be able to create IFC-files"
      end
    
      # Export model to temporary IFC file
      model = Sketchup.active_model
      file = Tempfile.new(['BIMserver-', '.ifc'])
      show_summary = false
      
      unless model.export file.path , show_summary
        raise "Unable to write temporary IFC-file"
      end
      
      # return the temp file
      file
      
    end # def IfcExport
  end # BIMserver
end # module OpenSourceBIM
