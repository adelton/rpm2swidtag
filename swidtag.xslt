<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:swid="http://standards.iso.org/iso/19770/-2/2015/schema.xsd"
  xmlns="http://standards.iso.org/iso/19770/-2/2015/schema.xsd"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:str="http://exslt.org/strings"
  xmlns:exslt="http://exslt.org/common"
  xmlns:xmlsig="http://www.w3.org/2000/09/xmldsig#"
  exclude-result-prefixes="swid"
  >

<xsl:output method="xml" omit-xml-declaration="no" indent="yes" encoding="utf-8"/>
<xsl:strip-space elements="*"/>

<xsl:param name="name" />
<xsl:param name="version" />
<xsl:param name="release" />
<xsl:param name="epoch" />
<xsl:param name="arch" />
<xsl:param name="summary" />
<xsl:param name="arch" />

<xsl:param name="tag-creator-regid"/>
<xsl:param name="tag-creator-name"/>
<xsl:param name="tag-creator-from"/>

<xsl:variable name="tag-creator-regid-v">
  <xsl:choose>
    <xsl:when test="$tag-creator-regid">
      <xsl:value-of select="$tag-creator-regid"/>
    </xsl:when>
    <xsl:when test="$tag-creator-from">
      <xsl:value-of select="document($tag-creator-from)/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' tagCreator ')]/@regid"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' tagCreator ')]/@regid"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:param name="software-creator-regid"/>
<xsl:param name="software-creator-name"/>
<xsl:param name="software-creator-from"/>
<xsl:param name="distributor-regid"/>
<xsl:param name="distributor-name"/>
<xsl:param name="distributor-from"/>
<xsl:param name="component-of"/>

<xsl:param name="preserve-signing-template"/>

<xsl:template match="/">
  <xsl:if test="not($name)">
    <xsl:message terminate="yes">Parameter name was not provided.</xsl:message>
  </xsl:if>
  <xsl:if test="not($version)">
    <xsl:message terminate="yes">Parameter version was not provided.</xsl:message>
  </xsl:if>
  <xsl:if test="not($release)">
    <xsl:message terminate="yes">Parameter release was not provided.</xsl:message>
  </xsl:if>
  <xsl:if test="not($tag-creator-regid-v)">
    <xsl:message terminate="yes">Tag creator regid could not be determined.</xsl:message>
  </xsl:if>
  <xsl:message>Tag creator regid [<xsl:value-of select="$tag-creator-regid-v"/>].</xsl:message>
  <xsl:copy>
    <xsl:choose>
      <xsl:when test="$component-of">
        <xsl:apply-templates select="node()" mode="component-of"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:copy>
</xsl:template>

<xsl:template match="node()|@*">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>

<xsl:template name="si_name_attr" match="swid:SoftwareIdentity/@name">
  <xsl:attribute name="name">
    <xsl:value-of select="$name" />
  </xsl:attribute>
</xsl:template>

