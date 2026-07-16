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
def file_loader(folder_path)
  code_files = []

  # Pulling every single item name from the directory and spinning up a loop to inspect them one by one
  Dir.entries(folder_path).each do |item|
    # Bailing out immediately if the item is '.' or '..' because processing these system links causes an infinite loop (my pc goes vrom vrom).
    next if item == '.' || item == '..'

    # Gluing the base folder path and the item name together so the OS knows exactly where to look
    full_path = File.join(folder_path, item)

    # Asking the operating system straight up: is this path pointing to another folder?
    if File.directory?(full_path)
      # The actual inception: calling ourselves with the new folder path and dumping the results into our current bucket
      code_files.concat(file_loader(full_path))

    # Catching the fallback scenario where the item is just a file, checking if it wears the ruby extension
    elsif item.end_with?('.rb')
      # Throwing the confirmed ruby file path into our collection
      code_files << full_path
      
    end
  end
  # implicit return :)
  code_files
# Sealing the method definition
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