require 'mongo'
include Mongo

class ECMongo
    @@db = nil
    @@fs = nil

    def self.connect()
        if @@db.nil?
            @@db = MongoClient.new('127.0.0.1', 27017).db("EuroCup")
        end
    end

    def self.connectFS()
        EEMongo.connect
        if @@fs.nil?
            @@fs = Grid.new(@@db)
        end
    end

    def self.getCollection(name)
        EEMongo.connect
        return @@db.collection(name)
    end


    def set_file(file, fn)
        EEMongo.connectFS 
        ## Make this over write to avoid conflicts    
        @@fs.delete(fn)
        id = @@fs.put(file[:tempfile], :filename => fn, :_id => fn)
        id.to_s
    end   
 
    def display_file(id)
        file = EEMongo.get_file(id)

        [200, {'Content-type' => 'image/png'}, [file.read]]
    end

    def self.get_file(id)
        @@fs = Grid.new(@@db)
        file = @@fs.get(id)
        file
    end

end
