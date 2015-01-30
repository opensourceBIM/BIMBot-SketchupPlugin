#  BIMserver.rb
#  
#  Copyright 2015 Jan Brouwer <Jan@brewsky.nl>
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

# Create an entry in the Extension list that loads a script called
# core.rb.
require 'sketchup.rb'
require 'extensions.rb'

SKETCHUP_CONSOLE.show

module BIMserver
  bimserver_extension = SketchupExtension.new("Send to BIMserver", "BIMserver/core.rb")
  bimserver_extension.version = '0.1'
  bimserver_extension.description = 'Send model to BIMserver as IFC.'
  Sketchup.register_extension(bimserver_extension, true)
end # module BIMserver
