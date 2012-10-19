description 'Asset manager'

class ::Olelo::Application
  @assets = {}
  @scripts = {}

  class << self
    attr_reader :assets, :scripts
  end

  attr_reader? :disable_assets

  hook :head, 2 do
    return if disable_assets?
    js = Application.scripts['js']
    css = Application.scripts['css']
    result = ''
    if css
      path = build_path "_/assets/assets.css?#{css.first.to_i}"
      result << %{<link rel="stylesheet" href="#{escape_html path}" type="text/css"/>}
    end
    if js
      path = build_path "_/assets/assets.js?#{js.first.to_i}"
      result << %{<script src="#{escape_html path}" type="text/javascript"/>}
    end
    result
  end

  get "/_/assets/assets.:type", :type => 'js|css' do
    if script = Application.scripts[params[:type]]
      cache_control :last_modified => script.first, :max_age => :static
      response['Content-Type'] = MimeMagic.by_extension(params[:type]).to_s
      response['Content-Length'] = script.last.bytesize.to_s
      script.last
    else
      :not_found
    end
  end

  get "/_/assets/:name", :name => '.*' do
    if asset = Application.assets[params[:name]]
      if path = asset.real_path
        file = Rack::File.new(nil)
        file.path = path
        file.serving(env)
      else
        cache_control :last_modified => asset.mtime, :max_age => :static
        response['Content-Type'] = (MimeMagic.by_path(asset.name) || 'application/octet-stream').to_s
        response['Content-Length'] = asset.size.to_s
        asset.read
      end
    else
      :not_found
    end
  end
end

class ::Olelo::Plugin
  def export_assets(*files)
    virtual_fs.glob(*files) do |file|
      Application.assets[plugin_dir/file.name] = file
    end
  end

  def export_scripts(*files)
    virtual_fs.glob(*files) do |file|
      raise 'Invalid script type' if file.name !~ /\.(css|js)$/
      scripts = Application.scripts[$1].to_a
      Application.scripts[$1] = [[scripts[0], file.mtime].compact.max, "#{scripts[1]}/* #{plugin_dir/file.name} */\n#{file.read}\n"]
    end
  end

  def plugin_dir
    if File.basename(file) == 'main.rb'
      path
    else
      File.dirname(path)
    end
  end
end
