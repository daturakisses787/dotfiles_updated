#!/usr/bin/env python3
"""Cluster wallpapers into dynamic color groups using k-means in CIELAB space.

Reads:  themes/analysis/colors.csv
Output: JSON to stdout (groups + member mappings)
Usage:  python3 cluster-wallpapers.py [--csv PATH] [--filter-current DIR] [--k-min N] [--k-max N]

No external dependencies required (stdlib only).
"""

import argparse
import json
import math
import random
import sys
from pathlib import Path


# ============================================================================
# CSV parsing
# ============================================================================

def parse_csv(path):
    """Parse colors.csv into wallpaper dicts.

    CSV format: filename|luminance|H S L|hex1:count,hex2:count,...
    Returns: [{"file": str, "luminance": float, "colors": [(hex, count), ...]}]
    """
    wallpapers = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) < 4:
            continue
        filename = parts[0]
        try:
            luminance = float(parts[1])
        except ValueError:
            continue

        colors = []
        for entry in parts[3].split(","):
            entry = entry.strip()
            if ":" not in entry:
                continue
            hex_color, weight_str = entry.split(":", 1)
            hex_color = hex_color.strip()
            weight_str = "".join(c for c in weight_str if c.isdigit())
            if hex_color and weight_str:
                colors.append((hex_color, int(weight_str)))

        if colors:
            wallpapers.append({
                "file": filename,
                "luminance": luminance,
                "colors": colors,
            })
    return wallpapers


# ============================================================================
# Color conversion: hex -> CIELAB
# ============================================================================

def _linearize(c):
    """sRGB gamma expansion."""
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _xyz_f(t):
    """CIE XYZ to LAB helper."""
    return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116


def hex_to_lab(hex_color):
    """Convert 6-digit hex (no #) to CIELAB (L*, a*, b*)."""
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)

    rl, gl, bl = _linearize(r), _linearize(g), _linearize(b)

    # sRGB D65 matrix
    x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl
    y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl
    z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl

    # D65 white point
    fx = _xyz_f(x / 0.95047)
    fy = _xyz_f(y / 1.00000)
    fz = _xyz_f(z / 1.08883)

    L = 116 * fy - 16
    a = 500 * (fx - fy)
    b_val = 200 * (fy - fz)
    return (L, a, b_val)


def lab_to_xyz(L, a, b):
    """Convert CIELAB back to XYZ."""
    fy = (L + 16) / 116
    fx = a / 500 + fy
    fz = fy - b / 200

    def inv_f(t):
        return t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787

    x = 0.95047 * inv_f(fx)
    y = 1.00000 * inv_f(fy)
    z = 1.08883 * inv_f(fz)
    return x, y, z


def _gamma_compress(c):
    """sRGB gamma compression."""
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def lab_to_hsl(L, a, b):
    """Convert CIELAB to HSL (H: 0-360, S: 0-100, L: 0-100)."""
    x, y, z = lab_to_xyz(L, a, b)

    # XYZ to linear sRGB
    rl = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z
    gl = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z
    bl = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z

    # Clamp and gamma compress
    r = max(0.0, min(1.0, _gamma_compress(max(0.0, rl))))
    g = max(0.0, min(1.0, _gamma_compress(max(0.0, gl))))
    b_rgb = max(0.0, min(1.0, _gamma_compress(max(0.0, bl))))

    # RGB to HSL
    mx = max(r, g, b_rgb)
    mn = min(r, g, b_rgb)
    l_val = (mx + mn) / 2

    if mx == mn:
        h = 0.0
        s = 0.0
    else:
        d = mx - mn
        s = d / (2 - mx - mn) if l_val > 0.5 else d / (mx + mn)
        if mx == r:
            h = (g - b_rgb) / d + (6 if g < b_rgb else 0)
        elif mx == g:
            h = (b_rgb - r) / d + 2
        else:
            h = (r - g) / d + 4
        h *= 60

    return h, s * 100, l_val * 100


# ============================================================================
# Feature vector computation
# ============================================================================

def compute_feature_vector(wallpaper):
    """Extract the most chromatic (colorful) color from the top-5 palette.

    Returns: (L*, a*, b*)
    Uses the color with the highest chroma (distance from neutral axis in a*,b*)
    among the extracted colors. This ensures clustering groups wallpapers by their
    accent/highlight colors rather than their dominant (often neutral) background.
    """
    best_chroma = -1.0
    best_lab = (50.0, 0.0, 0.0)

    for hex_color, count in wallpaper["colors"]:
        L, a, b = hex_to_lab(hex_color)
        # Skip near-black and near-white
        if L <= 5 or L >= 95:
            continue
        chroma = math.sqrt(a * a + b * b)
        # Weight chroma by pixel count to avoid picking rare outlier colors
        weighted_chroma = chroma * math.log1p(count)
        if weighted_chroma > best_chroma:
            best_chroma = weighted_chroma
            best_lab = (L, a, b)

    return best_lab


