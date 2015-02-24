#  ui.rb
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

# Common toolbar for opensourceBIM

require 'sketchup'

module OpenSourceBIM
  module OsBimUI
    extend self
  
    # Create toolbar containing all available OpenSourceBIM tools.
    @toolbar = UI::Toolbar.new "opensourceBIM"
    @toolbar.show
    
    # Add tool to toolbar and dialog
    # - name must be a "String"
    # - toolbar_command must be a "UI::Command"
    # - dialog_section must be a ...
    def add_item(toolbar_command)
      @toolbar.add_item toolbar_command
    end
  end # OsBimUI
end # module OpenSourceBIM
