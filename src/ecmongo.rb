require 'mongo'
#include Mongo

class ECMongo
    @@db = nil
    @@fs = nil

    def self.connect()
        if @@db.nil?
            @@db = Mongo::Client.new([ 'localhost:27017' ], :database => 'TestEuroCup')
            #([ '192.168.56.102:27017' ], :database => 'convoos')
        end
    end

    def self.connectFS()
        ECMongo.connect
        if @@fs.nil?
            @@fs = Grid.new(@@db)
        end
    end

    def self.getCollection(name)
        ECMongo.connect
        return @@db[name]
    end

    def set_file(file, fn)
        ECMongo.connectFS 
        ## Make this over write to avoid conflicts    
        @@fs.delete(fn)
        id = @@fs.put(file[:tempfile], :filename => fn, :_id => fn)
        id.to_s
    end   
 
    def display_file(id)
        file = ECMongo.get_file(id)

        [200, {'Content-type' => 'image/png'}, [file.read]]
    end

    def self.get_file(id)
        @@fs = Grid.new(@@db)
        file = @@fs.get(id)
        file
    end

end


#db = Mongo::Client.new([ 'localhost:27017' ], :database => 'testStuff')
#db.create_collection("fuckYeah")

