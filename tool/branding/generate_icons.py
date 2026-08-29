"""Pembuat ikon aplikasi Antaride.

==============================================================================
 KENAPA DIGAMBAR KODE, BUKAN DIEKSPOR DARI FIGMA
==============================================================================
 Ikon peluncur dibutuhkan dalam belasan ukuran, dan tiga aplikasi memakai mark
 yang SAMA dengan warna berbeda. Mengekspornya manual berarti 3 x belasan berkas
 yang harus diekspor ulang setiap kali marknya disentuh — dan satu yang terlewat
 tidak terlihat sampai ada yang memasang APK-nya di HP dengan kerapatan layar
 itu.

 Berkas ini menghasilkan SELURUHNYA dari satu definisi bentuk: master
 1024x1024, mipmap Android setiap kerapatan, adaptive icon beserta XML-nya, dan
 AppIcon iOS. Mengubah marknya berarti mengubah satu fungsi, lalu menjalankan
 ulang.

==============================================================================
 MARKNYA: HURUF "A" YANG JUGA PANAH ARAH
==============================================================================
 Tiga goresan tebal berujung bulat: dua kaki bertemu di puncak, satu palang
 melintang. Terbaca sebagai huruf A (Antaride) sekaligus panah yang menunjuk ke
 depan.

 Yang menentukan bentuknya BUKAN selera, tapi ukuran terkecilnya: 48 dp di
 laci aplikasi, sekitar 48 piksel di layar mdpi. Pada ukuran itu detail apa pun
 hilang — yang tersisa hanya siluet. Karena itu tidak ada gradien, tidak ada
 garis tipis, dan tidak ada teks.

==============================================================================
 TIGA APLIKASI HARUS BISA DIBEDAKAN SEKILAS
==============================================================================
 Ketiganya bisa terpasang di satu HP sekaligus — driver yang memesan ojek saat
 kendaraannya di bengkel punya dua di antaranya.

 Yang membedakan LATAR, bukan marknya: mark yang berbeda berarti tiga merek,
 dan pengguna tidak akan mengenalinya sebagai satu keluarga. Ini pola yang sama
 dengan Gojek/GoPartner dan Grab/Grab Driver.

 Kontras warnanya juga diperiksa: pembeda yang hanya warna gagal untuk pengguna
 buta warna. Karena itu latar driver JAUH lebih gelap daripada dua lainnya —
 bedanya terlihat sebagai terang/gelap, bukan hanya sebagai rona.

==============================================================================
 KENAPA TIDAK MEMAKAI `flutter_launcher_icons`
==============================================================================
 Paket itu memang untuk pekerjaan ini, dan itu pilihan pertama. Yang
 menghalanginya konflik dependency yang tidak bisa dihindari:

     flutter_launcher_icons >=0.13  ->  cli_util ^0.4
     melos 8.5.0                    ->  cli_util ^0.5

 Keduanya dev dependency di workspace yang sama, jadi pub menolak resolusinya.
 Menurunkan melos berarti kehilangan dukungan pub workspace; memakai
 flutter_launcher_icons 0.9 berarti sintaks konfigurasi lama yang sudah tidak
 didokumentasikan lagi.

 Yang dilakukan paket itu untuk kita sebenarnya sederhana: mengecilkan satu
 gambar ke belasan ukuran dan menulis dua berkas XML. Itu dikerjakan di sini,
 dan hasilnya nol dependency baru.

==============================================================================
 CARA MENJALANKAN
==============================================================================
     pip install Pillow
     python tool/branding/generate_icons.py

 Menghasilkan seluruhnya sekaligus: master, mipmap Android setiap kerapatan,
 adaptive icon beserta XML-nya, dan AppIcon iOS. Tidak ada langkah kedua.
"""

from __future__ import annotations

import io
import json
import os

from PIL import Image, ImageDraw

# ==============================================================================
#  Ukuran
# ==============================================================================

MASTER = 1024

# Digambar 4x lalu dikecilkan.
#
# Pillow tidak punya anti-aliasing saat menggambar bentuk. Tanpa supersampling,
# setiap tepi miring — dan mark ini seluruhnya tepi miring — bergerigi. Pada
# ikon 48 piksel gerigi itu terlihat sebagai bentuk yang kotor.
SKALA = 4
KANVAS = MASTER * SKALA


