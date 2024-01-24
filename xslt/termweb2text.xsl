<!--

Purpose:
  Converts a TermWeb export file into text output that can be
  consumed by Vale


Call:
  $ xsltproc -param write-internal "P" -o tbx.txt termweb2text.xsl tbx.xml

  Pass either "true()" or "false()" for "P".

Parameters:
  * lang (default 'en-us'): which language to select
  * sep (default '|'): the separator to include between each preferred term
  * sep2 (default ': '): the separator to include between a non-recommended term(s)
    and recommended terms
  * write-internal (default false): write the internal format (="true()") or not (="false()")
  * filename (default 'termweb-simplified.xml'): the filename that is used to write
    the internal format. This is only needed for debugging purpose.

Input:
  A TermWeb export file (tbx.xml) which has the following structure:

  <martif type="TBX" xml:lang="en">
    <martifHeader> ... </martifHeader>
    <text>
        <body>
            <termEntry id="c147">
                <langSet xml:lang="en-us">
                    <tig id="c147-1">
                        <term>application</term>
                        <termNote id="c147-1-f0" type="administrativeStatus">preferred</termNote>
                        <termNote id="c147-1-f1" type="termType">fullForm</termNote>
                    </tig>
                    <tig id="c147-2">
                        <term>app</term>
                        <termNote id="c147-2-f0" type="administrativeStatus">preferred</termNote>
                        <termNote id="c147-2-f1" type="termType">abbreviation</termNote>
                    </tig>
                    ... more tig elements ...
                </langSet>
            </termEntry>
            ... more termEntry elements ...
        </body>
    </text>
  </martif>


Output:
  Text which contains the syntax:

  not_recommended_term1|not_recommended_term2: recommended1|recommended2|...


Internal format:
  The internal format is solely for the purpose to make transformation easier.
  The previous entry from above is transformed into this structure:

  <terms>
    <termentry id="c147">
        <entry id="c147-1" type="fullForm" status="preferred">application</entry>
        <entry id="c147-2" type="abbreviation" status="preferred">app</entry>
        <entry id="c147-3" type="fullForm" status="admitted">application program</entry>
        <entry id="c147-4" type="fullForm" status="admitted">software application</entry>
        <entry id="c147-5" type="fullForm" status="admitted">application software</entry>
    </termentry>
    ... more termentry elements ...
  </terms>


Design:
  Currently, the stylesheet contains the following steps:

  1. Create an intermediate, temporary tree in memory. This is done in the
     mode="copy" templates. This temporary tree contains a simplified version
     of the TermWeb export.
  2. If parameter $write-internal is set to true(), the intermediate tree
     is written to a file. This is only needed when you want to debug things.
     If the parameter is false(), writing is skipped.
     This part works only, if your XSLT processor supports the EXSLT extensions.
     This is currently the case for xsltproc.
  3. Apply the temporary tree and create the text output.


Author:
  Tom Schraitle, 2023

-->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exsl="http://exslt.org/common"
  extension-element-prefixes="exsl"
  exclude-result-prefixes="exsl">

  <xsl:output omit-xml-declaration="yes" indent="no" method="text"/>
  <xsl:strip-space  elements="*"/>


<!-- =====================
     Parameters
-->
  <xsl:param name="lang" select="'en-us'"/>
  <xsl:param name="sep" select="'|'"/>
  <xsl:param name="sep2" select="': '"/>
  <xsl:param name="write-internal" select="false()"/>
  <xsl:param name="filename">termweb-simplified.xml</xsl:param>
  <xsl:param name="skip-debug-msg" select="false()"/>

<!-- =====================
     Templates in "copy" mode: converts TermWeb format into a simplified format

     All these templates are in mode="copy" to distinguish them from
     normal templates (without a mode)
