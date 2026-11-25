# Core 206 compatibility

This version accepts IPFire's Core 206 language identifiers (en, zh_CN/zh-CN, zh_TW/zh-TW) and their legacy aliases. Legacy community strings are loaded independently from the removed core language cache. Native gettext translations are preferred, with packaged legacy fallback dictionaries where necessary.

Validation: isolated Core 206 x86_64 syntax, English/Simplified/Traditional translation-resource coverage and initial CGI output checks. These checks do not claim full service connectivity, reboot, authentication or every form/error-path validation. Existing service binaries and user settings are not upgraded by this compatibility change.

Fallback dictionary source (GPL): https://git.ipfire.org/?p=ipfire-2.x.git;a=blob_plain;f=langs/en/cgi-bin/en.pl;hb=refs/tags/v2.29-core204 (with corresponding zh/tw files).
