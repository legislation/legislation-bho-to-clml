<?xml version="1.0" encoding="UTF-8"?>
<xsl:package xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation"
  xmlns:bho-to-clml="http://www.legislation.gov.uk/packages/bho-to-clml/bho-to-clml.xsl"
  xmlns:common="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl"
  xmlns:pass6="http://www.legislation.gov.uk/packages/bho-to-clml/pass6.xsl"
  xmlns:local="local:"
  xmlns="http://www.legislation.gov.uk/namespaces/legislation"
  name="http://www.legislation.gov.uk/packages/bho-to-clml/pass6.xsl"
  package-version="1.0"
  default-mode="pass6"
  exclude-result-prefixes="xs local"
  version="3.0">
  
  <!-- PASS 6: Turn the BHO XML into CLML -->
  
  <!-- -/- MODES -/- -->
  <xsl:mode name="pass6" visibility="public"/>
  <xsl:mode name="pass6-title"/>
  <xsl:mode name="pass6-text"/>
  <xsl:mode name="pass6-head"/>
  <xsl:mode name="pass6-resource"/>
  <xsl:mode name="pass6-pnumber"/>
  <xsl:mode name="pass6-p1para"/>
  <xsl:mode name="pass6-p"/>
  <xsl:mode name="pass6-text-wrap"/>
  
  <!-- -/- PACKAGE IMPORTS -/- -->
  <xsl:use-package name="http://www.legislation.gov.uk/packages/bho-to-clml/common.xsl" version="1.0">
    <xsl:override>
      <xsl:variable name="common:moduleName" select="tokenize(base-uri(document('')), '/')[last()]"/>
    </xsl:override>
  </xsl:use-package>
  
  <!-- -/- VARIABLES -/- -->
  <!-- Note these are abstract and must be overridden when using any
    package that *uses this package*! -->
  <xsl:variable name="common:reportId" as="xs:string?" visibility="abstract"/>
  <xsl:variable name="common:docUri" visibility="abstract"/>
  <xsl:variable name="bho-to-clml:lookupFile" visibility="abstract"/>
  
  <xsl:variable name="lookup" select="doc($bho-to-clml:lookupFile)"/>
  
  <!-- must select as element() or we get a doc fragment -->
  <xsl:variable name="report" as="element()">
    <xsl:choose>
      <xsl:when test="$lookup//report[@id=$common:reportId]">
        <xsl:sequence select="$lookup//report[@id=$common:reportId]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="failNode" select="/"/>
            <xsl:with-param name="message">no entry in lookup file for this item</xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="leg" as="xs:string" select="$report/@leg"/>
  <xsl:variable name="legyr" as="xs:integer" select="$report/@year"/>
  <xsl:variable name="legnum" as="xs:integer" select="$report/@chapter"/>
  <xsl:variable name="legreg" as="xs:string" select="$report/@regnal"/>
  <xsl:variable name="legtitle" as="xs:string" select="$report/@title"/>
  <xsl:variable name="legtitlesource" as="xs:string" select="$report/@titleSource"/>
  <xsl:variable name="legtitlecomment" as="xs:string" select="$report/@titleComment"/>
  
  <xsl:variable name="legregregex"
    select="'^([A-Z][a-z]+)([1-9])?((and)(1)?([A-Z][a-z]+)([1-9])?)?/([1-9][0-9]?)(-([1-9][0-9]?))?(-([1-9][0-9]?))?(/([Ss][a-z]+)([1-9]))?$'"/>
  
  <xsl:variable name="legregaltfn">
    <!-- & => and, any seq of non-alphanum chars to _ (underscore) -->
    <xsl:value-of select="replace(replace($legreg, '&#38;', 'and'), '[^a-zA-Z0-9]+', '_')"/>
  </xsl:variable>
  
  <xsl:variable name="legregaltprelim">
    <xsl:analyze-string select="$legreg" regex="{$legregregex}">
      <xsl:matching-substring>
        <xsl:variable name="regyrs" select="replace(
          replace(
          string-join(
          (
          regex-group(8),
          regex-group(10),
          regex-group(12)
          ),
          ' '
          ), '([1-9][0-9]?) ([1-9][0-9]?)$', '$1 and $2'
          ), '^([1-9][0-9]?) ([1-9][0-9]?)( |$)', '$1, $2$3'
          )"/>
        <xsl:value-of select="normalize-space(string-join(
          (
          $regyrs,
          regex-group(1),
          regex-group(2),
          regex-group(4),
          regex-group(5),
          regex-group(6),
          regex-group(7),
          if (regex-group(13))
          then (concat(regex-group(14), '.'), regex-group(15))
          else ()
          ), ' '))"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="message">
              <xsl:text>couldn't make prelims regnal year because I </xsl:text>
              <xsl:text>don't know how to parse </xsl:text>
              <xsl:value-of select="$legreg"/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:variable>
  
  <xsl:variable name="legregalt"
    select="replace($legregaltprelim, '[^a-zA-Z0-9]+', '_')"/>
  
  <!-- TODO - remove this as we're not going to use these titles any more -->
  <xsl:variable name="legtitleFixed">
    <xsl:choose>
      <!-- don't use long title as title, make a regnal "The Act" title instead like SIF Acts -->
      <xsl:when test="matches($legtitle, '^An Act')">
        <xsl:text>The Act </xsl:text>
        <xsl:value-of select="$legregaltprelim"/>
        <xsl:text> c. </xsl:text>
        <xsl:value-of select="$legnum"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$legtitle"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  
  <!-- -/- FUNCTIONS -/- -->
  <!-- local:make-id turns BHO-style IDs for commentaries and footnotes into legislation.gov.uk-style IDs -->
  <xsl:function name="local:make-id" as="xs:string">
    <xsl:param name="idref" as="xs:string" required="true"/>
    <xsl:param name="type" as="xs:string" required="true"/>
    <xsl:variable name="numberFormat" as="xs:string">
      <xsl:value-of select="concat($type, '000000')"/>
    </xsl:variable>
    <xsl:analyze-string select="$idref" regex="^n([1-9][0-9]{{0,4}})$">
      <xsl:matching-substring>
        <xsl:value-of
          select="format-number(number(regex-group(1)), $numberFormat)"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="message">
              <xsl:text>id/idref </xsl:text>
              <xsl:value-of select="$idref"/>
              <xsl:text> is not a valid footnote id</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="/report">
    <Legislation SchemaVersion="1.0"
      xsi:schemaLocation="http://www.legislation.gov.uk/namespaces/legislation https://www.legislation.gov.uk/schema/legislation.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"
      xmlns:xhtml="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns="http://www.legislation.gov.uk/namespaces/legislation">

      <xsl:apply-templates select="@*"/>

      <ukm:Metadata>
        <dc:title><xsl:value-of select="$legtitleFixed"/></dc:title>
        <dc:language>en</dc:language>
        <dc:publisher>British History Online</dc:publisher>
        <ukm:PrimaryMetadata>
          <ukm:DocumentClassification>
            <ukm:DocumentCategory Value="primary"/>
            <ukm:DocumentMainType Value="EnglandAct"/>
            <ukm:DocumentStatus Value="final"/>
          </ukm:DocumentClassification>
          <ukm:Year Value="{$legyr}"/>
          <ukm:Number Value="{$legnum}"/>
          <ukm:AlternativeNumber Category="Regnal" Value="{$legregalt}"/>
        </ukm:PrimaryMetadata>
      </ukm:Metadata>

      <Primary>
        <PrimaryPrelims>
          <Title><xsl:value-of select="$legtitleFixed"/></Title>
          <Number>
            <xsl:value-of select="$legyr"/>
            <xsl:text> CHAPTER </xsl:text>
            <xsl:value-of select="$legnum"/>
            <xsl:text> </xsl:text>
            <xsl:value-of select="$legregaltprelim"/>
          </Number>
          <LongTitle>
            <xsl:apply-templates select="subtitle" mode="pass6-title"/>
          </LongTitle>
          <DateOfEnactment>
            <DateText/>
          </DateOfEnactment>
        </PrimaryPrelims>

        <Body>
          <xsl:apply-templates select="descendant::section"/>
        </Body>
      </Primary>

      <xsl:if test="descendant::note">
        <Commentaries>
          <xsl:apply-templates select="descendant::note"/>
        </Commentaries>
      </xsl:if>

      <xsl:if test="descendant::figure">
        <Resources>
          <xsl:apply-templates select="descendant::figure" mode="pass6-resource"/>
        </Resources>
      </xsl:if>

    </Legislation>
  </xsl:template>

  <xsl:template match="/report/(section|section/section)">
    <P1group>
      <xsl:apply-templates select="@*"/>
      <Title>
        <xsl:if test="head/node()">
          <xsl:apply-templates select="head" mode="pass6-head"/>
        </xsl:if>
      </Title>
      <xsl:choose>
        <xsl:when test="matches(head, '^[IVXLC]+(\W?\s|\W\s?)')">
          <P1>
            <xsl:apply-templates select="head" mode="pass6-pnumber"/>
            <xsl:apply-templates mode="pass6-p1para"/>
          </P1>
        </xsl:when>
        <xsl:otherwise>
          <P>
            <xsl:choose>
              <xsl:when test="para">
                <xsl:apply-templates mode="pass6-p"/>
              </xsl:when>
              <xsl:otherwise>
                <!-- if no child paras, just output whatever is here -->
                <xsl:apply-templates select="node() except head"/>
                <xsl:message>
                  <xsl:text>Warning: </xsl:text>
                  <xsl:call-template name="common:errmsg">
                    <xsl:with-param name="failNode" select="."/>
                    <xsl:with-param name="message">
                      <xsl:text>section with no paras</xsl:text>
                    </xsl:with-param>
                  </xsl:call-template>
                </xsl:message>
              </xsl:otherwise>
            </xsl:choose>
          </P>
        </xsl:otherwise>
      </xsl:choose>
    </P1group>
  </xsl:template>

  <xsl:template match="section" mode="pass6-p1para"/>
  <xsl:template match="section" mode="pass6-p"/>

  <xsl:template match="head" mode="pass6-p1para"/>
  <xsl:template match="head" mode="pass6-p"/>

  <xsl:template match="note" mode="pass6-p1para"/>
  <xsl:template match="note" mode="pass6-p"/>

  <xsl:template match="head" mode="pass6-head">
    <xsl:variable name="this" select="."/>
    <xsl:apply-templates select="@*"/>
    <xsl:analyze-string select="string()" flags="s"
      regex="^([IVXLC0-9]+(\.? |\.\s*))?(.*)$">
      <xsl:matching-substring>
        <xsl:apply-templates select="$this" mode="pass6-title"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="failNode" select="$this"/>
            <xsl:with-param name="message">
              <xsl:text>head text pattern failed to match head text </xsl:text>
              <xsl:value-of select="."/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <xsl:template match="head" mode="pass6-pnumber">
    <xsl:variable name="this" select="."/>
    <xsl:apply-templates select="@*"/>
    <xsl:analyze-string select="string()" flags="s" regex="^([IVXLC0-9]+)(\W)?\s*.*$">
      <xsl:matching-substring>
        <xsl:variable name="num" select="regex-group(1)"/>
        <xsl:variable name="puncAfter" select="regex-group(2)"/>
        <Pnumber PuncAfter="{$puncAfter}">
          <xsl:value-of select="$num"/>
        </Pnumber>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="failNode" select="$this"/>
            <xsl:with-param name="message">
              <xsl:text>couldn't extract the pnumber for head text </xsl:text>
              <xsl:value-of select="."/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <xsl:template match="head/text()"/>

  <xsl:template match="head/text()" mode="pass6-p"/>

  <xsl:template match="para" mode="pass6-p1para">
    <xsl:apply-templates select="@*"/>
    <P1para>
      <xsl:apply-templates select="." mode="pass6-text-wrap"/>
    </P1para>
  </xsl:template>

  <xsl:template match="para" mode="pass6-p">
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates select="." mode="pass6-text-wrap"/>
    <!-- include tables and figures (but only those immediately adjacent to
      this para) in the P element, so they show up when viewing the P on its
      own on the website -->
    <xsl:apply-templates
      select="following-sibling::*[self::table or self::figure] except
              following-sibling::element()[
                not(self::table or self::figure)
              ]/following-sibling::*[self::table or self::figure]"
     />
  </xsl:template>

  <xsl:template match="para/@id"/>

  <xsl:template match="note">
    <xsl:variable name="noteContent">
      <Para>
        <xsl:choose>
          <xsl:when test="matches(., ' O\.\s*$')">
            <!-- when the footnote ends in "O.", add in an extra note to explain what that means -->
            <xsl:apply-templates select="." mode="pass6-text-wrap">
              <xsl:with-param name="overrideStart">Variant reading of the text noted in <Emphasis>The Statutes of the Realm</Emphasis> as follows: </xsl:with-param>
              <xsl:with-param name="overrideEnd"> [<Emphasis>O.</Emphasis> refers to a collection in the library of Trinity College, Cambridge]</xsl:with-param>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:otherwise>
            <!-- for other notes, pass text through as normal -->
            <xsl:apply-templates select="." mode="pass6-text-wrap"/>
          </xsl:otherwise>
        </xsl:choose>
      </Para>
    </xsl:variable>
    <Commentary id="{local:make-id(@id, 'c')}" Type="X">
      <xsl:apply-templates select="@* except @id"/>
      <xsl:sequence select="$noteContent"/>
    </Commentary>
  </xsl:template>

  <xsl:template match="note/@number"/>

  <xsl:template match="local:bracketed">
    <Addition CommentaryRef="{local:make-id(@idref, 'c')}" ChangeId="{local:make-id(@idref, 'c')}-{generate-id()}">
      <xsl:apply-templates mode="pass6-text"/>
    </Addition>
  </xsl:template>

  <xsl:template match="ref">
    <xsl:apply-templates select="@* except @idref"/>
    <CommentaryRef Ref="{local:make-id(@idref, 'c')}"/>
  </xsl:template>

  <xsl:template match="emph[@type='i']" priority="+1">
    <xsl:choose>
      <xsl:when test="node()">
        <xsl:variable name="outputNodeName">
          <xsl:choose>
            <xsl:when test="@type = 'i'">Emphasis</xsl:when>
            <xsl:when test="@type = 'p'">Superior</xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">
                <xsl:text>FATAL ERROR: </xsl:text>
                <xsl:call-template name="common:errmsg">
                  <xsl:with-param name="failNode" select="."/>
                  <xsl:with-param name="message">
                    <xsl:text>unknown emph type '</xsl:text>
                    <xsl:value-of select="@type"/>
                    <xsl:text>'</xsl:text>
                  </xsl:with-param>
                </xsl:call-template>
              </xsl:message>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:element name="{$outputNodeName}" namespace="http://www.legislation.gov.uk/namespaces/legislation">
          <xsl:apply-templates select="@* except @type"/>
          <xsl:apply-templates mode="pass6-text"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <!-- occasionally emph appears empty - output nothing except a warning and continue -->
        <xsl:message>
          <xsl:text>Warning: </xsl:text>
          <xsl:call-template name="common:errmsg">
            <xsl:with-param name="failNode" select="."/>
            <xsl:with-param name="message">unexpectedly empty element</xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="emph[@type='p']" priority="+1">
    <xsl:apply-templates select="@* except @type"/>
    <Superior>
      <xsl:apply-templates mode="pass6-text"/>
    </Superior>
  </xsl:template>

  <xsl:template match="table" mode="pass6-p1para">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <xsl:template match="table" mode="pass6-p"/>

  <xsl:template match="table">
    <xsl:variable name="tableNumber" as="xs:integer">
      <xsl:number count="table" level="any"/>
    </xsl:variable>
    <Tabular id="{format-number($tableNumber, 't00000')}">
      <xsl:apply-templates select="@* except @id"/>
      <table xmlns="http://www.w3.org/1999/xhtml">
        <!-- no thead as some SotR tables have headers half way down -->
        <tbody>
          <xsl:apply-templates select="node()"/>
        </tbody>
      </table>
    </Tabular>
  </xsl:template>

  <xsl:template match="tr">
    <tr xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates/>
    </tr>
  </xsl:template>

  <xsl:template match="(table|tr)/text()[not(normalize-space())]"/>

  <xsl:template match="th">
    <th xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates mode="pass6-text"/>
    </th>
  </xsl:template>

  <xsl:template match="td">
    <td xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*"/>
      <xsl:if test="descendant::element() or text()[normalize-space()]">
        <xsl:choose>
          <xsl:when test="exists(br)">
            <!-- need to wrap in <Text> if contains <br> as it's our only way to create line breaks -->
            <xsl:apply-templates select="." mode="pass6-text-wrap"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates mode="pass6-text"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </td>
  </xsl:template>

  <xsl:template match="(th|td)/@rows">
    <xsl:attribute name="rowspan" select="data()"/>
  </xsl:template>

  <xsl:template match="(th|td)/@cols">
    <xsl:attribute name="colspan" select="data()"/>
  </xsl:template>

  <xsl:template match="figure">
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any"/>
    </xsl:variable>
    <xsl:apply-templates select="@*"/>
    <Figure id="{format-number($figureNumber, 'g00000')}">
      <xsl:apply-templates select="caption"/>
      <Image ResourceRef="{format-number($figureNumber, 'r00000')}"/>
    </Figure>
    <xsl:message>
      <xsl:text>Attention: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">
          <xsl:text>image </xsl:text>
          <xsl:value-of select="@graphic"/>
          <xsl:text> is referenced</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="figure/@id"/>
  <xsl:template match="figure/@number"/>
  <xsl:template match="figure/@graphic"/>

  <xsl:template match="figure" mode="pass6-p1para"/>
  <xsl:template match="figure" mode="pass6-p"/>

  <xsl:template match="figure" mode="pass6-resource">
    <xsl:variable name="imglang" select="'enm'"/>
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any"/>
    </xsl:variable>
    <xsl:variable name="uri"
      select="concat(replace($leg, '/id/', '/'), '/images/aep_', $legyr, format-number($legnum, '0000'),' _', $imglang, '_', format-number($figureNumber, '000'))"/>
    <xsl:message><!-- TODO fix img lang - check what it should be for each doc and add to lookup.xml -->
      <xsl:text>Warning: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">
          <xsl:text>need to ensure image is present at </xsl:text>
          <xsl:value-of select="$uri"/>
          <xsl:text> and check image lang is actually 'enm'</xsl:text>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:message>
    <Resource id="{format-number($figureNumber, 'r00000')}">
      <ExternalVersion URI="{$uri}"/>
    </Resource>
  </xsl:template>

  <xsl:template match="caption">
    <Para>
      <xsl:apply-templates select="." mode="pass6-text-wrap"/>
    </Para>
  </xsl:template>

  <xsl:template match="section/text()[not(normalize-space())]"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="pass6-p1para"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="pass6-p"/>

  <xsl:template match="node() | text()" mode="pass6-p">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <xsl:template match="head|subtitle" mode="pass6-title">
    <!-- turn the title contents into a "template" string that has non-text nodes
      replaced with placeholders, so we can do string ops on the template and then
      sub back in the non-text nodes later -->
    <xsl:variable name="templated">
      <xsl:iterate select="node()">
        <xsl:param name="currentTemplate" as="xs:string" select="''"/>
        <xsl:param name="currentNodes" as="node()*" select="()"/>
        <xsl:param name="nodeIndex" as="xs:integer" select="1"/>
        <xsl:on-completion>
          <local:template value="{$currentTemplate}"/>
          <local:nodes>
            <xsl:sequence select="$currentNodes"/>
          </local:nodes>
        </xsl:on-completion>
        
        <xsl:next-iteration>
          <xsl:with-param name="currentTemplate">
            <xsl:choose>
              <xsl:when test="self::text()">
                <!-- add text onto the template -->
                <xsl:value-of select="concat($currentTemplate, .)"/>
              </xsl:when>
              <xsl:otherwise>
                <!-- output a %%placeholder%% for non-text nodes -->
                <xsl:value-of select="concat($currentTemplate, '%%', $nodeIndex, '%%')"/> 
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
          
          <!-- add the current node to our list of nodes (unless it's text) -->
          <xsl:with-param name="currentNodes" select="($currentNodes, if (not(self::text())) then . else ())"/>
          
          <!-- only non-text nodes will go into the node list, so don't count text nodes -->
          <xsl:with-param name="nodeIndex" select="$nodeIndex + (if (not(self::text())) then 1 else 0)"/>
        </xsl:next-iteration>
      </xsl:iterate>
    </xsl:variable>
    
    <!-- do the string ops on the title -->
    <xsl:variable name="transformed" as="xs:string">
      <xsl:analyze-string select="$templated/local:template/@value" flags="s"
        regex="^([Cc][Hh]? ?[Aa] ?([Pp][Tt][Ee][Rr])?\s*)?([IVXLC0-9]+\.?\s*)(.*)$">
        <xsl:matching-substring>
          <xsl:value-of select="normalize-space(replace(replace(regex-group(4), ' ?\[ ?(O\.|Rot).+$', ''), ' [.,;]', ' '))"/>
        </xsl:matching-substring>
        <xsl:non-matching-substring>
          <xsl:value-of select="."/>
        </xsl:non-matching-substring>
      </xsl:analyze-string>
    </xsl:variable>
    
    <xsl:analyze-string select="$transformed" regex="%%([0-9]+)%%">
      <!-- replace %%placeholder%% with its corresponding node -->
      <xsl:matching-substring>
        <xsl:sequence select="($templated/local:nodes/node())[position() eq xs:int(regex-group(1))]"/>
      </xsl:matching-substring>
      
      <!-- output text in the template as-is -->
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <xsl:template match="@* | node()" mode="pass6-title">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="common:errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <xsl:template match="node()" mode="pass6-text-wrap">
    <xsl:param name="overrideStart" as="node()*" select="()"/>
    <xsl:param name="overrideEnd" as="node()*" select="()"/>
    
    <xsl:variable name="nodes" select="($overrideStart, (node()), $overrideEnd)"/>
    <xsl:for-each-group
      select="$nodes"
      group-starting-with="self::br">
      <Text>
        <!-- iterate through the nodes and apply templates separately to ensure we process them in the order we specified above -->
        <xsl:for-each select="current-group() except self::br">
          <xsl:sort data-type="number">
            <xsl:variable name="node" select="."/>
            <!-- sort the elements by whether they're in start, end or neither;
          those in start should come first (-2) then those in neither (0)
          i.e. those from the actual document, then those in end (+2)
        -->
            <xsl:sequence
              select="(if ($overrideStart[. = $node]) then -2 else 0) +
              (if ($overrideEnd[. = $node]) then 2 else 0)"/>
          </xsl:sort>
          <xsl:apply-templates select="." mode="pass6-text"/>
        </xsl:for-each>
      </Text>
    </xsl:for-each-group>
  </xsl:template>
  
  <xsl:template match="leg:*" mode="pass6-text" priority="+1">
    <!-- any leg:* elements should be ones we've inserted via override, so just copy them -->
    <xsl:copy-of select="."/>
  </xsl:template>
  
  <xsl:template match="text()" mode="pass6-text" priority="+1">
    <!-- keep only non-empty text nodes -->
    <xsl:if test="normalize-space()">
      <xsl:sequence select="."/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="emph|ref" mode="pass6-text" priority="+1">
    <!-- process emph and ref within text as normal -->
    <xsl:apply-templates select="." mode="pass6"/>
  </xsl:template>
  
  <!-- -/-/-/- Explicit structure templates -/-/-/- -->
  <!-- These handle the expected paths in the structure so there's an explicit
    rule for everything we expect, which means anything we don't expect falls
    through to a fallback rule to either be explicitly ignored or flagged -->
  <!--<xsl:template match="(head|para|emph|ref|caption|title|subtitle|th|td|note)/text()" priority="+1">
    <xsl:copy/>
  </xsl:template>
  
  <xsl:template match="/report/(title|subtitle|section)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/subtitle/(self::*|emph|ref)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/(self::*|head|para|figure|table|note)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/head/(emph|ref)">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="/report/(section|section/section)/para/(emph|ref|br)">
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
  </xsl:template>-->
  
  <!-- -/-/-/- Fallback templates -/-/-/- -->
  <!-- These templates explicitly ignore things we know should be there but don't
    want to handle, or catch anything we didn't expect and haven't handled - this
    makes the stylesheet's behaviour much more predictable by explicitly flagging
    any situation we haven't handled -->
  <xsl:template match="/report/(self::*|section|section/section)/text()[not(normalize-space())]"/>
  <xsl:template match="/report/(section|section/section)/table/(self::*|tr)/text()[not(normalize-space())]"/>
  <xsl:template match="/report/(section|section/section)/figure/text()[not(normalize-space())]"/>
  
  <xsl:template match="/report/@id"/>
  <xsl:template match="/report/@pubid"/>
  <xsl:template match="/report/@publish"/>
  
  <xsl:template match="/report/(section|section/section)/@id"/>
  
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