#
# makefile for common devops / automation tasks
#

help::
	@echo ""
	@echo "==> Setup and Dependency Management"
	@echo "setup		-- Install Perl to $(LOCALDIR) and bootstrap dependencies"
	@echo "installdeps	-- Install 'cpanfile' dependencys to $(LOCALDIR)"
	@echo "installdevelop 	-- Install 'cpanfile --with-develop' dependencys to $(LOCALDIR)"
	@echo "buildperl	-- Install Perl to $(PERLINSTALLTARGETDIR)"
	@echo "locallib		-- Bootstrap a local-lib to $(LOCALDIR)"
	@echo "buildexec	-- Create $(LOCALDIR)/exec script"
	@echo ""
	@echo "==> Server Control"
	@echo "server		-- Start the application in the foreground process"
	@echo "db do=..."	-- Run migration commands
	@echo ""

deployment_statements::
	perl -Ilib -I ../../lib/ -e 'use Example; print Example->model("Schema")->schema->deployment_statements;'


