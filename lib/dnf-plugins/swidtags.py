
from dnf.cli import commands

import argparse
import platform

from dnf import Plugin, rpm
from dnfpluginscore import logger
from subprocess import run, PIPE
import platform
from os import path, makedirs, environ, unlink, listdir, rmdir, symlink
import re
from rpm2swidtag import repodata

NAME = "swidtags"
RPM2SWIDTAG_COMMAND = "/usr/bin/rpm2swidtag"
SWIDQ_COMMAND = "/usr/bin/swidq"

SWIDTAG_DIR_GEN = "var/lib/swidtag"
SWIDTAG_DIR_DOWNLOAD = "usr/lib/swidtag"
SWIDTAGS_D = "etc/swid/swidtags.d"

class swidtagsCommand(commands.Command):
	aliases = [ NAME ]
	summary = "Generate SWID tag files for installed rpms"

	plugin = None

	def __init__(self, cli):
		super(swidtagsCommand, self).__init__(cli)
		for p in self.base._plugins.plugins:
			if p.name == NAME:
				self.plugin = p
				break
		if not self.plugin:
			logger.error("Internal error: cannot find the plugin from command.")
			return

	def configure(self):
		self.cli.demands.available_repos = True
		self.cli.demands.sack_activation = True
		self.cli.demands.resolving = False
		self.cli.demands.root_user = True

	@staticmethod
	def set_argparser(parser):
		subparser = parser.add_subparsers(parser_class=argparse.ArgumentParser, dest="swidtagscmd")
		subparser.add_parser("regen", help="for installed rpms, fetch SWID tags from repository metadata or generate them locally")
		subparser.add_parser("purge", help="remove all SWID tags that were locally-generated by the plugin")

	def run(self):
		if self.opts.swidtagscmd == "purge" or self.opts.swidtagscmd == "regen":
			self.plugin.purge_generated_dir()
			self.plugin.purge_generated_symlink()
		else:
			print("dnf swidtags [regen | purge]")

		if self.opts.swidtagscmd == "regen":
			ts = rpm.transaction.initReadOnlyTransaction(root=self.base.conf.installroot)
			pkgs = []
			for p in ts.dbMatch():
				# Filter out imported GPG keys
				if p["arch"]:
					pkgs.append(p)

			dirs = {}
			for r in self.base.repos.iter_enabled():
				if hasattr(r, "get_metadata_path"):
					file = r.get_metadata_path(self.plugin.METADATA_TYPE)
					if not file or file == "":
						continue
					s = repodata.Swidtags(None, file)
					tags = s.tags_for_rpm_packages(pkgs)

					remaining_pkgs = []
					for p in pkgs:
						if p not in tags:
							remaining_pkgs.append(p)
							continue
						found = False
						if isinstance(p["name"], str):
							p_nevra = "%s-%s-%s.%s" % (p["name"], p["version"], p["release"], p["arch"])
						else:
							p_nevra = b"%s-%s-%s.%s" % (p["name"], p["version"], p["release"], p["arch"])
							p_nevra = p_nevra.decode("utf-8")
						for t in tags[p]:
							logger.debug("Retrieved SWID tag from repodata for %s: %s" % (p_nevra, t.get_tagid()))
							x = t.save_to_directory(self.plugin.dir_downloaded)
							dirs[x[0]] = True
							found = True
						if not found:
							remaining_pkgs.append(p)

					pkgs = remaining_pkgs

			for d in dirs:
				self.plugin.create_swidtags_d_symlink(path.basename(d))

			if len(pkgs) > 0:
				if isinstance(p["name"], str):
					p_names = [ "%s-%s-%s.%s" % (p["name"], p["version"], p["release"], p["arch"]) for p in pkgs ]
				else:
					p_names = [ "%s-%s-%s.%s" % (p["name"].decode("utf-8"), p["version"].decode("utf-8"), p["release"].decode("utf-8"), p["arch"].decode("utf-8")) for p in pkgs ]
				if self.plugin.run_rpm2swidtag_for(p_names) == 0:
					if run(self.plugin.conf.get("main", "swidq_command").split() + ["--silent", "-p", self.plugin.dir_generated, "--rpm"] + p_names).returncode != 0:
						logger.warn("The SWID tag for rpm %s should have been generated but could not be found" % str(i))


