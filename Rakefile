## a set of tasks to make this nicer
def ejabberd_path
  begin
    File.stat "/usr/local/lib/ejabberd"
    "/usr/local/lib/ejabberd"
  rescue Errno::ENOENT
    "/usr/lib/ejabberd"
  end
end


desc "configure the erlang build system to make this friendly enough to work"
task :configure do
  # where's ejabberd?
  open("Emakefile", "w") do |file|
    file.write "{'src/http_prebind', [debug_info, {outdir, 'ebin'}, {i, '#{ejabberd_path}/include'}, {i,'#{ejabberd_path}/include/web'}]}.\n"
  end

  puts "Crafted an Emakefile to allow you to build this sucker..."
  puts "Now, edit src/http_prebind.erl to your taste, remember to replace AUTH_USER, AUTH_PASS and EJABBERD_DOMAIN"
end

desc "build the beam file"
task :build do
  begin
    puts `mkdir -p ebin` # perhaps the ebin folder doesn't yet exist?
    puts `erl -make ` if File.stat(File.getpwd + "Emakefile")
  rescue
    puts "Emakefile not found, you should run rake configure"
  end
end

desc "install the beam to #{ejabberd_path}"
task :install do
  puts `sudo cp ebin/http_prebind.beam #{ejabberd_path}/ebin`
  puts "installed to #{ejabberd_path}"
end
