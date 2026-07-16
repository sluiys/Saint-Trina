# So, what actually Saint-Trina does?
# Every time you commit something by doing " git commit -m 'commit description' ", Saint-Trina scans your commited files for tokens, APIs, and other sensitive information that are "hardcoded" and gives you an alert.
# You will be able to ignore false positives by adding a comment:
# 
# saint-trina:ignore-line for ignoring a specific line.
# saint-trina:ignore-file for ignoring an entire file.
# 
# The user will receive a warning if the script catches something.
# The user can approve that commit or review what the script found.


# File loader method finds all code files in a given directory and its subdirectories.
# Only Ruby files at the moment (for testing)
def file_loader
  # Asking git directly which files are in the staging area right now
  # --cached targets the stage, --name-only returns just the file paths without the code diffs
  # The backticks ` ` execute the command in the OS shell and return the output as a string
  staged_files_raw = `git diff --cached --name-only`

  # Splitting the raw multi-line string into an array of individual file paths
  all_staged_files = staged_files_raw.split("\n")

  # Filtering the array to keep only the ruby files that actually exist on the disk
  ruby_files = all_staged_files.select do |file_path|
    # Making sure it has a .rb extension AND checking if the file exists
    # We must check File.exist? because if you DELETE a ruby file and commit the deletion,
    # git will list it, but our File.foreach would crash trying to read a ghost file
    file_path.end_with?('.rb') && File.exist?(file_path)
  # Closing the filter block
  end

  # Returning the clean list of staged ruby files
  ruby_files
end


def transform_file(code_files)
  findings = []

  # AWS keys: 'AKIA' followed by exactly 16 uppercase letters or numbers
  aws_regex = /AKIA[A-Z0-9]{16}/

  # Grabbing the list of files and walking through them one at a time
  code_files.each do |file_path|
    
    # Streaming the file line by line straight from the hard drive, tagging each with its actual line number
    File.foreach(file_path).with_index(1) do |line, line_number|
      
      # Checking if the very first line holds the master override switch to skip the whole file
      if line_number == 1 && line.include?('saint-trina:ignore-file')
        # Smashing the emergency stop button for this file, aborting the read and jumping to the next file in the queue
        break
      end
      
      # Firing the regex engine at the current line to see if it triggers.
      if line.match?(aws_regex)
        
        # The regex caught something, but let's see if the dev left a sticky note to ignore this exact line
        unless line.include?('saint-trina:ignore-line')
          
          # Packing up the evidence into a clean hash and shoving it into our hit list
          findings << {
            # Pinpointing the exact file where the slip-up happened
            path: file_path,
            # Recording the exact line number so the dev can fix it fast
            line: line_number,
            # Snagging the actual string data while shaving off annoying whitespace or newline characters. (Aesthetics only)
            content: line.strip
          # Closing the evidence hash  
          }
          
        end
        
      end
      
    end
    
  end

  findings
end

# Starting the main orchestration flow by grabbing the current directory where git is running
project_root = Dir.pwd

# Firing up our crawler to find every ruby file in the project
all_code_files = file_loader()

# Sending the list of files to the scanner to hunt for hardcoded secrets
leaks = transform_file(all_code_files)

# Checking if the scanner came back completely clean
if leaks.empty?
  # Giving git the green light (Exit 0) to proceed with the commit silently
  exit 0
  
# Handling the scenario where we actually found dangerous data
else
  # Printing a loud warning to the terminal so the dev stops what they are doing
  puts "\nSaint Trina: Potential secrets detected in your code!"
  
  # Looping through the findings to show the user exactly where they messed up
  leaks.each do |leak|
    puts " -> File: #{leak[:path]} | Line: #{leak[:line]} | Match: #{leak[:content]}"
  end
  
  # Asking the user if they want to fix it or force it through
  print "\nDo you want to Abort (A) or force the Commit anyway (C)? [A/C]: "
  
  # Opening a direct hardware line to the keyboard because git hijacks standard input
  user_choice = File.open('/dev/tty', 'r') { |tty| tty.gets.chomp.upcase }
  
  # Evaluating the user's manual override choice
  if user_choice == 'C'
    # Letting the dev proceed at their own risk
    puts "Saint Trina: Overriding lock. Proceeding with commit..."
    exit 0
  else
    # Smashing the abort button (Exit 1) and telling git to halt the commit process
    puts "Saint Trina: Commit aborted. Stay safe."
    exit 1
    
  end

end

