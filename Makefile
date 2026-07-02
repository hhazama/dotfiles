SHELL_FILES := install.sh scripts/setup.sh \
	config/scripts/bin/claude-notify.sh \
	config/scripts/bin/fzf-preview-directory \
	config/scripts/bin/fzf-preview-file \
	config/scripts/bin/fzf-preview-git \
	config/claude-settings/hooks/validate-command.sh \
	config/claude-settings/statusline-command.sh

.PHONY: setup-hooks lint secrets check help

help:
	@echo "setup-hooks  pre-commit + commit-msg フックを有効化(Conventional Commits 強制)"
	@echo "lint         shellcheck/shfmt/yamllint/ansible-lint を実行(助言的)"
	@echo "secrets      gitleaks で秘密情報を走査"
	@echo "check        ansible を --check ドライランし links のドリフトを検知"

setup-hooks:
	pre-commit install --install-hooks

# 助言的。1つの linter が落ちても続行する(- prefix)
lint:
	-shellcheck $(SHELL_FILES)
	-shfmt -d $(SHELL_FILES)
	-yamllint ansible/
	-ansible-lint ansible/

secrets:
	gitleaks detect --no-banner --redact

check:
	cd ansible && ansible-playbook -i ./hosts/local \
		--extra-vars ansible_exec_user=$$USER \
		--extra-vars ansible_exec_user_home=$$HOME \
		--check --diff --tags links ./site.yml
