<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:local="local:"
  exclude-result-prefixes="xs map local"
  version="3.0">
 
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
  
  <xsl:mode use-accumulators="brackets-paired"/>
  
  <xsl:variable name="within-bracket-map" as="map(*)">
    <xsl:sequence select="accumulator-after('brackets-paired')('within-bracket')"/>
  </xsl:variable>
  
  <!-- The standard template is adapted so it processes each node one by one.
       This allows us to later control which text node will get output within each bracket. -->
  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <!-- process the first child node -->
      <xsl:apply-templates select="node()[1]"/>
    </xsl:copy>
    <!-- process the first following sibling node -->
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>
  
  <!-- We don't want to output processing instructions into the final document -->
  <xsl:template match="processing-instruction()" priority="+1">
    <!-- skip to the next node -->
    <xsl:apply-templates select="following-sibling::node()[1]"/>
  </xsl:template>
  
  <xsl:template match="text()|ref" priority="+1">
    <xsl:param name="accumulated-node" as="node()?" select="()"/>
    <!-- Keep track of which brackets are open (by default those open just after descent into
         the preceding sibling, or just before descent into the parent if no preceding sibling -->
    <xsl:param name="open" as="xs:integer*">
      <xsl:choose>
        <!-- Ignore text() nodes not within a para -->
        <xsl:when test="not(ancestor::para)"/>
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
      <node>
        <xsl:sequence select="$accumulated-node/node()"/>
        <xsl:choose>
          <xsl:when test="self::text()">
            <!-- Include the <text>/<bracket> version of this text node, instead of the original -->
            <xsl:sequence select="accumulator-after('brackets-paired')('current-node')/node()"/>
          </xsl:when>
          <xsl:when test="self::ref">
            <!-- Just include the <ref> directly -->
            <xsl:sequence select="."/>
          </xsl:when>
        </xsl:choose>
      </node>
    </xsl:variable>

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
        <xsl:copy>
          <xsl:copy-of select="@*"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text|ref" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" as="xs:integer*" select="$open"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    
    <xsl:variable name="current-node" select="."/>
    
    <xsl:if test="not($current-pair) or $current-pair eq $open[last()]">
      <xsl:variable name="to-be-output" as="node()*">
        <xsl:variable name="contiguous-text-and-refs" as="node()+">
          <xsl:sequence select="$current-node"/>
          <xsl:sequence select="$current-node/following-sibling::node()[self::text or self::ref] except $current-node/following-sibling::node()[not(self::text or self::ref)][1]/following-sibling::node()"/>
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
                    <bracketed idref="{$bracket-info('refs')[last()]/@idref}">
                      <xsl:sequence select="$wrapped"/>
                      <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::text or self::ref)][1]/self::bracket[@type='open']" mode="bracketize">
                        <xsl:with-param name="wrapping" select="()"/>
                        <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                      </xsl:apply-templates>
                    </bracketed>
                  </xsl:when>
                  <xsl:otherwise>
                    <!-- ...output whatever would otherwise have been wrapped... -->
                    <xsl:sequence select="$wrapped"/>
                    <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::text or self::ref)][1]/self::bracket[@type='open']" mode="bracketize">
                      <xsl:with-param name="wrapping" select="()"/>
                      <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                    </xsl:apply-templates>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:apply-templates
                  select="$current-node/following-sibling::node()/self::bracket[@type='close' and @closes-pair = $current-pair]" mode="bracketize">
                  <xsl:with-param name="current-pair" select="$current-pair" tunnel="yes"/>
                </xsl:apply-templates>
                <xsl:apply-templates
                  select="$current-node/following-sibling::node()/self::bracket[@type='close' and @closes-pair = $current-pair]/following-sibling::node()[1]" mode="bracketize">
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
          <xsl:apply-templates select="$current-node/following-sibling::node()[not(self::text or self::ref)][1]" mode="bracketize"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="bracket[@type='open']" mode="bracketize">
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
  
  <xsl:template match="bracket[@type='close']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="current-pair" as="xs:integer?" select="$open[last()]" tunnel="yes"/>
    <xsl:if test="not($current-pair) or $current-pair = $open[last()]">
      <xsl:if test="local:get-bracket-info(@closes-pair)('kind') eq 'raw'">
        <xsl:value-of select="."/>
      </xsl:if>
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
      
    <xsl:choose>
      <!-- if input sequence exhausted, we've reached the end of the text() node -->
      <xsl:when test="not($input)">
        <xsl:variable name="current-node" as="node()">
          <node>
            <xsl:sequence select="$accumulated-nodes"/>
          </node>
        </xsl:variable>
        <xsl:sequence
          select="map{'open': $open, 'last-opened': $last-opened, 'current-node': $current-node, 'within-bracket': $within-bracket}"/>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:for-each select="head($input)">
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
              <xsl:variable name="new-bracket" as="node()">
                <bracket opens-pair="{$new-bracket-pair}">
                  <xsl:apply-templates select="@*"/>
                  <xsl:value-of select="."/>
                </bracket>
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
        <bracket>
          <xsl:attribute name="type" select="if (. = ('[', '(')) then 'open' else 'close'"/>
          <xsl:attribute name="shape" select="if (. = ('[', ']')) then 'square' else 'round'"/>
          <xsl:value-of select="."/>
        </bracket>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <text><xsl:value-of select="."/></text>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
</xsl:stylesheet>