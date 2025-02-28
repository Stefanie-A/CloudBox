TF_DIR=terraform  # Change this if your Terraform files are in a different directory

up:
	cd $(TF_DIR) && terraform init && terraform apply -auto-approve

down:
	cd $(TF_DIR) && terraform destroy -auto-approve

plan:
	terraform plan

fmt:
	cd $(TF_DIR) && terraform fmt -recursive

validate:
	cd $(TF_DIR) && terraform validate

output:
	cd $(TF_DIR) && terraform output

clean:
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl $(TF_DIR)/terraform.tfstate* 
