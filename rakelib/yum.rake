namespace :yum do
  signing_dir = "out/yum"

  desc "generate yum repository"
  task :createrepo => 'gpg:setup' do
    rm_rf signing_dir
    mkdir_p signing_dir

    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} --delete --exclude='*' --include '*.rpm' s3://#{S3_DOWNLOAD_BUCKET_BASE_URL} #{signing_dir}")
    cd signing_dir do
      sh("createrepo --database --update --unique-md-filenames --retain-old-md=5 .")
      sh("gpg --batch --yes --default-key '#{GPG_SIGNING_ID}' --armor --detach-sign --sign --output repodata/repomd.xml.asc repodata/repomd.xml")
      sh("gpg --batch --yes --verify --default-key '#{GPG_SIGNING_ID}' repodata/repomd.xml.asc repodata/repomd.xml")
      sh("repoview --title 'GoCD Yum Repository' .")
    end

    # yum repomd.xml (low cache ttl)
    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} #{signing_dir}/repodata s3://#{S3_DOWNLOAD_BUCKET_BASE_URL}/repodata/ --delete --acl public-read --cache-control 'max-age=600' --exclude '*' --include 'repomd.xml*'")

    # rest of the yum metadata (high cache ttl)
    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} #{signing_dir}/repodata s3://#{S3_DOWNLOAD_BUCKET_BASE_URL}/repodata/ --delete --acl public-read --cache-control 'max-age=31536000'")

    # yum repoview (low cache ttl)
    sh("aws s3 sync #{'--no-progress' unless $stdin.tty?} #{signing_dir}/repoview s3://#{S3_DOWNLOAD_BUCKET_BASE_URL}/repoview/ --delete --acl public-read --cache-control 'max-age=600'")
  end
end