<xsl:template match="swid:SoftwareIdentity">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:if test="not(@name)">
      <xsl:if test="not(@tagId)"> <xsl:call-template name="si_tagid_attr" /> </xsl:if>
      <xsl:call-template name="si_name_attr" />
      <xsl:if test="not(@version)"> <xsl:call-template name="si_version_attr" /> </xsl:if>
      <xsl:if test="not(@versionScheme)"> <xsl:call-template name="si_vs_attr" /> </xsl:if>
      <xsl:if test="not(swid:Meta)">
        <Meta>
          <xsl:call-template name="meta_product_attr" />
          <xsl:call-template name="meta_cv_attr" />
          <xsl:call-template name="meta_revision_attr" />
          <xsl:call-template name="meta_arch_attr" />
          <xsl:call-template name="meta_summary_attr" />
        </Meta>
      </xsl:if>
    </xsl:if>
    <xsl:variable name="tag-creator-needed">
      <xsl:call-template name="tag-creator-needed"/>
    </xsl:variable>
    <xsl:variable name="software-creator-needed">
      <xsl:call-template name="software-creator-needed"/>
    </xsl:variable>
    <xsl:variable name="distributor-needed">
      <xsl:call-template name="distributor-needed"/>
    </xsl:variable>
    <xsl:apply-templates select="swid:Entity">
      <xsl:with-param name="tag-creator-remove">
        <xsl:if test="exslt:node-set($tag-creator-needed)/swid:Entity">true</xsl:if>
      </xsl:with-param>
      <xsl:with-param name="software-creator-remove">
        <xsl:if test="exslt:node-set($software-creator-needed)/swid:Entity">true</xsl:if>
      </xsl:with-param>
      <xsl:with-param name="distributor-remove">
        <xsl:if test="exslt:node-set($distributor-needed)/swid:Entity">true</xsl:if>
      </xsl:with-param>
    </xsl:apply-templates>
    <xsl:choose>
      <xsl:when test="exslt:node-set($tag-creator-needed)/swid:Entity
        and exslt:node-set($software-creator-needed)/swid:Entity
        and exslt:node-set($tag-creator-needed)/swid:Entity/@regid = exslt:node-set($software-creator-needed)/swid:Entity/@regid
        and exslt:node-set($tag-creator-needed)/swid:Entity/@name = exslt:node-set($software-creator-needed)/swid:Entity/@name
	">
	<xsl:choose>
          <xsl:when test="exslt:node-set($distributor-needed)/swid:Entity
            and exslt:node-set($tag-creator-needed)/swid:Entity/@regid = exslt:node-set($distributor-needed)/swid:Entity/@regid
            and exslt:node-set($tag-creator-needed)/swid:Entity/@name = exslt:node-set($distributor-needed)/swid:Entity/@name
	    ">
	    <Entity name="{exslt:node-set($tag-creator-needed)/swid:Entity/@name}"
	      regid="{exslt:node-set($tag-creator-needed)/swid:Entity/@regid}"
	      role="tagCreator softwareCreator distributor"/>
          </xsl:when>
          <xsl:otherwise>
	    <Entity name="{exslt:node-set($tag-creator-needed)/swid:Entity/@name}"
	      regid="{exslt:node-set($tag-creator-needed)/swid:Entity/@regid}"
	      role="tagCreator softwareCreator"/>
          </xsl:otherwise>
	</xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="exslt:node-set($tag-creator-needed)/swid:Entity"/>
        <xsl:copy-of select="exslt:node-set($software-creator-needed)/swid:Entity"/>
        <xsl:copy-of select="exslt:node-set($distributor-needed)/swid:Entity"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="node()[name() != 'Entity']"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="swid:Entity">
  <xsl:param name="tag-creator-remove"/>
  <xsl:param name="software-creator-remove"/>
  <xsl:param name="distributor-remove"/>
  <xsl:variable name="role-without-tag-creator">
    <xsl:choose>
      <xsl:when test="$tag-creator-remove = 'true'">
        <xsl:value-of select="normalize-space(str:replace(concat(' ', @role, ' '), ' tagCreator ', ' '))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@role"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="role-without-software-creator">
    <xsl:choose>
      <xsl:when test="$software-creator-remove = 'true'">
        <xsl:value-of select="normalize-space(str:replace(concat(' ', $role-without-tag-creator, ' '), ' softwareCreator ', ' '))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$role-without-tag-creator"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="role">
    <xsl:choose>
      <xsl:when test="$distributor-remove = 'true'">
        <xsl:value-of select="normalize-space(str:replace(concat(' ', $role-without-tag-creator, ' '), ' distributor ', ' '))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$role-without-software-creator"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:if test="$role != ''">
    <xsl:copy>
      <xsl:apply-templates select="@*[name() != 'role']|node()"/>
      <xsl:attribute name="role">
        <xsl:value-of select="$role"/>
      </xsl:attribute>
    </xsl:copy>
  </xsl:if>
</xsl:template>

<xsl:template match="swid:Meta">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:if test="not(@product)"> <xsl:call-template name="meta_product_attr" /> </xsl:if>
    <xsl:if test="not(@colloquialVersion)"> <xsl:call-template name="meta_cv_attr" /> </xsl:if>
    <xsl:if test="not(@revision)"> <xsl:call-template name="meta_revision_attr" /> </xsl:if>
    <xsl:if test="not(@arch)"> <xsl:call-template name="meta_arch_attr" /> </xsl:if>
    <xsl:if test="not(@summary)"> <xsl:call-template name="meta_summary_attr" /> </xsl:if>
    <xsl:apply-templates select="node()"/>
  </xsl:copy>
</xsl:template>

