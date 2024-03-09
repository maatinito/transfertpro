# frozen_string_literal: true

require_relative "base"
require "securerandom"

module Transfertpro
  # class to use to upload and download files to Transfertpro file system
  class FileSystem < Base
    CHUNK_SIZE = 8 * 1024 * 1024

    # upload local files to a TP shared directory
    # @param source_directory String local path
    # @param pattern String pattern used to find local files to upload
    # @param target_directory String target path on TransfertPro. Must be relative to 'Collaborative workspace'
    # @example upload_shared_files('./source', '*.txt', 'my_project/text')
    def upload_shared_files(source_directory, pattern, target_directory, move: false)
      upload_files(source_directory, pattern, ":Share/#{target_directory}", move:)
    end

    # upload a file to a TP shared directory
    # @param input_file_path String path to local input file to upload
    # @param target_directory String target path on TransfertPro. Must be relative to 'Espace collaboratif'
    # @example: upload_shared_file('./source/file.txt', 'my_project/text')
    def upload_shared_file(input_file_path, target_directory, move: false)
      upload_file(input_file_path, ":Share/#{target_directory}", move:)
    end

    # download files from a shared directory
    # @param source_directory String Source path on TransfertPro. Must be relative to 'Espace collaboratif'
    # @param pattern String pattern used to find remote files to download
    # @param target_directory local path where files must be downloaded
    # @example download_shared_files('my_project/text', '*.txt', './target')
    def download_shared_files(source_directory, pattern, target_directory, move: false)
      download_files(":Share/#{source_directory}", pattern, target_directory, move:)
    end

    # download file from a shared directory
    # @param input_file_path String TP file path relative to the shared root ('Espace collaboratif')
    # @param target_directory String local directory where to download the file
    # @example download_shared_file('my_project/text/file.txt', './target')
    def download_shared_file(input_file_path, target_directory, move: false)
      download_file(":Share/#{input_file_path}", target_directory, move:)
    end

    # list file names in a given directory
    # @param directory relative to shared root ('Espace collaboratif')
    # @param pattern String file pattern to match for
    # @example list_shared_files('my_project/text', '*.txt')
    # @return Array<String> file paths relative to shared root
    def list_shared_files(directory, pattern = "*")
      list_files(":Share/#{directory}")
    end

    # delete files
    def delete_shared_files(directory, pattern = "*")
      delete_files(":Share/#{directory}", pattern)
    end

    #----------------- generic versions

    # upload local files to a TP shared directory
    # @param source_directory String local path
    # @param pattern String pattern used to find local files to upload
    # @param target_directory String target path on TransfertPro. Must be relative to 'Collaborative workspace'
    # @example upload_shared_files('./source', '*.txt', 'my_project/text')
    def upload_files(source_directory, pattern, target_directory, move: false)
      tp_target_dir = find_dir(target_directory)
      r = []
      Dir.glob("#{source_directory}/#{pattern}").each do |filepath|
        upload_file(filepath, tp_target_dir, move:)
        r << File.basename(filepath)
      end
      r
    end

    # upload a file to a TP shared directory
    # @param input_file_path String path to local input file to upload
    # @param target_directory String target path on TransfertPro. Must be relative to 'Espace collaboratif'
    # @example: upload_shared_file('./source/file.txt', 'my_project/text')
    def upload_file(input_file_path, target_directory, move: false)
      unless target_directory.is_a?(Hash) && !target_directory["DirectoryId"].nil?
        target_directory = find_dir(target_directory.to_s)
      end
      file_description = file_description(input_file_path, target_directory)
      share_id = target_directory["CurrentSharedDirectoryId"]
      upload_file_description(file_description, share_id)
      upload_content(input_file_path, file_description, share_id)
      File.unlink(input_file_path) if move
    end

    # download files from a shared directory
    # @param source_directory String Source path on TransfertPro. Must be relative to 'Espace collaboratif'
    # @param pattern String pattern used to find remote files to download
    # @param target_directory local path where files must be downloaded
    # @example download_shared_files('my_project/text', '*.txt', './target')
    def download_files(source_directory, pattern, target_directory, move: false)
      tp_dir = find_dir(source_directory)
      tp_files = tp_dir["Files"]["$values"].filter { |file| File.fnmatch(pattern, file["FileName"]) }
      tp_files.map do |tp_file|
        download_tp_file(target_directory, tp_dir, tp_file, move)
      end
      to_filenames(tp_files)
    end

    # download file from a shared directory
    # @param input_file_path String TP file path relative to the shared root ('Espace collaboratif')
    # @param target_directory String local directory where to download the file
    # @example download_shared_file('my_project/text/file.txt', './target')
    def download_file(input_file_path, target_directory, move: false)
      directory = File.dirname(input_file_path)
      tp_dir = find_dir(directory)
      filename = File.basename(input_file_path)
      tp_file = tp_dir["Files"]["$values"].find { |file| filename == file["FileName"] }
      raise Error, "Unable to find #{filename} in directory #{directory}" if tp_file.nil?

      download_tp_file(target_directory, tp_dir, tp_file, move)
    end

    # list file names in a given directory
    # @param directory path relative to choosen root ('Shared' or "MyFiles")
    # @param pattern String file pattern to match for
    # @example list_shared_files('my_project/text', '*.txt')
    # @return Array<String> file paths relative to shared root
    def list_files(directory, pattern = "*")
      tp_dir = find_dir(directory)
      tp_dir["Files"]["$values"].filter { |file| File.fnmatch(pattern, file["FileName"]) }.map { |f| f["FileName"] }
    end

    def delete_files(directory, pattern = "*")
      tp_dir = find_dir(directory)
      tp_files = tp_dir["Files"]["$values"].filter { |file| File.fnmatch(pattern, file["FileName"]) }
      tp_files.map do |tp_file|
        delete_file(tp_dir, tp_file)
      end
      to_filenames(tp_files)
    end

    private

    def to_filenames(tp_files)
      tp_files.map { |f| f["FileName"] }
    end

    def find_dir(directory)
      names = path_names(directory)
      root = names.shift
      tp_dir = find_root(root)
      names.empty? ? tp_dir : find_tp_dir(tp_dir, names)
    end

    def find_tp_dir(tp_dir, names)
      tp_dir = @directories[tp_dir["DirectoryId"]] ||= raw_ls(tp_dir["DirectoryId"])
      current_path = "/#{tp_dir["DirectoryName"]}"
      name = names.shift
      return tp_dir unless name

      current_path += "/#{name}"
      tp_dir = find_sub_dir(tp_dir, name, current_path)

      tp_dir = raw_lsr(tp_dir["DirectoryId"], names.count)
      names.each do |name|
        current_path += "/#{name}"
        tp_dir = find_sub_dir(tp_dir, name, current_path)
      end

      tp_dir
    end

    def find_sub_dir(tp_dir, name, current_path)
      r = tp_dir["Directories"]["$values"].find { |dir| dir["DirectoryName"] == name }
      raise Transfertpro::Error, "Directory #{current_path} does not exist on TransfertPro" if r.nil?
      r
    end

    def find_root(root)
      tp_dir = @root_directories.find { |d| d["DirectoryName"] == root }
      raise Transfertpro::Error, "Root #{root} does not exist" if tp_dir.nil?

      tp_dir
    end

    def raw_root
      http_get("/api/v5/Directory/Root")
    end

    def raw_root_directory
      http_get("/api/v5/Directory/RootDirectory")
    end

    def raw_lsr(directory_id, depth)
      http_get("/api/v5/Directory/#{directory_id}/#{depth}")
    end

    def raw_ls(directory_id)
      http_get("/api/v5/Directory/#{directory_id}")
    end

    def refresh
      @root_directories = raw_root["Directories"]["$values"]
      @directories = {}
    end

    def file_description(input_file_path, tp_dir)
      {
        UploadId: SecureRandom.uuid,
        FileName: File.basename(input_file_path),
        FileSize: File.size(input_file_path),
        DirectoryId: tp_dir["DirectoryId"]
      }
    end

    def upload_content(input_file_path, file_description, share_id)
      if File.size(input_file_path) < CHUNK_SIZE
        direct_upload(input_file_path, file_description, share_id)
      else
        chunked_upload(input_file_path, file_description, share_id)
      end
    end

    def direct_upload(input_file_path, file_description, share_id)
      file = File.open(input_file_path, "rb")
      params = chunk_params(0, 1, file_description, 0, share_id)
      upload_chunk(params, file)
    end

    def chunked_upload(input_file_path, file_description, share_id)
      file = File.open(input_file_path, "rb")
      extension = File.extname(input_file_path)
      chunk_index = 0
      chunk_count = chunk_count(input_file_path)
      offset = 0
      loop do
        Tempfile.create(["tp", extension], binmode: true) do |chunk_file|
          chunk = create_chunk(chunk_file, file)
          params = chunk_params(chunk_index, chunk_count, file_description, offset, share_id)
          upload_chunk(params, chunk_file)
          offset += chunk.size
          chunk_index += 1
        end
        break if chunk_index >= chunk_count
      end
    end

    def chunk_count(input_file_path)
      (File.size(input_file_path) * 1.0 / CHUNK_SIZE).ceil
    end

    def create_chunk(chunk_file, file)
      chunk = file.read(CHUNK_SIZE)
      chunk_file.write(chunk)
      chunk_file.rewind
      chunk
    end

    def upload_chunk(params, file)
      body = { file: }
      tries = 0
      r = nil
      while tries < 10
        r = Typhoeus.post("#{@upload_url}/Chunk", body:, params:, headers:, verbose: false)
        return if r.success?
        raise Error.new("Exception during upload #{r.code} #{r.body}", r) unless r.nil? || r.success?

        tries += 1
      end
      raise Error, "Network error during upload"
    end

    def chunk_params(chunk, chunk_count, file_description, offset, share_id)
      {
        uid: file_description[:UploadId],
        name: file_description[:FileName],
        chunk:,
        chunks: chunk_count,
        share: share_id,
        offset:,
        o: true,
        sender: @user
      }.merge(authentication_parameters)
    end

    def path_names(directory)
      directory.split("/").filter { |name| !name.empty? }
    end

    def upload_file_description(file_description, share_id)
      share = NIL_GUID == share_id ? "" : "/share/#{share_id}"
      http_post("/api/v5/File#{share}", file_description)
    end

    def reconnect
      r = super
      refresh
      r
    end

    def download_tp_file(target_directory, tp_dir, tp_file, move_file = false)
      filename = tp_file["FileName"]
      target_file = "#{target_directory}/#{filename}"
      out_stream = Tempfile.new("tp", target_directory)
      out_stream.binmode
      run_download_request(out_stream, download_params(tp_dir, tp_file))
      out_stream.close
      FileUtils.mv(out_stream.path, target_file)
      delete_file(tp_dir, tp_file) if move_file
      target_file
    rescue StandardError => e
      out_stream&.close!
      raise Transfertpro::Error, "Unable to download #{filename}: #{e.message}"
    end

    NIL_GUID = "00000000-0000-0000-0000-000000000000"

    def download_params(tp_dir, tp_file)
      {
        i: tp_file["Id"],
        n: tp_file["FileName"],
      }.tap do |h|
        shareId = tp_dir["CurrentSharedDirectoryId"]
        h[:s] = shareId if shareId != NIL_GUID
      end.merge(authentication_parameters)
    end

    def run_download_request(outstream, params)
      request = Typhoeus::Request.new("#{@download_url}/download/myfile", params:, headers:)
      request.on_headers do |response|
        unless response.success?
          raise Transfertpro::Error, "Error #{response.code} when downloading #{params[:n]} (#{response.body}"
        end
      end
      request.on_body do |chunk|
        outstream.write(chunk)
      end
      request.on_complete { outstream.close }
      request.run
    end

    def delete_file(tp_dir, tp_file)
      operation = "/api/v5/File/#{tp_file["Id"]}"
      shared_id = tp_dir["CurrentSharedDirectoryId"]
      operation += "/share/#{shared_id}" unless shared_id.nil? # || shared_id == NIL_GUID commented as triggers crash on TP
      http_delete(operation)
    end

    def http_delete(operation)
      r = Typhoeus.delete(@api_url + operation, params: authentication_parameters, verbose: false, headers:)
      puts "delete #{operation}: #{(r.time * 1000).round}ms"
      raise_error(r) unless r.success?
      r.success?
    end

    def http_get(operation)
      r = Typhoeus.get(@api_url + operation, params: authentication_parameters, verbose: false, headers:)
      puts "get #{operation}: #{(r.time * 1000).round}ms"
      raise_error(r) unless r.success?

      JSON.parse(r.body)
    end

    def http_post(operation, body)
      r = Typhoeus.post(@api_url + operation, body:, params: authentication_parameters, verbose: false, headers:)
      puts "post #{operation}: #{(r.time * 1000).round}ms"
      raise_error(r) unless r.success?
      r.body.empty? ? "" : JSON.parse(r.body)
    end

    def raise_error(response)
      pp response
      raise Transfertpro::Error.new("Error calling transfertpro api", response)
    end
  end
end