class swidtags(Plugin):

	name = NAME
	generated_dirname = "rpm2swidtag-generated"

	METADATA_TYPE = "swidtags"

	def __init__(self, base, cli):
		super().__init__(base, cli)
		self.conf = None
		self.install_set = None
		self.remove_set = None
		self.dir_generated = path.join(base.conf.installroot, SWIDTAG_DIR_GEN, self.generated_dirname)
		self.dir_downloaded = path.join(base.conf.installroot, SWIDTAG_DIR_DOWNLOAD)
		self.swidtags_d = path.join(base.conf.installroot, SWIDTAGS_D)
		if cli:
			cli.register_command(swidtagsCommand)

	def config(self):
		super(swidtags, self).config()
		self.conf = self.read_config(self.base.conf)
		DEFAULTS = { "main": {
			"rpm2swidtag_command": RPM2SWIDTAG_COMMAND,
			"swidq_command": SWIDQ_COMMAND,
			}
		}
		for s in DEFAULTS:
			if not self.conf.has_section(s):
				try:
					self.conf.addSection(s)
				except AttributeError:
					self.conf.add_section(s)
			for o in DEFAULTS[s]:
				if not self.conf.has_option(s, o):
					try:
						self.conf.setValue(s, o, DEFAULTS[s][o])
					except AttributeError:
						self.conf.set(s, o, DEFAULTS[s][o])

		for repo in self.base.repos.iter_enabled():
			if hasattr(repo, "add_metadata_type_to_download"):
				logger.debug("Will ask for SWID tags download for " + str(repo.baseurl))
				repo.add_metadata_type_to_download(self.METADATA_TYPE)

	def resolved(self):
		self.install_set = self.base.transaction.install_set
		self.remove_set = self.base.transaction.remove_set

	def transaction(self):
		remove_packages = []
		for i in self.remove_set:
			logger.debug('Will remove SWID tag for %s' % i)
			remove_packages.append(str(i))
		if len(remove_packages) > 0:
			swidtag = run(self.conf.get("main", "swidq_command").split() + ["--silent", "-p", path.join(self.base.conf.installroot, SWIDTAGS_D, "*"), "--rpm"] + remove_packages, stdout=PIPE, encoding="utf-8")
			component_supplemental = []
			for l in swidtag.stdout.splitlines():
				m = re.search(r'^(\S+) (\S+)$', l)
				if not m:
					continue
				self.remove_file(m.group(2))
				component_supplemental.append(m.group(1) + "-component-of-*")
			if len(component_supplemental) > 0:
				component_of = run(self.conf.get("main", "swidq_command").split() + ["--silent", "-p", path.join(self.base.conf.installroot, SWIDTAGS_D, "*"), "-a"] + component_supplemental, stdout=PIPE, encoding="utf-8")
				for ll in component_of.stdout.splitlines():
					m = re.search(r'^- (\S+) (\S+)$', ll)
					if not m:
						continue
					self.remove_file(m.group(2))

		downloaded_swidtags = {}
		packages_in_repos = { None: [] }
		dirs = {}
		for i in self.install_set:
			try:
				r = i.repo
				if r not in downloaded_swidtags:
					downloaded_swidtags[r] = None
					if hasattr(r, "get_metadata_path"):
						file = r.get_metadata_path(self.METADATA_TYPE)
						if file and file != "":
							downloaded_swidtags[r] = repodata.Swidtags(None, file)
				if downloaded_swidtags[r]:
					if r not in packages_in_repos:
						packages_in_repos[r] = []
					packages_in_repos[r].append(i)
					continue
			except KeyError:
				None
			packages_in_repos[None].append(i)

		for r in packages_in_repos:
			if not r:
				continue
			tags = downloaded_swidtags[r].tags_for_repo_packages(packages_in_repos[r])
			for p in tags:
				found = False
				for t in tags[p]:
					logger.debug("Retrieved SWID tag from repodata for %s: %s" % (p, t.get_tagid()))
					x = t.save_to_directory(self.dir_downloaded)
					dirs[x[0]] = True
					found = True
				if not found:
					packages_in_repos[None].append(p)

		for d in dirs:
			self.create_swidtags_d_symlink(path.basename(d))

		if len(packages_in_repos[None]) > 0:
			p_names = [ str(p) for p in packages_in_repos[None]]
			if self.run_rpm2swidtag_for(p_names) == 0:
				completed = run(self.conf.get("main", "swidq_command").split() + ["--silent", "-p", self.dir_generated, "--rpm"] + p_names, stdout=PIPE)
				if completed.returncode != 0:
					logger.warn("The SWID tag for rpm %s should have been generated but could not be found" % str(i))
				logger.debug(str(completed.stdout, "utf-8"))

	def remove_file(self, file):
		try:
			unlink(file)
		except OSError as e:
			logger.warning("Failed to remove [%s]: %s" % (file, e))

	def purge_generated_dir(self):
		if not path.isdir(self.dir_generated):
			return
		count = 0
		for f in listdir(self.dir_generated):
			try:
				unlink(path.join(self.dir_generated, f))
				count += 1
			except OSError as e:
				logger.warning("Failed to remove [%s]: %s" % (file, e))
		try:
			rmdir(self.dir_generated)
		except OSError:
			logger.warning("Failed to remove [%s]: %s" % (self.dir_generated, e))
		if count > 0:
			logger.debug("Removed %d generated files from %s" % (count, self.dir_generated))

	def purge_generated_symlink(self):
		symlink_path = path.join(self.swidtags_d, self.generated_dirname)
		if not path.islink(symlink_path):
			return
		self.remove_file(symlink_path)

	def create_generated_dir(self):
		if not path.isdir(self.dir_generated):
			makedirs(self.dir_generated)

	def create_download_dir(self, dir):
		dir = path.join(self.dir_downloaded, dir)
		if not path.isdir(dir):
			makedirs(dir)

	def create_swidtags_d_symlink(self, basename=None):
		if basename:
			target = path.join(SWIDTAG_DIR_DOWNLOAD, basename)
		else:
			basename = self.generated_dirname
			target = path.join(SWIDTAG_DIR_GEN, basename)
		if not path.isdir(self.swidtags_d):
			makedirs(self.swidtags_d)
		src = path.join(self.swidtags_d, basename)
		if not path.islink(src):
			symlink(path.join("../../..", target), src)

	def run_rpm2swidtag_for(self, pkgs):
		if not pkgs or len(pkgs) < 1:
			return
		hostname = platform.uname()[1]
		rpm2swidtag_command = self.conf.get("main", "rpm2swidtag_command")
		logger.debug("Running %s for %s ..." % (rpm2swidtag_command, pkgs))
		env = { "_RPM2SWIDTAG_RPMDBPATH": path.join(self.base.conf.installroot, "var/lib/rpm") }
		if "PYTHONPATH" in environ:
			env["PYTHONPATH"] = environ["PYTHONPATH"]
		ret = run(rpm2swidtag_command.split() + ["--tag-creator", hostname, "--output-dir", path.join(self.dir_generated, ".")] + pkgs,
			env=env).returncode
		self.create_generated_dir()
		self.create_swidtags_d_symlink()
		return ret
