<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  package-version="1.0"
  exclude-result-prefixes="xs common"
  version="3.0">

  <!-- -/- VARIABLES -/- -->
  <!-- Note these are abstract and must be overridden when using any
    package that *uses this package*! In practice, this means when
    bho-to-clml.xsl imports each of the packages that use common.xsl,
    bho-to-clml.xsl must override common:reportId and common:docUri.
    -->
  <xsl:variable name="common:reportId" visibility="abstract"/>
  <xsl:variable name="common:docUri" visibility="abstract"/>
  <xsl:variable name="common:moduleName" visibility="abstract"/>

  <!-- -/- FUNCTIONS -/- -->
  <!-- common:node-kind is a helper function for outputting the node kind in error messages -->
  <xsl:function name="common:node-kind" as="xs:string" visibility="public">
    <xsl:param name="node" as="node()"/>
    <xsl:choose>
      <xsl:when test="$node/self::element()">
        <xsl:value-of select="concat('element(', $node/local-name(), ')')"/>
      </xsl:when>
      <xsl:when test="$node/self::comment()">
        <xsl:text>comment</xsl:text>
      </xsl:when>
      <xsl:when test="$node/self::processing-instruction()">
        <xsl:text>pi</xsl:text>
      </xsl:when>
      <xsl:when test="$node/self::document-node()">
        <xsl:text>doc fragment</xsl:text>
      </xsl:when>
      <xsl:otherwise>unknown</xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- -/- TEMPLATES -/- -->
  <xsl:template name="common:errmsg" visibility="public">
    <xsl:param name="failNode" as="node()?" required="false"/>
    <xsl:param name="message" as="xs:string" required="yes"/>

    <xsl:text>in module </xsl:text>
    <xsl:value-of select="$common:moduleName"/>
    <xsl:text>: report id </xsl:text>
    <xsl:value-of select="$common:reportId"/>
    <xsl:text> (</xsl:text>
    <xsl:value-of select="$common:docUri"/>
    <xsl:text>): </xsl:text>
    <xsl:value-of select="$message"/>
    <xsl:if test="$failNode">
      <xsl:text> at path </xsl:text>
      <xsl:value-of select="$failNode/path()"/>
    </xsl:if>
  </xsl:template>

</xsl:package>