# ============================================================================
# k-Means clustering (stdlib only)
# ============================================================================

def _euclidean(v1, v2):
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(v1, v2)))


def _kmeans_plusplus_init(points, k, rng):
    """k-means++ seeding."""
    centroids = [rng.choice(points)]
    for _ in range(k - 1):
        dists = [min(_euclidean(p, c) ** 2 for c in centroids) for p in points]
        total = sum(dists)
        if total == 0:
            centroids.append(rng.choice(points))
            continue
        r = rng.random() * total
        cumulative = 0.0
        for i, d in enumerate(dists):
            cumulative += d
            if cumulative >= r:
                centroids.append(points[i])
                break
    return centroids


def kmeans(points, k, n_restarts=10, max_iter=100, seed=42):
    """k-Means with multiple restarts and k-means++ init.

    Returns: (centroids, labels, inertia)
    """
    rng = random.Random(seed)
    best_inertia = float("inf")
    best_labels = None
    best_centroids = None
    n = len(points)
    dim = len(points[0])

    for _ in range(n_restarts):
        centroids = _kmeans_plusplus_init(points, k, rng)

        labels = [0] * n
        for _ in range(max_iter):
            # Assign
            new_labels = [
                min(range(k), key=lambda ci: _euclidean(p, centroids[ci]))
                for p in points
            ]

            # Update
            new_centroids = []
            for ci in range(k):
                members = [points[j] for j in range(n) if new_labels[j] == ci]
                if members:
                    new_centroids.append(
                        tuple(sum(c) / len(c) for c in zip(*members))
                    )
                else:
                    new_centroids.append(centroids[ci])

            if new_labels == labels and new_centroids == centroids:
                break
            labels = new_labels
            centroids = new_centroids

        inertia = sum(
            _euclidean(points[i], centroids[labels[i]]) ** 2 for i in range(n)
        )
        if inertia < best_inertia:
            best_inertia = inertia
            best_labels = labels
            best_centroids = centroids

    return best_centroids, best_labels, best_inertia


# ============================================================================
# Silhouette score
# ============================================================================

def silhouette_score(points, labels, k):
    """Average silhouette coefficient (-1 to 1, higher = better)."""
    n = len(points)
    if k <= 1 or k >= n:
        return -1.0

    scores = []
    for i in range(n):
        same = [points[j] for j in range(n) if labels[j] == labels[i] and j != i]
        if not same:
            scores.append(0.0)
            continue
        a = sum(_euclidean(points[i], p) for p in same) / len(same)

        b = float("inf")
        for c in range(k):
            if c == labels[i]:
                continue
            other = [points[j] for j in range(n) if labels[j] == c]
            if other:
                mean_dist = sum(_euclidean(points[i], p) for p in other) / len(other)
                b = min(b, mean_dist)

        denom = max(a, b)
        scores.append((b - a) / denom if denom > 0 else 0.0)

    return sum(scores) / len(scores)


# ============================================================================
# Optimal k search
# ============================================================================

def find_optimal_k(points, k_min=4, k_max=12):
    """Try k_min..k_max, return k with best silhouette score."""
    best_k = k_min
    best_score = -1.0
    best_result = None

    max_k = min(k_max, len(points) - 1)
    for k in range(k_min, max_k + 1):
        centroids, labels, inertia = kmeans(points, k)
        score = silhouette_score(points, labels, k)
        print(f"  k={k}: silhouette={score:.3f}, inertia={inertia:.1f}", file=sys.stderr)
        if score > best_score:
            best_score = score
            best_k = k
            best_result = (centroids, labels, inertia)

    return best_k, best_score, best_result


# ============================================================================
# Group naming
# ============================================================================

HUE_NAMES = [
    (15, "red"),
    (45, "orange"),
    (75, "lime"),
    (105, "green"),
    (150, "teal"),
    (195, "cyan"),
    (240, "blue"),
    (270, "indigo"),
    (300, "purple"),
    (330, "violet"),
    (360, "rose"),
]


def _hue_to_name(hue):
    """Map hue (0-360) to a color name."""
    hue = hue % 360
    for threshold, name in HUE_NAMES:
        if hue < threshold:
            return name
    return "red"


def centroid_to_name(centroid, theme_type, used_names):
    """Generate a unique descriptive name from a LAB centroid.

    Returns: name string
    """
    L_star, a_star, b_star = centroid
    h, s, l = lab_to_hsl(L_star, a_star, b_star)

    # Low saturation = achromatic
    if s < 10:
        hue_name = "neutral"
    else:
        hue_name = _hue_to_name(h)

    base_name = f"{hue_name}-{theme_type}"

    if base_name not in used_names:
        used_names.add(base_name)
        return base_name

    # Try saturation qualifier
    sat_qualifier = "deep" if s > 50 else "pale"
    qualified = f"{sat_qualifier}-{hue_name}-{theme_type}"
    if qualified not in used_names:
        used_names.add(qualified)
        return qualified

    # Numeric fallback
    n = 2
    while f"{base_name}-{n}" in used_names:
        n += 1
    name = f"{base_name}-{n}"
    used_names.add(name)
    return name


