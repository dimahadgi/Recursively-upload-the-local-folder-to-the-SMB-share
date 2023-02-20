require 'ruby_smb'

# Define the paths to the local folder and the shared CIFS/SMB folder
local_folder_path = '/path/to/your/local/folder'
@prefix_to_remove = "#{local_folder_path}/"
share = 'your_share_name'
address = '192.168.0.1' # your SMB server
smb_folder_path = "\\\\#{address}\\#{share}"

# Define the username and password to access the CIFS/SMB folder
username = 'test_user'
password = 'test_password'

# Connect to the SMB share
sock = TCPSocket.new address, 445
dispatcher = RubySMB::Dispatcher::Socket.new(sock)
client = RubySMB::Client.new(dispatcher, username: username, password: password)
client.negotiate
client.authenticate

begin
  tree = client.tree_connect(smb_folder_path)
  puts "Connected to #{smb_folder_path} successfully!"
rescue StandardError => e
  raise "Failed to connect to #{smb_folder_path}: #{e.message}"
end

# Recursively upload the local folder to the SMB share
def upload_folder(local_folder_path, smb_folder_path, tree)
  Dir.glob(File.join(local_folder_path, '*')).each do |local_file_path|
    if File.directory?(local_file_path)
      smb_subfolder_name = local_file_path.gsub(@prefix_to_remove, '')
      tree.open_directory(directory: smb_subfolder_name, disposition: RubySMB::Dispositions::FILE_CREATE)
      upload_folder(local_file_path, smb_subfolder_name, tree)
    else
      smb_file_path = if smb_folder_path.nil?
                        File.basename(local_file_path)
                      else
                        File.join(smb_folder_path, File.basename(local_file_path))
                      end
      file = tree.open_file(filename: smb_file_path, write: true, disposition: RubySMB::Dispositions::FILE_OVERWRITE_IF)
      file.write(data: File.read(local_file_path))
      file.close
    end
  end
end

upload_folder(local_folder_path, nil, tree)

# Disconnect from the SMB share
tree.disconnect!
client.disconnect!
