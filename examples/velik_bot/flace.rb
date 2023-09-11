require "pathname"
Kernel.class_eval do
  old = instance_method :require
  define_method :require do |lib|
    # puts "flace require #{lib.inspect} (#{Pathname.new(File.expand_path caller[0]).relative_path_from(File.expand_path Dir.pwd)})"
    old.bind(self).(lib)
  end
end

require "tmpdir"
FileUtils.rm_rf "#{Dir.tmpdir}/fake_lib"
FileUtils.mkdir_p "#{Dir.tmpdir}/fake_lib"
$LOAD_PATH.unshift "#{Dir.tmpdir}/fake_lib"
def Flace lib
  puts "faking #{lib}"
  FileUtils.mkdir_p File.dirname "#{Dir.tmpdir}/fake_lib/#{lib}"
  FileUtils.touch "#{Dir.tmpdir}/fake_lib/#{lib}.rb"
  require lib
end

ENV.clear
