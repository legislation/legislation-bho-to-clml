<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml/bho-to-clml.xsl"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:local="local:"
  xmlns="http://www.legislation.gov.uk/namespaces/legislation"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/bho-to-clml.xsl"
  package-version="1.0"
  exclude-result-prefixes="xs xhtml leg local"
  version="3.0">

  <!-- -/- PARAMETERS -/- -->
  <xsl:param name="lookupFile" select="'lookup.xml'" static="yes"/>
  
  <!-- -/- MODES -/- -->
  <!-- These exist to allow debugging by overriding the "initial mode"
    setting in the XSLT processor. Doing so will output the document
    at the end of the specified pass, instead of at the end of the
    whole process. -->
  <xsl:mode name="bho-pass1" visibility="public"/>
  <xsl:mode name="bho-pass2" visibility="public"/>
  <xsl:mode name="bho-pass3" visibility="public"/>
  <xsl:mode name="bho-pass4" visibility="public"/>
  <xsl:mode name="bho-pass5" visibility="public"/>
  <xsl:mode/> <!-- for the unnamed mode -->
  
  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl">
    <xsl:override>
      <xsl:variable name="common:reportId" select="$reportId" visibility="private"/>
      <xsl:variable name="common:docUri" select="$docUri" visibility="private"/>
    </xsl:override>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass1.xsl">
    <xsl:accept component="mode" names="pass1" visibility="public"/>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass2.xsl">
    <xsl:accept component="mode" names="pass2" visibility="public"/>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass3.xsl">
    <xsl:accept component="mode" names="pass3" visibility="public"/>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass4.xsl">
    <xsl:accept component="mode" names="pass4" visibility="public"/>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass5.xsl">
    <xsl:accept component="mode" names="pass5" visibility="public"/>
  </xsl:use-package>
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/pass6.xsl">
    <xsl:accept component="mode" names="pass6" visibility="public"/>
    <xsl:override>
      <xsl:variable name="bho-to-clml:lookupFile" select="$lookupFile" visibility="private"/>
    </xsl:override>
  </xsl:use-package>
  
  <!-- -/- VARIABLES -/- -->
  <xsl:variable name="reportId" as="xs:string?" select="/report/@id"/>
  <xsl:variable name="docUri" as="xs:string" select="document-uri()"/>

  <!-- -/- TEMPLATES -/- -->
  <!-- Root templates: run the document through the 6 passes -->
  <xsl:template match="/" mode="bho-pass1">
    <xsl:apply-templates mode="pass1"/>
  </xsl:template>
  
  <xsl:template match="/" mode="bho-pass2">
    <xsl:variable name="prev">
      <xsl:apply-templates select="." mode="pass1"/>
    </xsl:variable>
    <xsl:apply-templates select="$prev/node()" mode="pass2"/>
  </xsl:template>
  
  <xsl:template match="/" mode="bho-pass3">
    <xsl:variable name="prev">
      <xsl:apply-templates select="." mode="bho-pass2"/>
    </xsl:variable>
    <xsl:apply-templates select="$prev/node()" mode="pass3"/>
  </xsl:template>
  
  <xsl:template match="/" mode="bho-pass4">
    <xsl:variable name="prev">
      <xsl:apply-templates select="." mode="bho-pass3"/>
    </xsl:variable>
    <xsl:apply-templates select="$prev/node()" mode="pass4"/>
  </xsl:template>
  
  <xsl:template match="/" mode="bho-pass5">
    <xsl:variable name="prev">
      <xsl:apply-templates select="." mode="bho-pass4"/>
    </xsl:variable>
    <xsl:apply-templates select="$prev/node()" mode="pass5"/>
  </xsl:template>
  
  <xsl:template match="/">
    <xsl:variable name="prev">
      <xsl:apply-templates select="." mode="bho-pass5"/>
    </xsl:variable>
    <xsl:apply-templates select="$prev/node()" mode="pass6"/>
  </xsl:template>
  
</xsl:package>