-->
    <xsl:template match="node()" mode="copy">
       <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:apply-templates mode="copy"/>
       </xsl:copy>
    </xsl:template>

  <xsl:template match="/" mode="copy">
    <terms version="{martif/martifHeader[1]/fileDesc[1]/sourceDesc[1]/p[2]}">
      <xsl:apply-templates mode="copy"/>
    </terms>
  </xsl:template>

   <xsl:template match="martifHeader" mode="copy"/>

   <xsl:template match="termEntry" mode="copy">
      <termentry id="{@id}">
        <xsl:apply-templates mode="copy"/>
      </termentry>
   </xsl:template>

  <!-- We "sort" any terms that are preferred over admitted (order) -->
  <xsl:template match="langSet" mode="copy">
    <!--<xsl:message>
      Term: <xsl:value-of select="term"/>
      preferred: <xsl:value-of select="count(tig[termNote[@type='administrativeStatus'] = 'preferred'])"/>
      admitted: <xsl:value-of select="count(tig[termNote[@type='administrativeStatus'] = 'admitted'])"/>
    </xsl:message>-->

    <xsl:apply-templates select="tig[termNote[@type='administrativeStatus'] = 'notRecommended']" mode="copy"/>
    <xsl:apply-templates select="tig[termNote[@type='administrativeStatus'] = 'preferred']" mode="copy"/>
    <xsl:apply-templates select="tig[termNote[@type='administrativeStatus'] = 'admitted']" mode="copy"/>
  </xsl:template>

   <xsl:template match="tig" mode="copy">
     <xsl:choose>
       <xsl:when test="descrip[@type='valeRegex'] = 'dontshow'">
         <xsl:if test="$skip-debug-msg">
           <xsl:message>Skip <xsl:value-of select="@id"/>. </xsl:message>
        </xsl:if>
       </xsl:when>
       <xsl:otherwise>
        <entry id="{@id}" type="{termNote[@type='termType']}"
          status="{termNote[@type='administrativeStatus']}">
          <xsl:choose>
            <xsl:when test="descrip[@type='valeRegex']">
              <xsl:apply-templates select="descrip[@type='valeRegex']" mode="copy" />
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="term" mode="copy" />
            </xsl:otherwise>
          </xsl:choose>
        </entry>
       </xsl:otherwise>
     </xsl:choose>
   </xsl:template>

  <xsl:template match="tig/term" mode="copy">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>


<!-- =====================
     Write internal format if parameter $write-internal is true and $filename is set
-->
    <xsl:template name="write-internal-format">
        <xsl:param name="content"/>
        <xsl:if test="$write-internal and not(element-available('exsl:document'))">
            <xsl:message terminate="yes">
                <xsl:text>ERROR: exsl extension is not available for </xsl:text>
                <xsl:value-of select="system-property('xsl:vendor')"/>
                <xsl:text>. Cannot write simplified file.</xsl:text>
            </xsl:message>
        </xsl:if>
        <xsl:if test="$write-internal and $filename != ''">
            <exsl:document href="{$filename}" method="xml" encoding="UTF-8" indent="yes">
                <xsl:copy-of select="$content"/>
            </exsl:document>
        </xsl:if>
   </xsl:template>


<!-- =====================
     Templates for converting internal, simplified format into text
-->
    <xsl:template match="/">
      <xsl:variable name="doc">
        <xsl:apply-templates select="." mode="copy"/>
      </xsl:variable>
      <xsl:variable name="rtf-doc" select="exsl:node-set($doc)"/>
      <xsl:call-template name="write-internal-format">
         <xsl:with-param name="content" select="$doc"/>
      </xsl:call-template>

      <xsl:message>Found <xsl:value-of
        select="count($rtf-doc/*)"/> root element named <xsl:value-of select="name($rtf-doc/*)"/>
      </xsl:message>
      <xsl:apply-templates select="$rtf-doc/*" />
    </xsl:template>

    <xsl:template match="termentry">
        <xsl:variable name="notrecommended" select="entry[@status='notRecommended']"/>
        <xsl:variable name="allentries" select="entry"/>
        <xsl:variable name="entries"
                      select="$allentries[count(. | $notrecommended) != count($notrecommended)]"/>

         <!--<xsl:message>termentry
    allentries = <xsl:value-of select="count($allentries)"/>
    notrecommended = <xsl:value-of select="count($notrecommended)"/>
    entries = <xsl:value-of select="count($entries)"/>
        </xsl:message>-->

        <xsl:choose>
           <xsl:when test="count($notrecommended) >0">
                <xsl:variable name="terms" select="$entries[@status='preferred'] | $entries[@status='admitted']"/>
                <xsl:message>Found term <xsl:value-of select="concat('&quot;', $notrecommended[1], 
                  '&quot;:')"/> <xsl:for-each select="$terms">
                    <xsl:value-of select="." />
                    <xsl:if test="position() != last()">
                      <xsl:value-of select="$sep" />
                    </xsl:if>
                  </xsl:for-each>
                </xsl:message>
                <xsl:message></xsl:message>
                <xsl:for-each select="$notrecommended">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">
                        <xsl:value-of select="$sep"/>
                    </xsl:if>
                </xsl:for-each>
                <xsl:value-of select="$sep2"/>
                 <!-- ================= -->
                <xsl:for-each select="$terms">
                    <xsl:value-of select="." />
                    <xsl:if test="position() != last()">
                      <xsl:value-of select="$sep" />
                    </xsl:if>
                </xsl:for-each>
                <xsl:text>&#10;</xsl:text>
           </xsl:when>
           <xsl:otherwise>
             <xsl:if test="$skip-debug-msg">
               <xsl:message>Skip termentry/@id=<xsl:value-of select="@id"/>. </xsl:message>
             </xsl:if>
           </xsl:otherwise>
        </xsl:choose>

    </xsl:template>

</xsl:stylesheet>
