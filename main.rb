# So, what actually Saint-Trina does?
# Every time you commit something by doing " git commit -m 'commit description' ", Saint-Trina scans your commited files for tokens, APIs, and other sensitive information that are "hardcoded" and gives you an alert.
# You will be able to ignore false positives by adding a comment:
# 
# saint-trina:ignore-line for ignoring a specific line.
# saint-trina:ignore-file for ignoring an entire file.
# 
# The user will receive a warning if the script catches something.
# The user can approve that commit or review what the script found.


# The master dictionary of all dangerous patterns Saint Trina is hunting for.
# We use a Constant (capitalized) so it's globally available and built only once in memory.
SIGNATURES = {
  "AWS Access Key" => /AKIA[A-Z0-9]{16}/,
  "GitHub Token"   => /gh[posr]_[a-zA-Z0-9]{36}/,
  "Stripe Key"     => /[sr]k_(test|live)_[a-zA-Z0-9]{24}/,
  "Google API Key" => /AIza[a-zA-Z0-9\-_]{35}/,
  "Slack Token"    => /xox[bpe]-[a-zA-Z0-9\-]+/,
  "Generic Secret" => /(?i)(password|passwd|pwd|secret|token|api_key)\s*(=|:|=>)\s*["'][a-zA-Z0-9\-_]{8,}["']/
}

# The whitelist of file extensions that Saint Trina is allowed to open and read line by line.
# If a file doesn't end with one of these, we don't waste memory trying to parse it.
SCANNABLE_EXTENSIONS = [
  '.rb', '.py', '.js', '.ts', '.php', '.java', '.cs', '.go', '.sh',
  '.json', '.yml', '.yaml', '.ini', '.cfg', '.toml', '.xml'
]

# The blacklist of files that trigger an immediate lockdown just by existing in the commit.
# We don't even read these files; their presence alone is a critical security breach.
CRITICAL_FILES = [
  '.env', '.env.local', '.env.production', 
  '.pem', '.key', '.crt', '.p12', 
  'id_rsa', 'id_ed25519', 
  'credentials.json', 'secrets.yml'
]


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
  code_files = all_staged_files.select do |file_path|

    # Ensuring the file exists on disk, AND checking if it matches our arrays
    # The splat operator (*) unpacks the array directly into native arguments for maximum speed
  File.exist?(file_path) && (
        file_path.end_with?(*SCANNABLE_EXTENSIONS) || 
        file_path.end_with?(*CRITICAL_FILES)
  )
  end

  # Returning the clean list
  code_files
end


def transform_file(code_files)
  findings = []

  # Grabbing the list of files and walking through them one at a time
  code_files.each do |file_path|
    
    # EXTREME RISK ZONE: Intercepting critical files before we even try to open them
    if file_path.end_with?(*CRITICAL_FILES)
      
      # Immediately flagging the file as a leak without reading a single line of code
      findings << {
        path: file_path,
        line: "N/A", # There is no specific line to fix, the whole file is illegal
        type: "Restricted File Format",
        content: "Blocked by Saint Trina strict policy"
      }
      
      # Skipping to the next file in the loop, completely bypassing the File.foreach
      next
      
    end
    
    # Streaming the file line by line straight from the hard drive, tagging each with its actual line number
    File.foreach(file_path).with_index(1) do |line, line_number|
      
      # Checking if the very first line holds the master override switch to skip the whole file
      if line_number == 1 && line.include?('saint-trina:ignore-file')
        # Smashing the emergency stop button for this file, aborting the read and jumping to the next file in the queue
        break
      end
      
      # Iterating through our master dictionary of signatures to check for various leaks
      SIGNATURES.each do |secret_name, regex|
          
        # Firing the current regex engine at the line
        if line.match?(regex)
          
          # The regex caught something, but let's see if the dev left a sticky note to ignore this exact line
          unless line.include?('saint-trina:ignore-line')
            
            # Packing up the evidence into a clean hash and shoving it into our hit list
            findings << {
              path: file_path,
              line: line_number,
              type: secret_name,
              content: line.strip
            }
            
          end
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
  puts "\n\e[1;31mSaint Trina: Potential secrets detected in your code!\e[0m"
  
  # Looping through the findings to show the user exactly where they messed up
  leaks.each do |leak|
    # Upgraded output format to clearly state the TYPE of secret found
    puts "-> \e[33m[#{leak[:type]}]\e[0m File: \e[36m#{leak[:path]}\e[0m | Line: #{leak[:line]} | Match: \e[31m#{leak[:content]}\e[0m"
  end
  
  # Asking the user if they want to fix it or force it through
  print "\n\e[1;33mDo you want to Abort (A) or force the Commit anyway (C)? [A/C]: \e[0m"
  
  # Opening a direct hardware line to the keyboard because git hijacks standard input
  user_choice = File.open('/dev/tty', 'r') { |tty| tty.gets.chomp.upcase }
  
  # Evaluating the user's manual override choice
  if user_choice == 'C'
    # Letting the dev proceed at their own risk
    puts "\e[33mSaint Trina: Overriding lock. Proceeding with commit...\e[0m"
    exit 0
  else
    # Smashing the abort button (Exit 1) and telling git to halt the commit process
    puts "\e[32mSaint Trina: Commit aborted. Stay safe.\e[0m"
    exit 1
    
  end

end