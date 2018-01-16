# Spin up AWS EC2 configured Node App

*Note that the IP address 111.222.333.444 needs replaced with whatever IP you generate as your elastic IP.*

Work in Progress, brain dump from @scarstens

1. Create VPC (if not already exists)
1. Create security group with "my ip" access to all ports.
1. Create security group for "http_https_open" and open 80 and 443 to the public
1. Create IAM role for "default_ec2_role", assign it basic S3 read access for now.
1. Create EC2 -> Select free teir Ubuntu 16 AMI 
  1. assign it to the VPC, Security Groups, and IAM role created above
  1. default tags, storage space, and other options all fine as default
  1. use wizard to create PEM keypair (or select existing keypair) -> download the PEM -> move it to ~/.ssh -> chmod 600 the PEM key
  1. finalize / spin up instance
1. create elastic ip -> assign it to the instance
1. ssh into the ec2 instance with something like `ssh ubuntu@111.222.333.444 -i ~/.ssh/KEYNAME.pem`
1. git clone https://github.com/scarstens/devops-toolkit
1. bash devops-toolkit/setup-git-credentials.sh
  1. if you haven't already, get your github handle (username)
  1. if you haven't already, generate and prepare your github personal access token https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
  1. enter these two items into the prompts (note you won't see anything when it asks for password, this is a security feature)
1. bash devops-toolkit/beta/node-express.sh
1. curl localhost (should display hello world)
1. create github repo with actual node app (private or public at this point)
1. stop the current node app `pm2 stop nodeapp`
1. remove (backup) the sample node app `sudo mv /var/www/nodeapp /var/www/default_nodeapp`
1. clone your new repo onto the previous nodeapp folder location `git clone https://github.com/myuser/myrepo /var/www/nodeapp`
1. rebuild the node app based on its package.js `cd /var/www/nodeapp ; npm install --save`
1. restart the node app runner `pm2 start nodeapp`

Now you can update the node app automatically by stopping, git pulling, and starting the node app. Would look something like this:
```bash
cd ~/devops-toolkit ; git pull ; bash update-pm2-nodeapp.sh ;'
```

Or you can run it remotely using a command similar to this:
```bash
ssh ubuntu@111.222.333.444 'cd ~/devops-toolkit ; git pull ; bash update-pm2-nodeapp.sh ;'`
```
