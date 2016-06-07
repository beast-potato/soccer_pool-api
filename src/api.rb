get '/images/:filename' do
    puts params["filename"]
    send_file File.join(settings.public_folder, 'images/' + params['filename'])
end
