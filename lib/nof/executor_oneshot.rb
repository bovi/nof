# a Shell task executes a shell command at a given interval,
# formats the output and reports the result
class Executor
  def run_oneshot_job(job)
    command = job['opts']['cmd']
    pattern = job['opts']['pattern']
    template = job['opts']['template']

    url = URI("http://#{Controller.host}:#{Controller.port}/report")
    request = Net::HTTP::Post.new(url)

    # Create formatter lambda if pattern and template are provided
    formatter = if pattern && template
      ->(result) {
        return result if result.empty?
        if matches = result.match(/#{pattern}/)
          formatted = template.dup
          matches.named_captures.each do |name, value|
            formatted = formatted.gsub("\#{#{name}}", value)
          end
          formatted
        else
          result
        end
      }
    else
      ->(result) { result }
    end

    begin
      result = `#{command}`
      result = formatter.call(result)
      request.set_form_data({
        'uuid' => job['uuid'],
        'result' => result,
        'timestamp' => Time.now.to_i
      })
      Net::HTTP.start(url.hostname, url.port) do |http|
        response = http.request(request)
        warn "Error reporting result: #{response.code}" unless response.code == '200'
      end
    rescue StandardError => e
      err "Oneshot job execution failed: #{e.class}: #{e.message}"
    end
  end
end