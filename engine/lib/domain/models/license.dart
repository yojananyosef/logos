// Domain: license classification and the legal state of a resource.
//
// These types exist because licensing is not metadata — it is the field that decides
// whether a resource may be shipped at all. Keeping it in the domain layer (rather than
// in a build script) means the application can refuse to display content it must not.

/// A licence class as declared by a catalog manifest.
enum LicenseKind {
  publicDomain,
  cc0,
  ccBy('CC-BY'),
  ccBySa('CC-BY-SA'),
  ccByNc('CC-BY-NC'),
  proprietary;

  const LicenseKind([this.spdxSuffix = '']);

  /// The value written in `manifest.json`.
  final String spdxSuffix;

  static LicenseKind parse(String raw) {
    final v = raw.trim();
    for (final k in LicenseKind.values) {
      if (k.spdxSuffix.toLowerCase() == v.toLowerCase()) return k;
    }
    if (v.toLowerCase() == 'publicdomain') return LicenseKind.publicDomain;
    throw FormatException('unknown license "$raw"');
  }

  /// True when the licence obliges the redistributor to carry attribution.
  bool get requiresAttribution => switch (this) {
        LicenseKind.publicDomain || LicenseKind.cc0 => false,
        _ => true,
      };

  /// True when derivatives inherit an obligation to release under the same terms.
  ///
  /// Contagious: one such resource taints any catalog containing it. This is why the
  /// build refuses to mix share-alike content into a closed-distribution target.
  bool get isShareAlike =>
      this == LicenseKind.ccBySa || this == LicenseKind.ccByNc;

  /// True when commercial redistribution is forbidden.
  bool get forbidsCommercialUse => this == LicenseKind.ccByNc;
}

/// The licensing facts declared for one resource.
class LicenseInfo {
  const LicenseInfo({
    required this.kind,
    required this.attribution,
    required this.sourceUrl,
    required this.releaseDate,
    required this.jurisdictions,
    this.basis,
  });

  /// Unresolved when a resource carries no recognised licence. Such a resource is
  /// never distributable.
  final LicenseKind? kind;

  /// Mandatory when [LicenseKind.requiresAttribution]. Empty otherwise.
  final String attribution;

  final String sourceUrl;

  /// Earliest date this resource may be distributed, as `YYYY-MM-DD`.
  ///
  /// Public-domain works use a sentinel well in the past rather than null, so the
  /// comparison stays total and the manifest has no optional release field.
  final DateTime releaseDate;

  /// ISO-3166 alpha-2 codes the resource is cleared for. Empty means worldwide.
  final Set<String> jurisdictions;

  /// Why the resource is permissible: an expiry analysis or a dedication.
  final String? basis;

  static final DateTime _epoch = DateTime.utc(1970);

  factory LicenseInfo.publicDomain({
    required String sourceUrl,
    String? basis,
  }) =>
      LicenseInfo(
        kind: LicenseKind.publicDomain,
        attribution: '',
        sourceUrl: sourceUrl,
        releaseDate: _epoch,
        jurisdictions: const {},
        basis: basis,
      );

  bool get isResolved => kind != null;

  bool isDistributable({required DateTime now}) {
    if (kind == null) return false;
    if (!releaseDate.isAtSameMomentAs(_epoch) && now.isBefore(releaseDate)) {
      return false;
    }
    return true;
  }

  /// Whether this resource may be redistributed for commercial use in [country].
  bool allowsCommercialUseIn(String country) {
    if (kind == null) return false;
    if (kind!.forbidsCommercialUse) return false;
    if (jurisdictions.isEmpty) return true;
    return jurisdictions.contains(country.toUpperCase());
  }

  LicenseInfo copyWith({String? attribution}) => LicenseInfo(
        kind: kind,
        attribution: attribution ?? this.attribution,
        sourceUrl: sourceUrl,
        releaseDate: releaseDate,
        jurisdictions: jurisdictions,
        basis: basis,
      );

  @override
  String toString() =>
      'LicenseInfo(${kind?.name ?? 'UNRESOLVED'}, release=$releaseDate)';
}
