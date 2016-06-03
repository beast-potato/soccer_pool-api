class Utils

    def self.newID
        id = (0...6).map { ('A'..'Z').to_a[rand(26)] }.join
        id += Time.new.to_i.to_s
        return id
    end 

    def self.Encrypt(text)
        c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
        c.encrypt
        c.key = Digest::SHA1.hexdigest("q1w2e3r4t5y6")
        e = c.update(text)
        e << c.final
        temp = Base64.encode64(e)
        return temp
    end

    def self.Decrypt(text)
        temp = Base64.decode64(text)
        c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
        c.decrypt
        c.key = Digest::SHA1.hexdigest("q1w2e3r4t5y6")
        d = c.update(temp)
        d << c.final
        return d
    end
end
