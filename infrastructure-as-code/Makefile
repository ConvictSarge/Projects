.PHONY: fmt validate lint plan apply destroy configure

fmt:
	tofu -chdir=terraform fmt -recursive

validate:
	tofu -chdir=terraform init -backend=false
	tofu -chdir=terraform validate

lint:
	cd ansible && ansible-lint

plan:
	tofu -chdir=terraform plan -out lab.plan

apply:
	tofu -chdir=terraform apply lab.plan

destroy:
	tofu -chdir=terraform destroy

configure:
	cd ansible && ansible-playbook playbooks/baseline.yml
