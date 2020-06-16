#
# makefile for Automating Build and Deplouy
#

help:
	@echo ""
	@echo "==> Manage Demo Application"
	@echo "update_cpanlib			Install CPAN libs"		
	@echo "update_db			Deploy Sqitch"
	@echo "update				(both above)"
	@echo "server				Start demo application"
	@echo "create_migration name=???	Create a new migration"


update_cpanlib:
	@cpanm --verbose --installdeps .'

update_db:
	@sqitch deploy

update: update_cpanlib update_db

server:
	@CATALYST_DEBUG=1 DBIC_TRACE=1 perl -Ilib -I ../lib/ ./lib/Example/Server.pm


create_migration:
	perl -Ilib -I ../lib/ -MExample -e 'Example->create_migration("$(name)")'

