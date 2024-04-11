<?xml version="1.0" encoding="UTF-8"?>
<!-- SPDX-License-Identifier: OGL-UK-3.0 -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation"
  xmlns:local="local:"
  xmlns="http://www.legislation.gov.uk/namespaces/legislation"
  exclude-result-prefixes="xs map xhtml leg local"
  version="3.0">

  <!-- -/- PARAMETERS -/- -->
  <xsl:param name="lookupFile" select="'lookup.xml'" static="yes"/>
  
  <!-- -/- MODES -/- -->
  <xsl:mode use-accumulators="brackets-paired"/>
  <xsl:mode name="title"/>
  <xsl:mode name="text"/>
  <xsl:mode name="head"/>
  <xsl:mode name="resource"/>
  <xsl:mode name="pnumber"/>
  <xsl:mode name="p1para"/>
  <xsl:mode name="p"/>
  <xsl:mode name="text-wrap"/>

  <!-- -/- VARIABLES -/- -->
  <xsl:variable name="reportId" as="xs:string?" select="/report/@id"/>
  <xsl:variable name="docUri" as="xs:string" select="document-uri()"/>

  <xsl:variable name="lookup" select="doc($lookupFile)"/>

  <!-- must select as element() or we get a doc fragment -->
  <xsl:variable name="report" as="element()">
    <xsl:choose>
      <xsl:when test="$lookup//report[@id=$reportId]">
        <xsl:sequence select="$lookup//report[@id=$reportId]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="errmsg">
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
  
  <xsl:variable name="within-bracket-map" as="map(*)">
    <xsl:sequence select="accumulator-after('brackets-paired')('within-bracket')"/>
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
  
  <xsl:function name="local:process-brackets" as="node()*">
    <xsl:param name="input" as="xs:string"/>
    <xsl:analyze-string select="$input" regex="[\[\]\(\)]">
      <xsl:matching-substring>
        <local:bracket>
          <xsl:attribute name="type" select="if (. = ('[', '(')) then 'open' else 'close'"/>
          <xsl:attribute name="shape" select="if (. = ('[', ']')) then 'square' else 'round'"/>
          <xsl:value-of select="."/>
        </local:bracket>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <local:text><xsl:value-of select="."/></local:text>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
  <xsl:function name="local:get-bracket-info" as="map(*)" cache="yes" new-each-time="no">
    <xsl:param name="bracket-pair" as="xs:integer"/>
    <xsl:variable name="refs" select="$within-bracket-map($bracket-pair)[self::ref]"/>
    <xsl:variable name="not-refs" select="$within-bracket-map($bracket-pair)[not(self::ref)]"/>
    
    <!-- bracketed = wrap in bracketed els ; shuck = remove brackets from text ; raw = output brackets in text -->
    <xsl:sequence select="map{
      'kind': if ($refs) then if ($not-refs) then 'bracketed' else 'shuck' else 'raw',
      'refs': $refs
      }"/>
  </xsl:function>
  
  <!-- -/- ACCUMULATORS -/- -->
  <xsl:accumulator name="brackets-paired" as="map(*)"
    initial-value="map{'open': (), 'last-opened': 0, 'current-node': (), 'within-bracket': map{}}">
    
    <!-- Record any <emph>/<ref>/<br> nodes against the bracket they're within (if they are) -->
    <xsl:accumulator-rule match="emph|ref|br" phase="start">
      <xsl:variable name="last-open" select="$value('open')[last()]"/>
      <xsl:choose>
        <xsl:when test="$last-open">
          <xsl:variable name="new-within-bracket"
            select="map:merge(
            (map:get($value, 'within-bracket'), map:entry($last-open, .)),
            map{'duplicates': 'combine'}
            )"/>
          <xsl:sequence select="map:put($value, 'within-bracket', $new-within-bracket)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$value"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
    
    <!-- Turn text() nodes into sequences of <text> and <bracket> nodes, plus make metadata -->
    <xsl:accumulator-rule match="text()[not(parent::ref)]">
      <xsl:call-template name="process-brackets">
        <xsl:with-param name="input" select="local:process-brackets(.)"/>
        <xsl:with-param name="open" as="xs:integer*" select="$value('open')" tunnel="yes"/>
        <xsl:with-param name="last-opened" select="$value('last-opened')" tunnel="yes"/>
        <xsl:with-param name="within-bracket" select="$value('within-bracket')" tunnel="yes"/>
        <xsl:with-param name="preceding-bignore" tunnel="yes"
          select="exists(preceding-sibling::node()[1]/self::processing-instruction('bignore'))"/>
        <xsl:with-param name="following-bignore" tunnel="yes"
          select="exists(following-sibling::node()[1]/self::processing-instruction('bignore'))"/>
      </xsl:call-template>
    </xsl:accumulator-rule>
  </xsl:accumulator>

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
            <xsl:apply-templates select="subtitle" mode="title"/>
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
          <xsl:apply-templates select="descendant::figure" mode="resource"/>
        </Resources>
      </xsl:if>

    </Legislation>
  </xsl:template>

  <xsl:template match="/report/(section|section/section)">
    <P1group>
      <xsl:apply-templates select="@*"/>
      <Title>
        <xsl:if test="head/node()">
          <xsl:apply-templates select="head" mode="head"/>
        </xsl:if>
      </Title>
      <xsl:choose>
        <xsl:when test="matches(head, '^[IVXLC]+(\W?\s|\W\s?)')">
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
                  <xsl:text>Warning: </xsl:text>
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

  <xsl:template match="section" mode="p1para"/>
  <xsl:template match="section" mode="p"/>

  <xsl:template match="head" mode="p1para"/>
  <xsl:template match="head" mode="p"/>

  <xsl:template match="note" mode="p1para"/>
  <xsl:template match="note" mode="p"/>

  <xsl:template match="head" mode="head">
    <xsl:variable name="this" select="."/>
    <xsl:apply-templates select="@*"/>
    <xsl:analyze-string select="string()" flags="s"
      regex="^([IVXLC0-9]+(\.? |\.\s*))(.*)$">
      <xsl:matching-substring>
        <xsl:apply-templates select="$this" mode="title"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:message>
          <xsl:text>Attention: </xsl:text>
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="$this"/>
            <xsl:with-param name="message">
              <xsl:text>head text pattern failed to match head text "</xsl:text>
              <xsl:value-of select="."/>
              <xsl:text>"</xsl:text>
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
          <xsl:text>FATAL ERROR: </xsl:text>
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
      <xsl:apply-templates select="node()[1]" mode="text-wrap"/>
    </P1para>
  </xsl:template>

  <xsl:template match="para" mode="p">
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates select="node()[1]" mode="text-wrap"/>
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
            <xsl:apply-templates select="node()[1]" mode="text-wrap">
              <xsl:with-param name="overrideStart">Variant reading of the text noted in <Emphasis>The Statutes of the Realm</Emphasis> as follows: </xsl:with-param>
              <xsl:with-param name="overrideEnd"> [<Emphasis>O.</Emphasis> refers to a collection in the library of Trinity College, Cambridge]</xsl:with-param>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:otherwise>
            <!-- for other notes, pass text through as normal -->
            <xsl:apply-templates select="node()[1]" mode="text-wrap"/>
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

  <!--<xsl:template match="local:bracketed">
    <Addition CommentaryRef="{local:make-id(@idref, 'c')}" ChangeId="{local:make-id(@idref, 'c')}-{generate-id()}">
      <xsl:apply-templates mode="text"/>
    </Addition>
  </xsl:template>-->

  <xsl:template match="ref">
    <xsl:apply-templates select="@* except @idref"/>
    <CommentaryRef Ref="{local:make-id(@idref, 'c')}"/>
  </xsl:template>

  <xsl:template match="emph" priority="+1">
    <xsl:choose>
      <xsl:when test="node()">
        <xsl:variable name="outputNodeName" as="xs:string">
          <xsl:choose>
            <xsl:when test="@type = 'i'">Emphasis</xsl:when>
            <xsl:when test="@type = 'p'">Superior</xsl:when>
            <xsl:otherwise>
              <xsl:message terminate="yes">
                <xsl:text>FATAL ERROR: </xsl:text>
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
          <xsl:apply-templates select="node()[1]" mode="text"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <!-- occasionally emph appears empty - output nothing except a warning and continue -->
        <xsl:message>
          <xsl:text>Warning: </xsl:text>
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="."/>
            <xsl:with-param name="message">unexpectedly empty element</xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--<xsl:template match="emph[@type='p']" priority="+1">
    <xsl:apply-templates select="@* except @type"/>
    <Superior>
      <xsl:apply-templates mode="text"/>
    </Superior>
  </xsl:template>-->

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
      <xsl:apply-templates select="node()[1]" mode="text"/>
    </th>
  </xsl:template>

  <xsl:template match="td">
    <td xmlns="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*"/>
      <xsl:if test="descendant::element() or text()[normalize-space()]">
        <xsl:choose>
          <xsl:when test="exists(br)">
            <!-- need to wrap in <Text> if contains <br> as it's our only way to create line breaks -->
            <xsl:apply-templates select="node()[1]" mode="text-wrap"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="node()[1]" mode="text"/>
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
      <xsl:call-template name="errmsg">
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

  <xsl:template match="figure" mode="p1para"/>
  <xsl:template match="figure" mode="p"/>

  <xsl:template match="figure" mode="resource">
    <xsl:variable name="imglang" select="'enm'"/>
    <xsl:variable name="figureNumber" as="xs:integer">
      <xsl:number count="figure" level="any"/>
    </xsl:variable>
    <xsl:variable name="uri"
      select="concat(replace($leg, '/id/', '/'), '/images/aep_', $legyr, format-number($legnum, '0000'),' _', $imglang, '_', format-number($figureNumber, '000'))"/>
    <xsl:message><!-- TODO fix img lang - check what it should be for each doc and add to lookup.xml -->
      <xsl:text>Warning: </xsl:text>
      <xsl:call-template name="errmsg">
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
      <xsl:apply-templates select="node()[1]" mode="text-wrap"/>
    </Para>
  </xsl:template>

  <xsl:template match="section/text()[not(normalize-space())]"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="p1para"/>
  <xsl:template match="section/text()[not(normalize-space())]" mode="p"/>

  <xsl:template match="node() | text()" mode="p">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="head|subtitle" mode="title">
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
        regex="^([Cc][Hh]? ?[Aa] ?([Pp][Tt][Ee][Rr])?\s*)?([IVXLC0-9]+(\.? |\.\s*))(.*)$">
        <xsl:matching-substring>
          <xsl:value-of select="normalize-space(replace(replace(regex-group(5), ' ?\[ ?(O\.|Rot).+$', ''), ' [.,;]', ' '))"/>
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
  
  <xsl:template match="text()|ref|leg:*" mode="text" priority="+1">
    <xsl:param name="accumulated-node" as="node()?" select="()"/>
    <!-- Keep track of which brackets are open (by default those open just after descent into
         the preceding sibling, or just before descent into the parent if no preceding sibling -->
    <xsl:param name="open" as="xs:integer*">
      <xsl:choose>
        <xsl:when test="preceding-sibling::node()">
          <xsl:for-each select="preceding-sibling::node()[1]">
            <xsl:sequence select="accumulator-after('brackets-paired')('open')"/>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="parent::node()[1]">
            <xsl:sequence select="accumulator-before('brackets-paired')('open')"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    
    <xsl:variable name="new-accumulated-node" as="node()">
      <local:node>
        <xsl:sequence select="$accumulated-node/node()"/>
        <xsl:choose>
          <xsl:when test="self::text()">
            <!-- Include the <text>/<bracket> version of this text node, instead of the original -->
            <xsl:sequence select="accumulator-after('brackets-paired')('current-node')/node()"/>
          </xsl:when>
          <xsl:when test="self::ref|self::leg:*">
            <!-- Just include the <ref> directly -->
            <xsl:sequence select="."/>
          </xsl:when>
        </xsl:choose>
      </local:node>
    </xsl:variable>
    
    <xsl:choose>
      <!-- we roll up all adjacent text node/<ref> siblings and process them at once, so that we can
        wrap brackets around entire runs of contiguous text nodes and refs, instead of having them
        break when a <ref> interrupts a text node - this means we can wrap <refs in brackets where needed -->
      <xsl:when test="following-sibling::node()[1][self::text() or self::ref or self::leg:*]">
        <xsl:apply-templates select="following-sibling::node()[1][self::text() or self::ref or self::leg:*]" mode="text">
          <xsl:with-param name="accumulated-node" select="$new-accumulated-node"/>
          <xsl:with-param name="open" as="xs:integer*" select="$open"/>
        </xsl:apply-templates>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:apply-templates select="$new-accumulated-node/node()[1]" mode="bracketize">
          <xsl:with-param name="open" select="$open" tunnel="yes"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="following-sibling::node()[1]" mode="text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text()" mode="bracketize-inner">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:variable name="current-bracket" as="xs:integer?" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="if ($current-bracket) then local:get-bracket-info($current-bracket) else map{}"/>
    <xsl:choose>
      <xsl:when test="$current-bracket and $bracket-info('kind') eq 'bracketed' and following::node()[1]/self::ref = $bracket-info('refs')[last()]">
        <xsl:value-of select="replace(., '\s+$', '')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="ref" mode="bracketize-inner">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:variable name="current-bracket" as="xs:integer?" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="if ($current-bracket) then local:get-bracket-info($current-bracket) else map{}"/>
    <xsl:choose>
      <!-- filter out the last ref in this bracket -->
      <xsl:when test="$current-bracket and $bracket-info('kind') eq 'bracketed' and . = $bracket-info('refs')[last()]"/>
      <xsl:otherwise>
        <xsl:apply-templates select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="leg:*" mode="bracketize-inner">
    <xsl:copy-of select="." copy-namespaces="no"/>
  </xsl:template>
  
  <xsl:template match="local:text|ref|leg:*" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" as="xs:integer*" select="$open"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    
    <xsl:variable name="current-node" select="."/>
    
    <xsl:if test="not($current-pair) or $current-pair eq $open[last()]">
      <xsl:variable name="to-be-output" as="node()*">
        <xsl:variable name="contiguous-text-and-refs" as="node()+">
          <xsl:sequence select="$current-node"/>
          <xsl:sequence select="$current-node/following-sibling::node()[self::local:text or self::ref or self::leg:*] except $current-node/following-sibling::node()[not(self::local:text or self::ref or self::leg:*)][1]/following-sibling::node()"/>
        </xsl:variable>
        <xsl:apply-templates select="$contiguous-text-and-refs" mode="bracketize-inner"/>
      </xsl:variable>
      
      <xsl:choose>
        <!-- wrap (by default) in all open brackets, or whatever brackets we specify to wrap -->
        <xsl:when test="count($wrapping) gt 0">
          <!-- go from innermost to outermost bracket (if $wrapping specified, only those brackets, otherwise all) -->
          <xsl:iterate select="reverse($wrapping)">
            <!-- the thing initially being wrapped is the text of the <text> node -->
            <xsl:param name="wrapped" as="node()*" select="$to-be-output"/>
            
            <xsl:on-completion select="$wrapped"/>
            
            <xsl:variable name="current-pair" select="."/>
            <xsl:variable name="bracket-info" select="local:get-bracket-info($current-pair)"/>
            
            <xsl:next-iteration>
              <xsl:with-param name="wrapped" as="node()*">
                <xsl:choose>
                  <!-- if this bracket pair should become <bracketed> ... -->
                  <xsl:when test="$bracket-info('kind') eq 'bracketed' and exists($wrapped)">
                    <!-- ...wrap whatever is to be wrapped in <bracketed> with this pair's first <ref>'s idref... -->
                    <xsl:variable name="idref" select="$bracket-info('refs')[last()]/@idref"/>
                    <Addition CommentaryRef="{local:make-id($idref, 'c')}" ChangeId="{local:make-id($idref, 'c')}-{generate-id($current-node)}">
                      <xsl:sequence select="$wrapped"/>
                      <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::local:text or self::ref or self::leg:*)][1]/self::local:bracket[@type='open']" mode="bracketize">
                        <xsl:with-param name="wrapping" select="()"/>
                        <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                      </xsl:apply-templates>
                    </Addition>
                  </xsl:when>
                  <xsl:otherwise>
                    <!-- ...output whatever would otherwise have been wrapped... -->
                    <xsl:sequence select="$wrapped"/>
                    <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::local:text or self::ref or self::leg:*)][1]/self::local:bracket[@type='open']" mode="bracketize">
                      <xsl:with-param name="wrapping" select="()"/>
                      <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                    </xsl:apply-templates>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:apply-templates
                  select="$current-node/following-sibling::node()/self::local:bracket[@type='close' and @closes-pair = $current-pair]" mode="bracketize">
                  <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                </xsl:apply-templates>
                <xsl:apply-templates
                  select="$current-node/following-sibling::node()/self::local:bracket[@type='close' and @closes-pair = $current-pair]/following-sibling::node()[1]" mode="bracketize">
                  <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
                  <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                  <xsl:with-param name="wrapping" select="()"/>
                  <xsl:with-param name="current-pair" select="$open[last() - 1]" tunnel="yes"/>
                </xsl:apply-templates>
              </xsl:with-param>
            </xsl:next-iteration>
          </xsl:iterate>
        </xsl:when>
        
        <!-- if no open brackets, or we've specified to wrap in no brackets, then don't wrap... -->
        <xsl:otherwise>
          <xsl:sequence select="$to-be-output"/>
          <!-- ...and just process any immediately following node -->
          <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::local:text or self::ref or self::leg:*)][1]" mode="bracketize"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="local:bracket[@type='open']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    <xsl:param name="wrapping" select="$open"/>
    <xsl:if test="not($current-pair) or $current-pair = $open[last()]">
      <!-- if "raw", just output the text of the bracket -->
      <xsl:if test="local:get-bracket-info(@opens-pair)('kind') eq 'raw'">
        <xsl:value-of select="."/>
      </xsl:if>
      <xsl:apply-templates select="following-sibling::node()[1]" mode="bracketize">
        <xsl:with-param name="open" as="xs:integer*" select="($open, @opens-pair)" tunnel="yes"/>
        <xsl:with-param name="wrapping" select="($wrapping, @opens-pair)"/>
        <xsl:with-param name="current-pair" as="xs:integer?" select="@opens-pair" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="local:bracket[@type='close']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    <xsl:if test="not($current-pair) or $current-pair = $open[last()]">
      <xsl:if test="local:get-bracket-info(@closes-pair)('kind') eq 'raw'">
        <xsl:value-of select="."/>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <xsl:template match="@* | node()" mode="title">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="node()" mode="text-wrap">
    <xsl:param name="overrideStart" as="node()*" select="()"/>
    <xsl:param name="overrideEnd" as="node()*" select="()"/>
    
    <xsl:variable name="process-this-node" as="node()">
      <local:node>
        <xsl:copy-of select="$overrideStart"/>
        <xsl:apply-templates select="." mode="text"/>
        <xsl:copy-of select="$overrideEnd[1]"/>
      </local:node>
    </xsl:variable>
    <xsl:if test="$process-this-node/node()">
      <xsl:for-each-group
        select="$process-this-node"
        group-starting-with="self::br">
        <Text>
          <xsl:apply-templates select="current-group()[1]" mode="text"/>
        </Text>
      </xsl:for-each-group>
    </xsl:if>

    <!--<xsl:apply-templates select="$overrideStart[1]" mode="text"/>
    <xsl:apply-templates select="." mode="text"/>
    <xsl:apply-templates select="$overrideEnd[1]" mode="text"/>-->

    <!--<xsl:variable name="nodes" select="($overrideStart, (node()), $overrideEnd)"/>
    <xsl:for-each-group
      select="$nodes"
      group-starting-with="self::br">
      <Text>
        <!-\- iterate through the nodes and apply templates separately to ensure we process them in the order we specified above -\->
        <xsl:for-each select="current-group() except self::br">
          <xsl:sort data-type="number">
            <xsl:variable name="node" select="."/>
            <!-\- sort the elements by whether they're in start, end or neither;
          those in start should come first (-2) then those in neither (0)
          i.e. those from the actual document, then those in end (+2)
        -\->
            <xsl:sequence
              select="(if ($overrideStart[. = $node]) then -2 else 0) +
              (if ($overrideEnd[. = $node]) then 2 else 0)"/>
          </xsl:sort>
          <xsl:apply-templates select="." mode="text"/>
        </xsl:for-each>
      </Text>
    </xsl:for-each-group>-->
  </xsl:template>

  <!--<xsl:template match="text()" mode="text" priority="+1">
    <!-\- keep only non-empty text nodes -\->
    <xsl:if test="normalize-space()">
      <xsl:sequence select="."/>
    </xsl:if>
  </xsl:template>-->

  <xsl:template match="emph" mode="text" priority="+1">
    <!-- process emph within text as normal -->
    <xsl:apply-templates select="."/>
    <xsl:apply-templates select="following-sibling::node()[1]" mode="text"/>
  </xsl:template>

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
  
  <xsl:template match="local:bracket/(@type|@opens-pair|@closes-pair|@shape)">
    <xsl:sequence select="."/>
  </xsl:template>

  <!-- Final fallbacks - helps us discover and deal with unexpected doc structure -->
  <xsl:template match="@*">
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched/unexpected attr</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>

  <xsl:template match="node() | text()">
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched/unexpected node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
  <!-- -/-/- Utility templates -/-/- -->
  <xsl:template name="process-brackets" as="map(*)">
    <xsl:param name="input" as="node()*"/>
    <xsl:param name="last-opened" as="xs:integer" tunnel="yes"/>
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="position" as="xs:integer" select="1"/>
    <xsl:param name="last" as="xs:integer" select="count($input)"/>
    <xsl:param name="accumulated-nodes" as="node()*" select="()" tunnel="yes"/>
    <xsl:param name="within-bracket" as="map(*)" select="map{}" tunnel="yes"/>
    <xsl:param name="preceding-bignore" as="xs:boolean" tunnel="yes"/>
    <xsl:param name="following-bignore" as="xs:boolean" tunnel="yes"/>
    
    <xsl:choose>
      <!-- if input sequence exhausted, we've reached the end of the text() node -->
      <xsl:when test="not($input)">
        <xsl:variable name="current-node" as="node()">
          <local:node>
            <xsl:sequence select="$accumulated-nodes"/>
          </local:node>
        </xsl:variable>
        <xsl:sequence
          select="map{'open': $open, 'last-opened': $last-opened, 'current-node': $current-node, 'within-bracket': $within-bracket}"/>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:for-each select="head($input)">
          <xsl:choose>
            <!-- if the bracket is at start/end of text node and has bignore next to it, just output it as text -->
            <xsl:when
              test="self::local:bracket and (
              ($position eq 1 and $preceding-bignore) or
              ($position eq $last and $following-bignore)
              )">
              <xsl:variable name="new-text-node" as="node()">
                <local:text><xsl:value-of select="."/></local:text>
              </xsl:variable>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="accumulated-nodes" tunnel="yes" select="($accumulated-nodes, $new-text-node)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::local:bracket[@type='open']">
              <xsl:variable name="new-bracket-pair" as="xs:integer" select="$last-opened + 1"/>
              <xsl:variable name="new-bracket" as="node()">
                <local:bracket opens-pair="{$new-bracket-pair}">
                  <xsl:apply-templates select="@*"/>
                  <xsl:value-of select="."/>
                </local:bracket>
              </xsl:variable>
              
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="open" as="xs:integer*" select="($open, $new-bracket-pair)" tunnel="yes"/>
                <xsl:with-param name="last-opened" as="xs:integer" select="$new-bracket-pair" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*" tunnel="yes"
                  select="($accumulated-nodes, $new-bracket)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::local:bracket[@type='close']">
              <xsl:if test="not(exists($open))">
                <xsl:message expand-text="yes">with input {serialize($input, map{'method':'adaptive'})}, accum nodes {serialize($accumulated-nodes, map{'method':'adaptive'})} and current bracket node {serialize(., map{'method':'adaptive'})}, there are no open brackets</xsl:message>
              </xsl:if>
              <xsl:variable name="closing-bracket-pair" as="xs:integer" select="$open[last()]"/>
              <xsl:variable name="new-bracket" as="node()">
                <xsl:copy select=".">
                  <xsl:apply-templates select="@*"/>
                  <xsl:attribute name="closes-pair" select="$closing-bracket-pair"/>
                  <xsl:value-of select="."/>
                </xsl:copy>
              </xsl:variable>
              
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="open" as="xs:integer*"
                  select="$open[position() lt last()]" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*" tunnel="yes"
                  select="($accumulated-nodes, $new-bracket)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::local:text">
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="within-bracket" select="if (count($open) gt 0 and normalize-space(.)) then map:merge(
                  ($within-bracket, map:entry($open[last()], .)),
                  map{'duplicates': 'combine'}
                  ) else $within-bracket" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*"
                  select="($accumulated-nodes, .)" tunnel="yes"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:otherwise>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="errmsg" visibility="public">
    <xsl:param name="failNode" as="node()?" required="false"/>
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
