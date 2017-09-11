variable "aws_key_pair_name" {
  type   = "string"
}

variable "ssh_key_location" {
  type   = "string"
}

provider "aws" {
  region = "eu-west-1"
}

resource "random_id" "id" {
  byte_length = 6
}

resource "aws_instance" "test_runner" {

  ami           = "ami-6d48500b"
  instance_type = "t2.micro"
  key_name      = "${var.aws_key_pair_name}"

  tags = {
    Name = "test_terraform_runner_${random_id.id.dec}"
  }

  connection {
   type     = "ssh"
   user     = "ubuntu"
   host     = "${aws_instance.test_runner.public_dns}"
   private_key = "${file("${var.ssh_key_location}")}"
  }

  provisioner "remote-exec" {

    inline = [
      "echo '******************* INSTALLING GITLAB-CI-MULTI-RUNNER *******************'",
      "curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.deb.sh | sudo bash",
      "sudo apt-get install gitlab-ci-multi-runner",
      <<EOF
      sudo gitlab-runner register \
      --non-interactive \
      --url https://gitlab.com/ \
      --registration-token XXXXXXXXXXXXXXX \
      --description aws_terraform_runner_${random_id.id.dec} \
      --tag-list django,git,postgres,python,shell \
      --run-untagged=true \
      --executor shell
EOF
      ,
      "echo '************************* SETTING PERMISSIONS ***************************'",
      "sudo usermod -aG sudo gitlab-runner",
      "sudo usermod -aG admin gitlab-runner",
      "sudo cp /etc/sudoers /etc/sudoers.bak",
      "echo 'gitlab-runner ALL = NOPASSWD: ALL' | sudo tee -a /etc/sudoers",
      "echo '******************************** DONE! **********************************'",
    ]
  }

  provisioner "remote-exec" {

    when = "destroy"

    inline = [
      "echo '******************* UNREGISTERING GITLAB-CI-MULTI-RUNNER *******************'",
      "sudo gitlab-runner unregister --name aws_terraform_runner_${random_id.id.dec}",
    ]
  }

}
