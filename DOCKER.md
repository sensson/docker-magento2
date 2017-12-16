# Magento2 and Docker

The recommended way to install Magento is by downloading a zip file from
their website. Although this is easy for most, it doesn't give you much
control. How do you make sure that Magento2 runs the same version across
a large cluster? How do you handle updates?

Our Docker-image is intented to be used with git. 

# Create a new, clean environment

Clone the Magento2 repository to a new folder.

```
git clone https://github.com/magento/magento2.git environment
cd environment
```

And select the version that you want to run.

```
git checkout 2.2.1
```

Create a master branch. This is possible because Magento2 doesn't have a
master or develop branch on GitHub -- be careful though. This could change
in the future.

```
git checkout -b master
```

Add a new remote. This is where you will store your customizations, e.g.
for composer.json or other files and push the master branch.

```
git remote add custom git@git.yourdomain.com:user/magento2.git
git push custom -u master
```

# Making changes -- add Docker support

```
echo '.git' >> .dockerignore
cat <<DOCKER > Dockerfile
FROM sensson/magento2
COPY . /var/www/html/
DOCKER
```

This will create a Dockerfile for you that copies the content of the Magento2
repository into the image `sensson/magento2`. Make sure that you run `composer
install` before `docker build -t company/magento2-core`.

Commit and push your changes.

```
git add .dockerignore Dockerfile
git commit -m 'Add Docker support'
git push custom -u master
```

# Magento2 updates

Once Magento2 releases a new version you need to update your Docker image. We
assume you're using `master` for your local branch and that the remote called
`origin` points to `https://github.com/magento/magento2.git`.

```
git fetch origin
git checkout master (or even better: a temporary branch)
git merge origin/new-version
```

This will merge all changes from the branch `new-version` into your master
branch. If you need to undo this merge when you haven't push it yet, find
your last commit and go back.

```
git reset --hard commit_before_merge
```

Disclaimer: be very careful with updates. Don't expect everything to work
and always use a temporary new branch to test your changes before merging
them back into master.

# Releases

It doesn't matter what versioning scheme you use to mark your Docker images,
but it is important to pick one. 2.2.1-1 could work, where -1 would be the
release within the 2.2.1 branch, but others could work better depending on
your use case.

# Gitlab, CI and composer

At some point you need to get all dependencies with composer. We thought it
made most sense to have our CI do this for us. In our build process we pass
on the required credentials to download any private modules.

An example .gitlab-ci.yml has been provided for those who use Gitlab for their
repositories. It should give a pretty decent idea for Travis and Circle CI
users too.
