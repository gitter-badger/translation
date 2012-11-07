TOP_DIR = ../..
DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment

include $(TOP_DIR)/tools/Makefile.common

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))

DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

SERVER_MODULE = SeedRoleTranslation 
SERVICE = naming_translation 
SERVICE_PORT = 7032

SPHINX_PORT = 7038
SPHINX_HOST = localhost

SERVICE_DIR = $(TARGET)/services/$(SERVICE)

TPAGE = $(DEPLOY_RUNTIME)/bin/perl $(DEPLOY_RUNTIME)/bin/tpage
TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT) --define kb_service_dir=$(SERVICE_DIR) \
	--define kb_sphinx_port=$(SPHINX_PORT) --define kb_sphinx_host=$(SPHINX_HOST)

all: bin

bin: $(BIN_PERL)

$(BIN_DIR)/%: scripts/%.pl 
	$(TOOLS_DIR)/wrap_perl '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

deploy: deploy-service
deploy-service: deploy-dir deploy-scripts deploy-libs deploy-doc deploy-services deploy-monit deploy-sphinx
deploy-client: deploy-dir deploy-scripts deploy-libs  deploy-doc

deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/webroot ] ; then mkdir $(SERVICE_DIR)/webroot ; fi
	if [ ! -d $(SERVICE_DIR)/sphinx ] ; then mkdir $(SERVICE_DIR)/sphinx ; fi

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		bash $(TOOLS_DIR)/wrap_perl.sh "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done 

deploy-libs:
	rsync -arv lib/. $(TARGET)/lib/.

deploy-sphinx:
	$(TPAGE) $(TPAGE_ARGS) service/reindex_sphinx.tt > $(TARGET)/services/$(SERVICE)/reindex_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/reindex_sphinx
	$(TPAGE) $(TPAGE_ARGS) service/start_sphinx.tt > $(TARGET)/services/$(SERVICE)/start_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/start_sphinx
	$(TPAGE) $(TPAGE_ARGS) service/stop_sphinx.tt > $(TARGET)/services/$(SERVICE)/stop_sphinx
	chmod +x $(TARGET)/services/$(SERVICE)/stop_sphinx
	$(DEPLOY_RUNTIME)/bin/perl scripts/gen_cdmi_sphinx_conf.pl lib/KSaplingDBD.xml lib/sphinx.conf.tt $(TPAGE_ARGS) > $(TARGET)/services/$(SERVICE)/sphinx.conf

deploy-services:
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE)/start_service
	chmod +x $(TARGET)/services/$(SERVICE)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE)/stop_service

deploy-monit:
	$(TPAGE) $(TPAGE_ARGS) service/process.$(SERVICE).tt > $(TARGET)/services/$(SERVICE)/process.$(SERVICE)

deploy-doc:
	$(DEPLOY_RUNTIME)/bin/pod2html -t "Seed Role Translations to Different Ontologies" lib/$(SERVER_MODULE)Impl.pm > doc/$(SERVER_MODULE).html
	cp doc/*html $(SERVICE_DIR)/webroot/.
