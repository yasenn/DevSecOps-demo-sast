# Vulnerable Java App - DevSecOps Demo

# See also
* [IaC](iac.md)
* [K8s](k8s.md)

## Description
Demo app with several vulnerabilities for DevSecOps training.<br>
The project includes general CI/CD steps with security tools.<br>

## Some vulnerabities
1. SQL Injection<br>
2. XSS (Cross-Site Scripting)<br>
3. Hardcoded credentials<br>
4. Missing input validation<br>
5. Information disclosure<br>
and others...<br>

## How to setup the demoset (Linux)
You need 2 Linux boxes (Ubuntu) - one for Jenkins and "demo environment" (<b>"demo env"</b>), and another one - for a docker repo (<b>"local repo"</b>)

### For the both servers<br>
- Check partition size (setup > 50 Gb if necessary)<br>
`df -h`<br>

- Install Docker<br>
According [instructions](https://docs.docker.com/engine/install/)<br>

### For the "local repo" server
- Setup local repo for Docker:<br>
`sudo docker run -d -p 5000:5000 --restart=always --name local-registry registry:2`<br>

### For the "demo env" server
- Install Java 21<br>
`sudo apt install openjdk-21-jdk`<br>

- Setup the local repo as insecure storage:<br>
`echo '{"insecure-registries": ["192.168.0.5:5000"]}' | sudo tee /etc/docker/daemon.json`<br>
`sudo systemctl restart docker`<br>
(replace the "192.168.0.5" address with your local repo IP)<br>

- We will need the "mysql:5.7" container, tagged with the local registry IP and stored in the local registry (just for our vuln app deployment scenario). Replace "192.168.0.5" with your local repo IP<br>
`sudo docker pull mysql:5.7`<br>
`sudo docker tag mysql:5.7 192.168.0.5:5000/mysql:5.7`<br>
`sudo docker push 192.168.0.5:5000/mysql:5.7`<br>
- Check that the mysql image pushed successfully:<br>
`curl -s http://192.168.0.5:5000/v2/_catalog`<br>
You should see something like this: `{"repositories":["mysql"]}`<br>
`curl -s http://192.168.0.5:5000/v2/mysql/tags/list`<br>
Desired output: `{"name":"mysql","tags":["5.7"]}`<br>

- Remove the mysql images from the "demo env" server using the command:<br>
`sudo docker rmi mysql:5.7 192.168.0.5:5000/mysql:5.7`<br>

- Install Cosign locally (the only purpose - to use the tool for pub/private key pair generation) - [instructions](https://docs.sigstore.dev/cosign/system_config/installation/#with-the-cosign-binary-or-rpmdpkg-package)<br>
`curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"`<br>
`sudo mv cosign-linux-amd64 /usr/local/bin/cosign`<br>
`sudo chmod +x /usr/local/bin/cosign`<br>

- Generate the key pair with Cosign (for the test CI/CD please specify the password for the private key and remember it - we will use it in this scenario. In production may be decided to use or not of such password according the desired security policies)<br>
`sudo cosign generate-key-pair`<br>
After the command execution, you should have two files in the current path:<br>
`cosign.key` (private encrypted key)<br>
and<br>
`cosign.pub` (public key)<br>

- Run Hashicorp Vault in the Dev mode (all secrets shored in RAM memory only, not on disk - and will require to set them after each Vault restart)<br>
Also, here we use the "test-only-token" text as a token to access the Vault (you may replace it with other text - we will use the text furter in the pipeline as parameter)<br>
`sudo docker run -d --name=vault --restart=always --cap-add=IPC_LOCK -p 8200:8200 -e 'VAULT_DEV_ROOT_TOKEN_ID=test-only-token' hashicorp/vault`<br>

- Copy the private key inside the Vault container<br>
`sudo docker cp cosign.key vault:/tmp/cosign.key`<br>

- Put the key in the Vault using the token, provided above ("test-only-token" or your one). <b>REMEMBER: this command should be repeated after each Vault reboot!</b><br>
`sudo docker exec -e VAULT_TOKEN=test-only-token -e VAULT_ADDR=http://127.0.0.1:8200 vault vault kv put secret/docker-signing/cosign-private key=@/tmp/cosign.key`<br>
In case of the command execution success the output should show the created secret metadata<br>

- To double-check the secret availability and its content you can with the following command (where 192.168.0.4 - your "demo env" server IP)<br>
`curl -s --header "X-Vault-Token: test-only-token" http://192.168.0.4:8200/v1/secret/data/docker-signing/cosign-private | jq`<br>

### SAST stage (Semgrep) settings<br>
The actual pipeline uses Semgrep (as a Docker image) for the SAST stage. The configuration is that the Semgrep container takes rules from the local storage (the .semgrep-rules folder in the repository). The rules may be taken from the Community (https://github.com/semgrep/semgrep-rules) or written manually<br>

### Install Jenkins<br>
According [instructions](https://www.jenkins.io/doc/book/installing/)<br>

- Add user jenkins to the docker group<br>
`sudo usermod -a -G docker jenkins`<br>
then restart server to apply the changes<br>

### Setup Jenkins configuration<br>
- Unblock Jenkins with https://192.168.0.4:8080 (replace the "192.168.0.4" address with the "demo env" server IP)<br> 
`sudo cat /var/lib/jenkins/secrets/initialAdminPassword`<br>
- Install suggested plugins<br>
- Add the <b>"Docker Pipeline"</b> and <b>"Pipeline Utility Steps"</b> plugins<br>

### Create Pipeline in Jenkins<br>
- Select "New Item" - "Pipeline"<br>
- Set "Name" ("Demo" or something)<br>
- Set "GitHub project" with an URL to the project (like "https://github.com/trainer04/DevSecOps-demo04.git"). It's optional - if you use GitHub project<br>
- Set "Definition" with "Pipeline script from SCM"<br>
- Set "SCM" as "Git"<br>
- Set "Repository URL" with your URL (like "https://github.com/trainer04/DevSecOps-demo04.git" or local repo for your own Git server)<br>
- Set credentials if necessary (for private repos)<br>
- Set "Branch Specifier" as "*/main"<br>
- Set "Script Path" with the path to the Jenkins file (like "Jenkinsfile")<br>
<br>
Click "Save" finally<br>

### Configure entities in Jenkins (different variable parameters)<br>

For the possibility to use the demo pipeline without cloning and further editing of the repository files, some set of configurable pipeline parameters are moved in the Jenkins Credentials store.<br>
<b>Note! This configuration is insecure and used for demo purpose only, it should not be applied in production environment</b><br>

#### The IP of the "local repo" server<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: just the local repo IP and port - text <b>without backticks</b> (something like 192.168.0.5:5000)<br>
- ID (this ID will be used in the pipeline): <b>registry-host-ip</b><br>

#### The IP of the Vault server<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: the Vault connection string with protocol, IP and port - text <b>without backticks</b> (something like http://192.168.0.4:8200)<br>
- ID (this ID will be used in the pipeline): <b>vault-ip</b><br>

#### The token for the Vault server<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: the Vault token, defined on the Vault container creation step - text <b>without backticks</b> (the token specified above - test-only-token)<br>
- ID (this ID will be used in the pipeline): <b>vault-token</b><br>

#### The link for the Git repository<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: just the link to the actual git repo - text <b>without backticks</b> (here it is defined as https://github.com/trainer04/DevSecOps-demo04.git)<br>
- ID (this ID will be used in the pipeline): <b>git-repo-link</b><br>

#### In our scenario we use the private key password. Let's store it in the Jenkins Credentials (in production usually no such passwords used or they should be stored in Vault)<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: the password, which was specified with Cosign key pair generation<br>
- ID (this ID will be used in the pipeline): <b>cosign-key-password</b><br>

#### Specify the NVD key for the OWASP Dependency Check base downloading<br>
Use the https://nvd.nist.gov/developers/request-an-api-key link to obtain the NVD key.<br>
If you do not have the key, just use the empty string value ('') for the parameter (pipeline should work even if the provided key is wrong - just with lower download speed of the NVD base)<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>text</b><br>
- Secret: the received NVD key or an empty string<br>
- ID (this ID will be used in the pipeline): <b>NVD-key</b><br>

#### To verify the signed image you will need the public key of the generated key pair. There are several ways how to provide it in the pipeline - here in our scenario let's use Jenkins Credentials to store it as a Secret file<br>
- Jenkins > Credentials > System > Global credentials<br>
- "Add Credentials"<br>
- Kind: Secret <b>file</b><br>
- Select the "cosign.pub" file (copy it from the "demo env" server with scp or WinSCP or just create the text file with the public key content and save it locally)<br>
- ID (this ID will be used in the pipeline): <b>cosign-public-key</b><br>

### At the bottom-line you should have 7 entities in Jenkins Credentials (6 secret texts and 1 secret file). Once again - this is for the demo purpose only, DO NOT USE such configuration IN PRODUCTION environment!