<xsl:template name="si_version_attr" match="swid:SoftwareIdentity/@version">
  <xsl:attribute name="version">
    <xsl:if test="$epoch"><xsl:value-of select="$epoch"/>:</xsl:if>
    <xsl:value-of select="$version" />-<xsl:value-of select="$release" />
    <xsl:if test="$arch">.<xsl:value-of select="$arch"/></xsl:if>
  </xsl:attribute>
</xsl:template>

<xsl:template name="si_vs_attr" match="swid:SoftwareIdentity/@versionScheme">
  <xsl:attribute name="versionScheme">rpm</xsl:attribute>
</xsl:template>

<xsl:template name="meta_product_attr" match="swid:Meta/@product">
  <xsl:attribute name="product">
    <xsl:value-of select="$name" />
  </xsl:attribute>
</xsl:template>

<xsl:template name="meta_cv_attr" match="swid:Meta/@colloquialVersion">
  <xsl:attribute name="colloquialVersion">
    <xsl:value-of select="$version" />
  </xsl:attribute>
</xsl:template>

<xsl:template name="meta_revision_attr" match="swid:Meta/@revision">
  <xsl:attribute name="revision">
    <xsl:value-of select="$release" />
  </xsl:attribute>
</xsl:template>

<xsl:template name="nevra">
  <xsl:value-of select="$name" />
  <xsl:text>-</xsl:text>
  <xsl:if test="$epoch"><xsl:value-of select="$epoch"/>:</xsl:if>
  <xsl:value-of select="$version" />
  <xsl:if test="$release">-<xsl:value-of select="$release" /></xsl:if>
  <xsl:if test="$arch">.<xsl:value-of select="$arch"/></xsl:if>
</xsl:template>

<xsl:template name="si_tagid_value">
  <xsl:for-each select="str:tokenize($tag-creator-regid-v, '\.')">
    <xsl:sort select="position()" data-type="number" order="descending"/>
    <xsl:copy-of select="."/><xsl:text>.</xsl:text>
  </xsl:for-each>
  <xsl:call-template name="nevra"/>
</xsl:template>

<xsl:template name="si_tagid_attr" match="swid:SoftwareIdentity/@tagId">
  <xsl:attribute name="tagId">
    <xsl:call-template name="si_tagid_value"/>
  </xsl:attribute>
</xsl:template>

<xsl:template name="meta_arch_attr" match="swid:Meta/@arch">
  <xsl:if test="$arch and not($arch = 'src.rpm')">
    <xsl:attribute name="arch">
      <xsl:value-of select="$arch" />
    </xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template name="meta_summary_attr" match="swid:Meta/@summary">
  <xsl:attribute name="summary">
    <xsl:value-of select="$summary" />
  </xsl:attribute>
</xsl:template>

<xsl:template name="component_of_tagid">
  <xsl:param name="component_tagid"/>
  <xsl:for-each select="document($component-of)/swid:SoftwareIdentity/@tagId">
    <xsl:if test="$component_tagid">
      <xsl:value-of select="$component_tagid"/>
      <xsl:text>-component-of-</xsl:text>
    </xsl:if>
    <xsl:value-of select="."/>
  </xsl:for-each>
</xsl:template>

<xsl:template name="component_of_name">
  <xsl:value-of select="document($component-of)/swid:SoftwareIdentity/@name"/>
</xsl:template>

<xsl:template match="swid:SoftwareIdentity" mode="component-of">
  <xsl:copy>
    <xsl:apply-templates select="@xsi:schemaLocation"/>
    <xsl:attribute name="tagId">
      <xsl:call-template name="component_of_tagid">
        <xsl:with-param name="component_tagid">
          <xsl:call-template name="si_tagid_value" />
        </xsl:with-param>
      </xsl:call-template>
    </xsl:attribute>
    <xsl:attribute name="name">
      <xsl:call-template name="component_of_name"/>
    </xsl:attribute>
    <xsl:attribute name="supplemental">true</xsl:attribute>
    <Link rel="supplemental">
      <xsl:attribute name="href">
        <xsl:text>swid:</xsl:text>
        <xsl:call-template name="component_of_tagid" />
      </xsl:attribute>
    </Link>
    <Link rel="component">
      <xsl:attribute name="href">
        <xsl:text>swid:</xsl:text>
        <xsl:call-template name="si_tagid_value" />
      </xsl:attribute>
    </Link>
    <xsl:variable name="tag-creator-needed">
      <xsl:call-template name="tag-creator-needed"/>
    </xsl:variable>
    <xsl:copy-of select="exslt:node-set($tag-creator-needed)/swid:Entity"/>

    <xsl:apply-templates select="swid:Entity">
      <xsl:with-param name="tag-creator-remove">
        <xsl:if test="exslt:node-set($tag-creator-needed)/swid:Entity">true</xsl:if>
      </xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates select="xmlsig:Signature"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="swid:Entity" mode="component-of">
  <xsl:apply-templates select="."/>
