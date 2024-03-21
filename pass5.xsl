<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml/bho-to-clml.xsl"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:pass5="http://www.legislation.gov.uk/packages/bho-to-clml/pass5.xsl"
  xmlns:local="local:"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/pass5.xsl"
  package-version="1.0"
  default-mode="pass5"
  exclude-result-prefixes="xs local"
  version="3.0">
  
  <!-- PASS 5: Handle the <bracketed> elements:
   * Round brackets that contain a child <ref> just output the <ref>
     - we use this to create <CommentaryRef Ref=""> later
   * Square brackets that contain a <ref> take the @idref from the <ref> and put it on the <bracket>
     - we use this to create <Addition CommentaryRef=""> later
   * Round or square brackets that don't contain a <ref> get output as text in [(brackets)] again
     - to restore any brackets in the text that don't denote a commentary or footnote!
  -->
  
  <!-- -/- MODES -/- -->
  <xsl:mode name="pass5" visibility="public"/>
  <xsl:mode name="pass5-ref"/>
  
  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl" version="1.0">
    <xsl:override>
      <xsl:variable name="common:moduleName" select="tokenize(base-uri(document('')), '/')[last()]"/>
    </xsl:override>
  </xsl:use-package>
  
  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracketed">
    <xsl:variable name="ref" select="child::ref/@idref"/>
    <xsl:if test="count($ref) gt 1">
      <xsl:message>
        <xsl:text>Warning: </xsl:text>
        <xsl:call-template name="common:errmsg">
          <xsl:with-param name="failNode" select="."/>
          <xsl:with-param name="message">
            <xsl:text>bracketed el with pair </xsl:text>
            <xsl:value-of select="@pair"/>
            <xsl:text> and string content &quot;</xsl:text>
            <xsl:value-of select="string()"/>
            <xsl:text>&quot; has multiple refs: </xsl:text>
            <xsl:value-of select="string-join($ref, ' ')"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:message>
    </xsl:if>
    
    <xsl:choose>
      <!-- We treat <ref> in round brackets as a CommentaryRef -->
      <xsl:when test="@shape = 'round'">
        <xsl:choose>
          <xsl:when test="$ref">
            <xsl:apply-templates mode="pass5-ref"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>(</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>)</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- We treat <ref> in square brackets as an <Addition> -->
      <xsl:when test="@shape = 'square'">
        <xsl:choose>
          <xsl:when test="$ref">
            <xsl:copy>
              <xsl:attribute name="idref" select="subsequence($ref, 1, 1)"/>
              <xsl:apply-templates/>
              
              <!-- if there's multiple refs, we stick them at the end -->
              <xsl:if test="count($ref) gt 1">
                <xsl:apply-templates select="subsequence($ref, 2)" mode="pass5-ref"/>
              </xsl:if>
            </xsl:copy>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>[</xsl:text>
            <xsl:apply-templates/>
            <xsl:text>]</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="ref" mode="pass5-ref" priority="+1">
    <!-- copy the ref and its attrs but not its text, which we don't need -->
    <xsl:copy>
      <xsl:copy-of select="@*"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="ref" priority="+1"/>
  
  <!-- -/-/-/- Explicit structure templates -/-/-/- -->
  <!-- These handle the expected paths in the structure so there's an explicit
    rule for everything we expect, which means anything we don't expect falls
    through to a fallback rule to either be explicitly ignored or flagged -->
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/text()" priority="+1">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/local:bracketed/text()" priority="+1">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template match="/report/(self::*|title|subtitle)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/subtitle/(emph|ref)">
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
  <xsl:template match="(report|section)/text()[not(normalize-space())]"/>
  
  <xsl:template match="report/@pubid"/>
  <xsl:template match="report/@publish"/>
  
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