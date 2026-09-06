/// Semantic version `major.minor.patch` (extra suffix ignored).
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _re = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?');

  static SemVer? tryParse(String? raw) {
    if (raw == null) return null;
    final m = _re.firstMatch(raw.trim());
    if (m == null) return null;
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3) ?? '0'),
    );
  }

  /// Force update when [required] bumps major or minor ahead of this build.
  /// Patch-only bumps do not force.
  bool needsForceUpdate(SemVer required) {
    if (major != required.major) return major < required.major;
    return minor < required.minor;
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is SemVer &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
