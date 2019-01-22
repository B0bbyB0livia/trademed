# http://stackoverflow.com/questions/28293289/how-to-create-custom-paperclip-processor-to-retrive-image-dimensions-rails-4
module Paperclip
  class Stripexif < Processor
    def make
      basename = File.basename(file.path, File.extname(file.path))
      dst_format = options[:format] ? ".\#{options[:format]}" : ''

      dst = Tempfile.new([basename, dst_format])
      dst.binmode

      convert(':src -strip :dst',
              src: File.expand_path(file.path),
              dst: File.expand_path(dst.path))

      dst
    end
  end
end
