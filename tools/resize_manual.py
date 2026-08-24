import struct, json, io, pathlib
from PIL import Image

def resize_glb_manual(path, max_size=1024):
    p = pathlib.Path(path)
    print(f"\n=== {p.name} ===")
    data = p.read_bytes()
    if data[0:4] != b'glTF':
        print("  not a GLB")
        return
    version, length = struct.unpack('<II', data[4:12])
    # JSON chunk
    json_len, json_type = struct.unpack('<II', data[12:20])
    json_bytes = data[20:20+json_len]
    j = json.loads(json_bytes.decode('utf-8'))
    # BIN chunk
    bin_header_offset = 20 + json_len
    # Pad JSON to 4
    if json_len % 4 != 0:
        bin_header_offset += (4 - json_len % 4)
    if len(data) < bin_header_offset + 8:
        print("  no BIN chunk")
        return
    bin_len, bin_type = struct.unpack('<II', data[bin_header_offset:bin_header_offset+8])
    bin_offset = bin_header_offset + 8
    bin_data = data[bin_offset:bin_offset+bin_len]
    print(f"  JSON {json_len} bytes, BIN {bin_len} bytes, {len(j.get('bufferViews',[]))} bufferViews, {len(j.get('images',[]))} images")
    # Map bufferView index -> image index
    bv_to_img = {}
    for idx, img in enumerate(j.get('images',[])):
        bv = img.get('bufferView')
        if bv is not None:
            bv_to_img[bv] = idx
    # Prepare new data for each bufferView
    new_datas = {}
    for bv_idx, bv in enumerate(j.get('bufferViews',[])):
        start = bv.get('byteOffset',0)
        length = bv['byteLength']
        chunk = bin_data[start:start+length]
        if bv_idx in bv_to_img:
            img_idx = bv_to_img[bv_idx]
            img = j['images'][img_idx]
            try:
                im = Image.open(io.BytesIO(chunk))
                w,h = im.size
                print(f"  bv {bv_idx} img {img_idx} {w}x{h} {length} bytes")
                if max(w,h) > max_size:
                    scale = max_size / max(w,h)
                    nw, nh = int(w*scale), int(h*scale)
                    im2 = im.resize((nw, nh), Image.LANCZOS)
                    if im2.mode != "RGB":
                        im2 = im2.convert("RGB")
                    out = io.BytesIO()
                    im2.save(out, format="JPEG", quality=85, subsampling=0)
                    new_chunk = out.getvalue()
                    print(f"    -> {nw}x{nh} {len(new_chunk)} bytes")
                    new_datas[bv_idx] = new_chunk
                else:
                    print(f"    skip")
                    new_datas[bv_idx] = chunk
            except Exception as e:
                print(f"    PIL fail {e}")
                new_datas[bv_idx] = chunk
        else:
            new_datas[bv_idx] = chunk

    # Rebuild BIN in order of original offset (sorted)
    # Create list of (orig_offset, bv_idx)
    order = sorted(enumerate(j['bufferViews']), key=lambda x: x[1].get('byteOffset',0))
    new_bin = bytearray()
    new_offsets = {}
    for orig_idx, bv in order:
        chunk = new_datas[orig_idx]
        off = len(new_bin)
        new_offsets[orig_idx] = off
        new_bin.extend(chunk)
        # Pad to 4 bytes for next bufferView (GLB spec: bufferViews should be 4-byte aligned, but we pad each chunk)
        pad = (4 - len(chunk) % 4) % 4
        if pad:
            new_bin.extend(b'\x00'*pad)

    # Update JSON bufferViews
    for idx, bv in enumerate(j['bufferViews']):
        off, old_len = new_offsets[idx], len(new_datas[idx])
        bv['byteOffset'] = off
        bv['byteLength'] = old_len
    # Update buffer
    j['buffers'][0]['byteLength'] = len(new_bin)
    # Remove uri if any
    if 'uri' in j['buffers'][0]:
        del j['buffers'][0]['uri']

    # Write new GLB
    json_str = json.dumps(j, separators=(',', ':'))
    json_bytes = json_str.encode('utf-8')
    # Pad JSON to 4 with spaces (0x20)
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b' ' * json_pad
    json_len_new = len(json_bytes)
    bin_len_new = len(new_bin)
    # BIN chunk needs pad to 4, but new_bin already padded per chunk, but ensure overall pad?
    # Actually new_bin length is already padded per chunk, but we should ensure total BIN length is correct
    total_len = 12 + 8 + json_len_new + 8 + bin_len_new
    header = struct.pack('<4sII', b'glTF', 2, total_len)
    json_header = struct.pack('<II', json_len_new, 0x4E4F534A)  # JSON
    bin_header = struct.pack('<II', bin_len_new, 0x004E4942)  # BIN
    out_data = header + json_header + json_bytes + bin_header + bytes(new_bin)
    p.write_bytes(out_data)
    print(f"  saved {len(out_data)/1024:.1f} KB (was {len(data)/1024:.1f} KB)")

if __name__ == "__main__":
    base = pathlib.Path(r"D:\PROJETOS\Little sword\src\assets\terrenos\tileset")
    for name in ["agua tileset.glb","agua curva tileset.glb","agua metade tileset.glb"]:
        resize_glb_manual(base / name, 1024)
    base2 = pathlib.Path(r"D:\PROJETOS\Little sword\src\assets\tilesets")
    for name in ["agua tileset.glb","agua curva tileset.glb","agua metade tileset.glb"]:
        p = base2 / name
        if p.exists():
            resize_glb_manual(p, 1024)
