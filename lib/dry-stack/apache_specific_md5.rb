require 'digest/md5'

APR1_MAGIC = '$apr1$'
ITOA64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def to64(value, length)
  result = ''
  length.times do
    result << ITOA64[value & 0x3f]
    value >>= 6
  end
  result
end

def apr1_crypt(password, salt)
  salt = salt[0, 8]
  ctx = Digest::MD5.new
  ctx.update(password + APR1_MAGIC + salt)
  final = Digest::MD5.digest(password + salt + password)

  password.length.times { |i| ctx.update(final[i % 16].chr) }

  length = password.length
  while length > 0
    ctx.update(length & 1 != 0 ? "\0" : password[0].chr)
    length >>= 1
  end

  final = ctx.digest

  1000.times do |i|
    ctx = Digest::MD5.new
    ctx.update(i & 1 != 0 ? password : final)
    ctx.update(salt) unless (i % 3).zero?
    ctx.update(password) unless (i % 7).zero?
    ctx.update(i & 1 != 0 ? final : password)
    final = ctx.digest
  end

  hashed = final.bytes
  result = [
    to64((hashed[0] << 16) | (hashed[6] << 8) | hashed[12], 4),
    to64((hashed[1] << 16) | (hashed[7] << 8) | hashed[13], 4),
    to64((hashed[2] << 16) | (hashed[8] << 8) | hashed[14], 4),
    to64((hashed[3] << 16) | (hashed[9] << 8) | hashed[15], 4),
    to64((hashed[4] << 16) | (hashed[10] << 8) | hashed[5], 4),
    to64(hashed[11], 2)
  ].join

  "#{APR1_MAGIC}#{salt}$#{result}"
end

def apr1_check(password, hashed_password)
  parts = hashed_password.split('$')
  return false if parts.length != 4 || parts[1] != 'apr1'

  salt = parts[2]
  apr1_crypt(password, salt) == hashed_password
end

# SELF TEST ============================================================================================================
if File.expand_path($0) == File.expand_path(__FILE__)
  # openssl passwd -apr1 -salt 8sFt66rZ admin
  password = "admin"
  salt = "976CP"

  hashed_password = apr1_crypt(password, salt)
  puts "APR1 Hashed Password: #{hashed_password}"

  hashed_password2 = '$apr1$pkcC6Tmo$4HpuLoFryypSnXeJ1e02n/'
  hashed_password3 = '$apr1$976PimCP$PU7TWdOsyivf.u35yYGsv0'

  p apr1_check(password, hashed_password)
  p apr1_check(password, hashed_password2)
  p apr1_check(password, hashed_password3)
end