# ============================================================================
# Main
# ============================================================================

LUMINANCE_THRESHOLD = 0.45


def _cluster_subset(wallpapers, theme_type, k_min, k_max):
    """Cluster a subset of wallpapers (all dark or all light).

    Returns list of group dicts.
    """
    if not wallpapers:
        return []

    features = [compute_feature_vector(w) for w in wallpapers]

    # Need at least k_min+1 points to cluster
    effective_k_min = min(k_min, len(wallpapers) - 1)
    effective_k_max = min(k_max, len(wallpapers) - 1)
    if effective_k_min < 2:
        effective_k_min = 2
    if effective_k_max < effective_k_min:
        effective_k_max = effective_k_min

    print(f"\n  Clustering {len(wallpapers)} {theme_type} wallpapers (k={effective_k_min}..{effective_k_max})...", file=sys.stderr)
    best_k, best_score, result = find_optimal_k(features, effective_k_min, effective_k_max)
    centroids, labels, _ = result
    print(f"  Best: k={best_k}, silhouette={best_score:.3f}", file=sys.stderr)

    used_names = set()
    groups = []
    for cluster_idx in range(best_k):
        centroid = centroids[cluster_idx]
        members = [
            wallpapers[i]["file"]
            for i in range(len(wallpapers))
            if labels[i] == cluster_idx
        ]
        if not members:
            continue

        name = centroid_to_name(centroid, theme_type, used_names)
        L_star, a_star, b_star = centroid
        h, s, l = lab_to_hsl(L_star, a_star, b_star)

        groups.append({
            "name": name,
            "type": theme_type,
            "centroid_h": round(h),
            "centroid_s": round(s),
            "centroid_l": round(l),
            "size": len(members),
            "members": sorted(members),
        })

    return groups


def main():
    parser = argparse.ArgumentParser(
        description="Cluster wallpapers into dynamic color groups"
    )
    parser.add_argument(
        "--csv", default=None, help="Path to colors.csv (default: themes/analysis/colors.csv)"
    )
    parser.add_argument(
        "--filter-current", default=None,
        help="Path to directory with current wallpapers; skip stale CSV entries"
    )
    args = parser.parse_args()

    # Resolve CSV path
    if args.csv:
        csv_path = Path(args.csv)
    else:
        csv_path = Path(__file__).resolve().parent.parent / "themes" / "analysis" / "colors.csv"

    if not csv_path.exists():
        print(f"Error: CSV not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    wallpapers = parse_csv(csv_path)
    print(f"Parsed {len(wallpapers)} wallpapers from CSV", file=sys.stderr)

    # Filter to only currently-existing wallpapers
    if args.filter_current:
        current_dir = Path(args.filter_current)
        if current_dir.exists():
            current_files = {f.name for f in current_dir.iterdir() if f.is_file()}
            wallpapers = [w for w in wallpapers if w["file"] in current_files]
            print(f"Filtered to {len(wallpapers)} current wallpapers", file=sys.stderr)

    if not wallpapers:
        print("Error: no wallpapers to cluster", file=sys.stderr)
        sys.exit(1)

    # Stage 1: Split by luminance into dark and light
    dark_wp = [w for w in wallpapers if w["luminance"] < LUMINANCE_THRESHOLD]
    light_wp = [w for w in wallpapers if w["luminance"] >= LUMINANCE_THRESHOLD]
    print(f"Split: {len(dark_wp)} dark, {len(light_wp)} light", file=sys.stderr)

    # Stage 2: Cluster each category separately by color (LAB a*, b*, L*)
    # Adaptive k ranges based on category size
    def adaptive_k(n):
        k_min = max(2, n // 25)
        k_max = max(k_min + 2, n // 10)
        return k_min, k_max

    dark_kmin, dark_kmax = adaptive_k(len(dark_wp))
    light_kmin, light_kmax = adaptive_k(len(light_wp))

    all_groups = []
    all_groups.extend(_cluster_subset(dark_wp, "dark", dark_kmin, dark_kmax))
    all_groups.extend(_cluster_subset(light_wp, "light", light_kmin, light_kmax))

    # Sort: dark first, then light, alphabetically within each
    all_groups.sort(key=lambda g: (0 if g["type"] == "dark" else 1, g["name"]))

    total_k = len(all_groups)
    output = {
        "k": total_k,
        "groups": all_groups,
    }

    json.dump(output, sys.stdout, indent=2)
    print(file=sys.stdout)

    print(f"\nTotal: {total_k} groups", file=sys.stderr)
    for g in all_groups:
        print(f"  {g['name']:<25} {g['type']:<6} {g['size']:>3} wallpapers", file=sys.stderr)


if __name__ == "__main__":
    main()
