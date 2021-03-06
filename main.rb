require 'rubygems'
require 'sinatra'
require 'haml'
require 'AWS'

set :views, File.join(File.dirname(__FILE__),'views')

AWS_KEY = ENV['AWS_KEY']
AWS_SECRET = ENV['AWS_SECRET']

class Metric

  def self.all
    @metrics ||= Metric.get_metrics
  end

  def self.get(id)
    Metric.all
    @metric = @metrics[id.to_i-1]

    @now = DateTime.now
    if @metric[:data].empty?
      d = `mon-get-stats #{@metric[:name]} --end-time #{@now.to_s} --start-time #{(@now-1).to_s} --period 60 --namespace #{@metric[:namespace]} --statistics "Average" --statistics "Sum" --statistics "Maximum" --statistics "Minimum"`
    else
      d = `mon-get-stats #{@metric[:name]} --end-time #{@now.to_s} --start-time #{(@now-1).to_s} --period 60 --namespace #{@metric[:namespace]} --statistics "Average" --statistics "Sum" --statistics "Maximum" --statistics "Minimum" --dimensions "#{@metric[:data].gsub('{','').gsub('}','')}"`
    end

    @data = []
    d.each_line("\n") do |line|
      matches = line.match(/^([-:\d\s]+)\s+([\d.]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([\d.E-]*)\s*([^\s]*)\s*$/)
      @data.push({
        :date => Time.parse(matches[1]) - 5*60*60,
        :samples => matches[2],
        :average => matches[3],
        :sum => matches[4],
        :maximum => matches[5],
        :minimum => matches[6],
        :unit => matches[7]
      })
    end

    return {:metric => @metric, :data => @data}

  end

  private

  def self.get_metrics

  end
end

@@acw = AWS::Cloudwatch::Base.new(:access_key_id => AWS_KEY,
  :secret_access_key => AWS_SECRET)

get '/' do
  @metrics = @@acw.list_metrics['ListMetricsResult']['Metrics']['member'].group_by{|m|
    m['Namespace']
  }
  haml :index
end

get '/metrics/:namespace/:metric' do
  opts = {
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60)
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

get '/metrics/:namespace/:metric/:range' do
  range = params[:range].to_i
  period = (range * 24 * 60 * 60)/1440
  opts = {
    :period => period,
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60*range),
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end


get '/metrics/:namespace/:metric/:dimension_name/:dimension_value' do
  opts = {
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60),
    :dimensions => {"#{params[:dimension_name]}" => "#{params[:dimension_value]}"}
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

get '/metrics/:namespace/:metric/:dimension_name/:dimension_value/:range' do
  range = params[:range].to_i
  period = (range * 24 * 60 * 60)/1440
  opts = {
    :period => period,
    :statistics => ['Sum', 'Average', 'Maximum', 'Minimum'],
    :measure_name => params[:metric],
    :namespace => params[:namespace].gsub('_', '/'),
    :end_time => Time.now.utc,
    :start_time => Time.now.utc - (24*60*60*range),
    :dimensions => {"#{params[:dimension_name]}" => "#{params[:dimension_value]}"}
  }
  @metric = params[:metric]
  @data = get_metrics(opts)
  haml :show
end

def get_metrics(opts)
  d = @@acw.get_metric_statistics(opts)
  return d['GetMetricStatisticsResult']['Datapoints']['member']
end