# ==============================================================================
#  Warna
# ==============================================================================
#  Diambil dari `ClayTokens` supaya ikonnya satu keluarga dengan aplikasinya.
#  Ikon dengan hijau yang sedikit berbeda dari layar pertama aplikasi terbaca
#  sebagai kurangnya perhatian, walaupun tidak ada yang bisa menyebut apa yang
#  salah.

PRIMARY = (0x0E, 0x9F, 0x6E)        # ClayTokens.primary
PRIMARY_LIGHT = (0x31, 0xC4, 0x8D)  # ClayTokens.primaryLight
WARNING = (0xD9, 0x77, 0x06)        # ClayTokens.warning
PUTIH = (0xFF, 0xFF, 0xFF)

# Hijau yang jauh lebih gelap daripada `primary`, bukan abu-abu netral: aplikasi
# driver harus tetap terbaca sebagai Antaride, bukan sebagai aplikasi lain.
DRIVER_BG = (0x06, 0x2E, 0x1E)


VARIAN = {
    'customer': {'bg': PRIMARY, 'mark': PUTIH, 'label': 'Penumpang'},
    'driver': {'bg': DRIVER_BG, 'mark': PRIMARY_LIGHT, 'label': 'Driver'},
    'merchant': {'bg': WARNING, 'mark': PUTIH, 'label': 'Merchant'},
}


def goresan(
    draw: ImageDraw.ImageDraw,
    a: tuple[float, float],
    b: tuple[float, float],
    lebar: float,
    warna: tuple[int, int, int],
) -> None:
    """Garis tebal berujung BULAT.

    `ImageDraw.line` punya `joint` tapi tidak punya ujung bulat, jadi ujungnya
    digambar sebagai lingkaran terpisah. Ujung siku pada mark setebal ini
    terlihat kaku dan bertabrakan dengan bahasa claymorphism aplikasinya.
    """
    draw.line([a, b], fill=warna, width=int(lebar))

    r = lebar / 2

    for x, y in (a, b):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=warna)


def gambar_mark(
    draw: ImageDraw.ImageDraw,
    warna: tuple[int, int, int],
    pusat: tuple[float, float],
    tinggi: float,
) -> None:
    """Huruf A dari tiga goresan.

    `tinggi` adalah tinggi total huruf. Seluruh geometri diturunkan darinya
    supaya mark bisa diperbesar untuk ikon penuh dan diperkecil untuk lapisan
    adaptive — tanpa menyetel ulang satu angka pun.
    """
    cx, cy = pusat

    atas = cy - tinggi / 2
    bawah = cy + tinggi / 2

    lebar_goresan = tinggi * 0.20
    rentang = tinggi * 0.42   # jarak kaki dari sumbu tengah

    puncak = (cx, atas + lebar_goresan / 2)

    kaki_kiri = (cx - rentang, bawah - lebar_goresan / 2)
    kaki_kanan = (cx + rentang, bawah - lebar_goresan / 2)

    goresan(draw, puncak, kaki_kiri, lebar_goresan, warna)
    goresan(draw, puncak, kaki_kanan, lebar_goresan, warna)

    # Palang melintang.
    #
    # Ditempatkan pada 68% tinggi, bukan di tengah. Palang di tengah membuat
    # ruang segitiga di atasnya terlalu kecil dan tertutup sendiri pada ukuran
    # kecil — huruf A-nya berubah menjadi segitiga penuh.
    y_palang = atas + tinggi * 0.68

    # Titik potong kaki pada ketinggian palang, supaya ujung palang berhenti
    # tepat di kakinya alih-alih menonjol keluar.
    t = (y_palang - puncak[1]) / (kaki_kiri[1] - puncak[1])
    x_kiri = puncak[0] + (kaki_kiri[0] - puncak[0]) * t
    x_kanan = puncak[0] + (kaki_kanan[0] - puncak[0]) * t

    goresan(
        draw,
        (x_kiri, y_palang),
        (x_kanan, y_palang),
        lebar_goresan * 0.86,
        warna,
    )


