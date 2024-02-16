<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation"
  xmlns:local="local:"
  xmlns="http://www.legislation.gov.uk/namespaces/legislation"
  exclude-result-prefixes="xs xhtml leg local"
  version="3.0">
  
  <xsl:param name="lookupFile" select="'lookup.xml'" />
  
  <xsl:variable name="reportId" as="xs:string?" select="/report/@id" />
  <xsl:variable name="docUri" select="document-uri()" />
  <xsl:variable name="lookup" select="doc($lookupFile)" />
  <xsl:variable name="leg" select="$lookup//report[@id=$reportId]/@leg" />
  <xsl:variable name="legyr" select="$lookup//report[@id=$reportId]/@year" />
  <xsl:variable name="legnum" select="$lookup//report[@id=$reportId]/@chapter" />
  <xsl:variable name="legreg" select="$lookup//report[@id=$reportId]/@regnal" />
  <xsl:variable name="legtitle" select="$lookup//report[@id=$reportId]/@title" />
  
  <!-- TODO <xsl:variable name="legregalt">
    <xsl:variable name="monarchs">
      <xsl:analyze-string select="$legreg" regex="^([A-Z][a-z][a-zA-Z0-9&]+)/.+$">
        <xsl:matching-substring>
          <xsl:value-of select="regex-group(1)" />
        </xsl:matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$legreg = 'WillandMar'">
        <xsl:text>W</xsl:text>
      </xsl:when>
    </xsl:choose>
    <xsl:analyze-string select="$legreg" regex="([A-Z][a-z]{1,3})([1-8])?"></xsl:analyze-string>
  </xsl:variable>-->
  
  <xsl:variable name="legregaltfn">
    <xsl:message terminate="yes">
      <xsl:text>TODO: fix generation of regnal slug for image filenames (to avoid regnal year conflicts in filenames)</xsl:text>
    </xsl:message>
  </xsl:variable>
  
  <xsl:function name="local:make-f-id" as="xs:string">
    <xsl:param name="idref" as="xs:string" required="true" />
    <xsl:analyze-string select="$idref" regex="^n([1-9][0-9]{{0,4}})$">
      <xsl:matching-substring>
        <xsl:value-of
          select="format-number(number(regex-group(1)),'f00000')" />
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
            <xsl:with-param name="message">
              <xsl:text>id/idref </xsl:text>
              <xsl:value-of select="$idref" />
              <xsl:text> is not a valid footnote id</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
  <xsl:template match="/report">
    <Legislation SchemaVersion="1.0" 
      xsi:schemaLocation="http://www.legislation.gov.uk/namespaces/legislation https://www.legislation.gov.uk/schema/legislation.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"
      xmlns:xhtml="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns="http://www.legislation.gov.uk/namespaces/legislation">
      
      <xsl:apply-templates select="@*" />
      
      <ukm:Metadata>
        <dc:title><xsl:value-of select="$legtitle" /></dc:title>
        <dc:language>en</dc:language>
        <dc:publisher>British History Online</dc:publisher>
        <ukm:PrimaryMetadata>
          <ukm:DocumentClassification>
            <ukm:DocumentCategory Value="primary" />
            <ukm:DocumentMainType Value="EnglandAct" />
            <ukm:DocumentStatus Value="final" />
          </ukm:DocumentClassification>
          <ukm:Year Value="{$legyr}" />
          <ukm:Number Value="{$legnum}" />
          <ukm:AlternativeNumber Category="Regnal" Value="[PLACEHOLDER REGNAL]"/>
          <xsl:message terminate="yes">
            <xsl:text>TODO: Fix generation of value for ukm:AlternativeNumber Category="Regnal"</xsl:text>
          </xsl:message>
        </ukm:PrimaryMetadata>
      </ukm:Metadata>
      
      <Primary>
        <PrimaryPrelims>
          <Title>[PLACEHOLDER TITLE]
            <xsl:message terminate="yes">
              <xsl:text>TODO: Fix generation of value for Title</xsl:text>
            </xsl:message></Title>
          <Number>[PLACEHOLDER CITATION]
            <xsl:message terminate="yes">
              <xsl:text>TODO: Fix generation of value for Act number citation</xsl:text>
            </xsl:message></Number>
          <LongTitle>[PLACEHOLDER LONG TITLE]
            <xsl:message terminate="yes">
              <xsl:text>TODO: Fix generation of value for long title</xsl:text>
            </xsl:message></LongTitle>
          <DateOfEnactment>
            <DateText/>
          </DateOfEnactment>
        </PrimaryPrelims>
        
        <Body>
          <xsl:apply-templates select="descendant::section" />
        </Body>
      </Primary>
      
      <xsl:if test="descendant::note">
        <Footnotes>
          <xsl:apply-templates select="descendant::note" />
        </Footnotes>
      </xsl:if>
      
      <xsl:if test="descendant::figure">
        <Resources>
          <xsl:apply-templates select="descendant::figure" mode="resource" />
        </Resources>
      </xsl:if>
      
    </Legislation>
  </xsl:template>
  
  <xsl:template match="report/@id" />
  <xsl:template match="report/@pubid" />
  <xsl:template match="report/@publish" />
  
  <xsl:template match="section">
    <P1group>
      <xsl:apply-templates select="@*" />
      <Title><xsl:apply-templates select="head" mode="title" /></Title>
      <xsl:choose>
        <xsl:when test="matches(head, '^[IVXLC]+\W?\s')">
          <P1>
            <xsl:apply-templates select="head" mode="pnumber" />
            <xsl:apply-templates mode="p1para" />
          </P1>
        </xsl:when>
        <xsl:when test="not(normalize-space(head))">
          <xsl:apply-templates mode="p" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="p" />
          <xsl:message>
            <xsl:call-template name="errmsg">
              <xsl:with-param name="failNode" select="." />
              <xsl:with-param name="message">
                <xsl:text>section with non-empty head (</xsl:text>
                <xsl:value-of select="head" />
                <xsl:text>) that doesn't seem to have a provision
                  number</xsl:text>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </P1group>
  </xsl:template>
  
  <xsl:template match="section/@id" />
  
  <xsl:template match="section" mode="p1para" />
  <xsl:template match="section" mode="p" />
  
  <xsl:template match="head" mode="p1para" />
  <xsl:template match="head" mode="p" />
  
  <!-- C[Hh]? ?[Aa] ?[Pp]([Tt][Ee][Rr])?\s* || ([\[(][^\])]+[\])]\s*)? -->
  <xsl:template match="head" mode="title">
    <xsl:variable name="this" select="." />
    <xsl:apply-templates select="@*" />
    <xsl:analyze-string select="string()" 
      regex="^([IVXLC0-9]+\.?\s*)?(.*)$">
      <xsl:matching-substring>
        <xsl:call-template name="processText">
          <xsl:with-param name="node" select="$this/node()" />
          <xsl:with-param name="title" select="true()" />
        </xsl:call-template>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="$this" />
            <xsl:with-param name="message">
              <xsl:text>head text pattern failed to match head text </xsl:text>
              <xsl:value-of select="." />
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <xsl:template match="head" mode="pnumber">
    <xsl:variable name="this" select="." />
    <xsl:apply-templates select="@*" />
    <xsl:analyze-string select="string()" regex="^([IVXLC0-9]+)(\W)?\s*.*$">
      <xsl:matching-substring>
        <xsl:variable name="num" select="regex-group(1)" />
        <xsl:variable name="puncAfter" select="regex-group(2)" />
        <Pnumber PuncAfter="{$puncAfter}">
          <xsl:value-of select="$num" />
        </Pnumber>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="$this" />
            <xsl:with-param name="message">
              <xsl:text>couldn't extract the pnumber for head text </xsl:text>
              <xsl:value-of select="." />
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <xsl:template match="head/text()" />
  
  <xsl:template match="para" mode="p1para">
    <xsl:apply-templates select="@*" />
    <P1para>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()" />
        <xsl:with-param name="wrapInTextEls" select="true()" />
      </xsl:call-template>
    </P1para>
  </xsl:template>
  
  <xsl:template match="para" mode="p">
    <xsl:apply-templates select="@*" />
    <P>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()" />
        <xsl:with-param name="wrapInTextEls" select="true()" />
      </xsl:call-template>
      <!-- include tables in P so they show up in section view -->
      <xsl:apply-templates 
        select="following-sibling::table except 
                following-sibling::element()[not(self::table)]/following-sibling::table" />
    </P>
  </xsl:template>
  
  <xsl:template match="para/@id" />
  
  <xsl:template match="note">
    <Footnote id="{local:make-f-id(@id)}">
      <xsl:apply-templates select="@* except @id" />
      <FootnoteText>
        <Para>
          <xsl:call-template name="processText">
            <xsl:with-param name="node" select="node()" />
            <xsl:with-param name="wrapInTextEls" select="true()" />
          </xsl:call-template>
        </Para>
      </FootnoteText>
    </Footnote>
  </xsl:template>
  
  <xsl:template match="note/@number" />
  
  <xsl:template match="ref">
    <xsl:apply-templates select="@* except @idref" />
    <FootnoteRef Ref="{local:make-f-id(@idref)}" />
  </xsl:template>
  
  <xsl:template match="emph[@type='i']">
    <xsl:apply-templates select="@* except @type" />
    <Emphasis>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()" />
      </xsl:call-template>
    </Emphasis>
  </xsl:template>
  
  <xsl:template match="emph[@type='p']">
    <xsl:apply-templates select="@* except @type" />
    <Superior>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()" />
      </xsl:call-template>
    </Superior>
  </xsl:template>
  
  <xsl:template match="table" mode="p1para">
    <xsl:apply-templates select="." />
  </xsl:template>
  
  <xsl:template match="table" mode="p" />
  
  <xsl:template match="table">
    <xsl:variable name="tableNumber" as="xs:integer">
      <xsl:number count="table" level="any" />
    </xsl:variable>
    <Tabular id="{format-number($tableNumber, 't00000')}">
      <xsl:apply-templates select="@* except @id" />
      <table xmlns="http://www.w3.org/1999/xhtml">
        <!-- no thead as some SotR tables have headers half way down -->
        <tbody>
          <xsl:apply-templates select="node()" />
        </tbody>
      </table>
    </Tabular>
  </xsl:template>
  
  <xsl:template match="tr">
    <tr xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates />
    </tr>
  </xsl:template>
  
  <xsl:template match="(table|tr)/text()[not(normalize-space())]" />
  
  <xsl:template match="th">
    <th xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*" />
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()" />
      </xsl:call-template>
    </th>
  </xsl:template>
  
  <xsl:template match="td">
    <td xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*" />
      <xsl:if test="descendant::element() or text()[normalize-space()]">
        <xsl:call-template name="processText">
          <xsl:with-param name="node" select="node()" />
        </xsl:call-template>
      </xsl:if>
    </td>
  </xsl:template>
  
  <xsl:template match="(th|td)/@rows">
    <xsl:attribute name="rowspan" select="data()" />
  </xsl:template>
  
  <xsl:template match="(th|td)/@cols">
    <xsl:attribute name="colspan" select="data()" />
  </xsl:template>
  
  <xsl:template match="figure">
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any" />
    </xsl:variable>
    <xsl:apply-templates select="@*" />
    <Figure id="{format-number($figureNumber, 'g00000')}">
      <xsl:apply-templates select="caption" />
      <Image ResourceRef="{format-number($figureNumber, 'r00000')}" />
    </Figure>
  </xsl:template>
  
  <xsl:template match="figure" mode="resource">
    <xsl:variable name="leg" select="replace($leg, '^.+/id/(.+)$', '$1')" />
    <xsl:variable name="imglang" select="'?todolang?'" />
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any" />
    </xsl:variable>
    <Resource id="{format-number($figureNumber, 'r00000')}">
      <ExternalVersion URI="{replace($leg, '/id/', '/')}/images/aep_{$legregaltfn}_{format-number($legnum, '0000')}_{$imglang}_{format-number($figureNumber, '000')}" />
    </Resource>
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="." />
        <xsl:with-param name="message">figure transform not implemented yet for figure</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <xsl:template match="caption">
    <Para>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="." />
        <xsl:with-param name="wrapInTextEls" select="true()" />
      </xsl:call-template>
    </Para>
  </xsl:template>
  
  <xsl:template match="@*">
    <!-- fallback - helps us discover and deal with unexpected attributes -->
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="." />
        <xsl:with-param name="message">unmatched attr</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <xsl:template match="node() | text()">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="." />
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <xsl:template name="processText">
    <!-- This function wraps text in Text elements, strips brackets around
      footnotes, and so on -->
    <xsl:param name="node" as="node()+" />
    <xsl:param name="wrapInTextEls" as="xs:boolean" select="false()" />
    <xsl:param name="title" as="xs:boolean" select="false()" />

    <xsl:message terminate="yes">
      <xsl:text>TODO: Fix removal of brackets from around (1) footnotes</xsl:text>
    </xsl:message>
    
    <xsl:choose>
      <xsl:when test="$wrapInTextEls = true()">
        <xsl:if test="$title = true()">
          <xsl:message terminate="yes">
            <xsl:call-template name="errmsg">
              <xsl:with-param name="failNode" select="." />
              <xsl:with-param name="message">
                <xsl:text>musn't wrap title text in text els</xsl:text>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:message>
        </xsl:if>
        <xsl:for-each-group 
          select="$node"
          group-starting-with="self::br">
          <Text>
            <xsl:call-template name="processText">
              <xsl:with-param name="node" select="current-group() except self::br" />
            </xsl:call-template>
          </Text>
        </xsl:for-each-group>
      </xsl:when>
      <xsl:otherwise>
        <xsl:iterate select="$node">
          <xsl:param name="cumulText" as="xs:string?" />
          <xsl:param name="cumulNodes" as="node()*" />
          <xsl:param name="cumulChildNodes" as="node()*" />
          
          <xsl:on-completion>
            <xsl:sequence select="$cumulNodes" />
            <xsl:choose>
              <xsl:when test="$cumulChildNodes and not($cumulText)">
                <xsl:sequence select="$cumulChildNodes" />
              </xsl:when>
              <xsl:when test="$cumulText and not($cumulChildNodes)">
                <xsl:value-of select="$cumulText" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:message terminate="yes">
                  <xsl:call-template name="errmsg">
                    <xsl:with-param name="failNode" select="$node" />
                    <xsl:with-param name="message">
                      <xsl:text>both accumulated text and accumulated 
                        child nodes present at end of processText</xsl:text>
                    </xsl:with-param>
                  </xsl:call-template>
                </xsl:message>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:on-completion>
          
          <xsl:choose>
            <xsl:when test="self::emph or self::ref">
              <xsl:next-iteration>
                <xsl:with-param name="cumulText" select="()" />
                <xsl:with-param name="cumulNodes">
                  <xsl:sequence select="$cumulNodes" />
                  <xsl:if test="$cumulText">
                    <xsl:choose>
                      <xsl:when test="not($cumulChildNodes)">
                        <xsl:value-of select="$cumulText" />
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:message terminate="yes">
                          <xsl:call-template name="errmsg">
                            <xsl:with-param name="failNode" select="." />
                            <xsl:with-param name="message">
                              <xsl:text>new child node started when there is
                                text accumulated in processText</xsl:text>
                            </xsl:with-param>
                          </xsl:call-template>
                        </xsl:message>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:if>
                </xsl:with-param>
                <xsl:with-param name="cumulChildNodes">
                  <xsl:sequence select="$cumulChildNodes" />
                  <xsl:apply-templates select="." />
                </xsl:with-param>
              </xsl:next-iteration>
            </xsl:when>
            <xsl:when test="self::text()">
              <xsl:variable name="newCumulText">
                <xsl:choose>
                  <xsl:when 
                    test="matches($cumulText, '\s*') and 
                    matches(., '\s*[\])]') and
                    (every $n in $cumulChildNodes satisfies $n/self::ref)">
                    <xsl:value-of select="replace($cumulText, '[(\[]\s*', '')" />
                  </xsl:when>
                  <xsl:when test="matches($cumulText, '([(\[])\s+')">
                    <xsl:value-of select="replace(., '([(\[])\s+', '$1')" />
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$cumulText" />
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <xsl:variable name="newThisText">
                <xsl:choose>
                  <xsl:when 
                    test="$title = true() and 
                          not($cumulNodes[self::text()]) and
                          not(normalize-space($newCumulText))">
                    <xsl:analyze-string select="."
                      regex="^([IVXLC0-9]+\.?\s*)(.*)$">
                      <xsl:matching-substring>
                        <xsl:value-of select="regex-group(2)" />
                      </xsl:matching-substring>
                      <xsl:non-matching-substring>
                        <xsl:value-of select="." />
                      </xsl:non-matching-substring>
                    </xsl:analyze-string>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="." />
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <xsl:variable name="newThisText">
                <xsl:choose>
                  <xsl:when 
                    test="matches($cumulText, '[(\[]\s*') and 
                    matches($newThisText, '\s*[\])]') and
                    (every $n in $cumulChildNodes satisfies $n/self::ref)">
                    <xsl:value-of select="replace($newThisText, '\s*[\])]', '')" />
                  </xsl:when>
                  <xsl:when test="matches($newThisText, '\s+([\])])')">
                    <xsl:value-of select="replace($newThisText, '\s+([\])])', '$1')" />
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$newThisText" />
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <xsl:next-iteration>
                <xsl:with-param name="cumulText">
                  <xsl:choose>
                    <xsl:when test="$newCumulText and not($cumulChildNodes)">
                      <xsl:value-of 
                        select="concat($newCumulText, $newThisText)" />
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="$newThisText" />
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="cumulNodes">
                  <xsl:sequence select="($cumulNodes, $cumulChildNodes)" />
                </xsl:with-param>
                <xsl:with-param name="cumulChildNodes" select="()" />
              </xsl:next-iteration> 
            </xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">
                <xsl:call-template name="errmsg">
                  <xsl:with-param name="failNode" select="." />
                  <xsl:with-param name="message">
                    <xsl:text>unexpected node of kind </xsl:text>
                    <xsl:value-of 
                      select="if (self::element()) then local-name()
                              else if (self::comment()) then 'comment'
                              else if (self::processing-instruction()) then 'pi'
                              else if (self::document-node()) then 'doc fragment'
                              else 'unknown'" />
                    <xsl:text> found in processText with </xsl:text>
                    <xsl:text>wrapInTextEls = false</xsl:text>
                  </xsl:with-param>
                </xsl:call-template>
              </xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:iterate>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="errmsg">
    <xsl:param name="failNode" as="node()" required="false" />
    <xsl:param name="message" as="xs:string" required="yes" />
    
    <xsl:text>report id </xsl:text>
    <xsl:value-of select="$reportId" />
    <xsl:text> (</xsl:text>
    <xsl:value-of select="$docUri" />
    <xsl:text>): </xsl:text>
    <xsl:value-of select="$message" />
    <xsl:if test="$failNode">
      <xsl:text> at path </xsl:text>
      <xsl:value-of select="$failNode/path()" />
    </xsl:if>
  </xsl:template>
  
</xsl:stylesheet>