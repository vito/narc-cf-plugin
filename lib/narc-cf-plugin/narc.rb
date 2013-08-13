require 'eventmachine'
require "em-ssh"
require "highline"

module NarcCfPlugin
  class Narc
    def initialize(host, port, task_id)
      @host = host
      @port = port
      @task_id = task_id
    end

    class SSHInputForwarder < EM::Connection
      def initialize(channel)
        @channel = channel
      end

      def receive_data(data)
        @channel.send_data(data)
      end

      def post_init
        `stty raw -echo`

        trap("WINCH") { send_window_change }
      end

      def unbind
        `stty -raw echo`
      end

      private

      def send_window_change
        cols, rows = terminal_size

        @channel.send_channel_request "window-change",
          :long, cols,
          :long, rows,
          :long, 0,
          :long, 0
      end

      def send_signal(name)
        @channel.send_channel_request "signal",
          :string, name
      end

      def terminal_size
        HighLine::SystemExtensions.terminal_size
      end
    end

    class TCPForwardedSSHConnection < EM::Ssh::Connection
      def post_init
        send_data("GET / HTTP/1.1\r\n")
        send_data("Host: #{@options[:host]}\r\n")
        send_data("Upgrade: tcp\r\n")
        send_data("Connection: Upgrade\r\n")
        send_data("\r\n")
        send_data("\r\n")

        super
      end
    end

    def listen(task, secure_token)
      EM.run do
        EM.connect(@host, @port, TCPForwardedSSHConnection,
                    :user => task, :password => secure_token, :host => @task_id,
                    :auth_methods => %w[password]) do |connection|
          connection.errback do |err|
            $stderr.puts "#{err.class}: #{err}"
            EM.stop
          end

          connection.callback do |ssh|
            channel = ssh.open_channel do |ch|
              ch.on_data do |_, data|
                print data
              end

              cols, rows = HighLine::SystemExtensions.terminal_size

              ch.request_pty :term => "xterm", :chars_wide => cols, :chars_high => rows do |ch, success|
                raise "failed to request pty" unless success

                ch.send_channel_request "shell" do |ch, success|
                  raise "failed to request shell" unless success

                  EM.open_keyboard(SSHInputForwarder, ch)
                end
              end
            end

            channel.wait
            ssh.close

            EM.stop
          end
        end
      end
    end
  end
end
