class EEBase
    @obj = nil
    
    def initialize(obj)
        @obj = obj
        if @obj['_id'].nil?
            @obj['_id'] = EE.newID
        end
    end

    def getObj
        return @obj
    end

    def self.CollectionName
        return "tempCollection"
    end

    def self.Collection
        return EEMongo.getCollection(self.class.CollectionName)
    end

    def save
        coll = self.class.Collection
        coll.update({"_id" => @obj['_id']},@obj,{:upsert => true})
    end

end
