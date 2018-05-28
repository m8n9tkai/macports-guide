# $Id$

# Makefile to generate the MacPorts HTML guide pages.
# See README.md for the list of ports that need to be installed.

# If your MacPorts isn't installed in /opt/local you have to change PREFIX
# here.

UNAME := $(shell uname)

# Prefix of the MacPorts installation.
PREFIX = $(realpath $(realpath $(shell which port))/../..)
ifeq ($(UNAME), Linux)
PREFIX = /usr
endif

# Command abstraction variables.
MKDIR    = /bin/mkdir
CP       = /bin/cp
RM       = /bin/rm
LN       = /bin/ln
ifeq ($(UNAME), Linux)
SED      = /bin/sed
REINPLACE = $(SED) -i -r
else
SED      = /usr/bin/sed
REINPLACE = $(SED) -i '' -E
endif
TCLSH    = /usr/bin/tclsh
XSLTPROC = $(PREFIX)/bin/xsltproc
XMLLINT  = $(PREFIX)/bin/xmllint
DBLATEX  = $(PREFIX)/bin/dblatex
ASCIIDOCTOR = $(PREFIX)/bin/asciidoctor

# Data directories.
GUIDE = guide
# Source directories.
GUIDE_ADOC = $(GUIDE)/adoc
GUIDE_XML = $(GUIDE)/xml
# Result directories.
GUIDE_RESULT         = $(GUIDE)/html
GUIDE_RESULT_DBLATEX = $(GUIDE)/dblatex

# Path to the DocBook XSL files.
GUIDE_XSL       = $(GUIDE)/resources/single-page.xsl
GUIDE_XSL_CHUNK = $(GUIDE)/resources/chunk.xsl

# DocBook HTML stylesheet for the guide.
STYLESHEET = docbook.css

.PHONY: all clean guide guide-chunked guide-fromadoc guide-dblatex validate

all: guide guide-chunked

# Generate the HTML guide using DocBook from the XML sources
guide:
	$(call xml2html,$(GUIDE_XML),$(GUIDE_RESULT),$(GUIDE_XSL))

guide-chunked::
	$(call xml2html,$(GUIDE_XML),$(GUIDE_RESULT)/chunked,$(GUIDE_XSL_CHUNK))

# Experimental adoc input files
guide-adoc2xml:
	$(ASCIIDOCTOR) -b docbook5 $(GUIDE_ADOC)/guide.adoc

guide-fromadoc: guide-adoc2xml
	$(call xml2html,$(GUIDE_ADOC),$(GUIDE_RESULT)/adoc,$(GUIDE_XSL))

# Rules to generate HTML from DocBook XML

define xml2html
	$(MKDIR) -p $(2)
	$(CP) $(GUIDE)/resources/$(STYLESHEET) $(2)/$(STYLESHEET)
	$(CP) $(GUIDE)/resources/images/* $(2)/
	$(CP) $(GUIDE)/resources/*.js $(2)/
	$(XSLTPROC) --xinclude \
	    --output $(2)/index.html \
	    $(3) $(1)/guide.xml
	# Convert all sections (h1-h9) to a link so it's easy to link to them.
	# If someone knows a better way to do this please change it.
	$(REINPLACE) \
	    's|(<h[0-9] [^>]*><a id="([^"]*)"></a>)([^<]*)(</h[0-9]>)|\1<a href="#\2">\3</a>\4|g' \
	    $(2)/index.html
endef

guide-chunked::
	# Add the table of contents to every chunked HTML file.
	# If someone knows a better way to do this please change it.
	$(TCLSH) toc-for-chunked.tcl $(GUIDE_RESULT)/chunked

# Generate the guide as a PDF.
guide-dblatex: SUFFIX = pdf
guide-dblatex:
	$(MKDIR) -p $(GUIDE_RESULT_DBLATEX)
	$(DBLATEX) \
		--fig-path="$(GUIDE)/resources/images" \
		--type="$(SUFFIX)" \
		--param='toc.section.depth=2' \
		--param='doc.section.depth=3' \
		--output="$(GUIDE_RESULT_DBLATEX)/macports-guide.$(SUFFIX)" \
	$(GUIDE_XML)/guide.xml

# Remove all temporary files generated by guide:.
clean:
	$(RM) -rf $(GUIDE_RESULT)
	$(RM) -rf $(GUIDE_RESULT_DBLATEX)
	$(RM) -f  guide.tmp.xml

# Validate the XML files for the guide.
validate:
	$(XMLLINT) --xinclude --loaddtd --postvalid --noout $(GUIDE_XML)/guide.xml
