<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:local="local:"
  exclude-result-prefixes="xs map local"
  version="3.0">
 
  <xsl:accumulator name="brackets-paired" as="map(*)"
    initial-value="map{'open': (), 'last-opened': 0, 'current-node': (), 'within-bracket': map{}}">
    <xsl:accumulator-rule match="emph|ref|br" phase="start">
      <xsl:variable name="last-open" select="map:get($value, 'open')[last()]"/>
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
    
    <xsl:accumulator-rule match="text()[not(parent::ref)]">
      <xsl:variable name="current-text-node" select="."/>
      <xsl:variable name="current-node-brackets" as="node()*" select="local:process-brackets(.)"/>
      <!--<xsl:message select="'cnb (kind ' || local:node-kind($current-node-brackets) || '): ' || serialize($current-node-brackets,map{'method':'adaptive'})"/>-->
      <xsl:variable name="_open" select="map:get($value, 'open')"/>
      <xsl:variable name="_last-opened" select="map:get($value, 'last-opened')"/>
      <xsl:variable name="_within-bracket" select="map:get($value, 'within-bracket')"/>
      <!--<xsl:message expand-text="yes">text node is {.}, preceding sib is {serialize(preceding-sibling::node(), map{'method':'adaptive'})}, following sib is {serialize(following-sibling::node(), map{'method':'adaptive'})}</xsl:message>-->
      <xsl:variable name="temp" as="map(*)">
        <xsl:call-template name="process-brackets">
          <xsl:with-param name="input" select="$current-node-brackets"/>
          <xsl:with-param name="open" as="xs:integer*" select="$_open" tunnel="yes"/>
          <xsl:with-param name="last-opened" select="$_last-opened" tunnel="yes"/>
          <xsl:with-param name="within-bracket" select="$_within-bracket" tunnel="yes"/>
          <xsl:with-param name="preceding-bignore" tunnel="yes"
            select="exists(preceding-sibling::node()[1]/self::processing-instruction('bignore'))"/>
          <xsl:with-param name="following-bignore" tunnel="yes"
            select="exists(following-sibling::node()[1]/self::processing-instruction('bignore'))"/>
        </xsl:call-template>
      </xsl:variable>
      <!--<xsl:message select="'cnb-post-temp: ' || serialize($temp,map{'method':'adaptive'})"/>-->
      <!--<xsl:message expand-text="yes">kinds within cn: {for-each(map:get($temp, 'current-node'), local:node-kind#1)}</xsl:message>-->
      <xsl:sequence select="$temp"/>
    </xsl:accumulator-rule>
  </xsl:accumulator>
  
  <xsl:mode use-accumulators="brackets-paired"/>
  
  <xsl:variable name="within-bracket-map" as="map(*)">
    <xsl:variable name="temp" select="accumulator-after('brackets-paired')('within-bracket')"/>
    <!--<xsl:message select="'within-bracket-map:' || serialize($temp, map{'method': 'adaptive'})"/>-->
    <xsl:sequence select="$temp"/>
  </xsl:variable>
  
  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()[1]"/>
    </xsl:copy>
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>
  
  <xsl:template match="text()|ref" priority="+1">
    <xsl:param name="accumulated-node" as="node()?" select="()"/>
    <xsl:param name="open" as="xs:integer*">
      <xsl:for-each select="(preceding-sibling::node(), parent::node())[1]">
        <xsl:sequence select="accumulator-before('brackets-paired')('open')"/>
      </xsl:for-each>
    </xsl:param>
    <xsl:variable name="new-accumulated-node" as="node()">
      <node>
        <xsl:choose>
          <xsl:when test="self::text()">
            <xsl:variable name="new-nodes" select="accumulator-after('brackets-paired')('current-node')/node/node()"/>
            <xsl:variable name="terminal-refs" select="$accumulated-node/ref except $accumulated-node/node()[not(self::ref)][last()]/preceding-sibling::node()"/>
            <xsl:variable name="last-text-node" select="$accumulated-node/node()[last()][self::text]"/>
            <xsl:variable name="first-new-text-node" select="$new-nodes[position() eq 1 and self::text]"/>
            <xsl:sequence select="$accumulated-node/node() except ($terminal-refs, $accumulated-node/node()[last()][self::text])"/>
            <xsl:choose>
              <xsl:when test="$terminal-refs or $last-text-node">
                <text>
                  <xsl:sequence select="($last-text-node/node(), $terminal-refs, $first-new-text-node/node())"/>
                </text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="$first-new-text-node"/>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:sequence select="$new-nodes[not(position() eq 1 and self::text)]"></xsl:sequence>
          </xsl:when>
          <xsl:when test="self::ref">
            <xsl:variable name="ref" as="node()" select="."/>
            <xsl:variable name="output">
              <xsl:choose>
                <xsl:when test="$accumulated-node/node()[last()][self::text]">
                  <xsl:sequence select="$accumulated-node/node()[position() lt last()]"/>
                  <xsl:copy select="$accumulated-node/node()[last()]">
                    <xsl:copy-of select="@*"/>
                    <xsl:sequence select="node()"/>
                    <xsl:sequence select="$ref"/>
                  </xsl:copy>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$accumulated-node/node()"/>
                  <xsl:sequence select="$ref"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <!--<xsl:message expand-text="yes">self::ref output: {serialize($output, map{'method':'adaptive'})}</xsl:message>-->
            <xsl:sequence select="$output"/>
          </xsl:when>
        </xsl:choose>
      </node>
    </xsl:variable>
<!--    <xsl:message expand-text="yes">applying for text() with cn: {serialize(accumulator-after('brackets-paired')('current-node'),map{'method':'adaptive'})}</xsl:message>-->
    <xsl:choose>
      <!-- we roll up all adjacent text node/<ref> siblings and process them at once, so that we can
        wrap brackets around entire runs of contiguous text nodes and refs, instead of having them
        break when a <ref> interrupts a text node - this means we can wrap <refs in brackets where needed -->
      <xsl:when test="following-sibling::node()[1][self::text() or self::ref]">
        <xsl:apply-templates select="following-sibling::node()[1][self::text() or self::ref]">
          <xsl:with-param name="accumulated-node" select="$new-accumulated-node"/>
          <xsl:with-param name="open" as="xs:integer*" select="$open"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$new-accumulated-node/node()[1]" mode="bracketize">
          <xsl:with-param name="open" select="$open" tunnel="yes"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="following-sibling::node()[1]"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text()" mode="bracketize-inner">
    <xsl:sequence select="."/>
  </xsl:template>
  
  <xsl:template match="ref" mode="bracketize-inner">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:variable name="current-bracket" as="xs:integer?" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info($current-bracket)"/>
    <xsl:choose>
      <!-- filter out the last ref in this bracket -->
      <xsl:when test="$current-bracket and map:get($bracket-info, 'kind') eq 'bracketed' and . = $bracket-info('refs')[last()]"/>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" as="xs:integer*" select="$open"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    <xsl:variable name="current-node" select="."/>
    <xsl:if test="not($current-pair) or $current-pair eq $open[last()]">
      <xsl:choose>
        <!-- wrap (by default) in all open brackets, or whatever brackets we specify to wrap -->
        <xsl:when test="count($wrapping) gt 0">
          <!-- go from innermost to outermost bracket (if $wrapping specified, only those brackets, otherwise all) -->
          <xsl:iterate select="reverse($wrapping)">
            <!-- the thing initially being wrapped is the text of the <text> node -->
            <xsl:param name="wrapped">
              <xsl:apply-templates select="$current-node/(self::node(), following-sibling::node()[self::text] except $current-node/following-sibling::node()[not(self::text)][1]/following-sibling::node())" mode="bracketize-inner"/>
            </xsl:param>
            
            <xsl:on-completion select="$wrapped"/>
            
            <xsl:variable name="current-pair" select="."/>
            <xsl:variable name="bracket-info" select="local:get-bracket-info($current-pair)"/>
            
            <xsl:next-iteration>
              <xsl:with-param name="wrapped">
                <xsl:choose>
                  <!-- if this bracket pair should become <bracketed> ... -->
                  <xsl:when test="$bracket-info('kind') eq 'bracketed'">
                    <!-- ...wrap whatever is to be wrapped in <bracketed> with this pair's first <ref>'s idref... -->
                    <bracketed idref="{$bracket-info('refs')[last()]/@idref}">
                      <xsl:sequence select="$wrapped"/>
                      <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::text)][1]" mode="bracketize">
                        <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                        <xsl:with-param name="wrapping" select="()"/>
                        <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                      </xsl:apply-templates>
                    </bracketed>
                    <!-- ...and finally process *any following sibling close bracket** that closes the current pair -->
                    <xsl:apply-templates
                      select="$current-node/following-sibling::node()/self::bracket[@type='close' and @closes-pair = $current-pair]" mode="bracketize">
                      <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                      <xsl:with-param name="wrapping" select="()"/>
                    </xsl:apply-templates>
                    <xsl:apply-templates
                      select="$current-node/following-sibling::node()/self::bracket[@type='close' and @closes-pair = $current-pair]/following-sibling::node()[1]" mode="bracketize">
                      <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
                      <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                      <xsl:with-param name="wrapping" select="()"/>
                      <xsl:with-param name="current-pair" select="$open[last() - 1]" tunnel="yes"/>
                    </xsl:apply-templates>
                  </xsl:when>
                  
                  <!-- if this bracket pair should not become <bracketed> (i.e. to go in raw, or be shucked)... -->
                  <xsl:otherwise>
                    <!-- ...output whatever would otherwise have been wrapped... -->
                    <xsl:sequence select="$wrapped"/>
                    <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::text)][1]" mode="bracketize">
                      <xsl:with-param name="wrapping" select="()"/>
                      <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                    </xsl:apply-templates>
                    <!-- ...and finally process **any following sibling close bracket** that closes the current pair ;
                    the idea is that if brackets ABC are open and then this node has "text]C more]B text]A text" then
                    this code will produce A[B[C[text]C more]B text]A text -->
                    <xsl:apply-templates
                      select="$current-node/following-sibling::node()/self::bracket[@type='close' and @closes-pair = $current-pair]/following-sibling::node()[1]" mode="bracketize">
                      <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
                      <xsl:with-param name="wrapping" select="()"/>
                      <xsl:with-param name="current-pair" select="$open[last() - 1]" tunnel="yes"/>
                    </xsl:apply-templates>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:with-param>
            </xsl:next-iteration>
          </xsl:iterate>
        </xsl:when>
        
        <!-- if no open brackets, or we've specified to wrap in no brackets, then don't wrap... -->
        <xsl:otherwise>
          <!-- ...output whatever text is within this <text> node... -->
          <xsl:sequence select="$current-node/text()"/>
          <!-- ...and just process any immediately following node -->
          <xsl:apply-templates select="$current-node/following-sibling::node()[1]" mode="bracketize"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="bracket[@type='open']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    <xsl:param name="wrapping" select="$open"/>
    <xsl:variable name="opens-pair" as="xs:integer" select="@opens-pair"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info($opens-pair)"/>
    <xsl:if test="not($current-pair) or $current-pair = $open[last()]">
      <!-- if "raw", just output the text of the bracket -->
      <xsl:if test="$bracket-info('kind') eq 'raw'">
        <xsl:value-of select="."/>
      </xsl:if>
      <xsl:apply-templates select="following-sibling::node()[1]" mode="bracketize">
        <xsl:with-param name="open" as="xs:integer*" select="($open, $opens-pair)" tunnel="yes"/>
        <xsl:with-param name="wrapping" select="($wrapping, $opens-pair)"/>
        <xsl:with-param name="current-pair" as="xs:integer?" select="$opens-pair" tunnel="yes"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="bracket[@type='close']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" select="$open"/>
    <xsl:variable name="current-pair" as="xs:integer" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info(@closes-pair)"/>
    <xsl:if test="$bracket-info('kind') eq 'raw'">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="node()" mode="bracketize" priority="-1"/>
  
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
    
    <xsl:message expand-text="yes">input is {serialize($input, map{'method':'adaptive'})}, pos is {$position}, last is {$last}</xsl:message>
    
    <!--<xsl:message expand-text="yes">p-b input: {serialize($input,map{'method':'adaptive'})}</xsl:message>-->
    <!--<xsl:message expand-text="yes">accumulated nodes: {serialize($accumulated-nodes,map{'method':'adaptive'})}</xsl:message>-->
      
    <xsl:choose>
      <!-- if input sequence exhausted, we've reached the end of the text() node -->
      <xsl:when test="not($input)">
        <xsl:variable name="current-node">
          <node>
            <xsl:sequence select="$accumulated-nodes"/>
          </node>
        </xsl:variable>
        <xsl:variable name="output" as="map(*)" 
          select="map{'open': $open, 'last-opened': $last-opened, 'current-node': $current-node, 'within-bracket': $within-bracket}"/>
        <xsl:message expand-text="yes">p-b end = {serialize($output, map{'method':'adaptive'})}</xsl:message>
        <xsl:sequence select="$output"/>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:variable name="ctx" select="head($input)"/>
        
        <xsl:for-each select="$ctx">
          <xsl:choose>
            <!-- if the bracket is at start/end of text node and has bignore next to it, just output it as text -->
            <xsl:when
          test="self::bracket and (
          ($position eq 1 and $preceding-bignore) or
          ($position eq $last and $following-bignore)
          )">
              <xsl:variable name="new-text-node" as="node()">
                <text><xsl:value-of select="."/></text>
              </xsl:variable>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="accumulated-nodes" tunnel="yes" select="($accumulated-nodes, $new-text-node)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::bracket[@type='open']">
              <xsl:variable name="new-bracket-pair" as="xs:integer" select="$last-opened + 1"/>
              <!--<xsl:message expand-text="yes">new-bracket-pair: {$new-bracket-pair}</xsl:message>-->
              <xsl:variable name="new-bracket" as="node()">
                <bracket opens-pair="{$new-bracket-pair}">
                  <xsl:apply-templates select="@*"/>
                  <xsl:value-of select="."/>
                </bracket>
              </xsl:variable>
              <!--<xsl:message expand-text="yes"
                >new bracket is kind {local:node-kind($new-bracket)}, val: {serialize($new-bracket,map{'method':'adaptive'})}</xsl:message>-->
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
            
            <xsl:when test="self::bracket[@type='close']">
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
              <!--<xsl:message expand-text="yes"
                >new bracket is kind {local:node-kind($new-bracket)}, val: {serialize($new-bracket,map{'method':'adaptive'})}</xsl:message>-->
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*" tunnel="yes"
                  select="($accumulated-nodes, $new-bracket)"/>
                <xsl:with-param name="position" as="xs:integer" select="$position + 1"/>
                <xsl:with-param name="last" select="$last"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::text">
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
  
  <!--<xsl:function name="local:node-kind" as="xs:string*">
    <xsl:param name="nodes" as="node()*"/>
    
    <xsl:sequence select="
      for $node in $nodes
      return
      if ($node instance of element()) then 'element'
      else if ($node instance of attribute()) then 'attribute'
      else if ($node instance of text()) then 'text'
      else if ($node instance of document-node()) then 'document-node'
      else if ($node instance of comment()) then 'comment'
      else if ($node instance of processing-instruction())
      then 'processing-instruction'
      else 'unknown'
      "/>
  </xsl:function>-->
  
  <xsl:function name="local:process-brackets" as="node()*">
    <xsl:param name="input" as="xs:string"/>
    <xsl:analyze-string select="$input" regex="[\[\]\(\)]">
      <xsl:matching-substring>
        <xsl:variable name="temp" as="node()">
          <bracket>
            <xsl:attribute name="type" select="if (. = ('[', '(')) then 'open' else 'close'"/>
            <xsl:attribute name="shape" select="if (. = ('[', ']')) then 'square' else 'round'"/>
            <xsl:value-of select="."/>
          </bracket>
        </xsl:variable>
        <!--<xsl:message expand-text="yes"
          >cnb matching-substring: {serialize($temp, map{'output':'adaptive'})}</xsl:message>-->
        <xsl:sequence select="$temp"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:variable name="temp" as="node()">
          <text><xsl:value-of select="."/></text>
        </xsl:variable>
        <!--<xsl:message expand-text="yes"
          >cnb non-matching-substring: {serialize($temp, map{'output':'adaptive'})}</xsl:message>-->
        <xsl:sequence select="$temp"/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
</xsl:stylesheet>