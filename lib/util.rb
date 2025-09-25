module Util

  def self.simple_hypenated_timestamp
    Time.current.strftime('%Y-%m-%d-%H-%M')
  end

  def self.simple_underscored_timestamp
    Time.current.strftime('%Y_%m_%d_%H_%M')
  end

  def self.match_file_name(file, extenstion)
    # Matches SOMETHING then a slash, then filename then dot then extension
    return file.match("^.+\/(.+).#{extenstion}")
  end

end