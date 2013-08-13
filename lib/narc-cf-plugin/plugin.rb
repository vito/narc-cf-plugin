require 'cf'

module NarcCfPlugin
  require 'narc-cf-plugin/narc'

  class Plugin < CF::CLI
    include LoginRequirements

    def precondition; end

    desc "Application narc... we tell everything"
    input :task, :argument => :required
    input :secure_token, :argument => :optional, :default => ""
    def narc
      narc = Narc.new("127.0.0.1", 8082, input[:task])
      narc.listen(input[:task], input[:secure_token])
    end
  end
end
