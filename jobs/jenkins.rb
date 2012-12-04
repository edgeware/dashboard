jenkins_host = 'augustus'
img_path = '/static/foo/images/48x48/'
port = 8080

last_builds = {}

SCHEDULER.every '10s', :first_in => 0 do |foo|
  http = Net::HTTP.new(jenkins_host, port)
  response = http.request(Net::HTTP::Get.new("/api/json?depth=1"))
  jobs = JSON.parse(response.body)["jobs"]

  builds = []

  jobs.map! do |job|
    name = job['name']
    cov_path = "/job/#{name}/lastBuild/cobertura/api/json?depth=2"
    response = http.request(Net::HTTP::Get.new(cov_path))
    coverage = nil
    if response.code == '200'
      elements = JSON.parse(response.body)['results']['elements']
      elements.map! do |element|
        if element['name'] == 'Conditionals'
          coverage = element['ratio']
        end
      end
    end

    color = job['color'].sub('blue', 'green')
    status = case color
               when 'green' then 'Success'
               when 'yellow' then 'Unstable'
               when 'disabled' then 'Disabled'
               when 'gray' then 'Disabled'
               when 'aborted' then 'Aborted'
               when 'green_anime' then 'Building'
               when 'red_anime' then 'Building'
               when 'gray_anime' then 'Building'
               when 'aborted_anime' then 'Building'
               when 'yellow_anime' then 'Building'
               else 'Failure'
             end
    icon_url = job['healthReport'][0]['iconUrl']
    health_url = "http://#{jenkins_host}:#{port}#{img_path}#{icon_url}"
    desc = job['description']
    build = {
      name: name, status: status, health: health_url, color: color
    }
    desc.empty? || build['desc'] = desc
    coverage && build['coverage'] = coverage.to_i.to_s + '%'
    builds << build
  end

  if builds != last_builds
    puts builds
    last_builds = builds
    send_event('jenkins', { items: builds })
  end
end