def latar_clay(ukuran: int, warna: tuple[int, int, int]) -> Image.Image:
    """Latar rata dengan sorotan halus di kiri atas.

    Claymorphism di aplikasi ini memakai arah cahaya kiri-atas
    (`ClayTokens.lightDirection`). Sorotan di sini mengikutinya supaya ikon dan
    permukaan di dalam aplikasi terlihat diterangi cahaya yang sama.

    Sangat halus dengan sengaja: gradien kuat pada ikon 48 piksel hanya
    membuatnya terlihat kotor.
    """
    dasar = Image.new('RGB', (ukuran, ukuran), warna)

    sorot = Image.new('L', (ukuran, ukuran), 0)
    draw = ImageDraw.Draw(sorot)

    pusat = (ukuran * 0.30, ukuran * 0.24)
    radius = ukuran * 0.78

    # Digambar sebagai cincin-cincin sepusat, dari luar ke dalam.
    langkah = 90

    for i in range(langkah, 0, -1):
        r = radius * i / langkah
        alpha = int(26 * (1 - i / langkah) ** 1.6)

        draw.ellipse(
            [pusat[0] - r, pusat[1] - r, pusat[0] + r, pusat[1] + r],
            fill=alpha,
        )

    putih = Image.new('RGB', (ukuran, ukuran), PUTIH)

    return Image.composite(putih, dasar, sorot).convert('RGB')


