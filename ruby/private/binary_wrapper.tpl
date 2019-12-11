#shell #!/usr/bin/env bash
#shell # This conditional is evaluated as true in Ruby, false in shell
#shell if [ ]; then
#shell eval <<'END_OF_RUBY'
#shell # -- begin Ruby --
#!/usr/bin/env ruby

# Ruby-port of the Bazel's wrapper script for Python

# Copyright 2017 The Bazel Authors. All rights reserved.
# Copyright 2019 BazelRuby Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rbconfig'
require 'shellwords'

def find_runfiles
  stub_filename = File.absolute_path($0)
  runfiles = "#{stub_filename}.runfiles"
  loop do
    case
    when File.directory?(runfiles)
      return runfiles
    when %r!(.*\.runfiles)/.*!o =~ stub_filename
      return $1
    when File.symlink?(stub_filename)
      target = File.readlink(stub_filename)
      stub_filename = File.absolute_path(target, File.dirname(stub_filename))
    else
      break
    end
  end
  raise "Cannot find .runfiles directory for #{$0}"
end

def create_loadpath_entries(custom, runfiles)
  [runfiles] + custom.map {|path| File.join(runfiles, path) }
end

def get_repository_imports(runfiles)
  Dir.children(runfiles).map {|d|
    File.join(runfiles, d)
  }.select {|d|
    File.directory? d
  }
end

# Finds the runfiles manifest or the runfiles directory.
def runfiles_envvar(runfiles)
  # If this binary is the data-dependency of another one, the other sets
  # RUNFILES_MANIFEST_FILE or RUNFILES_DIR for our sake.
  manifest = ENV['RUNFILES_MANIFEST_FILE']
  if manifest
    return ['RUNFILES_MANIFEST_FILE', manifest]
  end

  dir = ENV['RUNFILES_DIR']
  if dir
    return ['RUNFILES_DIR', dir]
  end

  # Look for the runfiles "output" manifest, argv[0] + ".runfiles_manifest"
  manifest = runfiles + '_manifest'
  if File.exists?(manifest)
    return ['RUNFILES_MANIFEST_FILE', manifest]
  end

  # Look for the runfiles "input" manifest, argv[0] + ".runfiles/MANIFEST"
  manifest = File.join(runfiles, 'MANIFEST')
  if File.exists?(manifest)
    return ['RUNFILES_DIR', manifest]
  end

  # If running in a sandbox and no environment variables are set, then
  # Look for the runfiles  next to the binary.
  if runfiles.end_with?('.runfiles') and File.directory?(runfiles)
    return ['RUNFILES_DIR', runfiles]
  end
end

def find_ruby_program
  File.join(
    RbConfig::CONFIG['bindir'],
    RbConfig::CONFIG['ruby_install_name'],
  )
end

def expand_vars(args)
  args.map do |arg|
    arg.gsub(/\${(.+?)}/o) do
      case $1
      when 'RUNFILES_DIR'
        runfiles
      else
        ENV[$1]
      end
    end
  end
end

def main(args)
  custom_loadpaths = {loadpaths}
  runfiles = find_runfiles

  loadpaths = create_loadpath_entries(custom_loadpaths, runfiles)
  loadpaths += get_repository_imports(runfiles)
  loadpaths += ENV['RUBYLIB'].split(':') if ENV.key?('RUBYLIB')
  ENV['RUBYLIB'] = loadpaths.join(':')

  runfiles_envkey, runfiles_envvalue = runfiles_envvar(runfiles)
  ENV[runfiles_envkey] = runfiles_envvalue if runfiles_envkey

  program_name = {program}
  if program_name
    program = File.join(runfiles, program_name)
  else
    program = find_ruby_program
  end
  program_opts = expand_vars({program_opts})

  main = {main}
  main = File.join(runfiles, main)
  rubyopt = expand_vars({rubyopt})
  ENV['RUBYOPT'] = Shellwords.join(expand_vars({rubyopt}))

  exec(program, *program_opts, main, *args)
  # TODO(yugui) Support windows
end

if __FILE__ == $0
  main(ARGV)
end
#shell END_OF_RUBY
#shell __END__
#shell # -- end Ruby --
#shell fi
#shell # -- begin Shell Script --
#shell 
#shell # --- begin runfiles.bash initialization v2 ---
#shell # Copy-pasted from the Bazel Bash runfiles library v2.
#shell set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
#shell source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
#shell source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
#shell source "$0.runfiles/$f" 2>/dev/null || \
#shell source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
#shell source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
#shell { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
#shell # --- end runfiles.bash initialization v2 ---
#shell 
#shell exec "$(rlocation {interpreter})" ${BASH_SOURCE:-$0} "$@"
