
require 'rex/socket'

module Rex::SSLScan
class Result

	attr_reader :ciphers
	attr_reader :supported_versions

	def initialize()
		@cert = nil
		@ciphers = []
		@supported_versions = [:SSLv2, :SSLv3, :TLSv1]
	end

	def cert
		@cert
	end

	def cert=(input)
		unless input.kind_of? OpenSSL::X509::Certificate or input.nil?
			raise ArgumentError, "Must be an X509 Cert!" 
		end
		@cert = input
	end

	def sslv2
		@ciphers.reject{|cipher| cipher[:version] != :SSLv2 }
	end

	def sslv3
		@ciphers.reject{|cipher| cipher[:version] != :SSLv3 }
	end

	def tlsv1
		@ciphers.reject{|cipher| cipher[:version] != :TLSv1 }
	end

	def weak_ciphers
		@ciphers.reject{|cipher| cipher[:weak] == false }
	end

	def strong_ciphers
		@ciphers.reject{|cipher| cipher[:weak] }
	end

	def accepted(version = :all)
		if version.kind_of? Symbol
			case version
			when :all
				return @ciphers.reject{|cipher| cipher[:status] == :rejected}
			when :SSLv2, :SSLv3, :TLSv1
				return @ciphers.reject{|cipher| cipher[:status] == :rejected or cipher[:version] != version}
			else
				raise ArgumentError, "Invalid SSL Version Supplied: #{version}"
			end
		elsif version.kind_of? Array 
			version.reject!{|v| !(@supported_versions.include? v)}
			if version.empty?
				return @ciphers.reject{|cipher| cipher[:status] == :rejected}
			else
				return @ciphers.reject{|cipher| cipher[:status] == :rejected or !(version.include? cipher[:version])}
			end
		else
			raise ArgumentError, "Was expecting Symbol or Array and got #{version.class}"
		end
	end

	def rejected(version = :all)
		if version.kind_of? Symbol
			case version
			when :all
				return @ciphers.reject{|cipher| cipher[:status] == :accepted}
			when :SSLv2, :SSLv3, :TLSv1
				return @ciphers.reject{|cipher| cipher[:status] == :accepted or cipher[:version] != version}
			else
				raise ArgumentError, "Invalid SSL Version Supplied: #{version}"
			end
		elsif version.kind_of? Array 
			version.reject!{|v| !(@supported_versions.include? v)}
			if version.empty?
				return @ciphers.reject{|cipher| cipher[:status] == :accepted}
			else
				return @ciphers.reject{|cipher| cipher[:status] == :accepted or !(version.include? cipher[:version])}
			end
		else
			raise ArgumentError, "Was expecting Symbol or Array and got #{version.class}"
		end
	end

	def each_accepted(version = :all)
		accepted(version).each do |cipher_result|
			yield cipher_result
		end
	end

	def each_rejected(version = :all)
		rejected(version).each do |cipher_result|
			yield cipher_result
		end
	end

	def supports_sslv2?
		!(accepted(:SSLv2).empty?)
	end

	def supports_sslv3?
		!(accepted(:SSLv3).empty?)
	end

	def supports_tlsv1?
		!(accepted(:TLSv1).empty?)
	end

	def supports_ssl?
		supports_sslv2? or supports_sslv3? or supports_tlsv1?
	end

	def supports_weak_ciphers?
		!(weak_ciphers.empty?)
	end

	def standards_compliant?
		if supports_ssl?
			return false if supports_sslv2?
			return false if supports_weak_ciphers?
		end
		true
	end

	def add_cipher(version, cipher, key_length, status)
		unless @supported_versions.include? version
			raise ArgumentError, "Must be a supported SSL Version"
		end
		unless OpenSSL::SSL::SSLContext.new(version).ciphers.flatten.include? cipher
			raise ArgumentError, "Must be a valid SSL Cipher for #{version}!"
		end
		unless key_length.kind_of? Fixnum
			raise ArgumentError, "Must supply a valid key length"
		end
		unless [:accepted, :rejected].include? status
			raise ArgumentError, "status Must be either :accepted or :rejected"
		end

		strong_cipher_ctx = OpenSSL::SSL::SSLContext.new(version)
		strong_cipher_ctx.ciphers = "ALL:!aNULL:!eNULL:!LOW:!EXP:RC4+RSA:+HIGH:+MEDIUM"
		
		if strong_cipher_ctx.ciphers.flatten.include? cipher
			weak = false
		else
			weak = true
		end

		cipher_details = {:version => version, :cipher => cipher, :key_length => key_length, :weak => weak, :status => status}
		@ciphers << cipher_details
		@ciphers.uniq!
	end
end
end