Summary: Example rpm package
Name: pkg1
Version: 1.3.0
Release: 1%{?dist}
License: ASL 2.0
Group: System Environment/Daemons
URL: https://www.example.com/
Source0: testfile

BuildRequires: gcc
Requires: glibc

%description
This is an example rpm package to test generating SWID tags.

%prep
%build
%install
mkdir -p %{buildroot}/usr/share/testdir/testdir2
install -m 644 %{SOURCE0} %{buildroot}/usr/share/testdir/testfile
touch %{buildroot}/usr/share/testdir/emptyfile
mkdir -p %{buildroot}/usr/share/testdir/testdir
ln -s testfile %{buildroot}/usr/share/testdir/testsymlink
ln -s testdir %{buildroot}/usr/share/testdir/testsymlink-to-dir
ln -s missing %{buildroot}/usr/share/testdir/testsymlink-to-missing
mkdir -p %{buildroot}/etc
echo "[config]" > %{buildroot}/etc/testconfig.conf
echo "křížala" > %{buildroot}/usr/share/testdir/testutf8-křížala
echo 6 > %{buildroot}/usr/share/testdir/testutf8-sqrt-$( echo $'\342\210\23236' )

%files
/usr/share/testdir/testfile
/usr/share/testdir/emptyfile
/usr/share/testdir/testdir
%config /etc/testconfig.conf
/usr/share/testdir/testsymlink*
/usr/share/testdir/testutf8*
%dir /usr/share/testdir