def buat_ikon_penuh(varian: str) -> Image.Image:
    """Ikon lengkap dengan latar — untuk iOS dan Android lawas."""
    v = VARIAN[varian]

    latar = latar_clay(KANVAS, v['bg'])

    lapisan = Image.new('RGBA', (KANVAS, KANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(lapisan)

    # 52% dari kanvas.
    #
    # Ikon iOS dipotong menjadi squircle, dan Android lawas memberi bingkai
    # sendiri. Mark yang memenuhi kanvas akan terpotong di sudutnya.
    gambar_mark(draw, v['mark'], (KANVAS / 2, KANVAS / 2), KANVAS * 0.52)

    latar = latar.convert('RGBA')
    latar.alpha_composite(lapisan)

    return latar.convert('RGB').resize((MASTER, MASTER), Image.LANCZOS)


def buat_foreground(varian: str) -> Image.Image:
    """Lapisan depan adaptive icon Android — transparan, tanpa latar.

    ==========================================================================
     MARKNYA LEBIH KECIL DI SINI, DAN ITU WAJIB
    ==========================================================================
     Android memotong lapisan ini dengan bentuk yang DITENTUKAN PELUNCUR:
     lingkaran, squircle, kotak membulat, atau tetesan — berbeda per merek HP.

     Yang dijamin selalu terlihat hanya lingkaran tengah selebar 66/108 kanvas
     (sekitar 61%). Mark yang lebih besar dari itu akan terpotong di sebagian
     HP dan utuh di sebagian lain — dan yang mengujinya di satu HP tidak akan
     pernah melihat masalahnya.

     36% dipilih supaya mark tetap punya ruang napas di dalam lingkaran aman
     itu, bukan menyentuh tepinya.
    ==========================================================================
    """
    v = VARIAN[varian]

    lapisan = Image.new('RGBA', (KANVAS, KANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(lapisan)

    gambar_mark(draw, v['mark'], (KANVAS / 2, KANVAS / 2), KANVAS * 0.36)

    return lapisan.resize((MASTER, MASTER), Image.LANCZOS)


# ==============================================================================
#  Android
# ==============================================================================
#  Angka-angka ini BUKAN pilihan bebas. Android menuntut ikon peluncur 48 dp,
#  dan setiap kerapatan layar mengalikannya: mdpi 1x, hdpi 1.5x, xhdpi 2x,
#  xxhdpi 3x, xxxhdpi 4x.
#
#  Kerapatan yang berkasnya tidak ada akan diambil Android dari kerapatan lain
#  lalu diskalakan sendiri — dan hasilnya buram. Itu terlihat sebagai aplikasi
#  yang tidak selesai, pada HP yang kebetulan memakai kerapatan itu.

MIPMAP = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}

# Adaptive icon memakai kanvas 108 dp — lebih besar daripada ikonnya sendiri.
# Kelebihannya ruang untuk animasi parallax yang dilakukan sebagian peluncur
# saat ikonnya disentuh.
ADAPTIVE = {nama: round(ukuran * 108 / 48) for nama, ukuran in MIPMAP.items()}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

WARNA_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{warna}</color>
</resources>
"""


def tulis_android(akar: str, varian: str, penuh: Image.Image, depan: Image.Image) -> int:
    """Seluruh mipmap, adaptive icon, dan warna latarnya."""
    res = os.path.join(akar, 'apps', varian, 'android', 'app', 'src', 'main', 'res')

    jumlah = 0

    for nama, ukuran in MIPMAP.items():
        d = os.path.join(res, f'mipmap-{nama}')
        os.makedirs(d, exist_ok=True)

        penuh.resize((ukuran, ukuran), Image.LANCZOS).save(
            os.path.join(d, 'ic_launcher.png'), 'PNG', optimize=True,
        )

        depan.resize((ADAPTIVE[nama], ADAPTIVE[nama]), Image.LANCZOS).save(
            os.path.join(d, 'ic_launcher_foreground.png'), 'PNG', optimize=True,
        )

        jumlah += 2

    # `anydpi-v26`: hanya dibaca Android 8+. Versi lawas mengabaikan direktori
    # ini sepenuhnya dan tetap memakai PNG di atas — itulah cara satu APK
    # melayani keduanya.
    d = os.path.join(res, 'mipmap-anydpi-v26')
    os.makedirs(d, exist_ok=True)

    for nama in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        io.open(os.path.join(d, nama), 'w', encoding='utf-8').write(ADAPTIVE_XML)
        jumlah += 1

    d = os.path.join(res, 'values')
    os.makedirs(d, exist_ok=True)

    warna = '#%02X%02X%02X' % VARIAN[varian]['bg']

    io.open(
        os.path.join(d, 'ic_launcher_background.xml'), 'w', encoding='utf-8',
    ).write(WARNA_XML.format(warna=warna))

    return jumlah + 1


# ==============================================================================
#  iOS
# ==============================================================================


def tulis_ios(akar: str, varian: str, penuh: Image.Image) -> int:
    """AppIcon set iOS, mengikuti `Contents.json` yang sudah ada.

    Daftar ukurannya DIBACA dari Contents.json, bukan ditulis ulang di sini.
    Xcode menolak asset catalog yang berkasnya tidak cocok dengan manifesnya,
    dan daftar yang disalin akan menyimpang begitu Xcode memperbarui
    templatnya.

    ==========================================================================
     TANPA KANAL ALPHA
    ==========================================================================
     App Store MENOLAK ikon iOS yang punya transparansi, dan penolakannya
     terjadi saat unggah — setelah build selesai dan setelah menunggu antrean
     proses. `penuh` sudah RGB, tapi disebut di sini supaya tidak ada yang
     menggantinya dengan `depan` yang transparan.
    ==========================================================================
    """
    d = os.path.join(
        akar, 'apps', varian, 'ios', 'Runner',
        'Assets.xcassets', 'AppIcon.appiconset',
    )

    manifes = os.path.join(d, 'Contents.json')

    if not os.path.exists(manifes):
        return 0

    with io.open(manifes, encoding='utf-8') as f:
        data = json.load(f)

    jumlah = 0

    for gambar in data.get('images', []):
        berkas = gambar.get('filename')

        if not berkas:
            continue

        # "60x60" + scale "3x" -> 180 piksel
        sisi = float(gambar['size'].split('x')[0])
        skala = float(str(gambar.get('scale', '1x')).rstrip('x'))

        piksel = int(round(sisi * skala))

        penuh.resize((piksel, piksel), Image.LANCZOS).save(
            os.path.join(d, berkas), 'PNG', optimize=True,
        )

        jumlah += 1

    return jumlah


def main() -> None:
    akar = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    for varian, v in VARIAN.items():
        tujuan = os.path.join(akar, 'apps', varian, 'assets', 'branding')
        os.makedirs(tujuan, exist_ok=True)

        penuh = buat_ikon_penuh(varian)
        depan = buat_foreground(varian)

        penuh.save(os.path.join(tujuan, 'icon.png'), 'PNG', optimize=True)
        depan.save(os.path.join(tujuan, 'icon_foreground.png'), 'PNG', optimize=True)

        n_android = tulis_android(akar, varian, penuh, depan)
        n_ios = tulis_ios(akar, varian, penuh)

        warna = '#%02X%02X%02X' % v['bg']

        print(
            f'  {v["label"]:10} bg={warna}   master 2  '
            f'android {n_android}  ios {n_ios}'
        )


if __name__ == '__main__':
    main()
