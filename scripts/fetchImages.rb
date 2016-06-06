require 'json'
require 'net/http'
require 'rsvg2'
require 'nokogiri'


def svg_to_png(svg, width, height)
    svg = RSVG::Handle.new_from_data(svg)
    #width   = width  ||=500
    #height  = height ||=500
    surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, width, height)
    context = Cairo::Context.new(surface)
    context.render_rsvg_handle(svg)
    b = StringIO.new
    surface.write_to_png(b)
    return b.string
end

uri = URI('http://api.football-data.org/v1/soccerseasons/424/teams')
data = JSON.parse(Net::HTTP.get(uri))

teams = data["teams"]
for team in teams
	url = URI(team["crestUrl"])
    puts team["crestUrl"]
    imageInfo = Net::HTTP.get(url)
    #puts imageInfo
    doc = Nokogiri::XML(imageInfo)
    node = doc.xpath("//xmlns:svg").first
    
    width = node.attr("width")
    height = node.attr("height")

    puts "Width:" + width + " Height:" + height
    
    png = svg_to_png(imageInfo, width.to_i, height.to_i)
    fileName = "../public/images/"+team["name"]+ ".png"
    File.open(fileName, 'w') { |file| file.write(png) }
end


