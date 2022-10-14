# frozen_string_literal: true

require "typhoeus"
require "json"
require "time"
require "openssl"

module Transfertpro
  # This class is used as a base for main classes of the api to provide default operations like connection
  class Base
    ROUTE_PREFIX_BASE = "api/Account/"
    API_KEY_NAME = "apiKeyName"
    NONCE_NAME = "nonce"
    HASH_KEY_NAME = "hash"
    HASH_SEPARATOR = "|"
    CTIMEOUT = 30

    ADDRESSES = {
      default: {
        api: "https://ext.transfertpro.com",
        download: "https://dl.transfertpro.com",
        upload: "https://up.transfertpro.com"
      },
      hds: {
        api: "https://ext-sante.transfertpro.com",
        download: "https://dl-sante.transfertpro.com",
        upload: "https://up-sante.transfertpro.com"
      }
    }.freeze

    def token_expired? = @token_expiration_date.present? && @token_expiration_date < 1.hour.since

    def initialize(api_key, secret_key, tenant = :default)
      @tenant = tenant
      raise Transfertpro::Error, "tenant must be one of #{ADDRESSES.keys.join(",")}" unless ADDRESSES.key?(tenant)

      @api_url = ADDRESSES[@tenant][:api]
      @download_url = ADDRESSES[@tenant][:download]
      @upload_url = ADDRESSES[@tenant][:upload]
      @api_key = api_key
      @secret_key = secret_key
    end

    def login_required? = !@is_connected || @token.nil?

    # || @token_expiration_date < 1.minute.since

    # login to TransfertPro using regular user mail & password
    #
    # @param user String user email to log in
    # @param password String user password
    #
    def connect(user, password)
      raise Transfertpro::Error, "user(#{user}) should be set" if user.nil? || user.empty?
      raise Transfertpro::Error, "password(#{password}) should be set" if password.nil? || password.empty?

      @user = user
      @password = password
      reconnect
    end

    def disconnect
      @is_connected = false
      @token = nil
      @token_expiration_date = nil
    end

    def headers
      { Authorization: "Bearer #{@token}" }
    end

    def authentication_parameters
      nonce = Time.now.nsec
      to_hash = "apiKeyName|#{@api_key}|nonce|#{nonce}|#{@secret_key}"
      {
        apiKeyName: @api_key,
        nonce:,
        hashkey: hmac(to_hash)
      }
    end

    private

    def hmac(data)
      digest = OpenSSL::Digest.new("sha512")
      OpenSSL::HMAC.hexdigest(digest, @secret_key, data)
    end

    def reconnect
      body = { grant_type: "password", username: @user, password: @password }
      url = "#{@api_url}/Token"
      response = Typhoeus.post(url, connecttimeout: CTIMEOUT, ssl_verifypeer: true, verbose: false, body:)
      unless response.success?
        raise Transfertpro::Error, "Unable to connect to TransfertPro url #{url}, response code=#{response.code}"
      end

      response_body = JSON.parse(response.body)
      @token_expiration_date = DateTime.parse(response_body[".expires"])
      @token = response_body["access_token"]
      @is_connected = true
    end
  end
end
