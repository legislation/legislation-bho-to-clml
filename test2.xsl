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
      <xsl:message select="'cnb (kind ' || local:node-kind($current-node-brackets) || '): ' || serialize($current-node-brackets,map{'method':'adaptive'})"/>
      <xsl:variable name="_open" select="map:get($value, 'open')"/>
      <xsl:variable name="_last-opened" select="map:get($value, 'last-opened')"/>
      <xsl:variable name="_within-bracket" select="map:get($value, 'within-bracket')"/>
      <xsl:variable name="temp" as="map(*)">
        <xsl:call-template name="process-brackets">
          <xsl:with-param name="input" select="$current-node-brackets"/>
          <xsl:with-param name="open" as="xs:integer*" select="$_open" tunnel="yes"/>
          <xsl:with-param name="last-opened" select="$_last-opened" tunnel="yes"/>
          <xsl:with-param name="within-bracket" select="$_within-bracket" tunnel="yes"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:message select="'cnb-post-temp: ' || serialize($temp,map{'method':'adaptive'})"/>
      <xsl:message expand-text="yes">kinds within cn: {for-each(map:get($temp, 'current-node'), local:node-kind#1)}</xsl:message>
      <xsl:sequence select="$temp"/>
    </xsl:accumulator-rule>
  </xsl:accumulator>
  
  <xsl:mode use-accumulators="brackets-paired"/>
  
  <xsl:variable name="within-bracket-map" as="map(*)">
    <xsl:variable name="temp" select="accumulator-after('brackets-paired')('within-bracket')"/>
    <xsl:message select="'within-bracket-map:' || serialize($temp, map{'method': 'adaptive'})"/>
    <xsl:sequence select="$temp"/>
  </xsl:variable>
  
  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="text()" priority="+1">
    <xsl:message expand-text="yes">applying for text() with cn: {serialize(accumulator-after('brackets-paired')('current-node'),map{'method':'adaptive'})}</xsl:message>
    <xsl:apply-templates select="accumulator-after('brackets-paired')('current-node')/node/node()[1]" mode="bracketize">
      <xsl:with-param name="open" as="xs:integer*" tunnel="yes">
        <xsl:for-each select="(preceding-sibling::*, parent::*)[1]">
          <xsl:sequence select="accumulator-before('brackets-paired')('open')"/>
        </xsl:for-each>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="ref" priority="+1">
    <xsl:variable name="current-bracket" as="xs:integer?" select="accumulator-after('brackets-paired')('open')[last()]"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info($current-bracket)"/>
    <xsl:choose>
      <xsl:when test="$current-bracket and map:get($bracket-info, 'kind') eq 'bracketed' and . = map:get($within-bracket-map, $current-bracket)"/>
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
    <xsl:variable name="current-node" select="."/>
    <xsl:choose>
      <!-- wrap (by default) in all open brackets, or whatever brackets we specify to wrap -->
      <xsl:when test="count($wrapping) gt 0">
        <!-- go from innermost to outermost bracket (if $wrapping specified, only those brackets, otherwise all) -->
        <xsl:iterate select="reverse($wrapping)">
          <!-- the thing initially being wrapped is the text of the <text> node -->
          <xsl:param name="wrapped" select="$current-node/text()"/>
          
          <xsl:on-completion select="$wrapped"/>
          
          <xsl:variable name="current-pair" select="."/>
          <xsl:variable name="bracket-info" select="local:get-bracket-info($current-pair)"/>
          
          <xsl:next-iteration>
            <xsl:with-param name="wrapped">
              <xsl:choose>
                <!-- if this bracket pair should become <bracketed> ... -->
                <xsl:when test="$bracket-info('kind') eq 'bracketed'">
                  <!-- ...wrap whatever is to be wrapped in <bracketed> with this pair's first <ref>'s idref... -->
                  <bracketed idref="{head($bracket-info('refs'))/@idref}">
                    <xsl:sequence select="$wrapped"/>
                    <!-- ...and if we're in the *innermost* bracket then also process any immediately following open bracket... -->
                    <xsl:if test="position() eq 1">
                      <xsl:apply-templates select="$current-node/following-sibling::*[1]/self::bracket[@type='open']" mode="bracketize">
                        <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                        <xsl:with-param name="wrapping" select="()"/>
                      </xsl:apply-templates>
                    </xsl:if>
                  </bracketed>
                  <!-- ...and finally process *any following sibling close bracket** that closes the current pair -->
                  <xsl:apply-templates
                    select="$current-node/following-sibling::*[1]/self::bracket[@type='close' and @closes-pair = $current-pair]" mode="bracketize">
                    <!-- (but don't wrap in any of the currently open brackets as we've done that here already) -->
                    <xsl:with-param name="wrapping" select="()"/>
                  </xsl:apply-templates>
                </xsl:when>
                
                <!-- if this bracket pair should not become <bracketed> (i.e. to go in raw, or be shucked)... -->
                <xsl:otherwise>
                  <!-- ...output whatever would otherwise have been wrapped... -->
                  <xsl:sequence select="$wrapped"/>
                  <!-- ...and if we're in the *innermost* bracket then also process any immediately following open bracket...
                    (any other opening brackets later should be picked up with further template match steps -->
                  <xsl:if test="position() eq 1">
                    <xsl:apply-templates select="$current-node/following-sibling::*[1]/self::bracket[@type='open']" mode="bracketize">
                      <xsl:with-param name="wrapping" select="()"/>
                    </xsl:apply-templates>
                  </xsl:if>
                  <!-- ...and finally process **any following sibling close bracket** that closes the current pair ;
                    the idea is that if brackets ABC are open and then this node has "text]C more]B text]A text" then
                    this code will produce A[B[C[text]C more]B text]A text -->
                  <xsl:apply-templates
                    select="$current-node/following-sibling::bracket[@type='close' and @closes-pair = $current-pair]" mode="bracketize">
                    <xsl:with-param name="wrapping" select="()"/>
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
        
        <!-- ...but if no open brackets yet, then process any immediately following bracket to kick off bracketing -->
        <xsl:if test="count($open) eq 0">
          <xsl:apply-templates select="$current-node/following-sibling::bracket[1]" mode="bracketize"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="bracket[@type='open']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" select="$open"/>
    <xsl:variable name="opens-pair" as="xs:integer" select="@opens-pair"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info($opens-pair)"/>
    <!-- if "raw", just output the text of the bracket -->
    <xsl:if test="$bracket-info('kind') eq 'raw'">
      <xsl:value-of select="."/>
    </xsl:if>
    <xsl:apply-templates select="following-sibling::*[1]" mode="bracketize">
      <xsl:with-param name="open" as="xs:integer*" select="($open, $opens-pair)" tunnel="yes"/>
      <xsl:with-param name="wrapping" select="($wrapping, $opens-pair)"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="bracket[@type='close']" mode="bracketize">
    <xsl:param name="open" as="xs:integer*" select="()" tunnel="yes"/>
    <xsl:param name="wrapping" select="$open"/>
    <xsl:variable name="current-pair" as="xs:integer" select="$open[last()]"/>
    <xsl:variable name="bracket-info" select="local:get-bracket-info($current-pair)"/>
    <xsl:if test="$bracket-info('kind') eq 'raw'">
      <xsl:value-of select="."/>
    </xsl:if>
    <xsl:apply-templates select="following-sibling::*[1]" mode="bracketize">
      <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
      <xsl:with-param name="wrapping" select="$wrapping[not(. = $current-pair)]"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="ref" mode="bracketize">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
    </xsl:copy>
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
    <xsl:param name="accumulated-nodes" as="node()*" select="()" tunnel="yes"/>
    <xsl:param name="within-bracket" as="map(*)" select="map{}" tunnel="yes"/>
    
    <xsl:message expand-text="yes">p-b input: {serialize($input,map{'method':'adaptive'})}</xsl:message>
    <xsl:message expand-text="yes">accumulated nodes: {serialize($accumulated-nodes,map{'method':'adaptive'})}</xsl:message>
      
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
        
        <xsl:for-each select="head($input)">
          <xsl:choose>
            <!-- if the bracket is at start/end of text node and has bignore next to it, just output it as text -->
            <!--<xsl:when
          test="self::bracket and (
          (position() eq 1 and $current-text-node/preceding-sibling::*[1]/self::processing-instruction('bignore')) or
          (position() eq last() and $current-text-node/following-sibling::*[1]/self::processing-instruction('bignore'))
          )">
          <xsl:next-iteration>
            <xsl:with-param name="accumulated-nodes">
              <xsl:sequence select="$accumulated-nodes"/>
              <text><xsl:value-of select="."/></text>
            </xsl:with-param>
          </xsl:next-iteration>
        </xsl:when>-->
            
            <xsl:when test="self::bracket[@type='open']">
              <xsl:variable name="new-bracket-pair" as="xs:integer" select="$last-opened + 1"/>
              <xsl:message expand-text="yes">new-bracket-pair: {$new-bracket-pair}</xsl:message>
              <xsl:variable name="new-bracket">
                <bracket opens-pair="{$new-bracket-pair}">
                  <xsl:apply-templates select="@*"/>
                  <xsl:value-of select="."/>
                </bracket>
              </xsl:variable>
              <xsl:message expand-text="yes"
                >new bracket is kind {local:node-kind($new-bracket)}, val: {serialize($new-bracket,map{'method':'adaptive'})}</xsl:message>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="open" as="xs:integer*" select="($open, $new-bracket-pair)" tunnel="yes"/>
                <xsl:with-param name="last-opened" as="xs:integer" select="$new-bracket-pair" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*" tunnel="yes"
                  select="($accumulated-nodes, $new-bracket)"/>
              </xsl:call-template>
            </xsl:when>
            
            <xsl:when test="self::bracket[@type='close']">
              <xsl:variable name="closing-bracket-pair" as="xs:integer" select="$open[last()]"/>
              <xsl:variable name="new-bracket">
                <xsl:copy select=".">
                  <xsl:apply-templates select="@*"/>
                  <xsl:attribute name="closes-pair" select="$closing-bracket-pair"/>
                  <xsl:value-of select="."/>
                </xsl:copy>
              </xsl:variable>
              <xsl:message expand-text="yes"
                >new bracket is kind {local:node-kind($new-bracket)}, val: {serialize($new-bracket,map{'method':'adaptive'})}</xsl:message>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
                <xsl:with-param name="open" as="xs:integer*" select="$open[position() lt last()]" tunnel="yes"/>
                <xsl:with-param name="accumulated-nodes" as="node()*" tunnel="yes"
                  select="($accumulated-nodes, $new-bracket)"/>
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
              </xsl:call-template>
            </xsl:when>
            
            <xsl:otherwise>
              <xsl:call-template name="process-brackets">
                <xsl:with-param name="input" select="tail($input)"/>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="local:node-kind" as="xs:string*">
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
  </xsl:function>
  
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
        <xsl:message expand-text="yes"
          >cnb matching-substring: {serialize($temp, map{'output':'adaptive'})}</xsl:message>
        <xsl:sequence select="$temp"/>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:variable name="temp" as="node()">
          <text><xsl:value-of select="."/></text>
        </xsl:variable>
        <xsl:message expand-text="yes"
          >cnb non-matching-substring: {serialize($temp, map{'output':'adaptive'})}</xsl:message>
        <xsl:sequence select="$temp"/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>
  
</xsl:stylesheet>