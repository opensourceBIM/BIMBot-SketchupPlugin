#  loader.rb
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

# Main loader for BIMserver plugin

require 'sketchup'

module OpenSourceBIM
  module BIMserver
    
  
    # Load ui elements
    require File.join(PLUGIN_PATH, 'ui.rb')
    
    
    PLUGIN_PATH_IMAGE = File.join(PLUGIN_PATH, 'images')
    PLUGIN_PATH_CSS   = File.join(PLUGIN_PATH, 'css')
    
    
    # Load common ui elements
    load File.join(AUTHOR_PATH, 'lib', 'ui.rb')
    
    # BIMserver toolbar command
    
    cmd = UI::Command.new("BIMserver") {
      window = BIMserverWindow.new()
    }
    cmd.small_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_small.png')
    cmd.large_icon = File.join(PLUGIN_PATH_IMAGE, 'bimserver_large.png')
    cmd.tooltip = "Upload to BIMserver"
    cmd.status_bar_text = "Open BIMserver connection window"
    
    # add BIMserver tool to toolbar
    OpenSourceBIM::OsBimUI.add_item( cmd )
    


  end # module BIMserver
end # module OpenSourceBIM
