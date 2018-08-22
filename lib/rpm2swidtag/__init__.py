
from lxml import etree
from sys import stderr
import sys

XMLNS = 'http://adelton.fedorapeople.org/rpm2swidtag'
SWID_XMLNS = 'http://standards.iso.org/iso/19770/-2/2015/schema.xsd'

class Error(Exception):
	def __init__(self, strerror):
		self.strerror = strerror

from rpm2swidtag import rpm
from rpm2swidtag import payload

def _parse_xml(file, msg):
	x = None
	try:
		x = etree.parse(file)
	except OSError as e:
		raise Error("Error reading %s [%s]: %s" % (msg, file, str(e))) from None
	except etree.XMLSyntaxError as e:
		raise Error("Error parsing %s [%s]: %s" % (msg, file, str(e))) from None
	return x

def _pass_in_hdr(ih):
	def tag_from_header(c, tag):
		if tag == 'arch' and rpm.is_source_package(ih):
			return b'src.rpm'
		try:
			return ih[tag]
		except ValueError as e:
			raise Error("Unknown header tag [%s] requested by XSLT stylesheet: %s" % (tag, str(e))) from None
		return ''
	return tag_from_header

class Tag:
	def __init__(self, xml, encoding):
		self.xml = xml
		self.encoding = encoding

	def tostring(self):
		return etree.tostring(self.xml, pretty_print=True, xml_declaration=True, encoding=self.encoding)

	def get_tagid(self):
		r = self.xml.xpath('/swid:SoftwareIdentity/@tagId', namespaces = { 'swid': SWID_XMLNS })
		return r[0]

	def get_tagcreator_regid(self):
		r = self.xml.xpath("/swid:SoftwareIdentity/swid:Entity[contains(concat(' ', @role, ' '), ' tagCreator ')]/@regid",
			namespaces = { 'swid': SWID_XMLNS })
		return r[0]

class Template:
	def __init__(self, xml_template, xslt):
		self.xml_template = _parse_xml(xml_template, "SWID template file")
		self.xslt_stylesheet = _parse_xml(xslt, "processing XSLT file")

	def generate_tag_for_header(self, rpm_header, params={}):
		ns = etree.FunctionNamespace(XMLNS)
		ns['package_tag'] = _pass_in_hdr(rpm_header)

		generate_payload = payload.SWIDPayloadExtension(rpm_header)

		try:
			transform = etree.XSLT(self.xslt_stylesheet.getroot(),
				extensions = { (XMLNS, 'generate-payload') : generate_payload })

			str_params = {}
			for i in params:
				str_params[i] = etree.XSLT.strparam(params[i])
			tag = Tag(transform(self.xml_template, **str_params), self.xml_template.docinfo.encoding)
			generate_payload.cleanup_namespaces(tag.xml.getroot())
			return tag
		# except etree.XSLTApplyError as e:
		except TypeError as e:
			raise Error("Error processing SWID tag: %s" % str(e))

