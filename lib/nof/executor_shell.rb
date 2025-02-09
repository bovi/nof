# a Shell task executes a shell command at a given interval,
# formats the output and reports the result
class Executor
  def run_shell_task(task)
    interval = task['opts']['interval'].to_i
    command = task['opts']['cmd']
    pattern = task['opts']['pattern']
    template = task['opts']['template']

    url = URI("http://#{Controller.host}:#{Controller.port}/report")
    request = Net::HTTP::Post.new(url, 'Content-Type' => 'application/json')

    # Create formatter lambda if pattern and template are provided
    formatter = if pattern && template
      ->(result) {
        return result if result.empty?
        if matches = result.match(/#{pattern}/)
          formatted = template.dup
          matches.named_captures.each do |name, value|
            formatted = formatted.gsub("{#{name}}", value)
          end
          formatted
        else
          result
        end
      }
    else
      ->(result) { result }
    end

    while running?
      begin
        result = `#{command}`
        result = formatter.call(result)

        request.body = {
          'uuid' => task['uuid'],
          'result' => result.strip,
          'timestamp' => Time.now.to_i
        }.to_json

        Net::HTTP.start(url.hostname, url.port) do |http|
          response = http.request(request)
          warn "Error reporting result: #{response.code}" unless response.code == '200'
        end
      rescue StandardError => e
        err "Task execution failed: #{e.message}"
      end

      sleep interval
    end
  end
end