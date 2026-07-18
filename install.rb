# Pulling in the file system toolkit and network libraries from Ruby standard library
require 'fileutils'
require 'net/http'
require 'uri'

# The exact raw URL pointing to the core logic of Saint Trina on the main branch
# Note: We are pointing to the future path 'lib/saint_trina/core.rb' based on our structural upgrade
SOURCE_URL = "https://raw.githubusercontent.com/sluiys/Saint-Trina/main/lib/saint_trina/core.rb"

# Pinpointing exactly where the user is standing in their terminal right now
current_dir = Dir.pwd
git_dir = File.join(current_dir, '.git')
hooks_dir = File.join(git_dir, 'hooks')
hook_path = File.join(hooks_dir, 'pre-commit')

# Checking if the user is actually inside a git repository before modifying their system
unless Dir.exist?(git_dir)
  puts "\e[31mError: No .git folder found. Are you sure you are in the root of a git repository?\e[0m"
  exit 1
end

puts "\e[36m[Saint Trina]\e[0m Fetching latest core rules from GitHub..."

begin
  # Parsing the URL and opening a secure network connection to GitHub
  uri = URI.parse(SOURCE_URL)
  response = Net::HTTP.get_response(uri)

  # Validating if the network request was successful (HTTP 200 OK)
  unless response.is_a?(Net::HTTPSuccess)
    puts "\e[31mError: Failed to fetch the core script. HTTP Status: #{response.code}\e[0m"
    exit 1
  end

  # Making sure the hooks folder exists, creating it silently if necessary
  FileUtils.mkdir_p(hooks_dir)

  # Opening the pre-commit file in write mode, creating or overwriting it
  File.open(hook_path, 'w') do |file|
    # Injecting the shebang at the very top so the OS knows this is a Ruby script
    file.puts("#!/usr/bin/env ruby")
    file.puts("")
    # Dumping the raw code fetched directly from GitHub into the hook file
    file.puts(response.body)
  end

  # Flipping the executable bit on the file using octal permissions for git to trigger it
  File.chmod(0755, hook_path)
  
  puts "\e[32mSaint Trina installed successfully. Your commits are now protected.\e[0m"

rescue SocketError, Net::OpenTimeout => e
  # Catching hardware or network disconnections gracefully
  puts "\e[31mError: Network failure. Could not connect to GitHub. Please check your internet connection.\e[0m"
  exit 1
rescue StandardError => e
  # Catching any unexpected structural errors
  puts "\e[31mError: An unexpected failure occurred during installation: #{e.message}\e[0m"
  exit 1
end