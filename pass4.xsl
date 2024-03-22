<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:pass4="http://www.legislation.gov.uk/packages/bho-to-clml/pass4.xsl"
  xmlns:local="local:"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/pass4.xsl"
  package-version="1.0"
  default-mode="pass4"
  exclude-result-prefixes="xs local"
  version="3.0">

  <!-- PASS 4: Wrap els and text between matching opening and closing brackets in a <bracketed> el -->

  <!-- -/- MODES -/- -->
  <xsl:mode name="pass4" visibility="public"/>

  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl" version="1.0">
    <xsl:override>
      <xsl:variable name="common:moduleName" select="tokenize(base-uri(document('')), '/')[last()]"/>
    </xsl:override>
  </xsl:use-package>

  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='open']" priority="+1">
    <xsl:param name="current-pair" as="xs:integer?" tunnel="yes" select="()"/>
    <xsl:variable name="opens-pair" select="@opens-pair"/>
    <local:bracketed>
      <xsl:copy-of select="@shape"/>
      <xsl:attribute name="pair" select="$opens-pair"/>
      <xsl:apply-templates select="following-sibling::node()[1]">
        <xsl:with-param name="current-pair" select="$opens-pair"/>
      </xsl:apply-templates>
    </local:bracketed>
    <xsl:apply-templates 
      select="(descendant::local:bracket|following::local:bracket)[@type='close' and @closes-pair = $opens-pair][1]/((descendant::node()|following-sibling::node()) except child::text()[1])[1]">
      <xsl:with-param name="current-pair" select="$current-pair"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='close']" priority="+1"/>

  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:text">
    <xsl:param name="current-pair" as="xs:integer?" tunnel="yes" select="()"/>
    <xsl:copy-of select="text()"/>
    <xsl:apply-templates select="following-sibling::node()[1]">
      <xsl:with-param name="current-pair" select="$current-pair"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="node()">
    <xsl:param name="current-pair" as="xs:integer?" tunnel="yes" select="()"/>
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="descendant::node()[1]">
        <xsl:with-param name="current-pair" select="$current-pair"/>
      </xsl:apply-templates>
    </xsl:copy>
    <xsl:apply-templates select="following-sibling::node()[1]">
      <xsl:with-param name="current-pair" select="$current-pair"/>
    </xsl:apply-templates>
  </xsl:template>

</xsl:package>
