import struct, zlib, os, math

def create_icon(size, output_path):
    pixels = bytearray([0] * (size * size * 4))
    cx, cy = size / 2, size / 2
    radius = size * 0.42

    def set_pixel(x, y, r, g, b, a=255):
        x, y = int(x), int(y)
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            # Alpha blend with existing
            if a < 255:
                t = a / 255.0
                pixels[i] = int(pixels[i] * (1 - t) + r * t)
                pixels[i+1] = int(pixels[i+1] * (1 - t) + g * t)
                pixels[i+2] = int(pixels[i+2] * (1 - t) + b * t)
                pixels[i+3] = min(255, pixels[i+3] + a)
            else:
                pixels[i] = min(255, max(0, int(r)))
                pixels[i+1] = min(255, max(0, int(g)))
                pixels[i+2] = min(255, max(0, int(b)))
                pixels[i+3] = 255

    def dist(x1, y1, x2, y2):
        return ((x1-x2)**2 + (y1-y2)**2) ** 0.5

    for y in range(size):
        for x in range(size):
            d = dist(x, y, cx, cy)
            r, g, b = 0, 0, 0

            # Outside circle - transparent
            ring_outer = radius + size * 0.06
            if d > ring_outer:
                continue

            # Gold outer ring
            ring_inner = radius - size * 0.005
            if ring_inner < d <= ring_outer:
                ring_t = (d - ring_inner) / (ring_outer - ring_inner)
                gold_shade = 0.65 + 0.35 * (1 - ring_t)
                r = int(218 * gold_shade)
                g = int(185 * gold_shade)
                b = int(95 * gold_shade)
                # Subtle highlight at top
                highlight = max(0, 1 - abs(y - cy + radius * 0.3) / radius) * 0.15
                r = min(255, int(r + highlight * 255))
                g = min(255, int(g + highlight * 230))
                b = min(255, int(b + highlight * 140))
                set_pixel(x, y, r, g, b)
                continue

            # Anti-aliased circle edge
            if d > ring_inner - size * 0.008:
                alpha = int(255 * (ring_outer - d) / (size * 0.04))
                alpha = max(0, min(255, alpha))
                set_pixel(x, y, 200, 170, 90, alpha)
                continue

            # === BACKGROUND ===
            grad_t = y / size
            bg_r = int(18 * (1 - grad_t) + 8 * grad_t)
            bg_g = int(95 * (1 - grad_t) + 55 * grad_t)
            bg_b = int(75 * (1 - grad_t) + 40 * grad_t)
            edge_dark = max(0, (d / radius - 0.6) / 0.4) * 0.25
            r = int(bg_r * (1 - edge_dark))
            g = int(bg_g * (1 - edge_dark))
            b = int(bg_b * (1 - edge_dark))

            # Subtle radial light in center
            center_glow = max(0, 1 - d / (radius * 0.6)) * 0.12
            r = min(255, int(r + center_glow * 80))
            g = min(255, int(g + center_glow * 120))
            b = min(255, int(b + center_glow * 90))

            # === OPEN BOOK ===
            book_cx = cx
            book_cy = cy + size * 0.05
            book_w = size * 0.38
            book_h = size * 0.28
            spine_w = size * 0.02
            page_outline = size * 0.007

            # Left page
            lx = book_cx - book_w
            rx = book_cx + book_w
            ly = book_cy - book_h
            ry = book_cy + book_h

            in_left = (lx <= x <= book_cx - spine_w and ly <= y <= ry)
            in_right = (book_cx + spine_w <= x <= rx and ly <= y <= ry)

            if in_left or in_right:
                # Shadow near spine
                spine_dist = abs(x - book_cx) / book_w
                spine_shadow = max(0, 1 - spine_dist) * 0.2

                # Page curvature
                curve_y = ((y - book_cy) / book_h) ** 2
                curve_shadow = curve_y * 0.06

                # Base page color
                page_r = 252
                page_g = 248
                page_b = 235
                shade = 1 - spine_shadow - curve_shadow
                page_r = int(page_r * shade)
                page_g = int(page_g * shade)
                page_b = int(page_b * shade)

                # Edge darkening
                edge_y = abs(y - book_cy) / book_h
                if edge_y > 0.9:
                    et = (edge_y - 0.9) / 0.1
                    page_r = int(page_r * (1 - et * 0.25))
                    page_g = int(page_g * (1 - et * 0.2))
                    page_b = int(page_b * (1 - et * 0.15))

                # Text lines
                nlines = 6
                ls = book_h * 2 / (nlines + 1)
                for li in range(1, nlines + 1):
                    ly2 = book_cy - book_h + li * ls
                    if abs(y - ly2) < size * 0.004:
                        la = 0.45 + 0.25 * spine_dist
                        page_r = int(page_r * (1 - la) + 110 * la)
                        page_g = int(page_g * (1 - la) + 90 * la)
                        page_b = int(page_b * (1 - la) + 60 * la)

                # Gold decorative header line
                hdr_y = book_cy - book_h * 0.72
                if abs(y - hdr_y) < size * 0.006 and spine_dist > 0.15:
                    ga = 0.75
                    page_r = int(page_r * (1 - ga) + 200 * ga)
                    page_g = int(page_g * (1 - ga) + 170 * ga)
                    page_b = int(page_b * (1 - ga) + 85 * ga)

                # Small decorative diamond
                diamond_cx = book_cx + (book_w * 0.5 if in_right else -book_w * 0.5)
                diamond_cy = book_cy - book_h * 0.72
                dd = abs(x - diamond_cx) + abs(y - diamond_cy) * 2
                if dd < size * 0.02:
                    da = max(0, 1 - dd / (size * 0.02)) * 0.6
                    page_r = int(page_r * (1 - da) + 200 * da)
                    page_g = int(page_g * (1 - da) + 170 * da)
                    page_b = int(page_b * (1 - da) + 85 * da)

                r, g, b = page_r, page_g, page_b

            # Page borders
            border_color = (155, 135, 75)
            if ly - page_outline <= y <= ly + page_outline and lx <= x <= rx:
                r, g, b = border_color
            elif ry - page_outline <= y <= ry + page_outline and lx <= x <= rx:
                r, g, b = border_color
            elif (lx - page_outline <= x <= lx + page_outline and ly <= y <= ry):
                r, g, b = border_color
            elif (rx - page_outline <= x <= rx + page_outline and ly <= y <= ry):
                r, g, b = border_color
            # Spine
            elif abs(x - book_cx) < spine_w and ly <= y <= ry:
                spine_t = abs(y - book_cy) / book_h
                ss = 0.75 + 0.25 * (1 - spine_t)
                r = int(195 * ss)
                g = int(165 * ss)
                b = int(90 * ss)

            # === CRESCENT & STAR ===
            moon_cx2 = cx
            moon_cy2 = cy - size * 0.19
            moon_r = size * 0.075
            moon_off = size * 0.028

            dm = dist(x, y, moon_cx2 - moon_off, moon_cy2)
            dmi = dist(x, y, moon_cx2 + moon_off * 0.35, moon_cy2 - moon_off * 0.15)

            if dm < moon_r and dmi > moon_r * 0.72:
                ms = 0.82 + 0.18 * (y - (moon_cy2 - moon_r)) / (moon_r * 2)
                r = int(235 * ms)
                g = int(215 * ms)
                b = int(120 * ms)

            # Star
            star_cx2 = cx + size * 0.025
            star_cy2 = cy - size * 0.19
            star_r = size * 0.022
            angle = math.atan2(y - star_cy2, x - star_cx2)
            ds = dist(x, y, star_cx2, star_cy2)
            star_mod = abs(math.sin(angle * 2.5))
            star_bound = star_r * 0.4 + (star_r * 0.6) * star_mod

            if ds < star_bound:
                r, g, b = 240, 215, 120

            # === ORNAMENTAL DOTS around circle ===
            n_dots = 12
            for i in range(n_dots):
                dot_angle = (2 * math.pi * i / n_dots) - math.pi / 2
                dot_r_pos = radius + size * 0.035
                dot_x = cx + math.cos(dot_angle) * dot_r_pos
                dot_y = cy + math.sin(dot_angle) * dot_r_pos
                dot_dist = dist(x, y, dot_x, dot_y)
                if dot_dist < size * 0.008:
                    r, g, b = 200, 175, 95

            set_pixel(x, y, r, g, b)

    # Write PNG
    def write_png(filename, w, h, rgba):
        def chunk(ct, data):
            c = ct + data
            crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
            return struct.pack('>I', len(data)) + c + crc

        raw = b''
        for yy in range(h):
            raw += b'\x00' + bytes(rgba[yy * w * 4 : (yy + 1) * w * 4])

        sig = b'\x89PNG\r\n\x1a\n'
        ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        with open(filename, 'wb') as f:
            f.write(sig)
            f.write(chunk(b'IHDR', ihdr))
            f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
            f.write(chunk(b'IEND', b''))

    write_png(output_path, size, size, pixels)

# Generate all sizes
sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for density, sz in sizes.items():
    path = f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    print(f'Generating {density} ({sz}x{sz})...')
    create_icon(sz, path)
    print(f'  -> {path}')
print('All icons generated!')
