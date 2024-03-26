<?xml version="1.0" encoding="UTF-8"?>
<!-- SPDX-License-Identifier: OGL-UK-3.0 -->
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:pass2="http://www.legislation.gov.uk/packages/bho-to-clml/pass2.xsl"
  xmlns:local="local:"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/pass2.xsl"
  package-version="1.0"
  default-mode="pass2"
  exclude-result-prefixes="xs bho-to-clml common pass2 local"
  version="3.0">

  <!-- PASS 2: Add pair numbers to opening brackets, so we can track where each bracket pair starts -->

  <!-- -/- MODES -/- -->
  <xsl:mode name="pass2" visibility="public"/>

  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl" version="1.0">
    <xsl:override>
      <xsl:variable name="common:moduleName" select="tokenize(base-uri(document('')), '/')[last()]"/>
    </xsl:override>
  </xsl:use-package>

  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='open']" priority="+1">
    <xsl:choose>
      <!-- if the immediately preceding sibling is a <?bignore?>,
        then this bracket doesn't have a match in the original 
        printed text, so we can't handle it using our fancy bracket
        handling code - just output it as plain text instead -->
      <xsl:when test="preceding-sibling::node()[1]/self::processing-instruction('bignore')">
        <local:text>
          <!-- wrap in <local:text> so later steps process correctly -->
          <xsl:value-of select="."/>
        </local:text>
      </xsl:when>

      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:attribute name="num">
            <xsl:number level="any"/>
          </xsl:attribute>
          <xsl:attribute name="opens-pair">
            <xsl:number count="local:bracket[@type='open']" level="any"/>
          </xsl:attribute>
          <xsl:apply-templates select="node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='close']" priority="+1">
    <xsl:choose>
      <!-- if the immediately following sibling is a <?bignore?>,
        then this bracket doesn't have a match in the original 
        printed text, so we can't handle it using our fancy bracket
        handling code - just output it as plain text instead -->
      <xsl:when test="following-sibling::node()[1]/self::processing-instruction('bignore')">
        <!-- wrap in <local:text> so later steps process correctly -->
        <local:text>
          <xsl:value-of select="."/>
        </local:text>
      </xsl:when>

      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:attribute name="num">
            <xsl:number level="any"/>
          </xsl:attribute>
          <xsl:apply-templates select="node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- -/-/-/- Explicit structure templates -/-/-/- -->
  <!-- These handle the expected paths in the structure so there's an explicit
    rule for everything we expect, which means anything we don't expect falls
    through to a fallback rule to either be explicitly ignored or flagged -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket/text()" priority="+1">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:text" priority="+1">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:text/text()" priority="+1">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="/report/(self::*|title|subtitle)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/subtitle/emph">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/(self::*|head|para|figure|table|note)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/head/emph">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/para/(emph|br)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(subtitle|section/(head|para)|section/section/(head|para))/(emph/ref|ref)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/figure/caption">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/table/tr/(self::*|th|td)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/table/tr/(th|td)/(emph|ref|br)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/note/emph">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="(report|section|para|note|table)/@id">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="note/@number">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="emph/@type">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="ref/@idref">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="figure/(@id|@number|@graphic)">
    <xsl:copy/>
  </xsl:template>
  <xsl:template match="(th|td)/(@cols|@rows)">
    <xsl:copy/>
  </xsl:template>

  <!-- -/-/-/- Fallback templates -/-/-/- -->
  <!-- These templates explicitly ignore things we know should be there but don't
    want to handle, or catch anything we didn't expect and haven't handled - this
    makes the stylesheet's behaviour much more predictable by explicitly flagging
    any situation we haven't handled -->

  <xsl:template match="processing-instruction('bignore')"/>

  <!-- Final fallbacks - helps us discover and deal with unexpected doc structure -->
  <xsl:template match="@*">
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched/unexpected attr</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="node() | text()">
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched/unexpected node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

</xsl:package>
