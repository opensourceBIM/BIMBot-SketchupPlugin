#  profiles.rb
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

# Profiles class

require 'yaml'
require 'digest'

module OpenSourceBIM
  module BIMserver

    require File.join( PLUGIN_PATH, 'profile.rb' )
    require File.join( PLUGIN_PATH, 'connection.rb' )

    class Profiles
      attr_reader :conn, :profiles
      def initialize()

        # Set config file
        pathname = File.expand_path( File.dirname(__FILE__) )
        @filepath = File.join(pathname, 'config.yml')

        @profiles = Array.new()
        read_config
      end

      def active_profile()
        if @active_profile.nil?
          set_active_profile
        end
        return @active_profile
      end

      def get_profile_by_name( name )
        profiles = @profiles.select {|profile| profile.name == name }
        return profiles.first
      end

      def delete_profile( profile )
        @profiles.delete( profile )
        set_active_profile
        write_config
      end

      def set_connection( profile )
        
        # (?) Always recreating the connection takes time, but the active profile can be changed, then it needs to reconnect
        
        #if $conn.nil?
        #  $conn = BIMserver::Connection.new( profile )
        #elsif $conn.profile == BIMserver.profiles.active_profile
        #  return $conn
        #else
          $conn = BIMserver::Connection.new( profile )
        #end
      end

      def set_active_profile( name=nil )

        # find profile "name"
        if name.nil?
          unless @active_profile.class.name == "Profile"
            if @profiles.length == 0
              @active_profile = Profile.new()
              add_profile( @active_profile )
            else
              @active_profile = @profiles.first
            end
          end
        else
          profile = get_profile_by_name( name )
          if profile.nil?
            if @profiles.length == 0
              @active_profile = Profile.new()
              add_profile( @active_profile )
            else
              @active_profile = @profiles.first
            end
          else
            @active_profile = profile
          end
        end
        
        # only if there is a valid profile create connection and store profile hash
        unless @active_profile.nil?
          set_connection( @active_profile )

          # store default profile md5 hash inside SketchUp model
          md5 = Digest::MD5.new
          md5.update @active_profile.to_hash.to_s
          Sketchup.active_model.set_attribute( 'OpenSourceBIM', 'BIMserver_profile', md5.to_s )
        end
      end

      def names
        return @profiles.map{|profile| profile.name}
      end

      def write_config

        config = Array.new
        @profiles.each do | profile |
          config  << profile.to_hash
        end
        File.open(@filepath, 'w') {|f| f.write config.to_yaml } #Store
      end

      def read_config

        # load config file
        config = YAML::load_file(@filepath)

        config.each do | profile |
          add_profile( Profile.new(profile[:name], profile[:address], profile[:port], profile[:username], profile[:password], profile[:project], profile[:project_oid]) )
        end

        # get profile stored inside SketchUp
        stored = Sketchup.active_model.get_attribute( 'OpenSourceBIM', 'BIMserver_profile', "" )
        @profiles.each do | value |
          md5 = Digest::MD5.new
          md5.update value.to_hash.to_s
          if md5 == stored
            set_active_profile( value.name )
          end
        end
        if @active_profile.nil?
          set_active_profile
        end
      end

      def add_profile( profile )        
        @profiles << profile
      end
    end # class Profiles
  end # module BIMserver
end # module OpenSourceBIM