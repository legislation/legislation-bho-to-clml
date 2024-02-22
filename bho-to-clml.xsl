<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation"
  xmlns:local="local:"
  xmlns="http://www.legislation.gov.uk/namespaces/legislation"
  exclude-result-prefixes="xs xhtml leg local"
  version="3.0">

  <xsl:param name="lookupFile" select="'lookup.xml'"/>
  <xsl:param name="useXNotes" select="true()"/>

  <xsl:variable name="reportId" as="xs:string?" select="/report/@id"/>
  <xsl:variable name="docUri" select="document-uri()"/>
  <xsl:variable name="lookup" select="doc($lookupFile)"/>

  <!-- must select as element() or we get a doc fragment -->
  <xsl:variable name="report" as="element()">
    <xsl:choose>
      <xsl:when test="$lookup//report[@id=$reportId]">
        <xsl:sequence select="$lookup//report[@id=$reportId]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
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
          <xsl:call-template name="errmsg">
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

  <xsl:function name="local:make-f-id" as="xs:string">
    <xsl:param name="idref" as="xs:string" required="true"/>
    <xsl:variable name="numberFormat" as="xs:string">
      <xsl:choose>
        <xsl:when test="$useXNotes">c000000</xsl:when>
        <xsl:otherwise>f00000</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:analyze-string select="$idref" regex="^n([1-9][0-9]{{0,4}})$">
      <xsl:matching-substring>
        <xsl:value-of
          select="format-number(number(regex-group(1)), $numberFormat)"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
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

  <xsl:function name="local:node-kind" as="xs:string">
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
            <xsl:if test="subtitle/node()">
              <xsl:call-template name="processText">
                <xsl:with-param name="node" select="subtitle/node()"/>
                <xsl:with-param name="title" select="true()"/>
                <xsl:with-param name="wrapInTextEls" select="false()"/>
              </xsl:call-template>
            </xsl:if>
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
        <xsl:choose>
          <xsl:when test="$useXNotes">
            <Commentaries>
              <xsl:apply-templates select="descendant::note"/>
            </Commentaries>
          </xsl:when>
          <xsl:otherwise>
            <Footnotes>
              <xsl:apply-templates select="descendant::note"/>
            </Footnotes>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>

      <xsl:if test="descendant::figure">
        <Resources>
          <xsl:apply-templates select="descendant::figure" mode="resource"/>
        </Resources>
      </xsl:if>

    </Legislation>
  </xsl:template>

  <xsl:template match="report/@id"/>
  <xsl:template match="report/@pubid"/>
  <xsl:template match="report/@publish"/>

  <xsl:template match="section">
    <P1group>
      <xsl:apply-templates select="@*"/>
      <Title>
        <xsl:if test="head/node()">
          <xsl:apply-templates select="head" mode="title"/>
        </xsl:if>
      </Title>
      <xsl:choose>
        <xsl:when test="matches(head, '^[IVXLC]+\W?\s')">
          <P1>
            <xsl:apply-templates select="head" mode="pnumber"/>
            <xsl:apply-templates mode="p1para"/>
          </P1>
        </xsl:when>
        <xsl:otherwise>
          <P>
            <xsl:choose>
              <xsl:when test="para">
                <xsl:apply-templates mode="p"/>
              </xsl:when>
              <xsl:otherwise>
                <!-- if no child paras, just output whatever is here -->
                <xsl:apply-templates select="node() except head"/>
                <xsl:message>
                  <xsl:call-template name="errmsg">
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

  <xsl:template match="section/@id"/>

  <xsl:template match="section" mode="p1para"/>
  <xsl:template match="section" mode="p"/>

  <xsl:template match="head" mode="p1para"/>
  <xsl:template match="head" mode="p"/>

  <xsl:template match="note" mode="p1para"/>
  <xsl:template match="note" mode="p"/>

  <!-- C[Hh]? ?[Aa] ?[Pp]([Tt][Ee][Rr])?\s* || ([\[(][^\])]+[\])]\s*)? -->
  <xsl:template match="head" mode="title">
    <xsl:variable name="this" select="."/>
    <xsl:apply-templates select="@*"/>
    <xsl:analyze-string select="string()" flags="s"
      regex="^([IVXLC0-9]+\.?\s*)?(.*)$">
      <xsl:matching-substring>
        <xsl:call-template name="processText">
          <xsl:with-param name="node" select="$this/node()"/>
          <xsl:with-param name="title" select="true()"/>
        </xsl:call-template>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message terminate="yes">
          <xsl:call-template name="errmsg">
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

  <xsl:template match="head" mode="pnumber">
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
          <xsl:call-template name="errmsg">
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

  <xsl:template match="head/text()" mode="p"/>

  <xsl:template match="para" mode="p1para">
    <xsl:apply-templates select="@*"/>
    <P1para>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()"/>
        <xsl:with-param name="wrapInTextEls" select="true()"/>
      </xsl:call-template>
    </P1para>
  </xsl:template>

  <xsl:template match="para" mode="p">
    <xsl:apply-templates select="@*"/>
    <xsl:call-template name="processText">
      <xsl:with-param name="node" select="node()"/>
      <xsl:with-param name="wrapInTextEls" select="true()"/>
    </xsl:call-template>
    <!-- include tables and figures (but only those immediately adjacent to
      this para) in the P element, so they show up when viewing the P on its
      own on the website -->
    <xsl:apply-templates
      select="following-sibling::*[self::table or self::figure] except
              following-sibling::element()[
                not(self::table or self::figure)
              ]/following-sibling::*[self::table or self::figure]"/>
  </xsl:template>

  <xsl:template match="para/@id"/>

  <xsl:template match="note">
    <xsl:variable name="noteContent">
      <Para>
        <xsl:call-template name="processText">
          <xsl:with-param name="node" select="node()"/>
          <xsl:with-param name="wrapInTextEls" select="true()"/>
        </xsl:call-template>
      </Para>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$useXNotes">
        <Commentary id="{local:make-f-id(@id)}" Type="X">
          <xsl:apply-templates select="@* except @id"/>
          <xsl:sequence select="$noteContent"/>
        </Commentary>
      </xsl:when>
      <xsl:otherwise>
        <Footnote id="{local:make-f-id(@id)}">
          <xsl:apply-templates select="@* except @id"/>
          <FootnoteText>
            <xsl:sequence select="$noteContent"/>
          </FootnoteText>
        </Footnote>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="note/@number"/>

  <xsl:template match="ref">
    <xsl:apply-templates select="@* except @idref"/>
    <xsl:choose>
      <xsl:when test="$useXNotes">
        <CommentaryRef Ref="{local:make-f-id(@idref)}"/>
      </xsl:when>
      <xsl:otherwise>
        <FootnoteRef Ref="{local:make-f-id(@idref)}"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="emph[@type='i']">
    <xsl:choose>
      <xsl:when test="node()">
        <xsl:variable name="outputNodeName">
          <xsl:choose>
            <xsl:when test="@type = 'i'">Emphasis</xsl:when>
            <xsl:when test="@type = 'p'">Superior</xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">
                <xsl:call-template name="errmsg">
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
          <xsl:call-template name="processText">
            <xsl:with-param name="node" select="node()"/>
          </xsl:call-template>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <!-- occasionally emph appears empty - output nothing except a warning and continue -->
        <xsl:message>
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="."/>
            <xsl:with-param name="message">unexpectedly empty element</xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="emph[@type='p']">
    <xsl:apply-templates select="@* except @type"/>
    <Superior>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()"/>
      </xsl:call-template>
    </Superior>
  </xsl:template>

  <xsl:template match="table" mode="p1para">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <xsl:template match="table" mode="p"/>

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
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()"/>
      </xsl:call-template>
    </th>
  </xsl:template>

  <xsl:template match="td">
    <td xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*"/>
      <xsl:if test="descendant::element() or text()[normalize-space()]">
        <xsl:call-template name="processText">
          <xsl:with-param name="node" select="node()"/>
          <!-- need to wrap in <Text> if contains <br> as it's our only way to create line breaks -->
          <xsl:with-param name="wrapInTextEls" select="exists(br)"/>
        </xsl:call-template>
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
  </xsl:template>

  <xsl:template match="figure/@id"/>
  <xsl:template match="figure/@number"/>
  <xsl:template match="figure/@graphic"/>

  <xsl:template match="figure" mode="p1para"/>
  <xsl:template match="figure" mode="p"/>

  <!--<xsl:template match="figure" mode="p1para">
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="figure" mode="p">
    <xsl:apply-templates/>
  </xsl:template>-->

  <xsl:template match="figure" mode="resource">
    <xsl:variable name="imglang" select="'enm'"/>
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any"/>
    </xsl:variable>
    <xsl:message><!-- TODO fix img lang - check what it should be for each doc and add to lookup.xml -->
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">WARNING: need to check image lang is actually 'enm'</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
    <Resource id="{format-number($figureNumber, 'r00000')}">
      <ExternalVersion URI="{replace($leg, '/id/', '/')}/images/aep_{$legyr}{format-number($legnum, '0000')}_{$imglang}_{format-number($figureNumber, '000')}"/>
    </Resource>
    <!--<xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">figure transform not implemented yet for figure</xsl:with-param>
      </xsl:call-template>
    </xsl:message>-->
  </xsl:template>

  <xsl:template match="caption">
    <Para>
      <xsl:call-template name="processText">
        <xsl:with-param name="node" select="node()"/>
        <xsl:with-param name="wrapInTextEls" select="true()"/>
      </xsl:call-template>
    </Para>
  </xsl:template>

  <xsl:template match="@*">
    <!-- fallback - helps us discover and deal with unexpected attributes -->
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched attr</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="node() | text()">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="section/text()[not(normalize-space())]"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="p1para"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="p"/>

  <xsl:template match="node() | text()" mode="p">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template name="processText">
    <!-- This function wraps text in Text elements, strips brackets around
      footnotes, creates paragraph breaks, and so on.

      The function accumulates text until either the end of the nodes in $node,
      or until the first text node after an element child. It does this so that
      if an element child is a footnote ref and both the preceding accumulated
      text and the text following that ref have brackets (ie surrounding the
      ref) then the function can remove the brackets from both before
      outputting the preceding text, the ref and the following text. -->
    <xsl:param name="node" as="node()+"/>
    <xsl:param name="wrapInTextEls" as="xs:boolean" select="false()"/>
    <xsl:param name="title" as="xs:boolean" select="false()"/>

    <xsl:choose>
      <xsl:when test="$wrapInTextEls = true()">
        <xsl:if test="$title = true()">
          <xsl:message terminate="yes">
            <xsl:call-template name="errmsg">
              <xsl:with-param name="failNode" select="."/>
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
              <xsl:with-param name="node"
                select="current-group() except self::br"/>
            </xsl:call-template>
          </Text>
        </xsl:for-each-group>
      </xsl:when>

      <xsl:otherwise>
        <xsl:iterate select="$node">
          <xsl:param name="cumulText" as="xs:string?"/>
          <xsl:param name="cumulNodes" as="node()*"/>
          <xsl:param name="cumulChildNodes" as="node()*"/>

          <xsl:on-completion>
            <xsl:sequence select="$cumulNodes"/>

            <!-- there will be no accumulated child nodes if the last node
              is text; if there is text and also accumulated child nodes,
              then the text will have accumulated *before* the child nodes -->
            <xsl:value-of select="$cumulText"/>
            <xsl:apply-templates select="$cumulChildNodes"/>
          </xsl:on-completion>

          <xsl:choose>
            <xsl:when test="self::emph or self::ref">
              <xsl:next-iteration>
                <xsl:with-param name="cumulText" select="$cumulText"/>
                <xsl:with-param name="cumulNodes" select="$cumulNodes"/>
                <xsl:with-param name="cumulChildNodes"
                  select="($cumulChildNodes, .)"/>
              </xsl:next-iteration>
            </xsl:when>

            <xsl:when test="self::text()">
              <!-- process accumulated text to fix brackets -->
              <xsl:variable name="newCumulText">
                <xsl:choose>
                  <!-- strip leading bracket around footnote(s) -->
                  <xsl:when
                    test="matches($cumulText, '[(\[]\s*') and
                    matches(., '\s*[\])]') and
                    $cumulChildNodes and
                    (every $n in $cumulChildNodes satisfies $n/self::ref)">
                    <xsl:value-of select="replace($cumulText, '[(\[]\s*', '')"/>
                  </xsl:when>

                  <!-- remove whitespace inside brackets -->
                  <xsl:when test="matches($cumulText, '([(\[])\s+')">
                    <xsl:value-of select="replace(., '([(\[])\s+', '$1')"/>
                  </xsl:when>

                  <xsl:otherwise>
                    <xsl:value-of select="$cumulText"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>

              <!-- process current text to fix whitespace and titles -->
              <xsl:variable name="newThisText">
                <xsl:choose>
                  <!-- remove empty text nodes -->
                  <xsl:when test="not(normalize-space())"/>

                  <!-- if in title mode, remove section and chapter numbers and citations -->
                  <xsl:when
                    test="$title = true() and
                          not($cumulNodes[self::text()]) and
                          not(normalize-space($newCumulText))">
                    <xsl:analyze-string select="." flags="s"
                      regex="^([Cc][Hh]? ?[Aa] ?([Pp][Tt][Ee][Rr])?\s*)?([IVXLC0-9]+\.?\s*)(.*)$">
                      <xsl:matching-substring>
                        <xsl:value-of select="normalize-space(replace(replace(regex-group(4), ' ?\[ ?(O\.|Rot).+$', ''), ' [.,;]', ' '))"/>
                      </xsl:matching-substring>
                      <xsl:non-matching-substring>
                        <xsl:value-of select="."/>
                      </xsl:non-matching-substring>
                    </xsl:analyze-string>
                  </xsl:when>

                  <xsl:otherwise>
                    <xsl:value-of select="."/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>

              <!-- process current text to fix brackets -->
              <xsl:variable name="newThisText">
                <xsl:choose>
                  <!-- strip trailing bracket around footnote(s) -->
                  <xsl:when
                    test="matches($cumulText, '[(\[]\s*') and
                    matches($newThisText, '\s*[\])]') and
                    $cumulChildNodes and
                    (every $n in $cumulChildNodes satisfies $n/self::ref)">
                    <xsl:value-of select="replace($newThisText, '\s*[\])]', '')"/>
                  </xsl:when>

                  <!-- remove whitespace inside brackets -->
                  <xsl:when test="matches($newThisText, '\s+([\])])')">
                    <xsl:value-of select="replace($newThisText, '\s+([\])])', '$1')"/>
                  </xsl:when>

                  <xsl:otherwise>
                    <xsl:value-of select="$newThisText"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>

              <xsl:next-iteration>
                <xsl:with-param name="cumulText">
                  <xsl:choose>
                    <xsl:when test="$newCumulText and not($cumulChildNodes)">
                      <!-- if no child nodes accumulated, continue
                        accumulating text -->
                      <xsl:value-of
                        select="concat($newCumulText, $newThisText)"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <!-- if child nodes accumulated, restart text
                        accumulation here -->
                      <xsl:value-of select="$newThisText"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:with-param>
                <xsl:with-param name="cumulNodes">
                  <xsl:sequence select="$cumulNodes"/>
                  <xsl:if test="$newCumulText and $cumulChildNodes">
                    <!-- if child nodes accumulated, output the
                        currently accumulated text before them -->
                    <xsl:value-of select="$newCumulText"/>
                  </xsl:if>
                  <xsl:apply-templates select="$cumulChildNodes"/>
                </xsl:with-param>
                <!-- clear any child nodes accumulated before this text -->
                <xsl:with-param name="cumulChildNodes" select="()"/>
              </xsl:next-iteration>
            </xsl:when>

            <!-- fallback - to check we've handled all possible children -->
            <xsl:otherwise>
              <xsl:message terminate="yes">
                <xsl:call-template name="errmsg">
                  <xsl:with-param name="failNode" select="."/>
                  <xsl:with-param name="message">
                    <xsl:text>unexpected node of kind </xsl:text>
                    <xsl:value-of select="local:node-kind(.)"/>
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
    <xsl:param name="failNode" as="node()" required="false"/>
    <xsl:param name="message" as="xs:string" required="yes"/>

    <xsl:text>report id </xsl:text>
    <xsl:value-of select="$reportId"/>
    <xsl:text> (</xsl:text>
    <xsl:value-of select="$docUri"/>
    <xsl:text>): </xsl:text>
    <xsl:value-of select="$message"/>
    <xsl:if test="$failNode">
      <xsl:text> at path </xsl:text>
      <xsl:value-of select="$failNode/path()"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>