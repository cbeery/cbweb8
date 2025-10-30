# config/initializers/aws_s3_dns_fix.rb
if Rails.env.development?
  require 'aws-sdk-s3'
  Aws.config[:ssl_verify_peer] = false
end