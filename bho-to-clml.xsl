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
  <xsl:param name="lookupFile" select="'lookup.xml'" static="yes"/> <!-- contains metadata to add to the output files -->
  
  <!-- -/- MODES -/- -->
  <xsl:mode use-accumulators="brackets-paired"/>
  
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
  <xsl:variable name="legtitlecommentid" as="xs:string?">
    <xsl:choose>
      <xsl:when test="$legtitlesource eq 'chron'">chron</xsl:when>
      <xsl:otherwise><xsl:value-of select="$report/@titleComment"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="legtitlecomment" as="node()*" select="$lookup//titleComment[@id = $legtitlecommentid]/node()"/>

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
  
  <!-- A map of all nodes contained within each bracket, which we use for finding
       the ref to use as the CommentaryRef id for the output <Addition> elements -->
  <xsl:variable name="within-bracket-map" as="map(*)">
    <xsl:sequence select="accumulator-after('brackets-paired')('within-bracket')"/>
  </xsl:variable>
  
  <!-- Used to check if there are any brackets we opened but didn't close -->
  <xsl:variable name="all-opened-brackets" as="map(*)" select="accumulator-after('brackets-paired')('all-opened')"/>
  <xsl:variable name="all-closed-brackets" as="map(*)" select="accumulator-after('brackets-paired')('all-closed')"/>

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
  
  <!-- local:process-brackets turns a text node into a "brackets" version where 
       brackets are represented by nodes, so we can query and transform them

       e.g. this is [real] ->
         <local:text>this is </local:text>
         <local:bracket type="open" shape="square">[</local:bracket>
         <local:text>real</local:text>
         <local:bracket type="close" shape="square">]</local:bracket> -->
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
    
    <!--
      "kind" is used to tell the transform how to handle the brackets later:
       * bracketed = wrap in <local:bracketed> els (for <Addition> in output) ;
       * shuck = remove brackets from text (used for (<ref idref="n2"/>), because
           we don't want to output brackets around <CommentaryRef> els
       * raw = output brackets as-is in text (useful for e.g. "Su[m]me")

      "refs" collects all the <ref> elements so the transform can check if any
      given <ref> is the last in a bracketed pair (so as to use its id as the Ref id)
      or not (in which case just output it as a CommentaryRef). Useful in case a bracket
      contains multiple <ref>s for some reason.
    -->
    <xsl:sequence select="map{
      'kind': if ($refs) then if ($not-refs) then 'bracketed' else 'shuck' else 'raw',
      'refs': $refs
      }"/>
  </xsl:function>
  
  <!-- local:add-into-accumulated helps accumulate nodes into a nested, bracketed
    form, and optionally wrap them in <Text> nodes. For more information see the
    add-into-accumulated template -->
  <xsl:function name="local:add-into-accumulated" as="node()*">
    <xsl:param name="accumulated" as="element()?"/>
    <xsl:param name="output" as="node()*"/>
    <xsl:param name="bracket" as="xs:integer*"/>
    <xsl:param name="wrap" as="xs:boolean"/>
    <xsl:param name="original-context-node" as="node()"/>
    
    <xsl:choose>
      <xsl:when test="not(exists($output))">
        <xsl:sequence select="$accumulated"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="add-into-accumulated">
          <xsl:with-param name="scope" as="element()">
            <xsl:choose>
              <xsl:when test="exists($accumulated)">
                <xsl:sequence select="$accumulated"/>
              </xsl:when>
              <xsl:otherwise>
                <local:accumulated>
                  <xsl:if test="$wrap">
                    <Text/>
                  </xsl:if>
                </local:accumulated>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
          <xsl:with-param name="bracket" select="$bracket"/>
          <xsl:with-param name="output" select="$output" tunnel="yes"/>
          <xsl:with-param name="text-wrap" select="$wrap"/>
          <xsl:with-param name="original-context-node" select="$original-context-node" tunnel="yes"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!-- -/- ACCUMULATORS -/- -->
  <!-- brackets-paired tracks which brackets are open at every node in the document,
    as well as which nodes appear within which brackets, and what the "bracket" nodes
    are for each text node (see local:process-brackets for explanation) -->
  <xsl:accumulator name="brackets-paired" as="map(*)"
    initial-value="map{
      'open': (),
      'last-opened': 0,
      'all-opened': map{},
      'all-closed': map{},
      'current-node': (),
      'within-bracket': map{}}
      ">
    
    <!-- Record <emph>/<ref>/<br> nodes against any bracket they're within -->
    <xsl:accumulator-rule match="emph|ref|br" phase="start">
      <xsl:variable name="last-open" select="$value('open')[last()]"/>
      <xsl:choose>
        <xsl:when test="$last-open">
          <xsl:variable name="new-within-bracket"
            select="map:merge(($value('within-bracket'), map:entry($last-open, .)), map{'duplicates': 'combine'})"/>
          <xsl:sequence select="map:put($value, 'within-bracket', $new-within-bracket)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="$value"/> <!-- pass through the previous accumulator value -->
        </xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
    
    <!-- Turn text() nodes into sequences of <text> and <bracket> nodes, plus make metadata -->
    <xsl:accumulator-rule match="text()[parent::emph or parent::para or parent::head or parent::caption or parent::subtitle or parent::th or parent::td]">
      <xsl:call-template name="process-brackets">
        <xsl:with-param name="context-node" select="."/>
        <xsl:with-param name="input" select="local:process-brackets(.)"/>
        <xsl:with-param name="open" as="xs:integer*" select="$value('open')"/>
        <xsl:with-param name="last-opened" select="$value('last-opened')"/>
        <xsl:with-param name="all-opened" select="$value('all-opened')"/>
        <xsl:with-param name="all-closed" select="$value('all-closed')"/>
        <xsl:with-param name="within-bracket" select="$value('within-bracket')"/>
        <xsl:with-param name="preceding-bignore"
          select="exists(preceding-sibling::node()[1]/self::processing-instruction('bignore'))"/>
        <xsl:with-param name="following-bignore"
          select="exists(following-sibling::node()[1]/self::processing-instruction('bignore'))"/>
      </xsl:call-template>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!-- -/- TEMPLATES -/- -->
  <xsl:template match="/report">
    <!-- Check all opening brackets are paired up with closing brackets.
      We check the closing brackets inside the template rule for local:bracket[@type='close']. -->
    <xsl:for-each select="map:keys($all-opened-brackets)">
      <xsl:if test="not(. = map:keys($all-closed-brackets))">
        <xsl:message terminate="yes">
          <xsl:text>FATAL ERROR: </xsl:text>
          <xsl:call-template name="errmsg">
            <xsl:with-param name="failNode" select="$all-opened-brackets(.)"/>
            <xsl:with-param name="message">
              <xsl:text>opening bracket of pair </xsl:text>
              <xsl:value-of select="."/>
              <xsl:text> has no matching closing bracket</xsl:text>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:message>
      </xsl:if>
    </xsl:for-each>
    
    <Legislation SchemaVersion="1.0"
      xsi:schemaLocation="http://www.legislation.gov.uk/namespaces/legislation https://www.legislation.gov.uk/schema/legislation.xsd"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"
      xmlns:xhtml="http://www.w3.org/1999/xhtml"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns="http://www.legislation.gov.uk/namespaces/legislation">

      <xsl:apply-templates select="@*"/>

      <ukm:Metadata>
        <dc:title><xsl:value-of select="$legtitle"/></dc:title>
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
          <Title>
            <xsl:value-of select="$legtitle"/>
            <xsl:if test="$legtitlecomment">
              <CommentaryRef Ref="c400001"/>
            </xsl:if>
          </Title>
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
          <!-- NB: This unnests all nested sections. For most documents that's correct as the nesting is normally inappropriate,
               but a very small number of docs *should* have nested sections. These will require manual structural fixes - it's
               too complex to handle here. -->
          <xsl:apply-templates select="descendant::section"/>
        </Body>
      </Primary>

      <xsl:if test="descendant::note or $legtitlecomment">
        <Commentaries>
          <xsl:if test="$legtitlecomment">
            <Commentary id="c400001">
              <xsl:attribute name="Type">
                <xsl:choose>
                  <xsl:when test="$legtitlesource = 'conferred'">C</xsl:when>
                  <xsl:otherwise>X</xsl:otherwise>
                </xsl:choose>
              </xsl:attribute>
              <Para>
                <Text><xsl:copy-of select="$legtitlecomment" copy-namespaces="no"/></Text>
              </Para>
            </Commentary>
          </xsl:if>
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
                <!-- if no child paras, just output whatever is here (except the title or any sections) -->
                <xsl:apply-templates select="node() except (head | section)"/>
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
        <xsl:value-of select="."/>
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
      <xsl:apply-templates select="." mode="text-wrap"/>
    </P1para>
  </xsl:template>

  <xsl:template match="para" mode="p">
    <xsl:apply-templates select="@*"/>
    <xsl:apply-templates select="." mode="text-wrap"/>
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
    <Commentary id="{local:make-id(@id, 'c')}" Type="X">
      <xsl:apply-templates select="@* except @id"/>
      <Para>
        <xsl:choose>
          <xsl:when test="matches(., ' O\.\s*$')">
            <!-- when the footnote ends in "O.", add in an extra note to explain what that means -->
            <Text>Variant reading of the text noted in <Emphasis>The Statutes of the Realm</Emphasis> as follows: <xsl:apply-templates mode="note"/> [<Emphasis>O.</Emphasis> refers to a collection in the library of Trinity College, Cambridge]</Text>
          </xsl:when>
          <xsl:otherwise>
            <!-- for other notes, pass text through as normal -->
            <Text>
              <xsl:apply-templates mode="note"/>
            </Text>
          </xsl:otherwise>
        </xsl:choose>
      </Para>
    </Commentary>
  </xsl:template>

  <xsl:template match="note/@number"/>

  <xsl:template match="ref">
    <xsl:apply-templates select="@* except @idref"/>
    <CommentaryRef Ref="{local:make-id(@idref, 'c')}"/>
  </xsl:template>

  <xsl:template match="emph" priority="+1">
    <xsl:param name="process-text" as="xs:boolean" select="false()"/>
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
          <xsl:choose>
            <xsl:when test="$process-text">
              <xsl:apply-templates select="." mode="text"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates/>
            </xsl:otherwise>
          </xsl:choose>
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
  
  <!-- used only in footnotes, where we don't process brackets -->
  <xsl:template match="emph/text()">
    <xsl:sequence select="."/>
  </xsl:template>

  <xsl:template match="table" mode="p1para">
    <xsl:apply-templates select="."/>
  </xsl:template>

  <xsl:template match="table" mode="p"/>

  <xsl:template match="table">
    <xsl:variable name="tableNumber" as="xs:integer">
      <xsl:number count="table" level="any"/>
    </xsl:variable>
    <Tabular id="{format-number($tableNumber, 't00000')}" Orientation="portrait">
      <xsl:apply-templates select="@* except @id"/>
      <table xmlns="http://www.w3.org/1999/xhtml">
        <!-- no thead as some SotR tables have headers half way down -->
        <tbody>
          <xsl:apply-templates/>
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

  <xsl:template match="th|td">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:apply-templates select="@*"/>
      <xsl:if test="descendant::element() or text()[normalize-space()]">
        <xsl:choose>
          <xsl:when test="exists(br)">
            <!-- need to wrap in <Text> if contains <br> as it's our only way to create line breaks -->
            <xsl:apply-templates select="." mode="text-wrap"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="text"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
    </xsl:element>
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
      <xsl:apply-templates select="." mode="text-wrap"/>
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
    <xsl:variable name="preprocessed" as="node()*">
      <xsl:apply-templates select="." mode="text"/>
    </xsl:variable>
    
    <xsl:variable name="templated">
      <xsl:iterate select="$preprocessed">
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
  
  <xsl:template match="node()" mode="text-wrap">
    <xsl:apply-templates select="." mode="text">
      <xsl:with-param name="wrap" select="true()"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <!-- This template iterates over the child nodes of the element and wraps them in
    <local:bracketed> elements, which become <Addition> elements ("square brackets" on the
    legislation.gov.uk website), if any brackets are open around or within the element.

    This is necessary because BHO represents brackets in the text as [], whereas 
    legislation.gov.uk wraps them in <Addition>/<Substitution>/<Repeal> elements.
    Converting one to the other is awkward, hence this long template. -->
  <xsl:template match="node()" mode="text">
    <xsl:param name="wrap" as="xs:boolean" select="false()"/>

    <xsl:variable name="original-context-node" as="node()" select="."/>
    <xsl:variable name="collected" as="node()*">
      <xsl:iterate select="node()">
        <xsl:choose>
          <xsl:when test="self::text()">
            <!-- use the collected output of process-brackets for this node instead
              of the original text -->
            <xsl:sequence select="accumulator-after('brackets-paired')('current-node')/node()"/>
          </xsl:when>
          <xsl:when test="self::processing-instruction('bignore')"/> <!-- see process-brackets -->
          <xsl:otherwise>
            <xsl:sequence select="."/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:iterate>
    </xsl:variable>
    
    <xsl:iterate select="$collected">
      <xsl:param name="accumulated" as="element()?"/>
      <xsl:param name="to-accumulate" as="node()*"/>
      <!--
        If we have a preceding node, take the open brackets to be those *after* it, in
          case some brackets were opened within it;
        If we're the first node, take the open brackets to be the ones *before* our parent
          (rather than after it, which would count brackets opened/closed within it
        This could potentially be replaced with preceding::node ! accumulator-after(...) -->
      <xsl:param name="open" as="xs:integer*" select="(
        preceding-sibling::node()[1] ! accumulator-after('brackets-paired')('open'),
        parent::node() ! accumulator-before('brackets-paired')('open')
      )[1]"/>
      
      <xsl:on-completion>
        <xsl:variable name="accumulated" select="local:add-into-accumulated($accumulated, $to-accumulate, $open, $wrap, $original-context-node)"/>
        <xsl:apply-templates select="$accumulated/node()" mode="unbracketize"/>
      </xsl:on-completion>
      
      <xsl:choose>
        <xsl:when test="self::emph">
          <!-- in CLML <Emphasis> can't go inside <Addition> so we have to output what we've
            accumulated so far and then process the <emph> separately (i.e. close all the open
            brackets and reopen them all inside the resulting <Emphasis>) before continuing -->
          <xsl:variable name="emph" as="element()">
            <xsl:apply-templates select=".">
              <xsl:with-param name="process-text" select="true()"/>
            </xsl:apply-templates>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$wrap">
              <!-- if we're wrapping in <Text>, should keep accumulating in the same <Text>, but
                not in any existing brackets (as <Emphasis> will contain its own tree of brackets) -->
              <xsl:next-iteration>
                <xsl:with-param name="accumulated" select="local:add-into-accumulated(local:add-into-accumulated($accumulated, $to-accumulate, $open, true(), $original-context-node), $emph, (), true(), $original-context-node)"/>
                <xsl:with-param name="to-accumulate" select="()"/>
                <xsl:with-param name="open" select="$open"/>
              </xsl:next-iteration>
            </xsl:when>
            <xsl:otherwise>
              <!-- if we're not wrapping, just output the <Emphasis> and anything else ready to
                accumulated, then continue afresh -->
              <xsl:variable name="accumulated" select="local:add-into-accumulated(local:add-into-accumulated($accumulated, $to-accumulate, $open, false(), $original-context-node), $emph, (), false(), $original-context-node)"/>
              <xsl:apply-templates select="$accumulated/node()" mode="unbracketize"/>
              <xsl:next-iteration>
                <xsl:with-param name="accumulated" select="()"/>
                <xsl:with-param name="to-accumulate" select="()"/>
                <xsl:with-param name="open" select="$open"/>
              </xsl:next-iteration>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        
        <xsl:when test="self::br">
          <xsl:if test="not($wrap)">
            <!-- fatal error: <br> should not be present if we're not wrapping (whenever <br>
              appears in text, we should always be wrapping the text either side in  separate
              <Text> elements, as that's the only way to represent line breaks in CLML -->
              <xsl:message terminate="yes">
                <xsl:text>FATAL ERROR: </xsl:text>
                <xsl:call-template name="errmsg">
                  <xsl:with-param name="failNode" select="$original-context-node"/>
                  <xsl:with-param name="message">
                    <xsl:text>if &lt;br&gt; appears in a node we must process its </xsl:text>
                    <xsl:text>text with "text-wrap" mode to create CLML line breaks</xsl:text>
                  </xsl:with-param>
                </xsl:call-template>
              </xsl:message>
          </xsl:if>

          <!-- output what we've accumulated, then start a new <Text> node -->
          <xsl:variable name="accumulated"
            select="local:add-into-accumulated($accumulated, $to-accumulate, $open, $wrap, $original-context-node)"/>
          <xsl:apply-templates select="$accumulated/node()" mode="unbracketize"/>
          <xsl:next-iteration>
            <xsl:with-param name="accumulated" as="element()">
              <local:accumulated>
                <Text/>
              </local:accumulated>
            </xsl:with-param>
            <xsl:with-param name="open" select="$open"/>
            <xsl:with-param name="to-accumulate" select="()"/>
          </xsl:next-iteration>
        </xsl:when>
        
        <xsl:when test="self::local:bracket">
          <xsl:choose>
            <xsl:when test="@type eq 'open'">
              <xsl:variable name="btext" as="node()?">
                <xsl:if test="local:get-bracket-info(@opens-pair)('kind') eq 'raw'">
                  <xsl:value-of select="."/> <!-- if "raw" brackets, output the bracket as text -->
                </xsl:if>
              </xsl:variable>
              <xsl:next-iteration>
                <xsl:with-param name="accumulated"
                  select="local:add-into-accumulated($accumulated, ($to-accumulate, $btext), $open, $wrap, $original-context-node)"/>
                <xsl:with-param name="open" select="($open, @opens-pair)"/>
                <xsl:with-param name="to-accumulate" select="()"/>
              </xsl:next-iteration>
            </xsl:when>
            
            <xsl:when test="@type = 'close'">
              <xsl:variable name="btext" as="node()?">
                <xsl:if test="local:get-bracket-info(@closes-pair)('kind') eq 'raw'">
                  <xsl:value-of select="."/> <!-- if "raw" brackets, output the bracket as text -->
                </xsl:if>
              </xsl:variable>
              <xsl:choose>
                <xsl:when test="@closes-pair = $open[last()]">
                  <xsl:next-iteration>
                    <xsl:with-param name="accumulated"
                      select="local:add-into-accumulated($accumulated, ($to-accumulate, $btext), $open, $wrap, $original-context-node)"/>
                    <xsl:with-param name="open" select="$open[position() lt last()]"/>
                    <xsl:with-param name="to-accumulate" select="()"/>
                  </xsl:next-iteration>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:message terminate="yes">
                    <xsl:text>FATAL ERROR: </xsl:text>
                    <xsl:call-template name="errmsg">
                      <xsl:with-param name="failNode" select="$original-context-node"/>
                      <xsl:with-param name="message">closing bracket with no opening bracket</xsl:with-param>
                    </xsl:call-template>
                  </xsl:message>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
          </xsl:choose>
        </xsl:when>

        <xsl:otherwise>
          <!-- for other nodes, just process them and collect them ready to
            accumulate whenever this tree of brackets ends at an <Emphasis> or 
            element boundary (this is faster than "accumulating" every single node) -->
          <xsl:variable name="output" as="node()?">
            <xsl:apply-templates select="." mode="bracketize-inner">
              <xsl:with-param name="open" select="$open" tunnel="yes"/>
            </xsl:apply-templates>
          </xsl:variable>
          <xsl:next-iteration>
            <xsl:with-param name="to-accumulate" select="($to-accumulate, $output)"/>
            <xsl:with-param name="open" select="$open"/>
          </xsl:next-iteration>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
  </xsl:template>
  
  <!-- turn <local:bracketed> into <Addition>, or just output the contents
    if these brackets are raw (i.e. not footnoted) or shucked (i.e. only
    contain a single footnote ref) -->
  <xsl:template match="local:bracketed" mode="unbracketize" priority="+1">
    <xsl:choose>
      <xsl:when test="xs:boolean(@retain)">
        <xsl:if test="not(normalize-space(@idref))">
          <xsl:message terminate="yes">
            <xsl:call-template name="errmsg">
              <xsl:with-param name="message">
                <xsl:text>local:bracketed for pair </xsl:text>
                <xsl:value-of select="@pair"/>
                <xsl:text> has no idref</xsl:text>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:message>
        </xsl:if>
        <Addition CommentaryRef="{local:make-id(@idref, 'c')}"
          ChangeId="{local:make-id(@idref, 'c')}-d{format-number(@pair, '000000')}">
          <xsl:apply-templates mode="unbracketize"/>
        </Addition>
      </xsl:when>

      <xsl:otherwise>
        <xsl:apply-templates mode="unbracketize"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="node() | @*" mode="unbracketize">
    <xsl:copy copy-namespaces="no">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="unbracketize"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- add-into-accumulated takes one or more nodes and inserts them appropriately
    into a tree of <local:bracketed> elements that represent one or more layers of
    brackets, creating any missing <local:bracketed> elements as needed. -->
  <xsl:template name="add-into-accumulated">
    <xsl:param name="scope" as="element()?"/>
    <xsl:param name="bracket" as="xs:integer*" select="()"/>
    <xsl:param name="output" as="node()+" tunnel="yes"/>
    <xsl:param name="text-wrap" as="xs:boolean" select="false()"/>
    <xsl:param name="original-context-node" as="node()" tunnel="yes"/>
    
    <xsl:variable name="last-node-in-scope" select="$scope/node()[last()]"/>
    <xsl:variable name="nodes" as="node()+">
      <xsl:sequence select="$scope/node()[position() lt last()]"/>
      <xsl:choose>
        <xsl:when test="$text-wrap">
          <xsl:if test="$last-node-in-scope/not(self::leg:Text)">
            <!-- fatal error: if wrapping in <Text>, last node in top level accumulated
              must always be a <Text> node -->
            <xsl:message terminate="yes">
              <xsl:text>FATAL ERROR: </xsl:text>
              <xsl:call-template name="errmsg">
                <xsl:with-param name="failNode" select="$original-context-node"/>
                <xsl:with-param name="message">
                  <xsl:text>unexpected failure in text wrapping (this is a bug in the code)</xsl:text>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:message>
          </xsl:if>
          <xsl:call-template name="add-into-accumulated">
            <xsl:with-param name="scope" select="$last-node-in-scope"/>
            <xsl:with-param name="bracket" select="$bracket"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="not(exists($bracket))">
              <!-- No brackets (or inside innermost bracket); output nodes in scope + new node(s) -->
              <xsl:sequence select="$last-node-in-scope"/>
              <xsl:sequence select="$output"/>
            </xsl:when>
            <xsl:otherwise>
              <!-- There are brackets left; either wrap in them if not yet present, or add to
                existing wrapping if they are present -->
              <xsl:choose>
                <xsl:when test="$last-node-in-scope/self::local:bracketed[@pair = head($bracket)]">
                  <xsl:call-template name="add-into-accumulated">
                    <xsl:with-param name="scope" select="$last-node-in-scope"/>
                    <xsl:with-param name="bracket" select="tail($bracket)"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$last-node-in-scope"/>
                  <local:bracketed
                    pair="{head($bracket)}"
                    idref="{local:get-bracket-info(head($bracket))('refs')[last()]/@idref}"
                    retain="{local:get-bracket-info(head($bracket))('kind') eq 'bracketed'}"
                    >
                    <xsl:call-template name="add-into-accumulated">
                      <xsl:with-param name="scope" select="()"/>
                      <xsl:with-param name="bracket" select="tail($bracket)"/>
                    </xsl:call-template>
                  </local:bracketed>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="exists($scope)">
        <xsl:copy select="$scope">
          <xsl:sequence select="$scope/@*"/>
          <xsl:sequence select="$nodes"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$nodes"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text()" mode="bracketize-inner">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:variable name="current-bracket" as="xs:integer?" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="if ($current-bracket) then local:get-bracket-info($current-bracket) else map{}"/>
    <xsl:choose>
      <xsl:when
        test="$current-bracket and $bracket-info('kind') eq 'bracketed' and following::node()[1]/self::ref = $bracket-info('refs')[last()]">
        <!-- remove trailing whitespace at the end of this text node if the
          next node is the last <ref> of the bracket, as we'll remove that
          node and don't want useless whitespace left inside the bracket -->
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
      <!-- Don't output the last ref in this bracket - we'll use its id in the
        CommentaryRef attribute of the <Addition> tag instead -->
      <xsl:when test="$current-bracket and $bracket-info('kind') eq 'bracketed' and . = $bracket-info('refs')[last()]"/>
      <xsl:otherwise>
        <xsl:apply-templates select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="leg:*" mode="bracketize-inner">
    <xsl:copy-of select="." copy-namespaces="no"/>
  </xsl:template>
  
  <xsl:template match="text()" mode="note">
    <xsl:sequence select="."/>
  </xsl:template>
  
  <xsl:template match="emph" mode="note">
    <xsl:apply-templates select="."/>
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
  <xsl:template match="@* | node()" mode="title">
    <!-- fallback - helps us discover and deal with unexpected doc structure -->
    <xsl:message terminate="yes">
      <xsl:text>FATAL ERROR: </xsl:text>
      <xsl:call-template name="errmsg">
        <xsl:with-param name="failNode" select="."/>
        <xsl:with-param name="message">unmatched/unexpected node</xsl:with-param>
      </xsl:call-template>
    </xsl:message>
  </xsl:template>
  
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
    <xsl:param name="context-node" as="node()"/>
    <xsl:param name="input" as="node()*"/>
    <xsl:param name="open" as="xs:integer*" select="()"/>
    <xsl:param name="last-opened" as="xs:integer?" select="()"/>
    <xsl:param name="all-opened" as="map(*)" select="map{}"/>
    <xsl:param name="all-closed" as="map(*)*" select="map{}"/>
    <xsl:param name="within-bracket" as="map(*)" select="map{}"/>
    <xsl:param name="preceding-bignore" as="xs:boolean"/>
    <xsl:param name="following-bignore" as="xs:boolean"/>
    
    <xsl:iterate select="$input">
      <xsl:param name="open" as="xs:integer*" select="$open"/>
      <xsl:param name="last-opened" as="xs:integer?" select="$last-opened"/>
      <xsl:param name="all-opened" as="map(*)" select="$all-opened"/>
      <xsl:param name="all-closed" as="map(*)*" select="$all-closed"/>
      <xsl:param name="accumulated-nodes" as="node()*" select="()"/>
      <xsl:param name="within-bracket" as="map(*)" select="$within-bracket"/>
      
      <xsl:on-completion>
        <xsl:variable name="current-node" as="node()">
          <local:node>
            <xsl:sequence select="$accumulated-nodes"/>
          </local:node>
        </xsl:variable>
        <xsl:map>
          <xsl:map-entry key="'open'" select="$open"/>
          <xsl:map-entry key="'last-opened'" select="$last-opened"/>
          <xsl:map-entry key="'all-opened'" select="$all-opened"/>
          <xsl:map-entry key="'all-closed'" select="$all-closed"/>
          <xsl:map-entry key="'current-node'" select="$current-node"/>
          <xsl:map-entry key="'within-bracket'" select="$within-bracket"/>
        </xsl:map>
      </xsl:on-completion>
      
      <xsl:choose>
        <!-- if the bracket is at start/end of text node and has bignore next to it, just output it as text -->
        <xsl:when
          test="self::local:bracket and (
          (position() eq 1 and $preceding-bignore) or
          (position() eq last() and $following-bignore)
          )">
          <xsl:variable name="new-text-node" as="node()">
            <local:text><xsl:value-of select="."/></local:text>
          </xsl:variable>
          <xsl:next-iteration>
            <xsl:with-param name="accumulated-nodes" select="($accumulated-nodes, $new-text-node)"/>
          </xsl:next-iteration>
        </xsl:when>
        
        <xsl:when test="self::local:bracket[@type='open']">
          <xsl:variable name="new-bracket-pair" as="xs:integer" select="$last-opened + 1"/>
          <xsl:variable name="new-bracket" as="node()">
            <local:bracket opens-pair="{$new-bracket-pair}">
              <xsl:apply-templates select="@*"/>
              <xsl:value-of select="."/>
            </local:bracket>
          </xsl:variable>
          
          <xsl:next-iteration>
            <xsl:with-param name="open" as="xs:integer*" select="($open, $new-bracket-pair)"/>
            <xsl:with-param name="last-opened" as="xs:integer" select="$new-bracket-pair"/>
            <xsl:with-param name="all-opened" as="map(*)"
              select="map:put($all-opened, $new-bracket-pair, $context-node)"/>
            <xsl:with-param name="accumulated-nodes" as="node()*"
              select="($accumulated-nodes, $new-bracket)"/>
          </xsl:next-iteration>
        </xsl:when>
        
        <xsl:when test="self::local:bracket[@type='close']">
          <xsl:if test="not(exists($open))">
            <xsl:message terminate="yes">
              <xsl:text>FATAL ERROR: </xsl:text>
              <xsl:call-template name="errmsg">
                <xsl:with-param name="failNode" select="$context-node"/>
                <xsl:with-param name="message">
                  <xsl:text>closing bracket has no matching opening bracket</xsl:text>
                </xsl:with-param>
              </xsl:call-template>
            </xsl:message>
          </xsl:if>
          <xsl:if test="exists($open)">
          <xsl:variable name="closing-bracket-pair" as="xs:integer" select="$open[last()]"/>
          <xsl:variable name="new-bracket" as="node()">
            <xsl:copy select=".">
              <xsl:apply-templates select="@*"/>
              <xsl:attribute name="closes-pair" select="$closing-bracket-pair"/>
              <xsl:value-of select="."/>
            </xsl:copy>
          </xsl:variable>
          
          <xsl:next-iteration>
            <xsl:with-param name="open" as="xs:integer*"
              select="$open[position() lt last()]"/>
            <xsl:with-param name="all-closed" as="map(*)"
              select="map:put($all-closed, $closing-bracket-pair, $context-node)"/>
            <xsl:with-param name="accumulated-nodes" as="node()*"
              select="($accumulated-nodes, $new-bracket)"/>
          </xsl:next-iteration>
          </xsl:if>
        </xsl:when>
        
        <xsl:when test="self::local:text">
          <xsl:next-iteration>
            <xsl:with-param name="within-bracket" select="if (count($open) gt 0 and normalize-space(.)) then map:merge(
              ($within-bracket, map:entry($open[last()], .)),
              map{'duplicates': 'combine'}
              ) else $within-bracket"/>
            <!-- fix: exclude blank text nodes at start of el -->
            <xsl:with-param name="accumulated-nodes" as="node()*"
              select="($accumulated-nodes, if (normalize-space() or position() gt 1) then . else ())"/>
          </xsl:next-iteration>
        </xsl:when>
        
        <xsl:otherwise>
          <xsl:next-iteration/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:iterate>
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