</xsl:template>

<xsl:template match="swid:Payload" mode="component-of"/>

<xsl:template name="tag-creator-needed">
  <xsl:variable name="tag-creator-existing">
    <xsl:for-each select="swid:Entity[contains(concat(' ', @role, ' '), ' tagCreator ')][last()]">
      <Entity name="{@name}" regid="{@regid}"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="tag-creator-wanted">
    <xsl:choose>
      <xsl:when test="$tag-creator-regid">
        <Entity name="{$tag-creator-name}" regid="{$tag-creator-regid}" role="tagCreator"/>
      </xsl:when>
      <xsl:when test="$tag-creator-from">
        <xsl:for-each select="document($tag-creator-from)/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' tagCreator ')]">
          <Entity name="{@name}" regid="{@regid}" role="tagCreator"/>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:if test="exslt:node-set($tag-creator-wanted)/swid:Entity
    and not (exslt:node-set($tag-creator-wanted)/swid:Entity/@regid
      = exslt:node-set($tag-creator-existing)/swid:Entity/@regid
      and exslt:node-set($tag-creator-wanted)/swid:Entity/@name
      = exslt:node-set($tag-creator-existing)/swid:Entity/@name)">
    <xsl:copy-of select="exslt:node-set($tag-creator-wanted)/*"/>
  </xsl:if>
</xsl:template>

<xsl:template name="software-creator-needed">
  <xsl:variable name="software-creator-existing">
    <xsl:for-each select="swid:Entity[contains(concat(' ', @role, ' '), ' softwareCreator ')][last()]">
      <Entity name="{@name}" regid="{@regid}"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="software-creator-wanted">
    <xsl:choose>
      <xsl:when test="$software-creator-regid">
        <Entity name="{$software-creator-name}" regid="{$software-creator-regid}" role="softwareCreator"/>
      </xsl:when>
      <xsl:when test="$software-creator-from">
        <xsl:for-each
	select="document($software-creator-from)/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' softwareCreator ')]">
          <Entity name="{@name}" regid="{@regid}" role="softwareCreator"/>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:if test="exslt:node-set($software-creator-wanted)/swid:Entity
    and not(exslt:node-set($software-creator-wanted)/swid:Entity/@regid
      = exslt:node-set($software-creator-existing)/swid:Entity/@regid
      and exslt:node-set($software-creator-wanted)/swid:Entity/@name
      = exslt:node-set($software-creator-existing)/swid:Entity/@name)">
    <xsl:copy-of select="exslt:node-set($software-creator-wanted)/*"/>
  </xsl:if>
</xsl:template>

<xsl:template name="distributor-needed">
  <xsl:variable name="distributor-existing">
    <xsl:for-each select="swid:Entity[contains(concat(' ', @role, ' '), ' distributor ')][last()]">
      <Entity name="{@name}" regid="{@regid}"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:variable name="distributor-wanted">
    <xsl:choose>
      <xsl:when test="$distributor-regid">
        <Entity name="{$distributor-name}" regid="{$distributor-regid}" role="distributor"/>
      </xsl:when>
      <xsl:when test="$distributor-from">
        <xsl:for-each
	select="document($distributor-from)/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' distributor ')]">
          <Entity name="{@name}" regid="{@regid}" role="distributor"/>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
  </xsl:variable>
  <xsl:if test="exslt:node-set($distributor-wanted)/swid:Entity
    and not(exslt:node-set($distributor-wanted)/swid:Entity/@regid
      = exslt:node-set($distributor-existing)/swid:Entity/@regid
      and exslt:node-set($distributor-wanted)/swid:Entity/@name
      = exslt:node-set($distributor-existing)/swid:Entity/@name)">
    <xsl:copy-of select="exslt:node-set($distributor-wanted)/*"/>
  </xsl:if>
</xsl:template>

<xsl:template match="xmlsig:Signature">
  <xsl:if test="$preserve-signing-template = 'true'">
    <xsl:copy-of select="."/>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
