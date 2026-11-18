Name:       verdanditeam-branding
Version:    0.1.0
Release:    1
Summary:    VerdandiTeam Settings pages and browser content
License:    BSD-3-Clause and Proprietary and MPLv2.0
Source0:    %{name}-%{version}.tar.gz
Requires:   jolla-settings-system >= 1.2.95
Requires:   qt5-qtdeclarative-import-folderlistmodel
Requires:   sailfish-content-graphics
Provides:   sailfish-content-browser
Conflicts:  sailfish-content-browser-default
Obsoletes:  sailfish-content-browser-default
Obsoletes:  sailfish-content-browser-verdanditeam <= 1.0
Obsoletes:  verdanditeam-settings-battery <= 0.1.0

%define settingsdir %{_datadir}/jolla-settings
%define browsercontentdir %{_libdir}/mozembedlite/chrome/embedlite/content

%description
VerdandiTeam branding for Sailfish OS devices:

Settings → System → Battery is extended with charge/discharge rate, time
remaining, battery health, cycle count and charger details, read from
/sys/class/power_supply.

Settings → System → Temperatures shows the device's thermal sensors with
per-device labels, grouped by component, against their throttling limits.

Sailfish Browser gets VerdandiTeam bookmarks and search engines.

No files of jolla-settings-system are touched; removing this package brings
the stock Battery page back.

%prep
%setup -q

%build

%install
install -d %{buildroot}%{settingsdir}/pages/verdanditeam-battery
install -m 0644 settings/battery/*.qml settings/battery/*.js %{buildroot}%{settingsdir}/pages/verdanditeam-battery/
install -d %{buildroot}%{settingsdir}/pages/verdanditeam-thermal
install -m 0644 settings/thermal/*.qml %{buildroot}%{settingsdir}/pages/verdanditeam-thermal/
install -d %{buildroot}%{settingsdir}/entries
install -m 0644 settings/entries/*.json %{buildroot}%{settingsdir}/entries/

install -d %{buildroot}%{browsercontentdir}
install -m 0644 browser/search-engines/*.xml %{buildroot}%{browsercontentdir}/
install -d %{buildroot}%{_datadir}/sailfish-browser/default-content
install -m 0644 browser/default-content/bookmarks.json %{buildroot}%{_datadir}/sailfish-browser/default-content/

%files
%{settingsdir}/pages/verdanditeam-battery
%{settingsdir}/pages/verdanditeam-thermal
%{settingsdir}/entries/verdanditeam-battery.json
%{settingsdir}/entries/verdanditeam-thermal.json
%{browsercontentdir}/*.xml
%dir %{_datadir}/sailfish-browser/default-content
%{_datadir}/sailfish-browser/default-content/bookmarks.json
