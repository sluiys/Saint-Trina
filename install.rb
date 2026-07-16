# Pulling in the file system toolkit from Ruby standard library to handle directory creation and permissions
require 'fileutils'

# Pinpointing exactly where the user is standing in their terminal right now
current_dir = Dir.pwd

# Building the path pointing to the hidden git folder inside their current project
git_dir = File.join(current_dir, '.git')

# Building the exact path where git expects all the trigger scripts to live
hooks_dir = File.join(git_dir, 'hooks')

# Defining the final destination and name for our script, stripping the .rb extension because git demands it
hook_path = File.join(hooks_dir, 'pre-commit')

# Figuring out where our main logic file is sitting, assuming it is in the same folder as this installer
source_file = File.join(__dir__, 'main.rb')

# Checking if the user is actually inside a git repository before we start messing with their system
if Dir.exist?(git_dir)

  # Making sure the hooks folder exists, creating it silently in case someone deleted it
  FileUtils.mkdir_p(hooks_dir)

  # Reading the entire raw code from our main scanner script into memory
  raw_code = File.read(source_file)

  # Opening the pre-commit file in write mode, which creates it from scratch or overwrites whatever was there
  File.open(hook_path, 'w') do |file|

    # Injecting the shebang at the very top so the OS knows this is a Ruby script and not a bash script
    file.puts("#!/usr/bin/env ruby")

    # Adding a tiny blank line just to keep the generated file looking clean and readable
    file.puts("")

    # Dumping all of our scanner logic straight into the hook file
    file.puts(raw_code)

  # Closing the file automatically when the block ends to prevent memory leaks
  end

  # Flipping the executable bit on the file using octal permissions so the OS actually allows git to trigger it
  File.chmod(0755, hook_path)
  
  puts "Saint Trina installed successfully. Your commits are now protected."
else

  puts "Error: No .git folder found. Are you sure you are in the root of a git repository?"
end