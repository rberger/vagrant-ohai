require 'vagrant-ohai/helpers'

module VagrantPlugins
  module Ohai
    class ActionInstallOhaiPlugin
      OHAI_PLUGIN_PATH = File.expand_path("../../ohai/vagrant.rb", __FILE__)

      include VagrantPlugins::Ohai::Helpers

      def initialize(app, env)
        @app = app
        @env = env
        @machine = env[:machine]
      end

      def call(env)
        @app.call(env)
        return unless @machine.communicate.ready?

        if chef_provisioners.any? and @machine.config.ohai.enable
          @machine.ui.info("Installing Ohai plugin")
          create_ohai_folders
          copy_ohai_plugin
          hint_ohai
        end
      end

      private
      def create_ohai_folders
        @machine.communicate.tap do |comm|
          comm.sudo("mkdir -p /etc/chef/ohai/hints")
          comm.sudo("mkdir -p /etc/chef/ohai_plugins")
          comm.sudo("chown -R #{@machine.ssh_info[:username]} /etc/chef/ohai/hints /etc/chef/ohai_plugins")
        end
      end

      def private_ipv4
        @private_ipv4 ||= @machine.config.vm.networks.find {|network| network.first == :private_network}[1][:ip]
      rescue
        nil
      end

      def vagrant_info
        info = {}
        info[:private_ipv4] = private_ipv4 if private_ipv4
        info[:box] = @machine.config.vm.box
        info[:primary_nic] = @machine.config.ohai.primary_nic
        info
      end

      def hint_ohai
        hint_file = Tempfile.new(["vagrant-ohai", ".json"])
        hint_file.write(vagrant_info.to_json)
        hint_file.close
        @machine.communicate.upload(hint_file.path, "/etc/chef/ohai/hints/vagrant.json")
      end

      def copy_ohai_plugin
        @machine.communicate.upload(OHAI_PLUGIN_PATH, "/etc/chef/ohai_plugins/vagrant.rb")
      end

    end
  end
end
