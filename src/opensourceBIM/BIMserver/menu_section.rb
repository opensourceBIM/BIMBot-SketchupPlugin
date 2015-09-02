#  menu_section.rb
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

module OpenSourceBIM
  module BIMserver
    class MenuSection
      def initialize( name, window, maximized=true )
        @name = name
        @window = window.window
        @bs_window = window
        @group = SKUI::Groupbox.new( name )
        @maximized = maximized
        
        # add minimize button
        image = File.join(PLUGIN_PATH_IMAGE, 'minimize.png')
        @button = SKUI::Button.new( "" ) { |control|
          if @maximized == true
            minimize
          else
            maximize
          end
        }
        @button.background_image = image
        @button.width = 22
        @button.height = 24
        @button.css_class( 'icon' )
        
        @window.add_control( @button )
        @window.add_control( @group )
      end

      def minimize
        @maximized = false
        @group.controls.each do |control|
          control.visible = false
          @group.height = 0
        end
        @button.background_image = File.join(PLUGIN_PATH_IMAGE, 'maximize.png')
      end

      def maximize
        @maximized = true
        @group.controls.each do |control|
          control.visible = true
        end
        if @bs_window.ready
          id = @group.ui_id
          @window.bridge.call( "$('#" + id + "').css('height', 'auto')" )
        end
        @button.background_image = File.join(PLUGIN_PATH_IMAGE, 'minimize.png')
      end
      
      def set_size
        if @maximized == true
          maximize
        else
          minimize
        end
      end

      def add_control( control, name=nil )
        unless name.nil?
          #if control.is_a? SKUI::Textbox or control.is_a? SKUI::Listbox
            label = SKUI::Label.new( name.capitalize + ':', control )
            @group.add_control( label )
          #end
        end
        @group.add_control( control )
      end
    end # class MenuSection
  end # module BIMserver
end # module OpenSourceBIM