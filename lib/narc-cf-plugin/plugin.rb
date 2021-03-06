require 'cf'

module NarcCfPlugin
  begin
    require 'narc-cf-plugin/narc'
  rescue LoadError
    require 'narc-cf-plugin/narc_sucky'
  end

  class Plugin < CF::CLI
    include LoginRequirements

    def precondition; end

    desc "Application narc... we tell everything"
    input :app, :argument => :required, :from_given => by_name(:app)
    def narc
      app = input[:app]

      task_response = client.base.post(
        "v2", "tasks",
        :content => :json, :accept => :json,
        :payload => { :app_guid => app.guid })

      task_guid = task_response[:metadata][:guid]
      task_token = task_response[:entity][:secure_token]

      narc_host = client.target.gsub(/https?:\/\/(.*)\/?/, '\1')
      narc = Narc.new(client.target, task_guid, use_ssl?)

      narc.connect(task_guid, task_token)
    ensure
      client.base.delete("v2", "tasks", task_guid) if task_guid
    end

    private

    def use_ssl?
      client.target.start_with?("https")
    end
  end
end
