SHELL_FILES := install.sh scripts/setup.sh \
	scripts/test-antigravity-hooks.sh \
	config/scripts/bin/fzf-preview-directory \
	config/scripts/bin/fzf-preview-file \
	config/scripts/bin/fzf-preview-git \
	config/claude-settings/hooks/validate-command.sh \
	config/claude-settings/statusline-command.sh \
	home/.gemini/antigravity-cli/statusline-command.sh \
	home/.gemini/config/hooks/validate-command.sh \
	home/.gemini/config/hooks/guard-sensitive-files.sh \
	home/.gemini/config/hooks/format-on-edit.sh \
	home/.gemini/config/hooks/notify-on-stop.sh \
	scripts/hooks/pre-push

.PHONY: setup-hooks lint secrets check help

help:
	@echo "setup-hooks  pre-commit + commit-msg + pre-push フックを有効化(秘密検知・Conventional Commits 強制)"
	@echo "lint         shellcheck/shfmt/yamllint/ansible-lint を実行(助言的)"
	@echo "secrets      gitleaks で秘密情報を走査"
	@echo "check        ansible を --check ドライランし links のドリフトを検知"

setup-hooks:
	pre-commit install --install-hooks
	ln -sf "$(CURDIR)/scripts/hooks/pre-push" "$$(git rev-parse --git-common-dir)/hooks/pre-push"

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
