<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:pass3="http://www.legislation.gov.uk/packages/bho-to-clml/pass3.xsl"
  xmlns:local="local:"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/pass3.xsl"
  package-version="1.0"
  default-mode="pass3"
  exclude-result-prefixes="xs local"
  version="3.0">

  <!-- PASS 3: Add pair numbers to closing brackets, so we can match opening and closing bracket pairs later -->

  <!-- -/- MODES -/- -->
  <xsl:mode name="pass3" visibility="public"/>

  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl" version="1.0">
    <xsl:override>
      <xsl:variable name="common:moduleName" select="tokenize(base-uri(document('')), '/')[last()]"/>
    </xsl:override>
  </xsl:use-package>

  <!-- -/- FUNCTIONS -/- -->
  <!-- pass3:find-opening-bracket just counts back through the brackets until the number of closed
  and opened brackets = 0. At that point, we have our opening bracket (because the brackets 
  balance, so every opened bracket has a matching closing bracket).
  -->
  <xsl:function name="pass3:find-opening-bracket">
    <xsl:param name="closing-bracket" as="element()"/>
    <xsl:variable name="closing-bracket" as="element()" select="$closing-bracket/self::local:bracket[@type='close']"/>
    <xsl:iterate select="reverse($closing-bracket/preceding::local:bracket)">
      <xsl:param name="depth" as="xs:integer" select="-1"/>
      <xsl:on-completion>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="failNode" select="$closing-bracket"/>
            <xsl:with-param name="message">
              <xsl:text>closing bracket with num </xsl:text>
              <xsl:value-of select="$closing-bracket/@num"/>
              <xsl:text> with preceding text &quot;</xsl:text>
              <xsl:value-of select="$closing-bracket/preceding::text()[1]"/>
              <xsl:text>&quot; doesn't have a matching opening bracket</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:on-completion>
      <xsl:variable name="newDepth" as="xs:integer">
        <xsl:choose>
          <xsl:when test="self::local:bracket[@type='open']">
            <xsl:sequence select="$depth + 1"/>
          </xsl:when>
          <xsl:when test="self::local:bracket[@type='close']">
            <xsl:sequence select="$depth - 1"/>
          </xsl:when>
        </xsl:choose>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="$newDepth eq 0">
          <xsl:sequence select="."/>
          <xsl:break/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:next-iteration>
            <xsl:with-param name="depth" select="$newDepth"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:function>

  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='close']" priority="+1">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:attribute name="closes-pair">
        <xsl:value-of select="pass3:find-opening-bracket(.)/@opens-pair"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- -/-/-/- Explicit structure templates -/-/-/- -->
  <!-- These handle the expected paths in the structure so there's an explicit
    rule for everything we expect, which means anything we don't expect falls
    through to a fallback rule to either be explicitly ignored or flagged -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracket[@type='open']" priority="+1">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="local:bracket/(@type|@shape|@num|@opens-pair)">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="local:bracket/text()">
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
